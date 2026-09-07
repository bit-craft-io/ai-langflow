output "secret_arns" {
  description = "シークレット名 -> ARN"
  value       = { for k, v in aws_secretsmanager_secret.this : k => v.arn }
}
