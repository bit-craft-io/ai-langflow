# 前提・未決定事項

`docs/rules/0001-aws-migration.md` と `docs/decisions/*.md` を確認したが、移行構成を具体化する上で必須にもかかわらず
コード・ドキュメント上に根拠がない論点がいくつかあった。うち構造を大きく左右する3点はユーザーに確認済み。
残りは推測で断定せず、採用した前提には理由を明記し、断定できないものは「未決定」として残す。

## ユーザーに確認済みの前提

1. **IaCツール = Terraform**
2. **コンピュート基盤 = EC2上でdocker composeを継続**（ECS/EKSへの作り替えは行わない）
3. **ローカルLLM(LM Studio)は廃止し、Gemini API単独で継続**（Bedrockへの置き換えは行わない）

3.の帰結として、[ADR-0003](../../docs/decisions/0003-local-llm-with-cloud-fallback.md)の
「ローカルLLM優先 + 信頼度スコアによるクラウドLLMフォールバック」ロジック（`agent`フロー）はAWS環境では使わない。
代わりに、既存の`gemini.json`フロー（"Cloud LLM only"、`GeminiWithRetry` + `SearchRag`によるRAG付き）を使う前提とし、
bridgeの環境変数 `LANGFLOW_FLOW_ID=gemini` で切り替える（`cloud/docker/compose/docker-compose.agent.yaml`）。
これはLangflow/Bridgeのコード自体を変更するものではなく、既存の設定機構（pydantic-settings、
[ADR-0009](../../docs/decisions/0009-plaintext-env-file-secrets.md)/[ADR-0010](../../docs/decisions/0010-duplicated-utils-per-component.md)）
の範囲内での環境変数指定である前提（未確認事項10.参照）。

## 採用した前提（理由つき）

### 1. EC2は1台のみ（Auto Scaling等は組まない）

- 「EC2上でdocker composeを継続」という回答は、Composeによる単一ホスト上での協調動作を前提にした選択だと解釈した。
  複数台にスケールする場合、Compose自体が単一ホスト向けの仕組みであるため、より大きな構成変更
  （ECS/EKS化、またはCompose用のクラスタリングツール導入）が必要になる。可用性要件次第で見直すこと
  （未決定事項「C.」参照）。

### 2. Langflowのflowsファイルの配置 = S3経由でEC2ホストへsync、bindマウントは維持

- on-premisesでは `./langflow/agents:/app/flows` をホストbindマウントしている（[ADR-0001](../../docs/decisions/0001-docker-compose-microservices.md)）。
  EC2はホストの実ファイルシステムを持つため、on-premisesと同じ `langflowai/langflow:1.11.0` イメージ・同じbindマウント方式を維持できる
  （ECS Fargateのようにカスタムイメージへ焼き込む必要がない）。
- Terraformの`fileset()`で`on-premises/server/langflow/agents`配下のファイルをS3へ個別アップロードし（`cloud/terraform/modules/ec2_docker_host`）、
  EC2起動時（user-data）に`aws s3 sync`でホストへ取得してからbindマウントする。
- 副作用: フロー更新の反映には「S3へ再アップロード（terraform apply）→ EC2ホストでの再sync」が必要（on-premisesはファイル配置のみで反映）。
  頻繁に更新する運用であれば、`aws s3 sync`を定期実行するcronや、CI/CDからのデプロイ自動化を別途検討すること。

### 3. stamina状態(`/app/data/stamina.json`)の永続化先 = EC2ローカルディスク（EBS）

- [ADR-0006](../../docs/decisions/0006-stamina-state-persisted-in-langflow-volume.md) はコンテナ内ファイルへのJSON永続化を前提にしたロジック
  （`RecoverStaminaComponent`等）であり、アプリケーションコード自体は変更しない前提のため、on-premisesと同じ
  「ホスト上のディレクトリをbindマウント」方式をEC2上でも維持する（`/opt/agent/langflow-data:/app/data`）。
- 当初EFSへの切り出しを検討したが、EC2+docker compose継続という確認済み前提や`docs/rules/0001-aws-migration.md`の
  方針（「SQLite → RDS」以外のマネージド化はスコープ外）に照らすと、EFS採用を裏付けるADR/ルール上の根拠がなかった
  ため撤回した（下記「9.」参照）。EBSのみだとインスタンス入れ替え時にデータが
  失われるリスクは残るが、可用性要件（未決定事項「B.」参照）が明確になった段階でEFS等への切り出しを再検討すること。
- `langflow-init`（`chown -R 1000:0 /app/data`、[ADR-0001](../../docs/decisions/0001-docker-compose-microservices.md)）が担っていた権限初期化は、
  EC2起動時のuser-dataでの`chown`実行に置き換え、initコンテナ自体は廃止した。

