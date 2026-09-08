-include make.d/.env
export
SHELL := /bin/bash

# ========================================
# menu
# ----------------------------------------
TASKS += \
	firecrawl-git-pull:Firecrawlリポジトリを取得 \
	firecrawl-git-dell:Firecrawlリポジトリを削除
# ========================================
# command
# ----------------------------------------
.PHONY: firecrawl-git-pull
firecrawl-git-pull:
	@if [ ! -d "$(__DOCKER_ROOT_FIRECRAWL)" ]; then \
		echo "repository clone crawl"; \
		git clone --branch v2.11.0 --depth 1 https://github.com/firecrawl/firecrawl $(__DOCKER_ROOT_FIRECRAWL); \
		yes | rm -r $(__DOCKER_ROOT_FIRECRAWL)/.github; \
		echo "make .env from .env.example"; \
		cp docker/override.d/crawl/.env.example $(__DOCKER_ROOT_FIRECRAWL)/.env; \
	else \
		echo "exist crawl make skip"; \
	fi

.PHONY: firecrawl-git-dell
firecrawl-git-dell:
	@# ユーザーに実行確認を求める
	@read -p "Are you sure you want to delete crawl? [y/N]: " ans; \
	if [ "$$ans" != "y" ] && [ "$$ans" != "yes" ]; then \
		echo "Cancelled."; \
		exit 0; \
	fi; \
	sudo rm -rf $(__DOCKER_ROOT_FIRECRAWL)