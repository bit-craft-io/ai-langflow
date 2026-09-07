---
name: debug-bridge
description: Run the Bridge WebSocket server directly on the host (outside Docker) for debugging, and test it against the frontend debug client. Use when the user wants to debug, iterate on, or step through the Bridge server code.
---

Work from `on-premises/`.

1. Make sure the rest of the stack (Langflow, VOICEVOX, etc.) is up via Docker as usual — only the Bridge itself runs on the host for debugging. If the Dockerized `bridge` container is also running, stop it first (`docker compose stop bridge` or via `make docker-down`/`docker-up` as appropriate) to avoid two processes fighting over port 8765.

2. Run the Bridge on the host: `make bridge`. This sources `server/.env` (`LANGFLOW_API_KEY`, `GOOGLE_API_KEY`, etc.) and runs `cd server/bridge/backend/src && python3 server.py` directly — so print statements, breakpoints, and stack traces show up in the terminal.

3. Test it: open the frontend debug client at `http://localhost:5174` (start it separately if it's not already running as part of the dev override, e.g. `npm run dev` in `server/bridge/frontend/`) and send a message through the WebSocket UI to exercise the Bridge → Langflow → VOICEVOX round trip.

4. Backend-specific env overrides live in `server/bridge/backend/src/.env` (separate from `server/.env` used by Docker) — check both if behavior differs between the Docker and host-run versions.
