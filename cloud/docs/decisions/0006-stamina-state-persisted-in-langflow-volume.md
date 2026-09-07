# ADR-0006: エージェント状態（スタミナ）を Langflow コンテナ内の JSON ファイルで永続化し、ポーリングで配信する

## Status
Accepted（既存コードから採用済みと判断）

## Context
（不明）

## Decision
- Langflow フロー `state.json`（`description: "Powerful Prompts, Perfectly Positioned."`）が `RecoverStaminaComponent` → `GetStaminaComponent` → `ChatOutput` で構成される。
- `RecoverStaminaComponent` はコンテナ内ファイル `/app/data/stamina.json`（Langflowの `langflow-data` ボリューム上）に `{"current", "max", "last_updated"}` を保存し、`MAX_STAMINA=100`、経過時間 `RECOVERY_INTERVAL_SEC=60` 秒ごとに `RECOVERY_AMOUNT=1` を回復する計算をロード時に行う。ファイル未存在時は `current=max=100` で新規作成する。
- `GetStaminaComponent` は前段のJSON文字列をパースし `{"stamina": {"current": ..., "max": ...}}` 形式に整形して返す。パース失敗時は `{"current": 100, "max": 100}` をデフォルト値として返す。
- Bridge/Client 双方に、この `state` フロー（`langflow_state_flow_id: str = "state"`）を定期問い合わせする仕組みがある:
  - Bridge (`server.py`): `push_loop` が5秒間隔で `_monitor_agent_status` を呼び、結果を接続中の全クライアントへ `periodic_update` としてブロードキャストする（`FETCH_STATUS_API` 設定が `True` の場合のみ有効。デフォルトは `False`）。
  - Client (`await.py`): `_monitor_agent_status` の呼び出しはコード上コメントアウトされている（`# monitor_task = asyncio.create_task(...)`）。
- `agent.json` フロー内の `DecreaseStaminaComponent` はノードとして存在するが、詳細実装（テンプレートのコード内容）は本調査では未確認。

## Consequences
（不明）
