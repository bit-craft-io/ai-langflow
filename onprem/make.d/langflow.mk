-include make.d/.env
export
SHELL := /bin/bash

# ========================================
# menu
# ----------------------------------------
TASKS += \
	backup:Langflowデータをバックアップ \
	restore:Langflowデータを復元 \
	backup-prune:古いLangflowバックアップを削除（既定2世代保持）
# ========================================
# command
# ----------------------------------------
LANGFLOW_BACKUP_VOLUME  ?= langflow-data
LANGFLOW_RESTORE_VOLUME ?= langflow-data
LANGFLOW_BACKUP_ROOT    ?= $(CURDIR)/backup
LANGFLOW_RESTORE_NAME   ?= latest
LANGFLOW_BACKUP_KEEP    ?= 2

.PHONY: backup
backup:
	bash tools/langflow/langflow-backup.sh $(LANGFLOW_BACKUP_VOLUME) $(LANGFLOW_BACKUP_ROOT)

.PHONY: restore
restore:
	bash tools/langflow/langflow-restore.sh $(LANGFLOW_RESTORE_VOLUME) $(LANGFLOW_BACKUP_ROOT) $(LANGFLOW_RESTORE_NAME)

.PHONY: backup-prune
backup-prune:
	bash tools/langflow/langflow-backup-prune.sh $(LANGFLOW_BACKUP_ROOT) $(LANGFLOW_BACKUP_KEEP)