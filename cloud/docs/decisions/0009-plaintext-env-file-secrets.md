# ADR-0009: 設定・シークレット管理を平文 .env ファイル + pydantic-settings で行う

## Status
Accepted（既存コードから採用済みと判断）

## Context
（不明）

## Decision
- `client/.env`, `server/.env`（Makefile経由で読み込み。ファイル自体は本探索では内容非開示）, `server/bridge/backend/src/.env` に `LANGFLOW_API_KEY`, `GOOGLE_API_KEY` 等の実キーを平文で保持する。
- `on-premises/.gitignore` の内容は `.idea` / `.venv` / `__pycache__` のみで、`.env` 系ファイルは対象外。
- Client (`client/config.py`) と Bridge (`server/bridge/backend/src/config.py`) はそれぞれ独立した `pydantic_settings.BaseSettings` サブクラス `Settings` を定義し、`.env` ファイルおよび環境変数から設定値を読み込む。両者は別ファイル・別コードとして重複実装されている。
- Docker Compose (`server/docker-compose.yaml`) では `bridge` サービスに対して `env_file: bridge/backend/src/.env` に加え、`environment:` で `LANGFLOW_API_KEY`, `GOOGLE_API_KEY` をホストの環境変数から明示的に注入している。
- `langflow` サービスには `LANGFLOW_API_KEY_SOURCE=env` と `LANGFLOW_API_KEY=${LANGFLOW_API_KEY}` が設定され、コンテナ再作成のたびに Langflow API Key を再生成しなくて済むようにしている（compose ファイル内コメントに明記）。
- `make bridge`（`make.d/server.mk`）は Docker を使わず、`server/.env` を `grep`/`xargs` でシェル環境変数として展開してからホスト上で直接 `python3 server.py` を実行する。

## Consequences
（不明）
