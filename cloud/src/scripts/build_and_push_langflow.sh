#!/usr/bin/env bash
# cloud/docker/langflow/Dockerfile（langflowai/langflow:1.11.0 + google-generativeai）をdocker buildし、
# ECRリポジトリ"agent-langflow"へpushする。
# EC2上でのビルドは避け、bridgeと同じく事前ビルド済みイメージをECR経由でpullする運用にする
# （cloud/docs/assumptions.md「E.」と同じ理由）。
#
# 前提: aws configure等でAWS CLIの認証情報が設定済みであること。
# 使い方:
#   ./build_and_push_langflow.sh [tag] [aws_account_id] [aws_region]
#   例: ./build_and_push_langflow.sh latest 741448957524 ap-northeast-1
set -euo pipefail

TAG="${1:-latest}"
AWS_ACCOUNT_ID="${2:-741448957524}"
AWS_REGION="${3:-ap-northeast-1}"

REPO_NAME="agent-langflow"
ECR_REGISTRY="${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com"
IMAGE_URI="${ECR_REGISTRY}/${REPO_NAME}:${TAG}"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LANGFLOW_DIR="${SCRIPT_DIR}/../docker/langflow"

echo "ECRへログイン: ${ECR_REGISTRY}"
aws ecr get-login-password --region "${AWS_REGION}" | docker login --username AWS --password-stdin "${ECR_REGISTRY}"

echo "docker build: ${LANGFLOW_DIR} -> ${IMAGE_URI}"
# EC2ホストはx86_64のため、Apple Silicon等の別アーキテクチャ環境でビルドする場合は
# --platform linux/amd64 を明示する。
docker build --platform linux/amd64 -t "${IMAGE_URI}" "${LANGFLOW_DIR}"

echo "docker push: ${IMAGE_URI}"
docker push "${IMAGE_URI}"

echo "done: ${IMAGE_URI}"
echo "langflow_imageはterraform側(envs/dev/main.tf)でmodule.ecrの出力から自動算出される(タグは:latest固定)。"
echo "latestタグでpushした場合はterraform.tfvarsの変更は不要。EC2上で以下を実行して反映する:"
echo "  cd /opt/agent && sudo docker compose -p agent -f docker-compose.agent.yaml --env-file .env up -d --force-recreate langflow"
