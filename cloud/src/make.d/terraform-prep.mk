-include make.d/.env
export
SHELL := /bin/bash

# ========================================
# menu
# ----------------------------------------
TASKS += \
	tf-ecr:ECRリポジトリを作成 \
	tf-secrets:Secretsの箱を作成 \
	tf-secrets-push:Secretsに実値を投入 \
	tf-pgvector:pgvector検証用RDSを作成（ネットワーク・EC2作成後に実行） \
	tf-destroy-ecr:ECRリポジトリを削除 \
	tf-destroy-secrets:Secretsを削除 \
	tf-destroy-pgvector:pgvector検証用RDSを削除
# ========================================
# command
# ----------------------------------------
TF_DIR := terraform/envs/$(AGENT_ENV)

.PHONY: tf-ecr
tf-ecr:
	cd $(TF_DIR) && terraform apply -target=module.ecr

.PHONY: tf-secrets
tf-secrets:
	cd $(TF_DIR) && terraform apply -target=module.secrets

.PHONY: tf-secrets-push
tf-secrets-push:
	@read -p "LANGFLOW_API_KEY: " lak; \
	read -p "GOOGLE_API_KEY: " gak; \
	read -p "LANGFLOW_SUPERUSER_PASSWORD: " lsp; \
	LANGFLOW_API_KEY="$$lak" \
	GOOGLE_API_KEY="$$gak" \
	LANGFLOW_SUPERUSER_PASSWORD="$$lsp" \
		scripts/put_secrets.sh agent-$(AGENT_ENV) $(AWS_REGION)

# module.rds_pgvector・aws_security_group.rds_pgvectorはネットワーク(module.network)、
# aws_security_group_rule.rds_pgvector_from_ec2はEC2ホストのSG(module.ec2)に依存するため、
# 先にtf-apply（ネットワーク・EC2作成）を実行済みでないと-targetでも作成できない
# （envs/devにのみ定義。AGENT_ENV=prodでは対象moduleが存在せずエラーになる）。
.PHONY: tf-pgvector
tf-pgvector:
	cd $(TF_DIR) && terraform apply \
		-target=module.rds_pgvector \
		-target=aws_security_group.rds_pgvector \
		-target=aws_security_group_rule.rds_pgvector_from_ec2

.PHONY: tf-destroy-ecr
tf-destroy-ecr:
	cd $(TF_DIR) && terraform destroy -target=module.ecr

.PHONY: tf-destroy-secrets
tf-destroy-secrets:
	cd $(TF_DIR) && terraform destroy -target=module.secrets

# ネットワーク/EC2を先に壊すとVPC・SG参照が残ったRDSがdestroyできなくなるため、
# tf-destroy-network/tf-destroy-ec2より先に実行すること（_flow_destroy参照）。
.PHONY: tf-destroy-pgvector
tf-destroy-pgvector:
	cd $(TF_DIR) && terraform destroy \
		-target=module.rds_pgvector \
		-target=aws_security_group.rds_pgvector \
		-target=aws_security_group_rule.rds_pgvector_from_ec2
