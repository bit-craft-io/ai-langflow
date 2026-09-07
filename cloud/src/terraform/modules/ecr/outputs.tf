output "repository_urls" {
  description = "リポジトリ名 -> リポジトリURL"
  value       = { for k, v in aws_ecr_repository.this : k => v.repository_url }
}
