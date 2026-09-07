variable "project_name" {
  type    = string
  default = "agent"
}

variable "environment" {
  type    = string
  default = "dev"
}

variable "aws_region" {
  type    = string
  default = "ap-northeast-1"
}

# コスト優先でprodと同じ2AZ構成のまま（RDS/ElastiCacheのサブネットグループはAWS側の制約で
# 最低2AZ分のサブネットを要求されるため、AZ数を減らしてもコストは変わらない。
# NAT Gatewayを作らないことがコスト削減の本体。cloud/docs/assumptions.md「D.」参照）。
variable "azs" {
  type    = list(string)
  default = ["ap-northeast-1a", "ap-northeast-1c"]
}

variable "vpc_cidr" {
  description = "prodのVPCと重複しないCIDRにすること"
  type        = string
  default     = "10.21.0.0/16"
}

variable "public_subnet_cidrs" {
  type    = list(string)
  default = ["10.21.0.0/24", "10.21.1.0/24"]
}

variable "private_subnet_cidrs" {
  type    = list(string)
  default = ["10.21.10.0/24", "10.21.11.0/24"]
}

variable "dev_client_cidr_blocks" {
  description = "ALBを使わずEC2に直接接続するdev構成のため、bridgeポート(8765)への接続を許可するCIDRを明示指定する。0.0.0.0/0は避け、開発者の固定IP等に絞ること（例: [\"203.0.113.10/32\"]）"
  type        = list(string)
}

variable "instance_type" {
  description = "voicevox/langflow/bridge/opensearch/opensearch-uiを同居させるEC2インスタンスタイプ。動作確認用途のみのためt3.smallにしている（ADR-0012参照）。t3.micro(1vCPU/1GiB)はOpenSearch等5サービス同居時にメモリ不足のリスクが高いため見送った。t3.small(2vCPU/2GiB)でも本来のサイジングより小さく、OOMのリスクは残る（cloud/docs/assumptions.md「C.」参照）"
  type        = string
  default     = "t3.small"
}

variable "root_volume_size" {
  description = "GB"
  type        = number
  default     = 30
}

variable "langflow_secret_key" {
  description = "Langflowが暗号化保存（グローバル変数等）に使う固定キー。空文字だと起動の度にランダム生成され、既存の暗号化値が読めなくなる"
  type        = string
  default     = ""
  sensitive   = true
}

