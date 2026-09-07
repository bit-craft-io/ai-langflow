---
name: launch-stack
description: Bring up the full on-premises AI voice-agent stack (LM Studio host check, Python/direnv setup, Docker build/up, verify Langflow and the Bridge). Use when the user wants to start, set up, or verify the stack is running.
---

Work from `on-premises/` (all `make` tasks run there).

1. **Check LM Studio on the Windows host first** — this cannot be automated from WSL/the repo. Ask the user to confirm, or check via `curl -s http://localhost:11434/v1/models` (or similar) if reachable, that:
   - Local Server is enabled, port `11434`
   - "Serve on local network" is enabled
   - Model `google/gemma-3-1b` is loaded
   If it's not confirmed running, stop and tell the user to do this manually before continuing — nothing downstream will work without it.

2. **First-time setup only** (skip if `.venv` already exists): `make _setup_all` — installs direnv + git-lfs, creates the Python venv, installs all deps, wires `.envrc`.

3. **Build and start the Docker stack**: `make docker-build` (this runs `--no-cache` build then brings everything up) or `make docker-up` if images already exist. This starts both compose projects (`agent` main stack + `agent-crawl` Firecrawl) together.

4. **Verify**:
   - Langflow UI reachable at `http://localhost:7860` (auto-login `root`/`root`)
   - Bridge WS test page at `http://localhost:5174`
   - `docker ps` shows `voicevox`, `langflow`, `bridge`, `opensearch`, `opensearch-ui` (and Firecrawl's containers) up
   - If something didn't come up, check `make docker-logs`

Report which step failed, if any, rather than assuming success — this stack has several external dependencies (host LM Studio, GPU/VRAM, Docker network `nw_langflow`) that commonly break silently.
