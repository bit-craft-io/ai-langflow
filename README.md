# ai-langflow

Langflowを中核としたAIエージェント（音声対話）スタックのリポジトリ。<br />オンプレミス構築とAWS移行構成の2系統で構成される。

## ディレクトリ構成

```
.
├── onprem/   オンプレミス構成（学習用リポジトリ本体）
└── cloud/    onprem をAWS上で動作させるための移行構成
```

### [`onprem/`](onprem/README.md)

AIエージェント開発・検証のための学習用構成。WSL + Docker Composeで、以下のサービス群をローカル/開発機上で動かす。

- **Langflow** — エージェントフロー（Gemini APIまたはローカルLLM/Ollama + RAG）
- **Bridge** — ClientとLangflowを中継するWebSocketサーバー
- **VOICEVOX** — 日本語音声合成
- **Firecrawl / searxng / pgvector** — RAG・検索用の補助サービス
- **Client** — Python CLI（テキスト/音声対話）

セットアップ・起動方法は `onprem/README.md`、詳細なアーキテクチャは `cloud/CLAUDE.md`（両ディレクトリを俯瞰する形で記述）を参照。

### [`cloud/`](cloud/README.md)

`onprem/` のDocker Compose構成をAWS上（EC2 + Terraform）で動かすための並行構成。<br />`onprem/` 配下のコードは変更しない方針。

- IaC: Terraform（EC2上でdocker composeを継続、LangflowのDBのみRDSへ切り出し）
  - ECS/EKSへの作り替えは行わない。<br />既存のCompose構成を維持し、構成変更を最小化するための選択
  - お試し用の`envs/dev`はNAT Gateway/ALBを省いてコストを抑えた別構成
- ローカルLLMは廃止し、Gemini API単独で構成
- firecrawl-api / playwright-serviceは移行対象外

構築手順・前提条件は `cloud/README.md` を参照。

## 関連ドキュメント

- `cloud/CLAUDE.md` — リポジトリ全体（onprem/cloud双方）のアーキテクチャ概要
- `cloud/docs/` — 移行方針・ADR・前提条件
- `onprem/docs/overview/` — onpremのシーケンス図等

## ライセンス

[MIT License](LICENSE)
