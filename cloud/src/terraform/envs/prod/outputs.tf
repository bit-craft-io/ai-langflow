output "alb_dns_name" {
  description = "bridge(WebSocket)への到達先。ClientはこのDNS名(またはCNAME設定した独自ドメイン)に接続する"
  value       = module.alb.dns_name
}

output "ec2_instance_id" {
  value = module.ec2.instance_id
}

output "ec2_private_ip" {
  value = module.ec2.private_ip
}

output "ecr_repository_urls" {
  value = module.ecr.repository_urls
}

output "deploy_bucket_name" {
  value = module.ec2.deploy_bucket_name
}

output "secret_arns" {
  description = "apply後にaws secretsmanager put-secret-valueで実値を投入するシークレット一覧"
  value       = module.secrets.secret_arns
}
