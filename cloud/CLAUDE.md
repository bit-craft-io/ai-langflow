# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this is

An on-premises AI voice-agent/companion stack (all docs/comments in Japanese), living under `onprem/` — a sibling directory to this `cloud/` AWS-migration project (repo layout: `cloud/` and `onprem/` at the repo root). Architecture, in order:

1. A **Client**: Python CLI (`onprem/client/python/workflow.py`, run via `make client-text-only` / `client-text-audio` / `client-voice-audio`). A Unity project also lives at `onprem/client/unity/`, but only as backup/restore snapshots (`make unity-backup`/`unity-restore`/`unity-init`) of an external Unity project path (`__UNITY_PROJECT_DIR` in `make.d/.env`) — the live Unity source isn't part of this repo.
2. The **Bridge** (`onprem/docker/bridge/backend/`, Python `websockets` server, entrypoint `src/server.py`) relays requests to **Langflow** and streams responses back paired with synthesized audio. A React/TS debug frontend lives in `onprem/docker/bridge/frontend/` (Vite dev server, port 5173).
3. **Langflow** (Docker, flows in `onprem/docker/langflow/flows/*.json`). The active flow is whatever `LANGFLOW_FLOW_ID` in `onprem/docker/bridge/backend/src/.env` points to (currently `gemini-pg`): Gemini (cloud, via `GOOGLE_API_KEY`) as the LLM, plus a `PgVectorSearch` node doing RAG retrieval against the **pgvector** Postgres service. An **Ollama** container (`onprem/docker/ollama/`, port 11434, fronted by a LiteLLM proxy on port 4000) also runs as local-LLM infrastructure, and other flow files (`agent.json`, `gemini-os.json`, `rag-os.json`, `rag-pg.json`, ...) wire in Ollama/LM Studio/a confidence-threshold routing node — but those aren't the active flow. Don't assume which flow/backend is live; check `LANGFLOW_FLOW_ID` yourself before relying on it.
4. **VOICEVOX** (Docker, port 50021) does Japanese TTS.
5. **Firecrawl**, **searxng** (port 8080, metasearch — not OpenSearch), and **pgvector** (Postgres+pgvector extension, port 5432) run as additional Docker services for RAG/search tooling.

Full sequence diagram: `onprem/docs/overview/src/overview.md`.

## Vendored code — do not edit

`onprem/docker/firecrawl/` is a vendored copy (~50MB) of the upstream open-source Firecrawl project, with its own `CLAUDE.md`/`AGENTS.md`. Treat it as out-of-scope third-party code — don't edit it unless explicitly asked. It's listed in `onprem/.gitignore` (re-cloned on demand via `make firecrawl-git-pull`, removed via `make firecrawl-git-dell`).

## Running things

Everything is driven through an interactive `make` menu (`onprem/Makefile`, includes `make.d/*.mk`). Running bare `make` opens a picker; target specific tasks directly when scripting/automating.

Unlike `cloud/`'s two-compose-project design, onprem runs **one independent Docker Compose project per service** — `langflow`, `pgvector`, `firecrawl`, `searxng`, `ollama`, `voicevox`, `bridge` (see `SERVICES` in `make.d/docker.mk`) — all joined by a shared external Docker network `sandbox` that `docker-up`/`docker-down` create/remove:

- `make docker-up` / `make docker-down` — start/stop all 7 services (in that dependency order)
- `make docker-build` — rebuild the bridge image with `--no-cache`
- `make docker-one-build SERVICE=<name>` / `make docker-one-restart SERVICE=<name>` — rebuild/restart a single service (omit `SERVICE` for an interactive picker)
- `make docker-purge` — `down -v` everything, after a confirmation prompt
- `make _setup_all` — first-time setup (WSL tooling, Git LFS, Ollama model pull, Python env, Firecrawl clone — see `make.d/_common.mk` / `wsl.mk`)
- `make backup` / `make restore` (`make.d/langflow.mk`) — Langflow data volume backup/restore

There's no host-level "run bridge outside Docker for debugging" workflow here — that pattern (`make bridge`, `cloud/.claude/skills/debug-bridge/`) is specific to `cloud/`. Onprem's bridge only runs as its own Docker Compose project (`onprem/docker/bridge/`).

Ports: VOICEVOX 50021, Langflow UI/API 7860, Bridge WS 8765, bridge frontend debug client 5173, searxng 8080, pgvector/Postgres 5432, Ollama 11434, LiteLLM/Ollama proxy 4000.

## Env / secrets

Config is centralized in `onprem/make.d/.env` — read via `-include` by every `make.d/*.mk` and passed to Docker Compose with `--env-file` (see `onprem/README.md` for the variable table: `__OLLAMA_MODEL`, `__LANGFLOW_API_KEY`, `__LANGFLOW_GOOGLE_API_KEY`, `__UNITY_PROJECT_DIR`, ...). The bridge container additionally reads its own `onprem/docker/bridge/backend/src/.env` (`LANGFLOW_API_KEY`, `LANGFLOW_FLOW_ID`, `LANGFLOW_STATE_FLOW_ID`, ...). Neither is excluded by `onprem/.gitignore` (which only lists `.idea` / `.venv` / `__pycache__/` / `docker/firecrawl` / backup dirs) — never commit real key values or paste their contents into commits/PRs.

## Conventions

- Write new comments, docs, and commit messages in Japanese, matching the rest of the repo.
- No test framework or linter is currently configured for any onprem component (Python or the TS frontend). Match existing style rather than introducing new tooling unprompted.
- Path references to onprem from `cloud/` code (scripts, Terraform `local-exec`/`fileset()` paths, etc.) must point at `onprem/docker/...`, not `onprem/server/...` — an older `on-premises/server/...` layout is referenced in some `cloud/` comments and docs but no longer exists on disk. Verify with `ls` before trusting a path in a comment.
