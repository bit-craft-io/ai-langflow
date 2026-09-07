# ADR-0004: Bridge が文単位で VOICEVOX 音声合成をパイプライン化する

## Status
Accepted（既存コードから採用済みと判断）

## Context
（不明）

## Decision
- Langflow から SSE ストリーミング（`?stream=true`）でトークンを受信しながら、Bridge (`server.py`) が正規表現 `(.*?[。！？\n])` で文単位に分割する。
- 1文が確定するたびに、その文単位で VOICEVOX（`http://voicevox:50021`）へ `/audio_query` → `/synthesis` の2段階リクエストを行い、WAVバイナリを生成してからClientへ送信する（全文生成を待たずに逐次送信）。
- `_text_to_voicevox_wav` は `speedScale` を `query_json["speedScale"]` として書き換えてから `/synthesis` を呼ぶ（`voicevox_speaker_id`, `voicevox_speed_scale` は Bridge の設定値、デフォルトはそれぞれ `1`, `1.0`）。
- VOICEVOXへのリクエストタイムアウトは5秒固定（`_text_to_voicevox_wav` 内の `timeout=5`）。
- Langflowのストリームイベントは `event == "token"`（`data.chunk`）と `event == "add_message"`（`sender=="Machine"` かつ未処理の `msg_id` の場合のみ、`data.data.text`）の2種類を処理する。

## Consequences
（不明）
