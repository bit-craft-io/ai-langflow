# Terraformモジュール削除ルール

不要なTerraformモジュールを削除する際は、以下の型で依頼する。

## 手順

1. 対象モジュールの削除と理由の明記
2. terraform init / validate による確認
3. docs/decisions/ へのADR追加（理由を明示しないと記録されない）

## 指示テンプレート

```
以下を実行して:

1. [モジュール名] モジュールを [対象env] から削除する。
   理由: [削除理由]

2. terraform init と terraform validate を実行し、
   エラーが無いことを確認する。

3. この決定を docs/decisions/ にADRとして追加する。
   番号は既存の連番の続きとする。
```

推測で削除せず、根拠不明な場合は質問する。
