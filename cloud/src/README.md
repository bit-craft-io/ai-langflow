# cloud/ — AWS移行構成

`on-premises/` 配下の Docker Compose 構成（[ADR-0001](../docs/decisions/0001-docker-compose-microservices.md)）を
AWS上で動作させるための構成一式。`docs/rules/0001-aws-migration.md` の移行方針に従う。

**firecrawl-api / playwright-serviceは移行対象外**（`docs/rules/0001-aws-migration.md`「スコープ外」、
Cloud API課金のため）。このリポジトリにはそれらのAWS構成・関連インフラを含まない。

**`on-premises/` 配下のコードは変更しない。** ここは新規の並行構成であり、既存のオンプレ構成はそのまま残す。

## この構成の前提（ユーザー確認済み）

`docs/rules/0001-aws-migration.md` および `docs/decisions/` には明記がなかったため、着手前にユーザーへ確認した:

1. **IaCツール = Terraform**
2. **コンピュート基盤 = EC2上でdocker composeを継続**（ECS/EKSへの作り替えは行わない。既存のCompose定義に近い形を維持しつつ、
   `docs/rules/0001-aws-migration.md`で明示的にマネージド化が指示されているDB（SQLite→RDS）だけを切り出す。
   キュー/検索エンジンをマネージドサービスへ切り出す指示はないため、opensearch/opensearch-uiはon-premisesと同じくEC2上のコンテナのまま維持する）
3. **ローカルLLM(LM Studio)は廃止し、Gemini API単独で継続**（Bedrockへの置き換えは行わない）

上記以外にも、コード上の根拠がなく断定できなかった細部の前提は `cloud/docs/assumptions.md` にすべて明記した。
実装前に必ず目を通すこと。

## ディレクトリ構成

```
cloud/
├── README.md                    このファイル
├── docs/
│   ├── service-mapping.md       on-prem各サービス → AWSサービスの対応表と根拠
│   └── assumptions.md           推測で決めた前提と、未決定のまま残した論点の一覧
├── docker/
│   └── compose/
│       ├── docker-compose.agent.yaml        prod用。voicevox / langflow / bridge(ECRイメージ) / opensearch / opensearch-ui
│       │                                     （on-premisesのserver/docker-compose.yaml相当。firecrawl-api / playwright-serviceは移行対象外のため含まない）
│       └── docker-compose.agent.dev.yaml    dev用。prodと同じくbridgeはECRイメージ（image:）を参照する
├── terraform/
│   ├── modules/                 サービス単位で再利用可能なモジュール群
│   ├── envs/prod/               本番環境のルート構成（モジュールを呼び出して結線する）
│   └── envs/dev/                コスト最小構成（NAT Gateway/ALBなし、詳細は下記「コスト最小構成」参照）
└── scripts/
    └── build_and_push_bridge.sh  on-premises/server/bridge/backendをdocker buildしてECRへpushするスクリプト
```

## アーキテクチャ概要

EC2インスタンス1台の上で、on-premisesの本体compose project（[ADR-0001](../docs/decisions/0001-docker-compose-microservices.md)、
voicevox/langflow/bridge/opensearch/opensearch-ui）とほぼ同じdocker compose構成を1つ起動する
（firecrawl側のcompose project「`agent-crawl`」、[ADR-0008](../docs/decisions/0008-two-compose-projects-shared-network.md)は
firecrawl-apiごと移行対象外のため作らない）。
`docs/rules/0001-aws-migration.md`で明示的にマネージド化が指示されているLangflowのDB（SQLite→RDS）だけを
AWSマネージドサービスに切り出し、それ以外のアプリケーションコンテナ（voicevox / langflow / bridge /
opensearch / opensearch-ui）は既存のイメージ・DockerfileをそのままEC2上で実行する。

