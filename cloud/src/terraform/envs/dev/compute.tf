module "ec2" {
  source = "../../modules/ec2_docker_host"

  name          = "${local.name_prefix}-host"
  vpc_id        = module.network.vpc_id
  subnet_id     = module.network.public_subnet_ids[0] # NATなしのためパブリックサブネットに直置き
  instance_type = var.instance_type
  aws_region    = var.aws_region

  root_volume_size = var.root_volume_size

  associate_public_ip_address = true
  enable_alb                  = false
  direct_ingress_cidr_blocks  = var.dev_client_cidr_blocks

  deploy_bucket_name       = local.deploy_bucket_name
  compose_agent_local_path = "${path.module}/../../../docker/compose/docker-compose.agent.dev.yaml"
  langflow_flows_local_dir = "${path.module}/../../../../../onprem/docker/langflow/flows"

  bridge_image        = local.bridge_image
  langflow_image      = local.langflow_image
  voicevox_image      = local.voicevox_image
  langflow_secret_key = var.langflow_secret_key
  # Gemini + PgVectorSearchのフロー（pgvector検証用RDS: module.rds_pgvector参照）。
  langflow_flow_id = "gemini-pg"

  # rds_langflow_*は指定しない（RDSは作らない）。langflowは動作確認用途の間on-premisesと同じSQLiteのまま使う
  # （ADR-0013、cloud/docs/assumptions.md「F.」参照）。

  langflow_api_key_secret_arn            = module.secrets.secret_arns["langflow_api_key"]
  google_api_key_secret_arn              = module.secrets.secret_arns["google_api_key"]
  langflow_superuser_password_secret_arn = module.secrets.secret_arns["langflow_superuser_password"]
}
