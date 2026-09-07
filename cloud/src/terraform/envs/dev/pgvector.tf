# pgvectorを試すための使い捨てRDS（cloud/docs/rules/0001-aws-migration.md「スコープ外」の対象ではなく、
# 新規にpgvector検証用途で追加するもの。private subnet 10.21.10.0/24側に配置）。
# 動作確認が終わったら
#   terraform destroy -target=module.rds_pgvector -target=aws_security_group.rds_pgvector
# で畳む運用にする（cloud/README.md「壊す/作り直す運用が前提」参照）。
#
# instance_class/allocated_storage/engine_version/multi_azはmodules/rds_postgresのデフォルト
# （db.t4g.micro・gp3 20GiB・PostgreSQL16・Single-AZ = 最安構成、pgvectorはPostgreSQL15.2以降で対応）
# のまま使う。deletion_protection/skip_final_snapshotはモジュール側がprod想定のデフォルト
# （true/false）になっているため、devでは壊せる/最終スナップショット分の課金が残らないよう
# 明示的に上書きする。

resource "aws_security_group" "rds_pgvector" {
  name_prefix = "${local.name_prefix}-rds-pgvector-"
  vpc_id      = module.network.vpc_id

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# EC2ホストのSGからのみ5432を許可（prod envs/rds_langflowと同じ構成）。
resource "aws_security_group_rule" "rds_pgvector_from_ec2" {
  type                     = "ingress"
  security_group_id        = aws_security_group.rds_pgvector.id
  from_port                = 5432
  to_port                  = 5432
  protocol                 = "tcp"
  source_security_group_id = module.ec2.security_group_id
}

module "rds_pgvector" {
  source = "../../modules/rds_postgres"

  identifier      = "${local.name_prefix}-pgvector"
  db_name         = "pgvector"
  master_username = "pgvector_admin"

  subnet_ids             = module.network.private_subnet_ids
  vpc_security_group_ids = [aws_security_group.rds_pgvector.id]

  # 壊す/作り直す運用が前提のdevのため、destroyを妨げないよう上書きする。
  deletion_protection = false
  skip_final_snapshot = true
}
