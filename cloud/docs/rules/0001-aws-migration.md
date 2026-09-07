# AWS移行ルール
 
on-premises構成をAWS上で動作する構成に変換する。
 
## 方針
 
- docker-compose → 各サービスAWS配置
- SQLite → RDS(PostgreSQL)等 マネージド化検討
- .env平文キー → Secrets Manager/Parameter Store化
- 詳細判断はdocs/decisions/参照
推測で変えず、不明点は質問。

## スコープ外
- firecrawl-api / playwright-service は移行対象外（Cloud API課金のため）。
  AWS構成ファイルを作成しない。
- 上記に反してcloud/docker/compose/docker-compose.agent-crawl.yaml（firecrawl-api / playwright-service用のcompose）が
  作成されていたため削除済み。関連するdocker compose / Terraform / ドキュメントの記述も今後追加しないこと。
