# ADR-0001: Docker Compose によるマイクロサービス構成

## Status
Accepted（既存コードから採用済みと判断）

## Context
（不明）

## Decision
- サーバ側コンポーネントを Docker Compose で個別コンテナとして構成する（`on-premises/server/docker-compose.yaml`）。
- 構成サービスは以下の6つ:
  - `voicevox`（`voicevox/voicevox_engine:cpu-latest`、ポート 50021）
  - `langflow-init`（`alpine`、データディレクトリの権限を `chown -R 1000:0 /app/data` で初期化する one-shot コンテナ）
  - `langflow`（`langflowai/langflow:1.11.0`、ポート 7860）
  - `bridge`（`bridge/backend/Dockerfile` からビルド、ポート 8765）
  - `opensearch`（`opensearchproject/opensearch:latest`、ポート 9200/9600）
  - `opensearch-ui`（`opensearchproject/opensearch-dashboards:3.8.0`、ポート 5601）
- 全サービスは外部ネットワーク `nw_langflow`（`external: true`）に接続する。
- `langflow` は `langflow-init` の `service_completed_successfully` を `depends_on` の条件とする。
- `opensearch-ui` は `opensearch` の `service_healthy`（`/​_cluster/health` への curl ヘルスチェック）を `depends_on` の条件とする。
- 永続化ボリュームとして `langflow-data`・`opensearch-data` を定義する。
- `on-premises/make.d/docker.mk` の `docker-up`/`docker-build`/`docker-restart` が、Compose 実行前に `docker network create nw_langflow`（存在しなければ）を行う。

## Consequences
（不明）