| 種別 | on-premises | AWS |
|---|---|---|
| アプリケーションコンテナ | Docker Compose (ローカル/開発機) | 同じcompose定義をEC2インスタンス上で実行 |
| Langflow DB | SQLite（コンテナ内ファイル） | RDS for PostgreSQL |
| OpenSearch / OpenSearch Dashboards | Composeコンテナ | 変更なし（EC2上のコンテナのまま。マネージドサービス化の根拠がないため） |
| Langflowの`/app/data`（stamina.json等） | コンテナボリューム | 変更なし（EC2ローカルディスク上のディレクトリへbindマウント） |
| `.env`平文キー | ローカルファイル | Secrets Manager（EC2起動時に取得し`.env`を生成） |
| Client → bridge の到達経路 | 直接接続 | ALB経由（WebSocketをそのままフォワード。`envs/dev`はALBなしでEC2に直接接続） |
| ローカルLLM(LM Studio) | Windowsホスト常駐 | **廃止**。langflowは`gemini`フロー（Cloud LLM単独、ADR-0003）を使用 |
| firecrawl-api / playwright-service（と裏側のredis/rabbitmq/nuq-postgres） | Composeコンテナ（`agent-crawl`project） | **移行対象外**（`docs/rules/0001-aws-migration.md`「スコープ外」） |

詳細な対応表・根拠は `docs/service-mapping.md` を参照。

## 使い方（想定）

EC2初回起動時のuser-dataはSecrets Managerからその場で値を取得して`.env`を生成する
（リトライなしの一発取得、`cloud/terraform/modules/ec2_docker_host/templates/user_data.sh.tftpl`参照）。
そのため、EC2を作る（`terraform apply`で`compute`を含める）より前に、シークレットの箱の作成・実値投入・
イメージのECR push を終わらせておく必要がある。3段階に分けてapplyする。

```
cd cloud/terraform/envs/prod
cp terraform.tfvars.example terraform.tfvars   # 値を編集（特にdeploy_bucket_nameは要変更）
terraform init   # backend.tf のS3バケット/DynamoDBロックテーブルは事前作成が必要

# 1段階目: ECRリポジトリだけ先に作成する
terraform apply -target=module.ecr
```

```
# on-premises/server/bridge/backend の既存Dockerfileをビルドし、ECRへpush
# （terraform output ecr_repository_urls のURLへ。CI/CDパイプラインの構築は今回のスコープ外）
```

```
# 2段階目: secretsの箱だけ先に作成する（CHANGE_MEプレースホルダが1回だけ書き込まれる）
terraform apply -target=module.secrets
```

```
# terraform output secret_arns に列挙されたシークレットへ実値
# （LANGFLOW_API_KEY, GOOGLE_API_KEY, LANGFLOW_SUPERUSER_PASSWORD）を投入する。
# aws secretsmanager put-secret-value を都度直接叩く代わりに cloud/scripts/put_secrets.sh を使う
# （値をコマンドライン引数ではなく環境変数で渡す設計。shell履歴に残さないため）。
# ここでEC2作成前に実値を入れておくのが重要（後回しにすると初回起動時の.envにCHANGE_MEが入る）。
LANGFLOW_API_KEY=... GOOGLE_API_KEY=... LANGFLOW_SUPERUSER_PASSWORD=... \
  ./cloud/scripts/put_secrets.sh agent-prod ap-northeast-1
```

```
# 3段階目: 残り（network/compute/rds/alb等）を含めて全体をapply
terraform plan
terraform apply
```

適用後の手順（Terraformの範囲外）:

1. `terraform output ec2_public_ip`（またはALB経由のエンドポイント）でClientの接続先を確認する。
2. イメージ更新時（シークレット値のローテーション時も同様）は、上記スクリプトで再度ビルド・push、
   または`put_secrets.sh`で値を入れ直した後、EC2インスタンスを再起動する
   （または`aws ssm send-command`でuser-data相当のスクリプトを再実行する）と、
   最新のイメージ・シークレット・flowsを取得してコンテナが起動し直す。

## コスト最小構成（`envs/dev`）

起動〜動作確認〜削除までの詳細な手順は [`cloud/docs/dev-runbook.md`](docs/dev-runbook.md) を参照
（本セクションは要点のみ）。

