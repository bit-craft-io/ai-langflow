-include make.d/.env
export
SHELL := /bin/bash

# ========================================
# menu
# ----------------------------------------
TASKS += \
	windows-setup:Windows側のセットアップを実行 \
	mic-spk-enable:マイク・スピーカーを有効化 \
	mic-spk-disable:マイク・スピーカーを無効化 \
	nvidia-smi:GPU使用状況を表示
# ========================================
# command
# ----------------------------------------
ifndef ROOT_MK_INCLUDED
    ROOT_MK_INCLUDED := 1
	ROOT_DIR := $(shell pwd)
    export VENV_PYTHON := $(ROOT_DIR)/.venv/bin/python3
    export VENV_PIP    := $(ROOT_DIR)/.venv/bin/pip
endif

.PHONY: windows-setup
windows-setup:
	$(VENV_PYTHON) tools/win-ops/setup.py

.PHONY: mic-spk-enable
mic-spk-enable:
	@$(MAKE) --no-print-directory mic-on
	@$(MAKE) --no-print-directory spk-on
	@echo "completed!"

.PHONY: mic-spk-disable
mic-spk-disable:
	@$(MAKE) --no-print-directory mic-off
	@$(MAKE) --no-print-directory spk-off
	@echo "completed!"

# マイクの制御
.PHONY: mic-on
mic-on:
	@$(VENV_PYTHON) tools/win-ops/mic_on.py

.PHONY: mic-off
mic-off:
	@$(VENV_PYTHON) tools/win-ops/mic_off.py

# スピーカーの制御
.PHONY: spk-on
spk-on:
	@$(VENV_PYTHON) tools/win-ops/spk_on.py

.PHONY: spk-off
spk-off:
	@$(VENV_PYTHON) tools/win-ops/spk_off.py

.PHONY: nvidia-smi
nvidia-smi:
	@echo "--------------------------------------------------------------------------------"
	@echo "Ollama Loaded Models"
	@echo "--------------------------------------------------------------------------------"
	@docker exec -it ollama-base ollama ps 2>/dev/null || ollama ps
	@echo "--------------------------------------------------------------------------------"
	@echo "GPU VRAM Usage"
	@echo "--------------------------------------------------------------------------------"
	@nvidia-smi --query-gpu=memory.used,memory.free,memory.total --format=csv | column -s, -t