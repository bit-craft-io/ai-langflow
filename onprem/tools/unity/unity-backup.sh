#!/bin/bash
set -euo pipefail
# =====================================================
# Usage:
#   ./unity-langflow-backup.sh --apply --dir unity/backup
#   ./unity-langflow-backup.sh --apply --dir unity/init --clean
#
# Options:
#   --apply   実際に実行（無指定はdry-run）
#   --dir DIR 出力先ディレクトリ指定（必須）
#   --clean   機微情報(organizationId/cloudProjectId等)をクリアする
# =====================================================

UNITY_PROJECT_DIR="${UNITY_PROJECT_DIR:-/mnt/s/risuna}"

APPLY=false
CLEAN=false
UNITY_BACKUP_DIR=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --apply)
      APPLY=true
      shift
      ;;
    --clean)
      CLEAN=true
      shift
      ;;
    --dir)
      UNITY_BACKUP_DIR="${2:-}"
      shift 2
      ;;
    *)
      echo "Unknown option: $1" >&2
      exit 1
      ;;
  esac
done

if [[ -z "$UNITY_BACKUP_DIR" ]]; then
  echo "Error: --dir <output_dir> is required." >&2
  echo "Example: ./backup.sh --apply --dir unity/backup" >&2
  exit 1
fi

echo "=== Unity Backup Settings ==="
echo "  Source: ${UNITY_PROJECT_DIR}"
echo "  Target: ${UNITY_BACKUP_DIR}"
echo "  Clean sensitive info: ${CLEAN}"
echo "============================="

if [[ ! -d "${UNITY_PROJECT_DIR}/Assets" ]]; then
  echo "Error: ${UNITY_PROJECT_DIR} is not a valid Unity project." >&2
  exit 1
fi

if [[ "$APPLY" == false ]]; then
  echo ""
  echo "Dry-run mode. Re-run with --apply to execute backup."
  exit 0
fi

echo ""
echo "=== Cleaning old backup ==="
if [[ -d "$UNITY_BACKUP_DIR" ]]; then
  for item in "$UNITY_BACKUP_DIR"/*; do
    if [[ -e "$item" ]]; then
      echo "  Deleting $(basename "$item")..."
      rm -rf "$item"
    fi
  done
fi
mkdir -p "$UNITY_BACKUP_DIR"

echo ""
echo "=== Copying project files ==="
rsync -a --info=progress2 "${UNITY_PROJECT_DIR}/Assets" "${UNITY_BACKUP_DIR}/"
rsync -a --info=progress2 "${UNITY_PROJECT_DIR}/ProjectSettings" "${UNITY_BACKUP_DIR}/"

mkdir -p "${UNITY_BACKUP_DIR}/Packages"
rsync -a "${UNITY_PROJECT_DIR}/Packages/manifest.json" "${UNITY_BACKUP_DIR}/Packages/"
if [[ -f "${UNITY_PROJECT_DIR}/Packages/packages-lock.json" ]]; then
  rsync -a "${UNITY_PROJECT_DIR}/Packages/packages-lock.json" "${UNITY_BACKUP_DIR}/Packages/"
fi

# LastSceneManagerSetup.txt のコピー（存在する場合のみ）
if [[ -f "${UNITY_PROJECT_DIR}/Library/LastSceneManagerSetup.txt" ]]; then
  mkdir -p "${UNITY_BACKUP_DIR}/Library"
  rsync -a "${UNITY_PROJECT_DIR}/Library/LastSceneManagerSetup.txt" "${UNITY_BACKUP_DIR}/Library/"
fi

# 不要なフォント元素材の削除
find "${UNITY_BACKUP_DIR}/Assets" -type f \( -name "*.ttc" -o -name "*.otf" -o -name "*.ttf" \) -delete

if [[ "$CLEAN" == true ]]; then
  echo ""
  echo "=== Removing organization/project identifiers ==="
  PROJECT_SETTINGS_ASSET="${UNITY_BACKUP_DIR}/ProjectSettings/ProjectSettings.asset"
  if [[ -f "$PROJECT_SETTINGS_ASSET" ]]; then
    sed -i.bak \
      -e 's/^\(\s*projectName:\s*\).*/\1/' \
      -e 's/^\(\s*organizationId:\s*\).*/\1/' \
      -e 's/^\(\s*productGUID:\s*\).*/\1/' \
      -e 's/^\(\s*clonedFromGUID:\s*\).*/\1/' \
      -e 's/^\(\s*cloudProjectId:\s*\).*/\1/' \
      -e 's/^\(\s*metroPackageName:\s*\).*/\1/' \
      -e 's/^\(\s*metroApplicationDescription:\s*\).*/\1/' \
      -e 's/^\(\s*productName:\s*\).*/\1/' \
      "$PROJECT_SETTINGS_ASSET"
    rm -f "${PROJECT_SETTINGS_ASSET}.bak"
    echo "  Cleared: projectName, organizationId, productGUID, clonedFromGUID, cloudProjectId, metroPackageName, metroApplicationDescription, productName"
  else
    echo "  Warning: ProjectSettings.asset not found, skipped."
  fi
else
  echo ""
  echo "=== Skipping sensitive info cleanup (--clean not specified) ==="
fi

echo ""
echo "Completed: ${UNITY_BACKUP_DIR}"
