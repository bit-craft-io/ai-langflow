variable "identifier" {
  type = string
}

variable "db_name" {
  type = string
}

variable "master_username" {
  type    = string
  default = "app_admin"
}

variable "engine_version" {
  type    = string
  default = "16"
}

variable "instance_class" {
  type    = string
  default = "db.t4g.micro"
}

variable "allocated_storage" {
  type    = number
  default = 20
}

variable "multi_az" {
  type    = bool
  default = false
}

variable "deletion_protection" {
  description = "falseにするとterraform destroyで削除できる（destroyを繰り返してコストを抑えたいdev環境向け）"
  type        = bool
  default     = true
}

variable "skip_final_snapshot" {
  description = "trueの場合destroy時に最終スナップショットを取らない（dev環境向け。スナップショット分のストレージ課金も避けられる）"
  type        = bool
  default     = false
}

variable "subnet_ids" {
  type = list(string)
}

variable "vpc_security_group_ids" {
  type = list(string)
}

variable "tags" {
  type    = map(string)
  default = {}
}
