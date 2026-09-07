-include make.d/.env
export
SHELL := /bin/bash

# ========================================
# menu
# ----------------------------------------
TASKS += \
	_setup_all:初回セットアップを一括実行 \
	_flow_create:環境構築の操作順序を表示 \
	_flow_destroy:環境削除の操作順序を表示
# ========================================
# command
# ----------------------------------------
.PHONY: _setup_all
_setup_all:
	sudo apt update
	sudo apt install -y wslu
	sudo apt install -y npm
	sudo apt install -y jq
	@if command -v aws >/dev/null 2>&1; then \
		echo "[INFO] aws-cli は導入済みです ($$(aws --version))"; \
	else \
		echo "[INFO] aws-cli をインストールします"; \
		curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o /tmp/awscliv2.zip; \
		unzip -o /tmp/awscliv2.zip -d /tmp; \
		sudo /tmp/aws/install --update; \
		rm -rf /tmp/awscliv2.zip /tmp/aws; \
	fi
	@if command -v session-manager-plugin >/dev/null 2>&1; then \
		echo "[INFO] session-manager-plugin は導入済みです ($$(session-manager-plugin --version))"; \
	else \
		echo "[INFO] session-manager-plugin をインストールします"; \
		curl "https://s3.amazonaws.com/session-manager-downloads/plugin/latest/ubuntu_64bit/session-manager-plugin.deb" -o /tmp/session-manager-plugin.deb; \
		sudo dpkg -i /tmp/session-manager-plugin.deb; \
		rm -f /tmp/session-manager-plugin.deb; \
	fi

.PHONY: _flow_create
_flow_create:
	@echo "1. aws-login           - AWS SSOにログイン"
	@echo "2. aws-whoami          - 認証情報を確認（任意）"
	@echo "3. tf-ecr              - ECRリポジトリだけ先に作る"
	@echo "4. tf-secrets          - Secretsの箱だけ先に作る"
	@echo "5. tf-secrets-push     - Secretsに実値を投入"
	@echo "6. ecr-image-push-all  - 3つのイメージをECRへpush"
	@echo "7. tf-apply            - 残り全部をapply（ネットワーク・EC2作成）"
	@echo "8. tf-pgvector         - (任意) pgvector検証用RDSを作成。6・7でVPC/EC2のSGが無いと作れないため必ず最後"
	@echo ""
	@echo "詳細・注意点は cloud/docs/dev-runbook.md 参照"

.PHONY: _flow_destroy
_flow_destroy:
	@echo "1. tf-destroy-pgvector - (該当する場合) pgvector検証用RDSを先に削除する"
	@echo "2. tf-destroy-network  - ネットワークを削除する"
	@echo "3. tf-destroy-ec2      - EC2を削除する（2と両方明示的に実行が必要）"
	@echo "4. tf-destroy-ecr      - (任意) ECRリポジトリも完全に消す場合"
	@echo "5. tf-destroy-secrets  - (任意) Secrets Managerも完全に消す場合"
	@echo "6. aws-payable-check   - 削除後の確認: 課金対象リソースが残っていないか"
	@echo ""
	@echo "1はRDSのSGがVPC/EC2のSGを参照しているため、2・3より先に消さないとdestroyできない"
	@echo "4・5はECR/Secretsを残すか完全に畳むかの任意ステップ（次回起動が速いか、コストを完全ゼロにするか）"
	@echo "詳細・注意点は cloud/docs/dev-runbook.md 参照"
