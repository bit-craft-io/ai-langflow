# docs/rules/0001-aws-migration.md の指示（SQLite → RDS(PostgreSQL)等 マネージド化）に基づくモジュール。
# Langflow用にのみinstantiateする（firecrawl(nuq-postgres)用は移行対象外。cloud/docs/assumptions.md「4.」参照）。

resource "aws_db_subnet_group" "this" {
  name       = "${var.identifier}-subnet-group"
  subnet_ids = var.subnet_ids

  tags = var.tags
}

resource "aws_db_instance" "this" {
  identifier     = var.identifier
  engine         = "postgres"
  engine_version = var.engine_version
  instance_class = var.instance_class

  allocated_storage           = var.allocated_storage
  storage_encrypted           = true
  db_name                     = var.db_name
  username                    = var.master_username
  manage_master_user_password = true

  db_subnet_group_name   = aws_db_subnet_group.this.name
  vpc_security_group_ids = var.vpc_security_group_ids

  multi_az                  = var.multi_az
  publicly_accessible       = false
  backup_retention_period   = 7
  skip_final_snapshot       = var.skip_final_snapshot
  final_snapshot_identifier = var.skip_final_snapshot ? null : "${var.identifier}-final"
  deletion_protection       = var.deletion_protection

  tags = var.tags
}
