# on-premises 現状構成（as-is）

本ドキュメントは `on-premises/` 配下のコード・設定ファイルから読み取れる現状の構成を機械的に整理したものである。意図や設計判断の背景については `docs/decisions/` のADRを参照。コード上に根拠のない記述は避け、不明な点は明記する。

## 1. サービス一覧

| サービス | 実体 | イメージ / 実行方式 | 公開ポート | 属するCompose project | ネットワーク |
|---|---|---|---|---|---|
| Client | `client/await.py`（Python CLI, コンソール入力） | ホスト上で直接実行（Docker化なし） | - | - | - |
| bridge-frontend | `server/bridge/frontend`（React + TS, Vite） | `docker-compose.override.d/docker-compose.dev.yaml` からビルド（開発時のみ、`__DEV_CONTAINER=true` の場合に有効化） | 5174 | agent | nw_langflow |
| bridge | `server/bridge/backend`（Python `websockets`） | `bridge/backend/Dockerfile` からビルド | 8765 | agent | nw_langflow |
| langflow | Langflow | `langflowai/langflow:1.11.0` | 7860 | agent | nw_langflow |
| langflow-init | 権限初期化用 one-shot コンテナ | `alpine`（`chown -R 1000:0 /app/data`） | - | agent | - |
| voicevox | VOICEVOX Engine | `voicevox/voicevox_engine:cpu-latest` | 50021 | agent | nw_langflow |
| opensearch | OpenSearch | `opensearchproject/opensearch:latest` | 9200, 9600 | agent | nw_langflow |
| opensearch-ui | OpenSearch Dashboards | `opensearchproject/opensearch-dashboards:3.8.0` | 5601 | agent | nw_langflow |
| firecrawl-api | Firecrawl API（ベンダリング済み） | `server/firecrawl/apps/api` からビルド | 3002（`${PORT:-3002}`、`${INTERNAL_PORT:-3002}`へマップ） | agent-crawl | backend + nw_langflow（`api`のみ） |
| playwright-service | Firecrawlのブラウザ操作サービス | `server/firecrawl/apps/playwright-service-ts` からビルド | -（内部ポート3000） | agent-crawl | backend |
| redis | Firecrawlのキュー/レート制限 | `redis:alpine` | - | agent-crawl | backend |
| rabbitmq | Firecrawlのキュー基盤 | `rabbitmq:3-management` | - | agent-crawl | backend |
| nuq-postgres | Firecrawlのジョブキュー用DB | `server/firecrawl/apps/nuq-postgres` からビルド | - | agent-crawl | backend |
| foundationdb / foundationdb-init | Firecrawlのキュー代替バックエンド（`NUQ_BACKEND=fdb` 選択時のみ有効な構成） | `foundationdb/foundationdb:7.3.63` | - | agent-crawl | backend |
| LM Studio | ローカルLLM推論サーバ（Windowsホスト上、Docker外） | ホスト常駐アプリ、手動設定 | 11434（ホスト） | - | `host.docker.internal` 経由でコンテナから到達 |
| Gemini（Cloud LLM） | Google Generative AI API | 外部SaaS | - | - | インターネット経由 |

補足:
- `server/README.md` にはポート3000（`chat`）の記載があるが、`CLAUDE.md` の指示どおりこれは stale（現状どのサービスも3000番を公開していない）。
- `nw_langflow` は `docker network create nw_langflow` により事前作成される外部ネットワークで、`agent`（メイン）・`agent-crawl`（Firecrawl）の両Composeプロジェクトを横断して接続する唯一の経路。Firecrawlの内部サービス（redis/rabbitmq/playwright-service/nuq-postgres/foundationdb）は `backend` ネットワークのみに属し、`nw_langflow` には参加しない。

## 2. 各サービスの役割

