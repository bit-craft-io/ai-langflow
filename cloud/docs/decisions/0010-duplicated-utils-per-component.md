# ADR-0010: Client / Bridge で共通ユーティリティ（セッション管理・タイマー等）を意図的に重複実装する

## Status
Accepted（既存コードから採用済みと判断）

## Context
`on-premises/CLAUDE.md` に「`client/utils/` と `server/bridge/backend/src/utils/` は意図的に重複したヘルパーモジュール（セッション管理、タイマー、VOICEVOXパイプライン）であり、各コンポーネントが独立デプロイされるため統一を試みないこと」と明記されている。

## Decision
- `client/utils/` と `server/bridge/backend/src/utils/` の双方に、`session_manager.py`, `input_speak_timer.py`, `input_write_timer.py`, `suppress_stderr.py` が個別に存在する（内容はほぼ同一の `SessionManager` クラス等）。
- Bridge側 `utils/` にのみ `katakana.py`（`Katakana` クラス）が存在する。`server.py` 内では `Katakana().convert(...)` の呼び出しはコメントアウトされており未使用。
- Client側にのみ `utils/voicevox/output_speak.py`（`OutputSpeak` クラス、`await.py` 内で import されているが呼び出しはコメントアウト）が存在する。
- `config.py` もそれぞれのコンポーネント配下に個別定義されており（`client/config.py`, `server/bridge/backend/src/config.py`）、`.env` の探索パスやデフォルト値がわずかに異なる（例: Bridge側にのみ `websocket_port`, `voicevox_speaker_id`, `voicevox_speed_scale`, `fetch_status_api` フィールドが存在する）。

## Consequences
（不明。ただし CLAUDE.md の記述から、統一（共通ライブラリ化）は意図的に行わない方針であることは明記されている）
