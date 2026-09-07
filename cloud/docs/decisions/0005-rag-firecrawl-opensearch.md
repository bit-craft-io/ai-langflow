# ADR-0005: RAG基盤として Firecrawl（クロール）+ OpenSearch（ベクトル検索）を採用

## Status
Accepted（既存コードから採用済みと判断）

## Context
（不明）

## Decision
- Langflow フロー `rag.json`（`description: "create rag"`）が、Firecrawlでのクロール結果を OpenSearch にベクトルインデックスとして取り込むパイプラインを構成する。ノード構成:
  `FirecrawlCrawlApi` → `FirecrawlResultsToDataList` → `SplitText` → `EmbeddingModel` → `FilterEmptyChunks` → `OpenSearchDirectIngest` / `OpenSearchDirectIngestOne`（+ `CrawlerOptionsBuilder`, `ScrapeOptionsBuilder`, `GlobalConfigCreate`/`GlobalConfigRead`, `DeleteOpenSearchIndex`, `LoopComponent`, `DelayComponent`）。
- 検索側は `gemini.json` の `SearchRag` カスタムコンポーネントが、質問文を `EmbeddingModel` でベクトル化し、OpenSearch へ `knn` クエリ（フィールド `chunk_embedding`, `top_k=5`）を発行して関連チャンクをコンテキストとして返す。
  - `SearchRag` 内デフォルト: `opensearch_url="http://opensearch:9200"`, `index_name="langflow"`, `username="admin"`。
  - `rag.json` 側でのインデックス名は `GlobalConfigRead`/`GlobalConfigCreate` 経由の設定値に依存し、フローJSON内には具体的なインデックス名は含まれない（`GlobalConfigCreate`/`Read` の実値は本リポジトリのコードからは読み取れない）。
- OpenSearch サービスは `DISABLE_SECURITY_PLUGIN=true`（セキュリティプラグイン無効）で起動する（`server/docker-compose.yaml`）。
- Firecrawl 自体は本リポジトリに `on-premises/server/firecrawl/` としてベンダリングされている（[[0007]] を参照）。

## Consequences
（不明。ただし OpenSearch のセキュリティプラグインが無効化されている点は、認証・認可が構成されていないことをコード上の事実として示す）