検証・開発用にコストを極力抑えた環境。`envs/prod`と同じモジュール群を使い回すが、以下の点が異なる
（ユーザー確認済み、詳細は`docs/assumptions.md`「D.」「E.」参照）。

- **NAT Gatewayを作らない** — EC2ホストをパブリックサブネットに直置きし、IGW経由で直接インターネットへ出る
  （RDSはVPC内到達性のみで完結するためNAT不要）。単独で月$35〜45+相当かかるこの構成最大のコスト要因を削減する。
- **ALBを作らない** — ClientはEC2のパブリックIP:8765へ直接WebSocket接続する。HTTPS/独自ドメイン対応や
  ヘルスチェックによる自動復旧は失われる（dev用途なら許容範囲という判断）。
- **ECR（`agent-bridge`リポジトリ）は作る** — 当初はEC2上でリポジトリをgit clone/pullして
  `docker compose build`する運用にしていたが、ソース未配置によるビルド失敗が頻発したことと、
  t3.small上でのビルドが非効率だったため、prodと同じくビルド済みイメージをECR経由でpullする運用に変更した
  （`docker-compose.agent.dev.yaml`参照。リポジトリ名はprodの`agent-prod-bridge`と異なり固定の`agent-bridge`）。

構築するAWSマネージドサービスはRDS(langflow用)のみ（opensearch/opensearch-uiはEC2上のコンテナのため
追加費用なし）。月合計でおおよそ$40〜50程度（EC2 t3.medium + RDS db.t4g.micro、詳細は`docs/assumptions.md`「D.」参照）。

初回構築は次の順序で行う（prodと同じ理由。EC2初回起動時のuser-dataがSecrets Managerから
その場で値を取得して`.env`を生成するリトライなしの一発取得のため、EC2を作る前にECR pushと
シークレット実値投入を終わらせておく必要がある。3段階apply）。
`agent-bridge`/`agent-langflow`の2リポジトリは`module.ecr`（本体applyの一部）で作成されるため、
まず`-target=module.ecr`だけを先にapplyしてリポジトリのみ作成し、それぞれのイメージをpushする。

```
cd cloud/terraform/envs/dev
cp terraform.tfvars.example terraform.tfvars   # 値を編集（dev_client_cidr_blocksは必須。deploy_bucket_name/bridge_image/langflow_imageはterraform側でaws_caller_identity/module.ecrから自動算出するため指定不要）
terraform init

# 1段階目: ECRリポジトリだけ先に作成する
terraform apply -target=module.ecr
```

```
# ローカルでビルドしてECRへpush（bridge/langflow両方）
./cloud/scripts/build_and_push_bridge.sh latest <AWSアカウントID> ap-northeast-1
./cloud/scripts/build_and_push_langflow.sh latest <AWSアカウントID> ap-northeast-1
```

```
# 2段階目: secretsの箱だけ先に作成する（CHANGE_MEプレースホルダが1回だけ書き込まれる）
terraform apply -target=module.secrets
```

```
# EC2作成前に実値を投入する（デフォルトは agent-dev / ap-northeast-1 なので引数省略可）。
# 後回しにすると初回起動時の.envにCHANGE_MEが入ってしまう。
# 壊す/作り直す運用（terraform destroy → 再apply）のたびにこの投入をやり直す必要がある点に注意
# （recovery_window_in_days=0のため実値はAWS側に残らない）。
LANGFLOW_API_KEY=... GOOGLE_API_KEY=... LANGFLOW_SUPERUSER_PASSWORD=... \
  ./cloud/scripts/put_secrets.sh
```

```
# 3段階目: 残り（network/compute等）を含めて全体をapply
terraform plan
terraform apply
```

適用後の手順（Terraformの範囲外、`envs/prod`と異なる点のみ記載）:

