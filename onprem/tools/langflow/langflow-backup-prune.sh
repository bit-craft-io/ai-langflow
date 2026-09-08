#!/usr/bin/env bash
set -euo pipefail

# Usage: tools/langflow-backup-prune.sh [BACKUP_ROOT] [KEEP]
#   ${BACKUP_ROOT}/history/ 配下のバックアップを新しい順に KEEP 件残し、
#   それより古いものを削除する(latest が指す最新世代は常に残る)。
BACKUP_ROOT="${1:-$(pwd)/backup}"
KEEP="${2:-2}"
HISTORY_DIR="${BACKUP_ROOT}/history"

if ! [[ "$KEEP" =~ ^[0-9]+$ ]] || [ "$KEEP" -lt 1 ]; then
  echo "[prune] error: KEEP must be an integer >= 1 (got: ${KEEP})" >&2
  exit 1
fi

if [ ! -d "$HISTORY_DIR" ]; then
  echo "[prune] history dir not found: ${HISTORY_DIR}" >&2
  exit 1
fi

mapfile -t BACKUPS < <(find "$HISTORY_DIR" -mindepth 1 -maxdepth 1 -type d -printf '%f\n' | sort)
TOTAL=${#BACKUPS[@]}

if [ "$TOTAL" -le "$KEEP" ]; then
  echo "[prune] ${TOTAL} backup(s) found, keep=${KEEP}. nothing to delete."
  exit 0
fi

DELETE_COUNT=$((TOTAL - KEEP))
TO_DELETE=("${BACKUPS[@]:0:DELETE_COUNT}")
TO_KEEP=("${BACKUPS[@]:DELETE_COUNT}")

echo "[prune] keep (${#TO_KEEP[@]}):"
printf '  %s\n' "${TO_KEEP[@]}"
echo "[prune] delete (${#TO_DELETE[@]}):"
printf '  %s\n' "${TO_DELETE[@]}"

read -r -p "[prune] delete the above ${#TO_DELETE[@]} backup(s)? [y/N] " ans
case "$ans" in
  [yY]*) ;;
  *) echo "[prune] aborted"; exit 1 ;;
esac

for d in "${TO_DELETE[@]}"; do
  rm -rf "${HISTORY_DIR:?}/${d}"
  echo "[prune] removed ${d}"
done

echo "[prune] done"
