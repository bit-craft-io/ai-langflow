#!/usr/bin/env bash
set -euo pipefail

# Usage: tools/langflow-restore.sh [VOLUME_NAME] [BACKUP_DIR]
VOLUME="${1:-langflow-data}"
BACKUP_DIR="${2:-$(pwd)/backup}"

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