### 4. Langflow DB = RDS for PostgreSQL

- `docs/rules/0001-aws-migration.md` の「SQLite → RDS(PostgreSQL)等 マネージド化検討」に従いRDSを採用。
- Firecrawl(nuq-postgres)用のRDSは作らない。firecrawl-api自体が移行対象外のため（下記「9.」参照）。

### 5. （欠番）

Firecrawl関連（nuq-postgres/redis/rabbitmq、`foundationdb`のfdb経路を含む）はfirecrawl-api自体が
`docs/rules/0001-aws-migration.md`「スコープ外」により移行対象外と判明したため、個別の検討自体が不要になった。
詳細は下記「9.」参照。

### 6. OpenSearch / OpenSearch DashboardsはAmazon OpenSearch Serviceにせず、EC2上のコンテナのまま維持する

- [ADR-0001](../../docs/decisions/0001-docker-compose-microservices.md) の通り、opensearch/opensearch-uiは
  Firecrawl側の compose project（`agent-crawl`）ではなく、on-premisesの本体 compose project
  （voicevox/langflow/bridgeと同じ）に属する6サービスの1つである。firecrawl-apiが移行対象外であっても
  opensearch自体は対象外にならない。
- 「EC2上でdocker compose継続」という確認済み前提のもとで、on-premisesと同じくEC2上のコンテナとして
  そのまま起動する（`DISABLE_SECURITY_PLUGIN=true`も含め設定を変えない）。Amazon OpenSearch Serviceへ
  切り出す・fine-grained access controlを有効化するといった変更を裏付けるADR/ルール上の根拠がなかった
  ため、当初実装していたそれらは撤回した。詳細は下記「9.」参照。

### 7. bridge-frontend / Client はprod構成のスコープ外

- `docs/spec/as-is.md`に記載の通り、bridge-frontendは開発用オーバーレイでのみ起動するデバッグ用React UIであり、
  Clientはエンドユーザ端末（将来的にはUnity）側の成果物でサーバ側インフラではない。
  `docs/rules/0001-aws-migration.md`は「on-premises構成をAWS上で動作する構成に変換する」というサーバ側インフラの移行が主旨と解釈し、
  両者はAWS配置の対象に含めなかった。bridge-frontendを常時デプロイしたい場合は、S3+CloudFrontによる静的ホスティングを追加する。

### 8. デプロイパイプライン（CI/CD）は対象外

- `docs/rules/0001-aws-migration.md`にCI/CDに関する記述がないため、イメージのビルド・ECRへのpush・EC2への配布は
  手動実行を前提としたコマンド例（README.md「使い方」参照）のみ用意し、GitHub Actions等のパイプライン構築は行っていない。

### 9. firecrawl-api関連の管理インフラ、およびOpenSearch/Langflowデータの根拠なきマネージドサービス化を撤回

当初の実装では、以下をTerraformモジュールとして構築していたが、いずれも`docs/rules/0001-aws-migration.md`や
`docs/decisions/*.md`に根拠を持つ決定ではなく、実装時の推測（本ドキュメントの旧版で自己正当化していた内容）に
過ぎなかった。「推測で変えず、不明点は質問」というルール文書の指示に反していたため、全て是正した。

- **RDS(nuq-postgres)・ElastiCache for Redis・Amazon MQ(RabbitMQ)は削除**（モジュール自体も削除）。
  `docs/rules/0001-aws-migration.md`「スコープ外」に明記の通り、**firecrawl-api / playwright-serviceは
  移行対象外**（Cloud API課金のため）であり、「関連するdocker compose / Terraform / ドキュメントの記述も
  今後追加しないこと」と明示されている。これらはいずれもFirecrawl自身の compose project（`agent-crawl`、
  [ADR-0007](../../docs/decisions/0007-vendored-firecrawl.md)）の内部サービスであり、firecrawl-apiが
  動かない以上、裏側インフラも存在理由がない。
- **Amazon OpenSearch Service（fine-grained access control含む）は削除し、EC2上のコンテナに戻した**
  （モジュールは削除、代わりに`cloud/docker/compose/docker-compose.agent.yaml`にopensearch/opensearch-uiを
  on-premisesと同じ設定で追加）。OpenSearch自体は[ADR-0001](../../docs/decisions/0001-docker-compose-microservices.md)
  どおり本体 compose project に属し移行対象外ではないが、それを個別マネージドサービスへ切り出すこと・
  セキュリティプラグインを有効化することを裏付けるADR/ルール上の根拠がなかったため、この2点のみ撤回した
  （上記「6.」参照）。
- **EFSは削除し、EC2ローカルディスクに戻した**（モジュールは削除）。Langflowの`/app/data`永続化用で
  firecrawl-apiとは無関係だが（上記「3.」参照）、EC2ローカルディスクではなくEFSに切り出すことを裏付ける
  ADR/ルール上の根拠がなかったため撤回した。
