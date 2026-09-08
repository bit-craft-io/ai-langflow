-include make.d/.env
export
SHELL := /bin/bash

# ========================================
# menu
# ----------------------------------------
TASKS += \
	_setup_all:初回セットアップを一括実行
# ========================================
# command
# ----------------------------------------
.PHONY: _setup_all
_setup_all:
	@$(MAKE) wsl-tool-install
	@$(MAKE) wsl-git_lfs-setup
	@$(MAKE) wsl-ollama-model-pull
	@$(MAKE) python-install
	@$(MAKE) python-setup
	@$(MAKE) firecrawl-git-pull
