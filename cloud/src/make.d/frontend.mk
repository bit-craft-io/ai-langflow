-include make.d/.env
export
SHELL := /bin/bash

# ========================================
# menu
# ----------------------------------------
TASKS += \
	frontend-dev:frontendデバッグクライアントを起動
# ========================================
# command
# ----------------------------------------
TF_DIR := terraform/envs/$(AGENT_ENV)

# このリポジトリ自体がWSLネイティブのext4上（/mnt/...のDrvFsではない）にあるため、
# onprem/docker/bridge/frontend で直接npm install/devして問題ない
# （node_modulesは同ディレクトリの.gitignoreで除外済み）。
# node_modulesが既にあればnpm installはスキップする（package.jsonを更新した場合は
# 手動でnode_modulesを消してから実行すること）。
# NODE_OPTIONS=--dns-result-order=ipv4first はWSL2でnpm installがIPv6解決待ちで
# 詰まることがあるための対策。
.PHONY: frontend-dev
frontend-dev:
	@echo "----------------------------------------------------------------"
	@echo "  frontend:  http://localhost:5173"
	@ec2_ip=$$(cd $(TF_DIR) && terraform output -raw ec2_public_ip 2>/dev/null); \
	if [ -n "$$ec2_ip" ]; then \
		echo "  bridge WS (画面の接続先欄に入力): ws://$$ec2_ip:8765"; \
	else \
		echo "  [WARN] ec2_public_ip が取得できません（$(TF_DIR) が未applyか、tfstateが見当たりません）"; \
	fi
	@echo "----------------------------------------------------------------"
	cd ../../onprem/docker/bridge/frontend && \
	if [ ! -d node_modules ]; then NODE_OPTIONS=--dns-result-order=ipv4first npm install; fi && \
	npm run dev
