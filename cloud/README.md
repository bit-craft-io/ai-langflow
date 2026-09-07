# cloud/

`onprem/` のDocker Compose構成を元に、Claude Codeハーネスで作成したAWS移行構成。

## ディレクトリ構成

```
cloud/
├── README.md      このファイル
├── CLAUDE.md      Claude Code向けのアーキテクチャ解説（onprem/cloud全体を俯瞰）
├── .claude/       ハーネス設定（agents / skills）
├── docs/
│   ├── rules/       移行方針
│   ├── decisions/   設計判断（ADR）
│   └── spec/        on-premisesの現状仕様（as-is）
└── src/           Terraform・Docker Compose・スクリプト本体
```

## ドキュメント

- 構築手順・使い方 → [`src/README.md`](src/README.md)
- アーキテクチャ・前提条件 → [`CLAUDE.md`](CLAUDE.md)
- 移行方針 → [`docs/rules/0001-aws-migration.md`](docs/rules/0001-aws-migration.md)
- 設計判断（ADR） → [`docs/decisions/`](docs/decisions/)
