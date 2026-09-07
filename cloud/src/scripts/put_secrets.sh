#!/usr/bin/env bash
# Secrets Manager の3シークレット（langflow_api_key/google_api_key/langflow_superuser_password）に
# 実値を投入する。terraform applyはシークレットの「箱」だけを作り、値はTerraform管理外にしているため
# （cloud/terraform/modules/secrets/main.tf参照）、apply（または壊す/作り直す運用でのdestroy→apply）の
# 都度、このスクリプトで値を投入し直すこと。
#
# 値をコマンドライン引数で渡すとshell履歴やps auxに残るため、環境変数経由で渡す設計にしている。
#
# 前提: aws configure等でAWS CLIの認証情報が設定済みであること。
# 使い方:
#   LANGFLOW_API_KEY=... GOOGLE_API_KEY=... LANGFLOW_SUPERUSER_PASSWORD=... \
#     ./put_secrets.sh [name_prefix] [aws_region]
#   例（devのデフォルト値: name_prefix=agent-dev, aws_region=ap-northeast-1）:
#   LANGFLOW_API_KEY=sk-xxx GOOGLE_API_KEY=AQ.xxx LANGFLOW_SUPERUSER_PASSWORD=xxx \
#     ./put_secrets.sh
set -euo pipefail

NAME_PREFIX="${1:-agent-dev}"
AWS_REGION="${2:-ap-northeast-1}"

: "${LANGFLOW_API_KEY:?LANGFLOW_API_KEY を環境変数で指定してください}"
: "${GOOGLE_API_KEY:?GOOGLE_API_KEY を環境変数で指定してください}"
: "${LANGFLOW_SUPERUSER_PASSWORD:?LANGFLOW_SUPERUSER_PASSWORD を環境変数で指定してください}"

put_secret() {
  local secret_name="$1"
  local secret_value="$2"
  echo "put-secret-value: ${NAME_PREFIX}/${secret_name}"
  aws secretsmanager put-secret-value \
    --region "${AWS_REGION}" \
    --secret-id "${NAME_PREFIX}/${secret_name}" \
    --secret-string "${secret_value}" \
    >/dev/null
}

put_secret "langflow_api_key" "${LANGFLOW_API_KEY}"
put_secret "google_api_key" "${GOOGLE_API_KEY}"
put_secret "langflow_superuser_password" "${LANGFLOW_SUPERUSER_PASSWORD}"

echo "done: ${NAME_PREFIX} の3シークレットに実値を投入しました。"
