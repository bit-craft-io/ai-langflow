#!/usr/bin/env bash
# onprem/docker/bridge/backend をdocker buildし、ECRリポジトリ"agent-bridge"へpushする。
# EC2(t3.small)上でのビルドはソース未配置による失敗が頻発し非効率だったため、
# 事前ビルド済みイメージをECR経由でpullする運用に変更した（cloud/docs/assumptions.md「E.」参照）。
#
# 前提: aws configure等でAWS CLIの認証情報が設定済みであること。
# 使い方:
#   ./build_and_push_bridge.sh [tag] [aws_account_id] [aws_region]
#   例: ./build_and_push_bridge.sh latest 741448957524 ap-northeast-1
set -euo pipefail

TAG="${1:-latest}"
AWS_ACCOUNT_ID="${2:-741448957524}"
AWS_REGION="${3:-ap-northeast-1}"

REPO_NAME="agent-bridge"
ECR_REGISTRY="${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com"
IMAGE_URI="${ECR_REGISTRY}/${REPO_NAME}:${TAG}"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BACKEND_DIR="${SCRIPT_DIR}/../../../onprem/docker/bridge/backend"

echo "ECRへログイン: ${ECR_REGISTRY}"
aws ecr get-login-password --region "${AWS_REGION}" | docker login --username AWS --password-stdin "${ECR_REGISTRY}"

echo "docker build: ${BACKEND_DIR} -> ${IMAGE_URI}"
# EC2ホストはx86_64のため、Apple Silicon等の別アーキテクチャ環境でビルドする場合は
# --platform linux/amd64 を明示する。
docker build --platform linux/amd64 -t "${IMAGE_URI}" "${BACKEND_DIR}"

echo "docker push: ${IMAGE_URI}"
docker push "${IMAGE_URI}"

echo "done: ${IMAGE_URI}"
echo "bridge_imageはterraform側(envs/dev/main.tf)でmodule.ecrの出力から自動算出される(タグは:latest固定)。"
echo "latestタグでpushした場合はterraform.tfvarsの変更は不要。EC2再起動(またはssm send-commandでのuser-data再実行)でこのイメージが反映される。"
echo "latest以外のタグを使う場合はenvs/dev/main.tfのlocal.bridge_imageを直接編集すること。"
