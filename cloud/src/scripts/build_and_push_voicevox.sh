#!/usr/bin/env bash
# voicevox/voicevox_engine:cpu-latest（Docker Hub公式イメージ）をそのままECRリポジトリ"agent-voicevox"へ
# ミラーする。EC2起動の度にDocker Hubからpullすると時間が掛かるため、ECR経由でpullする運用に変更した。
# ビルドは行わない（vendored/カスタマイズ済みイメージではなく公式イメージそのままのため）。
#
# 前提: aws configure等でAWS CLIの認証情報が設定済みであること。
# 使い方:
#   ./build_and_push_voicevox.sh [source_tag] [aws_account_id] [aws_region]
#   例: ./build_and_push_voicevox.sh cpu-latest 741448957524 ap-northeast-1
set -euo pipefail

SOURCE_TAG="${1:-cpu-latest}"
AWS_ACCOUNT_ID="${2:-741448957524}"
AWS_REGION="${3:-ap-northeast-1}"

SOURCE_IMAGE="voicevox/voicevox_engine:${SOURCE_TAG}"
REPO_NAME="agent-voicevox"
ECR_REGISTRY="${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com"
IMAGE_URI="${ECR_REGISTRY}/${REPO_NAME}:latest"

echo "ECRへログイン: ${ECR_REGISTRY}"
aws ecr get-login-password --region "${AWS_REGION}" | docker login --username AWS --password-stdin "${ECR_REGISTRY}"

echo "docker pull: ${SOURCE_IMAGE}"
# EC2ホストはx86_64のため、Apple Silicon等の別アーキテクチャ環境でpullする場合は
# --platform linux/amd64 を明示する。
docker pull --platform linux/amd64 "${SOURCE_IMAGE}"

echo "docker tag: ${SOURCE_IMAGE} -> ${IMAGE_URI}"
docker tag "${SOURCE_IMAGE}" "${IMAGE_URI}"

echo "docker push: ${IMAGE_URI}"
docker push "${IMAGE_URI}"

echo "done: ${IMAGE_URI}"
echo "voicevox_imageはterraform側(envs/dev/main.tf)でmodule.ecrの出力から自動算出される(タグは:latest固定)。"
echo "pushした場合はterraform.tfvarsの変更は不要。EC2再起動(またはssm send-commandでのuser-data再実行)でこのイメージが反映される。"
echo "既存EC2に即時反映する場合は以下を実行する:"
echo "  cd /opt/agent && sudo docker compose -p agent -f docker-compose.agent.yaml --env-file .env pull voicevox && \\"
echo "  sudo docker compose -p agent -f docker-compose.agent.yaml --env-file .env up -d voicevox"
