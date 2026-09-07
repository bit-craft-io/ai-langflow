# ADR-0013: `cloud/terraform/envs/dev` はLangflowのDBをRDSではなくSQLiteのまま使う

## Status
Accepted

## Context
- `docs/rules/0001-aws-migration.md`の方針「SQLite → RDS(PostgreSQL)等 マネージド化検討」に従い、
  `cloud/docs/assumptions.md`「4.」でLangflow用のRDS for PostgreSQLを採用していた
  （`envs/prod`・`envs/dev`双方に`module "rds_langflow"`として実装済み）。
- コストを極力抑えたいという要望があり、`envs/dev`（動作確認・検証用途のみ、[ADR-0012](0012-dev-env-ec2-instance-sizing.md)参照）
  についてはRDSへの移行検証自体を本番構成（`envs/prod`）まで後回しにし、on-premisesと同じSQLiteのまま
  動作確認する方針とした。RDS(db.t4g.micro)は`envs/dev`のAWSリソースの中でEC2に次ぐコスト要因である。

## Decision
- `cloud/terraform/envs/dev/main.tf`から`module "rds_langflow"`とそれ専用のセキュリティグループを削除し、
  `envs/dev/compute.tf`からRDS関連の変数受け渡し・セキュリティグループルールを削除した。
- `modules/ec2_docker_host`の`rds_langflow_master_secret_arn`/`rds_langflow_host`/`rds_langflow_port`/
  `rds_langflow_dbname`変数を空文字（または`0`）許容にし、空の場合はuser-dataでのRDSシークレット取得・
  `.env`への`LANGFLOW_DATABASE_URL`書き込みをスキップするようにした。
- `cloud/docker/compose/docker-compose.agent.dev.yaml`のlangflowサービスで、`LANGFLOW_DATABASE_URL`を
  `${LANGFLOW_DATABASE_URL}`（RDS参照）ではなく、on-premisesと同じ`sqlite:////app/data/langflow.db`に固定した。
  SQLiteファイルはEC2ローカルディスク（`/opt/agent/langflow-data`、EBS）上に永続化される。
- `envs/prod`用の`docker-compose.agent.yaml`・`module "rds_langflow"`は変更しない。引き続きRDS for PostgreSQLを使う。

## Consequences
- `envs/dev`は単一EC2インスタンス構成のため、複数インスタンス間でのDB共有ができない制約は実害にならない。
- EC2インスタンス（またはEBSボリューム）を削除するとSQLiteデータも失われる。動作確認用途であり許容する。
- PostgreSQLへの移行に伴う実際の動作検証（接続文字列、マイグレーション等）は`envs/prod`側でのみ行われることになる。
  `envs/dev`での動作確認結果がそのまま`envs/prod`のDB層の動作を保証するわけではない点に注意すること。
