data "aws_caller_identity" "current" {}

locals {
  name_prefix = "${var.project_name}-${var.environment}"

  # S3バケット名はグローバルに一意である必要があるためアカウントIDを含める。
  deploy_bucket_name = "${local.name_prefix}-deploy-${data.aws_caller_identity.current.account_id}"

  # bridgeのECRイメージURI。リポジトリはmodule.ecrで作成済みのため、そのURLにタグを付けるだけでよい。
  bridge_image = "${module.ecr.repository_urls["agent-bridge"]}:latest"

  # langflowai/langflow:1.11.0にgoogle-generativeaiを追加したカスタムイメージ
  # （Google Generative AIコンポーネントのモデル一覧取得に必要。cloud/docker/langflow/Dockerfile参照）。
  langflow_image = "${module.ecr.repository_urls["agent-langflow"]}:latest"

  # voicevox/voicevox_engine:cpu-latestをそのままミラーしたイメージ。Docker Hubからの毎回pullが遅いため
  # ECR経由でpullする運用に変更した（cloud/scripts/build_and_push_voicevox.sh参照）。
  voicevox_image = "${module.ecr.repository_urls["agent-voicevox"]}:latest"
}

# コスト最優先構成（cloud/docs/assumptions.md「D.」参照、ユーザー確認済み）:
# - NAT Gatewayを作らない（EC2をパブリックサブネットに直置きし、IGW経由で直接インターネットへ出る）
# - ALBを作らない（ClientはEC2のパブリックIP:8765へ直接接続する）
# firecrawl-api / playwright-service、およびそれらの裏側インフラ（RDS/ElastiCache/Amazon MQ）、
# opensearch / efsは含まない（docs/rules/0001-aws-migration.md「スコープ外」、および
# EC2+docker compose継続の方針上、これらを個別マネージドサービスへ切り出す根拠がADR上にないため。
# cloud/docs/assumptions.md「D.」参照）。
# コストを抑えたい期間だけ壊しておきたい場合、module.ecr/module.secretsは残したまま
# ネットワーク+EC2だけを壊すには次の2つが必要（module.ecrにはimage_tag_mutability=IMMUTABLEで
# 積んだイメージが、module.secretsには実値がそのまま残るので、再applyしてもput_secrets.shや
# build_and_push_*.shのやり直しは不要）:
#   terraform destroy -target=module.network
#   terraform destroy -target=module.ec2
# 依存関係のcascadeで自動的に巻き込まれるのは、実際にmodule.networkの出力(vpc_id/subnet_id)を
# 参照しているリソースだけ（aws_instance.this / aws_security_group.instance）であり、
# module.ec2全体ではない。S3 deployバケット・IAMロール/ポリシー・S3オブジェクトはネットワークと
# 無関係に作られるため-target=module.networkだけでは残る。両方明示的にdestroyする必要がある
# （実際にterraform state listで確認済み。module.ecr/module.secretsはどちらにも依存していないため
# 対象外のまま）。cloud/README.md「壊す/作り直す運用が前提」参照。
module "network" {
  source = "../../modules/network"

  name                 = local.name_prefix
  vpc_cidr             = var.vpc_cidr
  azs                  = var.azs
  public_subnet_cidrs  = var.public_subnet_cidrs
  private_subnet_cidrs = var.private_subnet_cidrs
  create_nat_gateway   = false
}

module "secrets" {
  source = "../../modules/secrets"

  name_prefix  = local.name_prefix
  secret_names = ["langflow_api_key", "google_api_key", "langflow_superuser_password"]
  # 壊す/作り直す運用が前提のdevのため、destroy直後のapplyで同名シークレットの再作成が
  # 復旧猶予期間で失敗しないよう即時削除にする（cloud/README.md「壊す/作り直す運用が前提」参照）。
  recovery_window_in_days = 0
}

# bridgeイメージ用のECRリポジトリ。EC2上でのdocker build運用（ソース未配置によるビルド失敗、
# t3.small上でのビルドの非効率さ）をやめ、事前ビルド済みイメージをpullする運用に変更したため作成する
# （cloud/docs/assumptions.md「E.」参照、方針変更）。
# prod（envs/prod）は`${local.name_prefix}-bridge`= "agent-prod-bridge"という環境別の名前でECRを作るが、
# devはリポジトリ名を固定の"agent-bridge"にしている（bridge_imageをterraform.tfvarsで直接指定する運用のため。
# 詳細はcompute.tfのbridge_image変数を参照）。
module "ecr" {
  source = "../../modules/ecr"

  repository_names = ["agent-bridge", "agent-langflow", "agent-voicevox"]
  # 壊す/作り直す運用が前提のdevのため、イメージが残っていてもdestroyできるようにする
  # （cloud/README.md「壊す/作り直す運用が前提」参照）。
  force_delete = true
  # devは:latestタグのみ運用（image_tag_mutability=IMMUTABLEのため再pushは事前に旧タグを削除する
  # 運用、cloud/README.md参照）で複数世代を保持する必要がないため、最新1世代のみ保持する。
  max_image_count = 1
}

# RDS(langflow用)も作らない。動作確認用途の間はon-premisesと同じSQLiteのまま使う
# （ADR-0013、cloud/docs/assumptions.md「F.」参照、ユーザー確認済み）。PostgreSQLへの移行検証はenvs/prodで行う。