- 上記に伴い、`cloud/terraform/modules/ec2_docker_host`のuser-dataスクリプトから、存在しなくなった
  `docker-compose.agent-crawl.yaml`の取得・起動処理、およびredis/rabbitmq/opensearch(管理サービス版)/
  rds_firecrawl向けのシークレット取得・環境変数生成処理を削除した。

## 未決定（要確認・要検証事項）

### 10. Langflowフロー（`gemini.json`等）がコンテナ環境変数から接続先を実際に読み取れるか

[ADR-0005](../../docs/decisions/0005-rag-firecrawl-opensearch.md)によれば、`SearchRag`コンポーネントの
`opensearch_url`/`username`はコンポーネントのデフォルト値として実装されており、`rag.json`側の設定値は
Langflowの「グローバル変数」機能（`GlobalConfigCreate`/`GlobalConfigRead`）経由で保持されている可能性がある
（本リポジトリのコードからは実値を読み取れない、ADR-0005「Consequences」参照）。

つまり `cloud/docker/compose/docker-compose.agent.yaml` で `OPENSEARCH_URL` 等をコンテナ環境変数として渡しても、
Langflowの各コンポーネントが実際にその環境変数を読みに行く実装になっているとは限らない。
その場合、Langflow起動後にUI/API経由でグローバル変数を設定する追加作業が必要になる。
デプロイ後、実際のflow実行結果を確認して検証すること（README.md「未実施」参照）。

同様に、bridgeの`LANGFLOW_FLOW_ID`環境変数がBridgeのpydantic-settings実装で本当にこの名前で読み込まれるかも
未検証（[ADR-0002](../../docs/decisions/0002-websocket-client-bridge-protocol.md)/[ADR-0006](../../docs/decisions/0006-stamina-state-persisted-in-langflow-volume.md)に
`langflow_flow_id: str = "chat"`というフィールド名の記載はあるが、pydantic-settingsの環境変数名マッピング規則
（大文字化されるか、`env_prefix`が設定されているか等）はコードを直接確認していない）。

### A. 独自ドメイン・TLS証明書の有無

ALB用のACM証明書ARNは`terraform.tfvars.example`で空のプレースホルダにしている。独自ドメインを使うか、
デフォルトのALB DNS名のままでよいか（WebSocket接続のClientからの到達性要件次第）が不明なため確認が必要。

### B. 可用性要件

RDS/EC2は`terraform.tfvars.example`でシングルインスタンス・最小サイズをデフォルトにしている
（検証環境相当のコスト優先設定。「EC2上でdocker compose継続」という選択自体も、Compose特性上、水平スケールしにくい）。
本番の可用性要件（SLA、許容ダウンタイム）が不明なため、マルチAZ化やインスタンスサイズ、EC2の冗長化方式
（Auto Scaling + 何らかのオーケストレーション導入等）は要件確認の上で見直すこと。

### C. EC2インスタンスサイジング

voicevox / langflow / bridge / opensearch / opensearch-ui を1台（デフォルト`t3.large`）に同居させる構成にしているが、
実際の負荷（同時接続数、OpenSearchのインデックスサイズ等）に基づくサイジング検証は行っていない。

## コスト最小構成（`envs/dev`）に関して確認済みの前提

### D. `envs/dev`はNAT Gateway・ALBを作らない（ユーザー確認済み）

コストを極力抑えたいという要望を受け、検証・開発用の`cloud/terraform/envs/dev`を追加した。
`envs/prod`との差分は以下の2点（いずれもコスト影響とセキュリティ境界のトレードオフをユーザーに確認済み）。

- **NAT Gatewayを作らない**（`modules/network`に`create_nat_gateway`変数を追加）。EC2ホストをパブリックサブネットに
  直置きし、IGW経由で直接インターネットへ出る。RDS（langflow用）はVPC内到達性のみで完結し、
  インターネットへの経路を必要としないため、NAT Gatewayが不要になる。
  単独で月$35〜45+（データ転送料別）かかり、この構成の中で最大のコスト要因だったため削減効果が大きい。
- **ALBを作らない**（`modules/ec2_docker_host`に`enable_alb`/`direct_ingress_cidr_blocks`変数を追加）。
  ClientはEC2のパブリックIP:8765へ直接WebSocket接続する。ALBの固定費（月$16〜20+LCU）を削減できる代わりに、
  HTTPS/独自ドメイン対応・ヘルスチェックによる自動復旧は失われる。EC2のセキュリティグループでは
  `direct_ingress_cidr_blocks`（`terraform.tfvars`で明示指定必須、`0.0.0.0/0`は非推奨）からの8765番ポートのみ許可する。

