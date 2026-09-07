variable "name_prefix" {
  description = "シークレット名のプレフィックス（例: agent/prod）"
  type        = string
}

variable "secret_names" {
  description = "作成するシークレットのキー一覧（例: [\"langflow_api_key\", \"google_api_key\"]）。値は空のプレースホルダで作成し、apply後に別途投入する"
  type        = list(string)
}

variable "tags" {
  type    = map(string)
  default = {}
}

variable "recovery_window_in_days" {
  description = "シークレット削除時の復旧猶予期間（日）。0にすると即時削除される。壊す/作り直す運用のdevでは0推奨、誤削除からの復旧を残したいprodはデフォルト(30)のままにすること"
  type        = number
  default     = 30
}
