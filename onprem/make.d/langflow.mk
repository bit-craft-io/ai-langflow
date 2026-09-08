-include make.d/.env
export
SHELL := /bin/bash

# ========================================
# menu
# ----------------------------------------
TASKS += \
	backup:Langflowデータをバックアップ \
	restore:Langflowデータを復元
# ========================================
# command
# ----------------------------------------
LANGFLOW_BACKUP_VOLUME  ?= langflow-data
LANGFLOW_RESTORE_VOLUME ?= langflow-data
LANGFLOW_BACKUP_DIR     ?= $(CURDIR)/backup

.PHONY: backup
backup:
	bash tools/langflow/langflow-backup.sh $(LANGFLOW_BACKUP_VOLUME) $(LANGFLOW_BACKUP_DIR)

.PHONY: restore
restore:
	bash tools/langflow/langflow-restore.sh $(LANGFLOW_RESTORE_VOLUME) $(LANGFLOW_BACKUP_DIR)