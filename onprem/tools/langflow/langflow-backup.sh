#!/usr/bin/env bash
set -euo pipefail

# Usage: tools/langflow-backup.sh [VOLUME_NAME] [BACKUP_ROOT]
#   ${BACKUP_ROOT}/history/YYYYMMDD_HHMMSS/ にバックアップを作成し、
#   ${BACKUP_ROOT}/latest を最新のバックアップへのシンボリックリンクとして更新する
VOLUME="${1:-langflow-data}"
BACKUP_ROOT="${2:-$(pwd)/backup}"
TIMESTAMP="$(date +%Y%m%d_%H%M%S)"
BACKUP_DIR="${BACKUP_ROOT}/history/${TIMESTAMP}"

mkdir -p "$BACKUP_DIR"

echo "[backup] volume=${VOLUME} -> ${BACKUP_DIR}"

docker run --rm \
  -v "${VOLUME}:/data" \
  -v "${BACKUP_DIR}:/backup" \
  alpine cp -r /data/. /backup/

# WAL checkpoint (shrink -wal, keep db consistent)
if [ -f "${BACKUP_DIR}/langflow.db" ]; then
  docker run --rm \
    -v "${BACKUP_DIR}:/backup" \
    alpine sh -c "command -v sqlite3 >/dev/null 2>&1 || apk add --no-cache sqlite >/dev/null; sqlite3 /backup/langflow.db 'PRAGMA wal_checkpoint(TRUNCATE);'"
fi

du -sh "${BACKUP_DIR}"/* 2>/dev/null || true

ln -sfn "history/${TIMESTAMP}" "${BACKUP_ROOT}/latest"
echo "[backup] latest -> history/${TIMESTAMP}"
echo "[backup] done"