- **Client**（`client/await.py`）: コンソールでユーザー入力を受け付け、Langflow の `/api/v1/run/{flow_id}` へ直接HTTP POSTする。デフォルトの `flow_id` は `chat`。Bridgeを経由しない独立した動作経路。
- **bridge-frontend**（`server/bridge/frontend`）: WebSocket経由でBridgeに接続し、Langflowからの応答（テキスト/音声）を確認するためのReact製デバッグ用クライアント。開発用オーバーレイ（`override.d/docker-compose.dev.yaml`）でのみ起動する。
- **bridge**（`server/bridge/backend`）: WebSocketサーバ。Clientからのメッセージを受け取り、Langflowへストリーミングでリクエストを転送し、文単位でVOICEVOXによる音声合成を行いながらテキスト+音声をClientへ返す。5秒間隔でLangflowの `state` フローをポーリングし、`FETCH_STATUS_API=True` の場合は結果を全接続クライアントへブロードキャストする。
- **langflow**: ワークフローエンジン。`server/langflow/agents/*.json` に定義されたフロー（`agent`, `chat`, `gemini`, `rag`, `sample`, `state`）を実行し、ローカルLLM（LM Studio）・クラウドLLM（Gemini）・OpenSearch（RAG検索）・Firecrawl（クロール、`rag`フロー経由）を呼び出す。SQLiteデータベース（`langflow-data`ボリューム上）を使用（`LANGFLOW_DATABASE_URL=sqlite:////app/data/langflow.db`）。
- **voicevox**: 日本語テキストをWAV音声に変換するTTSエンジン。Bridgeから `/audio_query` → `/synthesis` の2段階で呼び出される。
- **opensearch / opensearch-ui**: RAG用のベクトル検索エンジンとその管理UI。セキュリティプラグインは無効化（`DISABLE_SECURITY_PLUGIN=true` / `DISABLE_SECURITY_DASHBOARDS_PLUGIN=true`）。
- **firecrawl-api 他**: Webクロール・スクレイピングAPI（アップストリームFirecrawlのベンダリング済みコピー）。Langflowの `rag` フローから `FirecrawlCrawlApi` コンポーネント経由で呼び出される想定（フローJSON上のノードとして存在）。
- **LM Studio**: Windowsホスト上で稼働するローカルLLM推論サーバ（OpenAI互換API）。GPU VRAM 4GB制約のため軽量モデル（ドキュメント上は `google/gemma-3-1b`、実際に `agent` フロー内で設定されているモデル名は `qwen2.5-3b-instruct` ── 両者は一致しない。詳細はADR-0003参照）を読み込む。コンテナからは `http://host.docker.internal:11434` で到達する。
- **Gemini（Cloud LLM）**: `agent` フローにおいて、ローカルLLMの信頼度スコアが閾値（70%）未満、または検証プロンプトで妥当性が確認できなかった場合のフォールバック先。`gemini` フローでは単独利用（RAG検索付き）。

## 3. 依存関係（呼び出し方向）

```
Client (CLI)
  └─ HTTP POST → langflow:7860 (/api/v1/run/{flow_id})   … await.py の経路

bridge-frontend (デバッグUI, port 5174)
  └─ WebSocket → bridge:8765

bridge:8765
  ├─ HTTP POST (stream) → langflow:7860 (/api/v1/run/{flow_id}?stream=true)
  └─ HTTP POST → voicevox:50021 (/audio_query, /synthesis)

langflow:7860
  ├─ HTTP → host.docker.internal:11434 (LM Studio, ローカルLLM, OpenAI互換API)
  ├─ HTTPS → Google Generative AI API (Gemini, クラウドLLM/Embedding)
  ├─ HTTP → opensearch:9200 (ベクトル検索 / インデックス投入)
  └─ HTTP → firecrawl-api:3002 (rag フロー経由でのクロール; nw_langflow 経由到達)

opensearch-ui:5601
  └─ HTTP → opensearch:9200

firecrawl-api
  ├─ → redis (backend network)
  ├─ → rabbitmq (backend network)
  ├─ → playwright-service (backend network)
  ├─ → nuq-postgres (backend network, デフォルトのキューバックエンド)
  └─ → foundationdb (backend network, NUQ_BACKEND=fdb 選択時のみ)
```

依存起動順序（`depends_on` による明示的な制約）:
- `langflow` は `langflow-init` の正常終了を待つ。
- `opensearch-ui` は `opensearch` のヘルスチェック成功を待つ。
- `bridge-frontend` は `bridge` の起動を待つ（health条件なし、`service_started` 相当）。
- Firecrawl `api` は `redis`（起動のみ）、`playwright-service`（起動のみ）、`rabbitmq`（ヘルスチェック成功）を待つ。
- Firecrawl `foundationdb-init` は `foundationdb` の起動を待つ。

## 4. 設定・シークレットの所在

- `client/.env`, `server/.env`, `server/bridge/backend/src/.env` に `LANGFLOW_API_KEY`, `GOOGLE_API_KEY` 等を平文保持（`.gitignore` の対象外。詳細はADR-0009）。
- `server/override.d/firecrawl/.env.example` が `docker-up` 等の実行時に `server/firecrawl/.env` へコピーされ、Firecrawl側の環境変数（`OPENAI_API_KEY`, `POSTGRES_*` 等）を提供する。

## 5. 未確認・不明点

- `server/.env` および `server/bridge/backend/src/.env` の実際の値（本調査では内容を開示せず、キー名のみコード参照から把握）。
- `agent.json` フロー内 `DecreaseStaminaComponent` の実装詳細。
- `rag.json` フロー内 `GlobalConfigCreate`/`GlobalConfigRead` が保持する実際の設定値（OpenSearchインデックス名など）。
- 本番運用でどのLangflowフロー（`chat` / `agent` / `gemini`）が実際に使用されているか（Bridge/Clientの設定デフォルトは `chat`）。
