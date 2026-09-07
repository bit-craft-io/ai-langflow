# ADR-0003: ローカルLLM（LM Studio）優先 + 信頼度スコアによるクラウドLLM（Gemini）フォールバック

## Status
Accepted（既存コードから採用済みと判断）

## Context
（不明。ただし `on-premises/docs/lm_studio/src/lm_studio.md` に「GPUのVRAMが4GB」という記載があり、ローカル推論モデルの選定制約になっていることは読み取れる）

## Decision
- Langflow フロー `agent.json` にカスタムコンポーネント `SelfConsistencyLMStudio` が定義されている（`server/langflow/agents/agent.json`）。
  - LM Studio へ `http://host.docker.internal:11434/v1`（`api_key="lm-studio"`）でOpenAI互換APIとして接続する。
  - 設定値: `model_name = qwen2.5-3b-instruct`, `n_iter = 2`（コード上のデフォルトは3）, `confidence_threshold = 70`（%）。
  - 同一プロンプトを最大 `n_iter` 回、`temperature=0.9` かつ毎回異なる `seed` で推論し、多数決で最頻回答と一致率（confidence）を算出。confidence が閾値以上になった時点で打ち切る。
  - 追加で `temperature=0.1` の検証プロンプト（「妥当」で始まるか判定）を1回実行し、`confidence >= threshold` かつ検証OKの場合のみ `status="PASS"`。
  - `ConditionalRouter`（`match_text="PASS"`, `operator="equals"`）で分岐し、PASS ならローカルLLMの回答を採用、それ以外は `GoogleGenerativeAIComponent`（`model_name="gemini-3.1-flash-lite"`, `api_key`はグローバル変数 `GOOGLE_API_KEY` 参照, `max_output_tokens=300`, `temperature=0.1`）へフォールバックする。
  - `on-premises/docs/overview/src/overview.md` に記載のシーケンス図（信頼度スコア閾値70、ローカルLLM優先・クラウドLLMフォールバック）と一致する。
- 一方、Bridge/Client のデフォルト設定 (`langflow_flow_id: str = "chat"`) が指すフロー `chat.json` は `LMStudioModel` のみで構成され、上記の信頼度判定・クラウドフォールバック処理を含まない（`ConditionalRouter` や `GoogleGenerativeAIComponent` が存在しない）。
- クラウドLLM単独フロー `gemini.json`（`description: "Cloud LLM only"`）も別途存在し、`GeminiWithRetry`（`max_retries=3`、レスポンス空または `RESOURCE_EXHAUSTED`/`429` 時に5秒待機してリトライ）と `SearchRag`（OpenSearchベクトル検索によるRAG）、`EmbeddingModel`（`gemini-embedding-2`）を組み合わせている。

## Consequences
（不明。ただし、Bridge/Client のデフォルト `langflow_flow_id="chat"` が信頼度スコア判定を実装した `agent` フローと異なる点は、コード上の事実として明記しておく）