その後、上記「9.」の是正によりfirecrawl-api関連の管理インフラ（RDS/ElastiCache/Amazon MQ）と
Amazon OpenSearch Service・EFSを削除し、下記「F.」の是正によりRDS(langflow用)も
削除したため、`envs/dev`が実際に構築するAWSリソースはEC2 1台・ECR・Secrets Manager・S3・VPC関連のみになった
（下記「E.」の是正により、当初削除していたECRを再度作成することにした）。
opensearch/opensearch-uiはEC2上のコンテナとして動くため追加のマネージドサービス費用は発生しない。
月合計でおおよそ$15〜20程度（EC2 t3.small ~$15 + Secrets Manager/S3/ECRストレージ少々、ap-northeast-1の
オンデマンド価格の概算、データ転送料別）まで下がっている。さらに削減する場合の選択肢:

- 使わない期間は`terraform destroy`する運用。
- EC2のスポットインスタンス化（中断リスクとのトレードオフ、今回は未対応）。

### E. `envs/dev`もECRへpushした既成イメージ（`image:`参照）を使う運用にする（方針変更）

当初は`envs/dev`のみ、bridgeの開発イテレーション（コード変更→即確認）を優先して、EC2上でリポジトリを
直接git clone/pullしてdocker composeでビルドする運用にしていた。しかし実際の運用では、EC2上に
ビルド元ソース（`/opt/bridge-src`）を配置し忘れたままuser-dataが実行されビルド失敗が頻発したことと、
t3.small（2vCPU/2GiB、ADR-0012参照）上でのdocker buildが非効率（他サービスと同居中のリソース圧迫・
ビルド時間）だったため、`envs/prod`と同じく事前ビルド済みイメージをECR経由でpullする運用に変更した。

- `envs/dev/main.tf`に`module "ecr"`を追加。ただしprodの`module "ecr"`（リポジトリ名`${local.name_prefix}-bridge`
  = `agent-prod-bridge`、環境ごとに命名）とは異なり、devは固定のリポジトリ名`agent-bridge`を使う
  （`bridge_image`をterraform.tfvarsで直接指定する運用のため、環境間でのリポジトリ命名の対称性は崩れている。
  将来的にprodと同じ命名規則に揃える場合は要調整）。
- `envs/dev/variables.tf`に`bridge_image`変数（必須、デフォルトなし）を追加し、`compute.tf`から
  `modules/ec2_docker_host`の`bridge_image`にそのまま渡す（prodのように`module.ecr.repository_urls[...]`から
  自動導出せず、`terraform.tfvars`で明示的に指定する）。
- `cloud/docker/compose/docker-compose.agent.dev.yaml`のbridgeサービス定義を、コメントアウトされていた
  `build:`版から`docker-compose.agent.yaml`と同じ`image: ${BRIDGE_IMAGE}`版に変更。
- ビルド・pushの手動実行手順は`cloud/scripts/build_and_push_bridge.sh`としてスクリプト化した
  （`docs/rules/0001-aws-migration.md`にCI/CD関連の記述がなくパイプライン構築はスコープ外、上記「8.」と同じ判断。
  自動化はせず手動実行前提のまま）。

### F. `envs/dev`のEC2インスタンスタイプはt3.small、LangflowのDBはRDSではなくSQLiteのままとする（ユーザー確認済み、[ADR-0012](../../docs/decisions/0012-dev-env-ec2-instance-sizing.md)/[ADR-0013](../../docs/decisions/0013-dev-env-sqlite-instead-of-rds.md)参照）

コストを極力抑えたいという要望を受け、`envs/dev`についてさらに以下の2点を見直した。詳細な理由・影響は
それぞれ対応するADRに記載しているため、ここでは要点のみ記す。

- **EC2インスタンスタイプ = t3.small**（デフォルト`t3.medium`から変更）。動作確認用途のみのため。
  `t3.micro`はOpenSearch等5サービス同居時のメモリ不足リスクが高いため見送った（[ADR-0012](../../docs/decisions/0012-dev-env-ec2-instance-sizing.md)）。
- **LangflowのDB = RDSではなくSQLiteのまま**。`module "rds_langflow"`を`envs/dev`から削除し、
  `docker-compose.agent.dev.yaml`のlangflowを on-premisesと同じ`sqlite:////app/data/langflow.db`に戻した。
  PostgreSQLへの移行検証は`envs/prod`側で行う（[ADR-0013](../../docs/decisions/0013-dev-env-sqlite-instead-of-rds.md)）。
  `modules/ec2_docker_host`の`rds_langflow_*`変数は空文字/0許容にし、未指定時はuser-dataでのRDSシークレット
  取得・`.env`への`LANGFLOW_DATABASE_URL`書き込みをスキップする。`envs/prod`には影響しない。
