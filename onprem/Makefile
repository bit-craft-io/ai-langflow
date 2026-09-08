SHELL := /bin/bash
.DEFAULT_GOAL := menu

# ========================================
# include
# ----------------------------------------
include make.d/_common.mk    # 共通処理・初回セットアップ
include make.d/wsl.mk        # WSL環境のセットアップ
include make.d/docker.mk     # Dockerサービス管理
include make.d/langflow.mk   # Langflowデータのバックアップ・復元
include make.d/firecrawl.mk  # Firecrawlリポジトリ管理
include make.d/python.mk     # Python環境のセットアップ
include make.d/client.mk     # Python製CUIクライアントの起動
include make.d/unity.mk      # Unityプロジェクトのバックアップ・復元
include make.d/tools.mk      # Windows連携・周辺機器ツール
# ========================================
# command
# ----------------------------------------
.PHONY: menu
menu:
	@trap 'echo ""; exit 0' INT; \
	\
	MENU_GROUPS=$$(awk -F'#' '/^include make\.d\// { \
	   n=split($$1, p, "/"); name=p[n]; sub(/\.mk[ \t]*$$/, "", name); \
	   desc=$$2; gsub(/^[ \t]+|[ \t]+$$/, "", desc); \
	   print name "\t" desc \
	}' Makefile | awk -F'\t' '!visited[$$1]++'); \
	if [ -z "$$MENU_GROUPS" ]; then echo "No .mk files included in Makefile"; exit 1; fi; \
	\
	echo "--- Select Group ---"; \
	echo " 1) _exit"; \
	\
	i=2; \
	while IFS=$$'\t' read -r g desc; do \
	   if [ -n "$$desc" ]; then \
	      printf "%2d) %-20s # %s\n" $$i "$$g" "$$desc"; \
	   else \
	      printf "%2d) %s\n" $$i "$$g"; \
	   fi; \
	   i=$$(($$i + 1)); \
	done <<< "$$MENU_GROUPS"; \
	\
	read -p "??: " g_num; \
	if [ "$$g_num" -eq 1 ] 2>/dev/null; then echo "Exit"; exit 0; fi; \
	\
	idx=$$(($$g_num - 1)); \
	selected_g=$$(echo "$$MENU_GROUPS" | sed -n "$${idx}p" 2>/dev/null | cut -f1); \
	if [ -z "$$selected_g" ]; then \
	   echo "Invalid group"; \
	   exit 0; \
	fi; \
	\
	echo "--- Select Task [$$selected_g] ---"; \
	echo " 1) _back"; \
	\
	# 2. TASKS += のブロックからタスク名を抽出 \
	SUB_TASKS=$$(awk '/TASKS *\+=/,/[^\\]$$/' make.d/$$selected_g.mk | sed -e 's/TASKS *+=//' -e 's/\\//g' | tr -s ' \t\n' '\n' | grep -v '^$$' | awk '!visited[$$0]++'); \
	\
	i=2; \
	for st in $$SUB_TASKS; do \
	   name=$${st%%:*}; \
	   if [ "$$st" != "$$name" ]; then \
	      desc=$${st#*:}; \
	      printf "%2d) %-20s # %s\n" $$i "$$name" "$$desc"; \
	   else \
	      printf "%2d) %s\n" $$i "$$name"; \
	   fi; \
	   i=$$(($$i + 1)); \
	done; \
	\
	read -p "??: " t_num; \
	if [ "$$t_num" -eq 1 ] 2>/dev/null; then exec make --no-print-directory menu; fi; \
	\
	t_idx=$$(($$t_num - 1)); \
	selected_t_raw=$$(echo "$$SUB_TASKS" | sed -n "$${t_idx}p" 2>/dev/null); \
	selected_t=$${selected_t_raw%%:*}; \
	if [ -n "$$selected_t" ]; then \
	   MAKEFLAGS="--no-print-directory" make $$selected_t; \
	else \
	   echo "Invalid task"; \
	   exit 0; \
	fi

.DEFAULT:
	@echo "[WARN] target '$@' unknown"