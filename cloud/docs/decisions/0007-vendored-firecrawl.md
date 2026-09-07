# ADR-0007: Firecrawl をアップストリームのフルコピーとしてベンダリングする

## Status
Accepted（既存コードから採用済みと判断）

## Context
（不明）

## Decision
- `on-premises/server/firecrawl/` にオープンソースの Firecrawl プロジェクトが、約50MBのフルコピーとして同梱されている（`apps/`, `firecrawl-cli/`, `firecrawl-cli-skills/`, `firecrawl-skills/`, `firecrawl-workflows/`, `examples/`, `img/`, 独自の `CLAUDE.md`/`AGENTS.md` を含む）。
- Firecrawl は自身の `docker-compose.yaml`（Compose project 名 `firecrawl`）を持ち、`api`, `playwright-service`, `redis`, `rabbitmq`, `nuq-postgres`, `foundationdb`（`NUQ_BACKEND=fdb` 選択時）, `foundationdb-init` の各サービスと `backend` ネットワーク（`driver: bridge`、独立ネットワーク）で構成される。
- `on-premises/server/override.d/firecrawl/docker-compose.override.yml` により、`api` サービスのみコンテナ名を `firecrawl-api` に変更し、外部ネットワーク `nw_langflow` にも参加させる（他の Firecrawl 内部サービスは `nw_langflow` に参加しない）。
- `on-premises/make.d/docker.mk` の `run_compose` により、メインの Compose プロジェクト（`-p agent`）とは別に Firecrawl 用 Compose プロジェクト（`-p agent-crawl`）として `docker-up`/`docker-down`/`docker-restart`/`docker-build`/`docker-logs`/`docker-purge` が同時実行される。実行時に `override.d/firecrawl/.env.example` が `server/firecrawl/.env` へコピーされる。
- `on-premises/server/firecrawl/CLAUDE.md` により「vendored copy（ベンダリング済みコード）、明示的な指示がない限り編集しない」ことが規定されている。

## Consequences
（不明）
