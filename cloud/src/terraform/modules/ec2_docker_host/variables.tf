variable "name" {
  type = string
}

variable "vpc_id" {
  type = string
}

variable "subnet_id" {
  description = "インスタンスを配置するサブネット"
  type        = string
}

variable "instance_type" {
  description = "voicevox/langflow/bridge/opensearch/opensearch-uiを1台に同居させるインスタンスタイプ（要サイジング見直し、cloud/docs/assumptions.md「C.」参照）"
  type        = string
  default     = "t3.large"
}

variable "ami_id" {
  description = "空文字の場合は最新のAmazon Linux 2023 AMIを自動選択する"
  type        = string
  default     = ""
}

variable "root_volume_size" {
  description = "GB。docker imageのローカルキャッシュ + langflowデータ分を見込む"
  type        = number
  default     = 60
}

variable "enable_alb" {
  description = "falseの場合ALB経由の設定を行わず、bridgeポートをdirect_ingress_cidr_blocksからの直接アクセスに開放する（dev構成向け。cloud/docs/assumptions.md「D.」参照）"
  type        = bool
  default     = true
}

variable "alb_security_group_id" {
  description = "enable_alb=trueの場合必須"
  type        = string
  default     = ""
}

variable "alb_target_group_arn" {
  description = "enable_alb=trueの場合必須"
  type        = string
  default     = ""
}

variable "direct_ingress_cidr_blocks" {
  description = "enable_alb=falseの場合にbridgeポート(8765)への直接アクセスを許可するCIDR。0.0.0.0/0は避け、開発者のIP等に絞ること"
  type        = list(string)
  default     = []
}

variable "associate_public_ip_address" {
  description = "trueの場合EC2にパブリックIPを直接付与する（パブリックサブネット配置・NATなしのdev構成向け）"
  type        = bool
  default     = false
}

variable "deploy_bucket_name" {
  type = string
}

variable "compose_agent_local_path" {
  description = "cloud/docker/compose/docker-compose.agent.yaml へのローカルパス"
  type        = string
}

variable "langflow_flows_local_dir" {
  description = "on-premises/server/langflow/agents へのローカルパス。中身をS3経由でEC2ホストにsyncしてbindマウントする"
  type        = string
}

variable "aws_region" {
  type = string
}

# --- コンテナイメージ（ECR）---
variable "bridge_image" {
  description = "ECRのイメージURL。空文字の場合はECRログインを行わない（bridgeをEC2上でgit clone + docker compose buildする運用向け。cloud/docs/assumptions.md「E.」参照）"
  type        = string
  default     = ""
}

variable "langflow_image" {
  description = "google-generativeaiを追加したカスタムlangflowイメージのECR URL。空文字の場合は.envにLANGFLOW_IMAGEを書かず、docker-compose側のデフォルト（langflowai/langflow:1.11.0）を使う"
  type        = string
  default     = ""
}

variable "voicevox_image" {
  description = "voicevox/voicevox_engine:cpu-latestをそのままミラーしたECR URL（Docker Hubからの毎回pullが遅いため）。空文字の場合は.envにVOICEVOX_IMAGEを書かず、docker-compose側のデフォルト（voicevox/voicevox_engine:cpu-latest）を使う"
  type        = string
  default     = ""
}

variable "langflow_secret_key" {
  description = "Langflowが暗号化保存（グローバル変数等）に使う固定キー。空文字の場合は.envに書かず、Langflow起動時の自動生成に任せる（コンテナ作り直しの度に鍵が変わり、既存の暗号化値が読めなくなる点に注意）"
  type        = string
  default     = ""
  sensitive   = true
}

variable "langflow_flow_id" {
  description = "bridgeが呼び出すLangflowフローのendpoint_name（例: gemini-pg）。空文字の場合は.envにLANGFLOW_FLOW_IDを書かず、docker-compose側の値をそのまま使う"
  type        = string
  default     = ""
}

# --- Secrets Manager ARN ---
variable "langflow_api_key_secret_arn" {
  type = string
}

variable "google_api_key_secret_arn" {
  type = string
}

variable "langflow_superuser_password_secret_arn" {
  type = string
}

variable "rds_langflow_master_secret_arn" {
  description = "空文字の場合RDS用のシークレット取得を行わない（langflowをSQLiteのまま使う運用向け。ADR-0013参照）"
  type        = string
  default     = ""
}

# --- 接続先エンドポイント（非シークレット）---
variable "rds_langflow_host" {
  type    = string
  default = ""
}

variable "rds_langflow_port" {
  type    = number
  default = 0
}

variable "rds_langflow_dbname" {
  type    = string
  default = ""
}

variable "tags" {
  type    = map(string)
  default = {}
}
