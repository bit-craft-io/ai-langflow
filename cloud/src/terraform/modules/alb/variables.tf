variable "name" {
  type = string
}

variable "vpc_id" {
  type = string
}

variable "public_subnet_ids" {
  type = list(string)
}

variable "target_port" {
  description = "bridgeのWebSocketポート（on-premisesのデフォルト8765、ADR-0002）"
  type        = number
  default     = 8765
}

variable "certificate_arn" {
  description = "ACM証明書ARN。空文字の場合はHTTPのみでリッスンする（cloud/docs/assumptions.md「B.」参照）"
  type        = string
  default     = ""
}

variable "tags" {
  type    = map(string)
  default = {}
}
