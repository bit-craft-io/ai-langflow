-include make.d/.env
export
SHELL := /bin/bash

# ========================================
# menu
# ----------------------------------------
TASKS += \
	wsl-tool-install:開発ツールをインストール（direnv/git-lfs/ollama） \
	wsl-git_lfs-setup:Git_LFSを設定 \
	wsl-ollama-model-pull:LLMモデルを取得 \
	wsl-ollama-model-list:LLMモデル一覧を表示 \
	wsl-ollama-model-clean:不要なLLMモデルを削除
# ========================================
# command
# ----------------------------------------
.PHONY: wsl-tool-install
wsl-tool-install:
	sudo apt -y update

	@echo "--- Install direnv ---"
	sudo apt -y install direnv
	echo "# add $(date +'%Y.%m.%d') direnv" >> ~/.bashrc
	source ~/.bashrc
	direnv version

	@echo "--- Install Git LFS ---"
	sudo apt -y install git-lfs

	@echo "--- Install Ollama ---"
	@which ollama > /dev/null 2>&1 || (sudo apt-get install -y zstd && curl -fsSL https://ollama.com/install.sh | sh)
	sudo systemctl stop ollama 2>/dev/null || true
	sudo systemctl disable ollama 2>/dev/null || true

.PHONY: wsl-git_lfs-setup
wsl-git_lfs-setup:
	git lfs install
	git lfs version
	git lfs track "backup/*.tar.gz"
	git add .gitattributes

__MODELS := $(__OLLAMA_MODEL) $(__WARMUP_MODEL)
.PHONY: wsl-ollama-model-pull
wsl-ollama-model-pull:
	@echo "--- Pull LLM models ---"
	@pgrep ollama > /dev/null 2>&1 || (ollama serve &)
	sleep 3
	@for model in $(__MODELS); do ollama pull $$model; done
	ollama list
	@pgrep ollama > /dev/null 2>&1 && pkill ollama || true

.PHONY: wsl-ollama-model-list
wsl-ollama-model-list:
	@echo "--- LLM models ---"
	@pgrep ollama > /dev/null 2>&1 || (ollama serve > /dev/null 2>&1 &)
	@sleep 3
	@ollama list
	@pgrep ollama > /dev/null 2>&1 && pkill ollama > /dev/null 2>&1 || true

.PHONY: wsl-ollama-model-clean
wsl-ollama-model-clean:
	@echo "--- Cleaning up Ollama processes ---"
	@pgrep ollama > /dev/null 2>&1 || (echo "Starting ollama for cleanup..."; ollama serve > /dev/null 2>&1 & sleep 2)

	@echo "--- Deleting all Ollama models EXCEPT $(__MODELS) ---"
	@sudo chown -R $$(whoami):$$(whoami) /home/guest/.ollama 2>/dev/null || true
	@if which ollama > /dev/null 2>&1; then \
		for model in $$(ollama list | tail -n +2 | awk '{print $$1}'); do \
			keep=0; \
			for target in $(__MODELS); do \
				[ "$$model" = "$$target" ] && keep=1; \
			done; \
			if [ "$$keep" = "1" ]; then \
				echo "Keeping target model: $$model (Skipped)"; \
			else \
				echo "Deleting unused model: $$model..."; \
				ollama rm $$model; \
			fi \
		done; \
		echo "Cleanup completed."; \
	else \
		echo "Ollama is not installed."; \
	fi

	@echo "--- Stopping Ollama process ---"
	@pgrep ollama > /dev/null 2>&1 && pkill ollama || true
