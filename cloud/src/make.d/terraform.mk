-include make.d/.env
export
SHELL := /bin/bash

# ========================================
# menu
# ----------------------------------------
TASKS += \
	tf-plan:terraform_planを実行 \
	tf-apply:残り全部をapply（EC2作成） \
	tf-destroy-network:ネットワークを削除 \
	tf-destroy-ec2:EC2を削除
# ========================================
# command
# ----------------------------------------
TF_DIR := terraform/envs/$(AGENT_ENV)

.PHONY: tf-plan
tf-plan:
	cd $(TF_DIR) && terraform plan

.PHONY: tf-apply
tf-apply:
	cd $(TF_DIR) && terraform apply

.PHONY: tf-destroy-network
tf-destroy-network:
	cd $(TF_DIR) && terraform destroy -target=module.network

.PHONY: tf-destroy-ec2
tf-destroy-ec2:
	cd $(TF_DIR) && terraform destroy -target=module.ec2