1. `terraform output ec2_public_ip`でClientの接続先を確認する。
2. イメージ更新時（`bridge_image`/`langflow_image`とも`:latest`固定）は、上記スクリプトで再度ビルド・pushした後、EC2上で
   `docker compose -p agent -f docker-compose.agent.yaml --env-file .env pull bridge langflow && \
    docker compose -p agent -f docker-compose.agent.yaml --env-file .env up -d bridge langflow`
   を実行する（またはEC2再起動でuser-data相当のスクリプトを再実行する）。
   ※`module.ecr`は`image_tag_mutability = "IMMUTABLE"`のため、同じ`:latest`タグへの再pushは
   ECR側で拒否される。再pushする場合は事前に対象タグのイメージをECRコンソール/CLIで削除しておくこと。

**壊す/作り直す運用が前提**なので、RDSは`deletion_protection=false`・`skip_final_snapshot=true`にしてあり、
`terraform destroy`でそのまま削除できる（コストを抑えたい期間だけ`apply`し、使わない時は`destroy`する運用を想定）。

## on-premisesとの差分（意図的な変更点）

`docs/rules/0001-aws-migration.md` の指示、および冒頭の「この構成の前提」に基づく変更点。

| 項目 | on-premises | cloud/ |
|---|---|---|
| Langflow DB | SQLite (`/app/data/langflow.db`, [ADR-0006](../docs/decisions/0006-stamina-state-persisted-in-langflow-volume.md)) | RDS for PostgreSQL（`docs/rules/0001-aws-migration.md`の指示どおり） |
| stamina状態 (`/app/data/stamina.json`) | Langflowコンテナのボリューム上のファイル | 変更なし（EC2ホスト上のディレクトリへ同じパスでbindマウント。`langflow-init`のchown処理はuser-dataで代替） |
| Langflowのflows配置 | ホストディレクトリbindマウント (`./langflow/agents:/app/flows`) | S3からEC2ホストへsyncしたディレクトリをbindマウント（イメージは`langflowai/langflow:1.11.0`のまま変更なし） |
| .envの平文キー | `client/.env` 等（[ADR-0009](../docs/decisions/0009-plaintext-env-file-secrets.md)） | Secrets Manager（EC2起動時に取得し`.env`を生成、コンテナへは従来どおり`.env`経由で注入） |
| OpenSearch | Docker公式イメージ、`DISABLE_SECURITY_PLUGIN=true`（[ADR-0005](../docs/decisions/0005-rag-firecrawl-opensearch.md)） | 変更なし（EC2上の同じコンテナ構成のまま。マネージドサービス化・認証有効化の根拠がないため踏襲） |
| firecrawl-api / playwright-service、および裏側のredis/rabbitmq/nuq-postgres/foundationdb | Compose内コンテナ（`agent-crawl`project、[ADR-0007](../docs/decisions/0007-vendored-firecrawl.md)） | **移行対象外**。AWS構成・関連インフラを作らない（`docs/rules/0001-aws-migration.md`「スコープ外」） |
| ローカルLLM (LM Studio) | Windowsホスト常駐、`agent`フローが信頼度スコアでフォールバック判定（ADR-0003） | 廃止。bridgeの`LANGFLOW_FLOW_ID`を`gemini`（Cloud LLM単独フロー）に固定 |
| Client / bridge-frontend | ホスト直接実行 / 開発時のみ起動するデバッグUI | スコープ外（詳細はassumptions.md「7.」） |

## 未実施

- `terraform plan`/`apply` の実行・動作確認（このリポジトリ環境にAWS認証情報・terraformバイナリなし）。
- コンテナイメージのビルド・ECRへのpush、および `terraform.tfvars` の実値設定（CI/CDパイプラインは今回のスコープ外）。
- Langflowの`gemini`フロー中の`SearchRag`コンポーネント（OpenSearchへのRAGクエリ、[ADR-0005](../docs/decisions/0005-rag-firecrawl-opensearch.md)参照）が
  正常に動作するかの検証。firecrawl-apiが移行対象外のためOpenSearchのインデックスは空のまま
  （クロールによるデータ投入経路がない）で、検索結果が空でも例外にならず動作するかは未確認
  （`assumptions.md`「10.」参照）。
