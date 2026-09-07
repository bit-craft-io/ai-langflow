#!/usr/bin/env bash
# 壊す/作り直す運用（cloud/README.md参照）で、destroy後に課金対象リソースが残っていないか
# まとめて確認するためのスクリプト。個別にaws cliを何度も打つ代わりにこれ1本で済ませる。
#
# 前提: aws configure等でAWS CLIの認証情報が設定済みであること。
# 使い方:
#   ./check_aws_usage.sh [aws_region]
#   例: ./check_aws_usage.sh ap-northeast-1
#
# 対象リージョンのみのチェック（全リージョン横断ではない点に注意）。
set -uo pipefail

AWS_REGION="${1:-ap-northeast-1}"

section() {
  echo
  echo "=== $1 ==="
}

section "EC2インスタンス（terminated以外、region: ${AWS_REGION}）"
aws ec2 describe-instances --region "${AWS_REGION}" \
  --query 'Reservations[].Instances[?State.Name!=`terminated`].[InstanceId,State.Name,Tags]'

section "EBSボリューム（available/in-use）"
aws ec2 describe-volumes --region "${AWS_REGION}" \
  --filters "Name=status,Values=available,in-use"

section "Elastic IP（未アタッチでも課金対象）"
aws ec2 describe-addresses --region "${AWS_REGION}"

section "NAT Gateway（高額注意）"
aws ec2 describe-nat-gateways --region "${AWS_REGION}" \
  --filter "Name=state,Values=available"

section "RDSインスタンス（高額注意、region: ${AWS_REGION}）"
aws rds describe-db-instances --region "${AWS_REGION}" \
  --query 'DBInstances[].[DBInstanceIdentifier,DBInstanceStatus,DeletionProtection]'

section "RDSスナップショット（手動作成分、削除保護解除後も課金対象、region: ${AWS_REGION}）"
aws rds describe-db-snapshots --region "${AWS_REGION}" \
  --snapshot-type manual \
  --query 'DBSnapshots[].[DBSnapshotIdentifier,Status]'

section "S3バケット一覧（全リージョン共通）"
aws s3 ls

section "Secrets Manager（削除予定含む、region: ${AWS_REGION}）"
aws secretsmanager list-secrets --region "${AWS_REGION}" \
  --include-planned-deletion --query "SecretList[].Name"

section "IAMロール（agentを含むもの、グローバル）"
aws iam list-roles --query "Roles[?contains(RoleName,'agent')]"

section "CloudWatch Logsロググループ（agentを含むもの、region: ${AWS_REGION}）"
aws logs describe-log-groups --region "${AWS_REGION}" \
  --query "logGroups[?contains(logGroupName,'agent')]"

section "ECRリポジトリ（region: ${AWS_REGION}）"
aws ecr describe-repositories --region "${AWS_REGION}"

echo
echo "done."
