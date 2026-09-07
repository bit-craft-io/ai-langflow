# ADR-0002: Client-Bridge 間を WebSocket で接続し、独自 JSON プロトコルで通信する

## Status
Accepted（既存コードから採用済みと判断）

## Context
（不明）

## Decision
- `on-premises/server/bridge/backend/src/server.py` の `LangflowWSServer` が `websockets` ライブラリで WebSocket サーバを起動する（デフォルトポート 8765、`ping_interval=20`, `ping_timeout=20`）。
- Client からの1メッセージ受信ごとに、Bridge がセッションIDを払い出し（`SessionManager(timeout=60.0)`、キー未指定時は `"default"` 固定キーを使うため、60秒以内の全接続で同一セッションIDが再利用される）、Langflow へリクエストを転送する。
- Bridge → Client のレスポンスは JSON テキストメッセージとバイナリ（WAV音声）メッセージが交互に送信される:
  - `{"type": "speech_text", "text": "..."}` の直後に WAV バイナリを送信（文単位）
  - 全文送信後に `{"type": "speech_done", "aborted": bool, "reason": str}` を送信
  - 5秒間隔の `push_loop` から `{"type": "periodic_update", "message": ...}` をブロードキャスト送信
- 文分割は正規表現 `(.*?[。！？\n])` による日本語の文末記号ベース。
- ストリーム処理には以下の打ち切り条件がハードコードされている:
  - 合計文字数が `MAX_TOTAL_CHARS = 1000` を超えたら中断（`abort_reason="max_chars"`）
  - 文数が `MAX_SENTENCES = 30` を超えたら中断（`abort_reason="max_sentences"`）
  - 同一文が `DUPLICATE_LIMIT = 3` 回連続したら中断（`abort_reason="duplicate"`）
  - `CHUNK_IDLE_TIMEOUT = 15.0` 秒チャンクが来なければ中断（`abort_reason="idle_timeout"`）
- Client 側（`on-premises/client/await.py`）は WebSocket ではなく Langflow API へ直接 HTTP POST するコンソールアプリであり、Bridge を経由しない別経路として存在する（`server/bridge/frontend/src/LangflowBridgeClient.tsx` が WebSocket 経由のデバッグ用フロントエンド）。

## Consequences
（不明）
