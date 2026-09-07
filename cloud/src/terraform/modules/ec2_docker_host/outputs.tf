output "instance_id" {
  value = aws_instance.this.id
}

output "security_group_id" {
  value = aws_security_group.instance.id
}

output "private_ip" {
  value = aws_instance.this.private_ip
}

output "public_ip" {
  description = "associate_public_ip_address=trueの場合のみ値が入る"
  value       = aws_instance.this.public_ip
}

output "deploy_bucket_name" {
  value = aws_s3_bucket.deploy.bucket
}
