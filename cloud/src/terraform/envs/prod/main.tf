locals {
  name_prefix = "${var.project_name}-${var.environment}"
}

module "network" {
  source = "../../modules/network"

  name                 = local.name_prefix
  vpc_cidr             = var.vpc_cidr
  azs                  = var.azs
  public_subnet_cidrs  = var.public_subnet_cidrs
  private_subnet_cidrs = var.private_subnet_cidrs
}

module "secrets" {
  source = "../../modules/secrets"

  name_prefix  = local.name_prefix
  secret_names = ["langflow_api_key", "google_api_key", "langflow_superuser_password"]
}

# EC2ホストがdocker composeでpullするイメージ（既存Dockerfileをそのままビルドしてpushする）。
# langflowはon-premisesと同じ langflowai/langflow:1.11.0 をそのままpullするためECRリポジトリは不要
# （flows(agents/*.json)はS3経由でホストにsyncしてbindマウントする。cloud/terraform/modules/ec2_docker_host参照）。
# firecrawl-api / playwright-serviceは移行対象外のためリポジトリを作らない（docs/rules/0001-aws-migration.md「スコープ外」参照）。
module "ecr" {
  source = "../../modules/ecr"

  repository_names = [
    "${local.name_prefix}-bridge",
  ]
}

# --- バックエンドサービス用セキュリティグループ（ingressルールはcompute.tfでEC2ホストのSGを参照して追加）---
resource "aws_security_group" "rds_langflow" {
  name_prefix = "${local.name_prefix}-rds-langflow-"
  vpc_id      = module.network.vpc_id
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

module "rds_langflow" {
  source = "../../modules/rds_postgres"

  identifier             = "${local.name_prefix}-langflow"
  db_name                = "langflow"
  master_username        = "langflow_admin"
  instance_class         = var.rds_instance_class
  subnet_ids             = module.network.private_subnet_ids
  vpc_security_group_ids = [aws_security_group.rds_langflow.id]
}

module "alb" {
  source = "../../modules/alb"

  name              = "${local.name_prefix}-alb"
  vpc_id            = module.network.vpc_id
  public_subnet_ids = module.network.public_subnet_ids
  target_port       = 8765
  certificate_arn   = var.certificate_arn
}
