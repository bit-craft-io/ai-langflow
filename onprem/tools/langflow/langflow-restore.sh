#!/usr/bin/env bash
set -euo pipefail

# Usage: tools/langflow-restore.sh [VOLUME_NAME] [BACKUP_ROOT] [BACKUP_NAME]
#   BACKUP_NAME は既定で "latest" (=${BACKUP_ROOT}/latest)。
#   ${BACKUP_ROOT}/history/YYYYMMDD_HHMMSS のようにタイムスタンプを指定して
#   特定の世代を復元することもできる。
VOLUME="${1:-langflow-data}"
BACKUP_ROOT="${2:-$(pwd)/backup}"
BACKUP_NAME="${3:-latest}"

if [ "$BACKUP_NAME" = "latest" ]; then
  BACKUP_DIR="${BACKUP_ROOT}/latest"
else
  BACKUP_DIR="${BACKUP_ROOT}/history/${BACKUP_NAME}"
fi

if [ ! -d "$BACKUP_DIR" ] || [ -z "$(ls -A "$BACKUP_DIR" 2>/dev/null)" ]; then
  echo "[restore] error: backup dir empty or missing: ${BACKUP_DIR}" >&2
  exit 1
fi

echo "[restore] ${BACKUP_DIR} -> volume=${VOLUME}"
read -r -p "[restore] volume ${VOLUME} content will be overwritten. continue? [y/N] " ans
case "$ans" in
  [yY]*) ;;
  *) echo "[restore] aborted"; exit 1 ;;
esac

docker run --rm \
  -v "${VOLUME}:/data" \
  -v "${BACKUP_DIR}:/backup" \
  alpine sh -c "rm -rf /data/* && cp -r /backup/. /data/"

echo "[restore] done. restart containers: docker compose down && docker compose up -d"