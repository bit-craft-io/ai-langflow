variable "project_name" {
  type    = string
  default = "agent"
}

variable "environment" {
  type    = string
  default = "prod"
}

variable "aws_region" {
  type    = string
  default = "ap-northeast-1"
}

variable "azs" {
  type    = list(string)
  default = ["ap-northeast-1a", "ap-northeast-1c"]
}

variable "vpc_cidr" {
  type    = string
  default = "10.20.0.0/16"
}

variable "public_subnet_cidrs" {
  type    = list(string)
  default = ["10.20.0.0/24", "10.20.1.0/24"]
}

variable "private_subnet_cidrs" {
  type    = list(string)
  default = ["10.20.10.0/24", "10.20.11.0/24"]
}

variable "certificate_arn" {
  description = "ALB用ACM証明書ARN。空文字の場合はHTTPのみで公開する（cloud/docs/assumptions.md「B.」参照、要確認）"
  type        = string
  default     = ""
}

variable "instance_type" {
  description = "voicevox/langflow/bridge/opensearch/opensearch-uiを同居させるEC2インスタンスタイプ"
  type        = string
  default     = "t3.large"
}

variable "deploy_bucket_name" {
  description = "compose定義を置くS3バケット名（グローバルに一意にする必要がある。例: agent-prod-deploy-<アカウントID>）"
  type        = string
}

variable "rds_instance_class" {
  type    = string
  default = "db.t4g.micro"
}
