module "ec2" {
  source = "../../modules/ec2_docker_host"

  name          = "${local.name_prefix}-host"
  vpc_id        = module.network.vpc_id
  subnet_id     = module.network.private_subnet_ids[0]
  instance_type = var.instance_type
  aws_region    = var.aws_region

  alb_security_group_id = module.alb.security_group_id
  alb_target_group_arn  = module.alb.target_group_arn

  deploy_bucket_name       = var.deploy_bucket_name
  compose_agent_local_path = "${path.module}/../../../docker/compose/docker-compose.agent.yaml"
  langflow_flows_local_dir = "${path.module}/../../../../../onprem/docker/langflow/flows"

  bridge_image = "${module.ecr.repository_urls["${local.name_prefix}-bridge"]}:latest"

  langflow_api_key_secret_arn            = module.secrets.secret_arns["langflow_api_key"]
  google_api_key_secret_arn              = module.secrets.secret_arns["google_api_key"]
  langflow_superuser_password_secret_arn = module.secrets.secret_arns["langflow_superuser_password"]
  rds_langflow_master_secret_arn         = module.rds_langflow.master_user_secret_arn

  rds_langflow_host   = module.rds_langflow.address
  rds_langflow_port   = module.rds_langflow.port
  rds_langflow_dbname = module.rds_langflow.db_name
}

# --- バックエンドサービスへのアクセスをEC2ホストのSGからのみ許可 ---

resource "aws_security_group_rule" "rds_langflow_from_ec2" {
  type                     = "ingress"
  security_group_id        = aws_security_group.rds_langflow.id
  from_port                = 5432
  to_port                  = 5432
  protocol                 = "tcp"
  source_security_group_id = module.ec2.security_group_id
}
