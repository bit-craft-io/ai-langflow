SHELL := /bin/bash
.DEFAULT_GOAL := menu

# ========================================
# include
# ----------------------------------------
include make.d/_common.mk        # 共通処理・初回セットアップ
include make.d/aws.mk            # AWS認証・EC2確認
include make.d/terraform-prep.mk # Terraform事前準備（ECR/Secrets）
include make.d/ecr-image.mk      # ECRイメージのビルド・push
include make.d/terraform.mk      # Terraformの適用・削除
include make.d/frontend.mk       # フロントエンドデバッグクライアント起動
# ========================================
# command
# ----------------------------------------
.PHONY: menu
menu:
	@trap 'echo ""; exit 0' INT; \
	\
	MENU_GROUPS=$$(awk '/^include make\.d\// {print $$2}' Makefile | xargs -n1 basename | sed 's/\.mk$$//' | awk '!visited[$$0]++'); \
	if [ -z "$$MENU_GROUPS" ]; then echo "No .mk files included in Makefile"; exit 1; fi; \
	\
	echo "--- Select Group ---"; \
	echo " 1) _exit"; \
	\
	i=2; \
	for g in $$MENU_GROUPS; do \
	   g_desc=$$(sed -n "s/^include make\.d\/$$g\.mk[ \t]*#[ \t]*//p" Makefile); \
	   if [ -n "$$g_desc" ]; then \
	      printf "%2d) %-23s # %s\n" $$i "$$g" "$$g_desc"; \
	   else \
	      printf "%2d) %s\n" $$i "$$g"; \
	   fi; \
	   i=$$(($$i + 1)); \
	done; \
	\
	read -e -p "??: " g_num; \
	if [ "$$g_num" -eq 1 ] 2>/dev/null; then echo "Exit"; exit 0; fi; \
	\
	idx=$$(($$g_num - 1)); \
	selected_g=$$(echo "$$MENU_GROUPS" | sed -n "$${idx}p" 2>/dev/null); \
	if [ -z "$$selected_g" ]; then \
	   echo "Invalid group"; \
	   exit 0; \
	fi; \
	\
	while true; do \
	   echo "--- Select Task [$$selected_g] ---"; \
	   echo " 1) _back"; \
	   \
	   # 2. TASKS += のブロックからタスク名を抽出 \
	   SUB_TASKS=$$(awk '/TASKS *\+=/,/[^\\]$$/' make.d/$$selected_g.mk | sed -e 's/TASKS *+=//' -e 's/\\//g' | tr -s ' \t\n' '\n' | grep -v '^$$' | awk '!visited[$$0]++'); \
	   \
	   i=2; \
	   for st in $$SUB_TASKS; do \
	      st_name=$${st%%:*}; \
	      case "$$st" in \
	         *:*) st_desc=$${st#*:} ;; \
	         *) st_desc="" ;; \
	      esac; \
	      if [ -n "$$st_desc" ]; then \
	         printf "%2d) %-23s # %s\n" $$i "$$st_name" "$$st_desc"; \
	      else \
	         printf "%2d) %s\n" $$i "$$st_name"; \
	      fi; \
	      i=$$(($$i + 1)); \
	   done; \
	   \
	   read -e -p "??: " t_num; \
	   if [ "$$t_num" -eq 1 ] 2>/dev/null; then exec make --no-print-directory menu; fi; \
	   \
	   t_idx=$$(($$t_num - 1)); \
	   selected_t=$$(echo "$$SUB_TASKS" | sed -n "$${t_idx}p" 2>/dev/null); \
	   selected_t=$${selected_t%%:*}; \
	   if [ -n "$$selected_t" ]; then \
	      MAKEFLAGS="--no-print-directory" make $$selected_t; \
	      break; \
	   else \
	      echo "Invalid task"; \
	   fi; \
	done

.DEFAULT:
	@echo "[WARN] target '$@' unknown"
