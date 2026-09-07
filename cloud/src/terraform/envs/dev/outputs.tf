output "ec2_public_ip" {
  description = "ClientはこのIPの8765番ポートへ直接WebSocket接続する（ALBなし構成のため、cloud/docs/assumptions.md「D.」参照）"
  value       = module.ec2.public_ip
}

output "ec2_instance_id" {
  value = module.ec2.instance_id
}

output "deploy_bucket_name" {
  value = module.ec2.deploy_bucket_name
}

output "secret_arns" {
  description = "apply後にaws secretsmanager put-secret-valueで実値を投入するシークレット一覧"
  value       = module.secrets.secret_arns
}

output "rds_pgvector_endpoint" {
  description = "pgvector接続先（host:port）。langflowからはここへ5432で接続する"
  value       = module.rds_pgvector.endpoint
}

output "rds_pgvector_master_secret_arn" {
  description = "RDSが自動作成したマスターユーザー認証情報（manage_master_user_password）のSecrets Manager ARN"
  value       = module.rds_pgvector.master_user_secret_arn
}
