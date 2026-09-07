# サービス対応表（on-premises → AWS）

`docs/spec/as-is.md` のサービス一覧を基準に、各サービスのAWS移行先と対応するTerraformモジュール/Compose定義を整理する。
採用理由の詳細は `assumptions.md` を参照。前提: IaC=Terraform、コンピュート=EC2上でdocker compose継続、
ローカルLLM(LM Studio)は廃止（いずれもユーザー確認済み）。

**firecrawl-api / playwright-serviceは`docs/rules/0001-aws-migration.md`「スコープ外」により移行対象外**
（Cloud API課金のため）。それらに依存する裏側インフラ（redis/rabbitmq/nuq-postgres/foundationdb）も
存在理由がないため、AWS側の対応・関連インフラを作らない。

| on-premisesサービス | Compose project | AWS移行先 | 対応するTerraform/Compose |
|---|---|---|---|
| voicevox | agent | EC2ホスト上のcomposeコンテナ（公式イメージそのまま） | `docker/compose/docker-compose.agent.yaml` |
| langflow | agent | EC2ホスト上のcomposeコンテナ（`langflowai/langflow:1.11.0`のまま） + RDS PostgreSQL | `docker/compose/docker-compose.agent.yaml` + `modules/rds_postgres` |
| langflow-init | agent | 廃止（EC2起動時のuser-dataでchownを実施） | `modules/ec2_docker_host`（user_data） |
| bridge | agent | EC2ホスト上のcomposeコンテナ（既存Dockerfileをビルド、ECR経由） + ALB(WebSocket) | `docker/compose/docker-compose.agent.yaml` + `modules/alb` |
| bridge-frontend | agent (dev限定) | スコープ外（assumptions.md「7.」参照） | - |
| opensearch | agent | 変更なし。EC2ホスト上のcomposeコンテナのまま（マネージドサービス化の根拠がないため。assumptions.md「6.」参照） | `docker/compose/docker-compose.agent.yaml` |
| opensearch-ui | agent | 変更なし。EC2ホスト上のcomposeコンテナのまま | `docker/compose/docker-compose.agent.yaml` |
| firecrawl-api | agent-crawl | **移行対象外**（`docs/rules/0001-aws-migration.md`「スコープ外」） | - |
| playwright-service | agent-crawl | **移行対象外**（同上） | - |
| redis (firecrawl) | agent-crawl | **移行対象外**（firecrawl-api専用の内部サービスのため） | - |
| rabbitmq (firecrawl) | agent-crawl | **移行対象外**（同上） | - |
| nuq-postgres (firecrawl) | agent-crawl | **移行対象外**（同上） | - |
| foundationdb / foundationdb-init | agent-crawl | **移行対象外**（firecrawl自体が対象外のため個別検討は不要。元々未使用経路でもある） | - |
| LM Studio（ホスト常駐） | - | **廃止**（ユーザー確認済み）。langflowは`gemini`フロー（Cloud LLM単独）を使用 | - |
| Gemini（Cloud LLM） | - | 変更なし（Google Generative AI APIを引き続き利用、キーはSecrets Manager経由） | `modules/secrets` |
| Client (`await.py`) | - | スコープ外（エンドユーザ端末側の成果物） | - |
| `nw_langflow`（Docker外部ネットワーク） | agent | EC2ホスト上のDockerネットワーク（同じ`nw_langflow`をuser-dataで作成） | `modules/ec2_docker_host`（user_data） |
| `.env`平文キー（`LANGFLOW_API_KEY`, `GOOGLE_API_KEY`等） | - | Secrets Manager（EC2起動時に取得し`.env`を生成、コンテナへの注入方式自体はon-premisesと同じ`.env`ファイル経由） | `modules/secrets` |

## ネットワーク到達性（移行後、`envs/prod`）

```
Internet
  └─ ALB (public subnet, HTTP/HTTPS, WebSocketをそのままフォワード)
       └─ EC2ホスト:8765 (bridge)

EC2ホスト（private subnet, 単一インスタンス）
  ├─ docker network "nw_langflow"（on-premisesのnw_langflowと同じ役割）
  │    └─ bridge → langflow:7860, voicevox:50021（コンテナ名でのDNS解決）
  ├─ opensearch / opensearch-ui（EC2上のコンテナ、on-premisesと同じ構成）
  ├─ → RDS PostgreSQL (langflow用インスタンス, private subnet)
  ├─ → Google Generative AI API (Gemini, NAT Gateway経由でインターネットへ)
  └─ → Secrets Manager / ECR / S3 (起動時のシークレット取得・イメージpull・compose定義/flows取得。NAT Gateway経由)
```

`envs/dev`ではNAT Gateway/ALBを作らず、EC2をパブリックサブネットに直置きしてIGW経由で直接インターネットへ出る
（`docs/assumptions.md`「D.」参照）。

firecrawl-api自体が移行対象外のため、on-premisesで存在した「langflow → firecrawl-api → OpenSearch」という
RAGクロール経路（[ADR-0005](../decisions/0005-rag-firecrawl-opensearch.md)参照）はAWS側には存在しない。
bridgeは`LANGFLOW_FLOW_ID=gemini`固定のため、この経路が使われるのは`gemini.json`内の`SearchRag`コンポーネント
（既存インデックスへの検索クエリのみ、クロール自体は行わない）に限られる。

## 未検証の接続経路

`gemini.json`フロー内の`SearchRag`コンポーネントがOpenSearchへ実際に接続できるか、インデックスが空の状態で
例外にならず動作するかは未検証。`assumptions.md`「10.」を参照。
