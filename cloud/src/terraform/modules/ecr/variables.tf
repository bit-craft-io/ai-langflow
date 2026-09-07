variable "repository_names" {
  description = "作成するECRリポジトリ名一覧（EC2ホストがdocker composeでpullするイメージ）"
  type        = list(string)
}

variable "tags" {
  type    = map(string)
  default = {}
}

variable "force_delete" {
  description = "trueの場合、イメージが残っていてもterraform destroyでリポジトリごと削除する（壊す/作り直す運用のdev向け。prodではfalseのままにすること）"
  type        = bool
  default     = false
}

variable "max_image_count" {
  description = "ライフサイクルポリシーで保持するイメージ数の上限（これを超えた分は自動でexpireされる）"
  type        = number
  default     = 20
}
