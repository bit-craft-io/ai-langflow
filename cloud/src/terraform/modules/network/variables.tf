variable "name" {
  description = "リソース名のプレフィックス"
  type        = string
}

variable "vpc_cidr" {
  description = "VPCのCIDR"
  type        = string
  default     = "10.20.0.0/16"
}

variable "azs" {
  description = "使用するアベイラビリティゾーン"
  type        = list(string)
}

variable "public_subnet_cidrs" {
  description = "パブリックサブネットのCIDR（azsと同数）"
  type        = list(string)
}

variable "private_subnet_cidrs" {
  description = "プライベートサブネットのCIDR（azsと同数）"
  type        = list(string)
}

variable "create_nat_gateway" {
  description = "falseの場合NAT Gatewayを作成しない（プライベートサブネットはインターネットへのデフォルトルートを持たない）。EC2ホストをパブリックサブネットに直置きしてNAT不要にするdev構成向け"
  type        = bool
  default     = true
}

variable "tags" {
  type    = map(string)
  default = {}
}
