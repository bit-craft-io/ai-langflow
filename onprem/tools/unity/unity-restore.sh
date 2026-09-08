#!/bin/bash
set -euo pipefail
# =====================================================
# Usage:
#   ./unity-restore.sh --apply --dir unity/backup
#   ./unity-restore.sh --apply --dir unity/init
#
# Options:
#   --apply   実際に実行（無指定はdry-run）
#   --dir DIR 復元元ディレクトリ指定（必須。unity/backup または unity/init）
#
# 前提:
#   UNITY_PROJECT_DIR は Unity Hub から手動で作成済みの
#   既存プロジェクトであること（テンプレート/バージョン一致させる）。
#   かつ Unity Editor は起動したまま実行すること（GUID安全のため）。
# =====================================================

UNITY_PROJECT_DIR="${UNITY_PROJECT_DIR:-/mnt/s/risuna}"

APPLY=false
SOURCE_DIR=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --apply)
      APPLY=true
      shift
      ;;
    --dir)
      SOURCE_DIR="${2:-}"
      shift 2
      ;;
    *)
      echo "Unknown option: $1" >&2
      exit 1
      ;;
  esac
done

if [[ -z "$SOURCE_DIR" ]]; then
  echo "Error: --dir <source_dir> is required." >&2
  echo "Example: ./restore.sh --apply --dir unity/backup" >&2
  exit 1
fi

echo "=== Unity Restore Settings ==="
echo "  Source: ${SOURCE_DIR}"
echo "  Target: ${UNITY_PROJECT_DIR}"
echo "==============================="

if [[ ! -d "${SOURCE_DIR}/Assets" ]]; then
  echo "Error: ${SOURCE_DIR} is not a valid backup (Assets not found)." >&2
  exit 1
fi

if [[ ! -d "${UNITY_PROJECT_DIR}/Assets" ]]; then
  echo "Error: ${UNITY_PROJECT_DIR} is not a valid Unity project." >&2
  echo "Create it via Unity Hub first (matching Unity version/template)." >&2
  exit 1
fi

if [[ "$APPLY" == false ]]; then
  echo ""
  echo "Dry-run mode. Re-run with --apply to execute restore."
  exit 0
fi

echo ""
echo "=== Copying files into project ==="
rsync -a --info=progress2 "${SOURCE_DIR}/Assets/" "${UNITY_PROJECT_DIR}/Assets/"
rsync -a --info=progress2 "${SOURCE_DIR}/ProjectSettings/" "${UNITY_PROJECT_DIR}/ProjectSettings/"

mkdir -p "${UNITY_PROJECT_DIR}/Packages"
rsync -a "${SOURCE_DIR}/Packages/manifest.json" "${UNITY_PROJECT_DIR}/Packages/"
if [[ -f "${SOURCE_DIR}/Packages/packages-lock.json" ]]; then
  rsync -a "${SOURCE_DIR}/Packages/packages-lock.json" "${UNITY_PROJECT_DIR}/Packages/"
fi

if [[ -f "${SOURCE_DIR}/Library/LastSceneManagerSetup.txt" ]]; then
  mkdir -p "${UNITY_PROJECT_DIR}/Library"
  rsync -a "${SOURCE_DIR}/Library/LastSceneManagerSetup.txt" "${UNITY_PROJECT_DIR}/Library/"
fi

echo ""
echo "Completed. If Unity is open, it will auto-detect and reimport."
echo "If Unity is NOT open, launch it manually now."