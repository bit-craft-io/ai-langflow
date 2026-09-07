# ADR-0008: 2つの独立した Docker Compose プロジェクトを外部ネットワークで接続する

## Status
Accepted（既存コードから採用済みと判断）

## Context
（不明。[[0007]] のFirecrawlベンダリングと併せて運用されている）

## Decision
- メインスタック（`agent` プロジェクト、`server/docker-compose.yaml`）と Firecrawl スタック（`agent-crawl` プロジェクト、`server/firecrawl/docker-compose.yaml`）は別々の Docker Compose ファイル・別プロジェクト名で管理される。
- 両プロジェクトを跨ぐ通信のために、Docker がデフォルトで作成しない外部ネットワーク `nw_langflow` を事前に `docker network create nw_langflow` で作成し、両方の `docker-compose.yaml` から `networks: nw_langflow: external: true` として参照する。
- ネットワーク作成は `on-premises/make.d/docker.mk` の `docker-up`/`docker-restart` 実行時に冪等（`docker network inspect` で存在確認してから作成）に行われる。
- `docker-purge` 実行時（確認プロンプト `y`/`yes` で承諾した場合）に `docker compose down -v` の後、`nw_langflow` ネットワークも削除される。
- Firecrawl 側の内部サービス（redis, rabbitmq, playwright-service, nuq-postgres, foundationdb）は Firecrawl 自身の `backend` ネットワークにのみ所属し、`nw_langflow` には参加しない（[[0007]] 参照）。

## Consequences
（不明）
