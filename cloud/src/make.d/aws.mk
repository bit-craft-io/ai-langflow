-include make.d/.env
export
SHELL := /bin/bash

# ========================================
# menu
# ----------------------------------------
TASKS += \
	aws-login:AWS_SSOにログイン \
	aws-whoami:AWS認証情報を確認 \
	aws-payable-check:課金対象リソースの残存を確認 \
	aws-ec2-ip:EC2のパブリックIPを確認 \
	aws-ec2-status:EC2の起動状態を確認 \
	aws-ec2-login:EC2にSSMで接続 \
	aws-ec2-docker-ps:EC2上のコンテナ状態を取得
# ========================================
# command
# ----------------------------------------
TF_DIR := terraform/envs/$(AGENT_ENV)

.PHONY: aws-login
aws-login:
	@if [ -z "$(AWS_PROFILE)" ]; then \
		echo "[ERROR] make.d/.envのAWS_PROFILEを設定してください"; \
		exit 1; \
	fi
	aws sso login --profile $(AWS_PROFILE)

.PHONY: aws-whoami
aws-whoami:
	@if [ -z "$(AWS_PROFILE)" ]; then \
		echo "[ERROR] make.d/.envのAWS_PROFILEを設定してください"; \
		exit 1; \
	fi
	aws sts get-caller-identity --profile $(AWS_PROFILE)

.PHONY: aws-payable-check
aws-payable-check:
	scripts/check_aws_usage.sh $(AWS_REGION)

.PHONY: aws-ec2-ip
aws-ec2-ip:
	cd $(TF_DIR) && terraform output ec2_public_ip

.PHONY: aws-ec2-status
aws-ec2-status:
	aws ec2 describe-instances --region $(AWS_REGION) \
		--filters "Name=tag:Name,Values=agent-$(AGENT_ENV)-host" \
		--query "Reservations[].Instances[].[InstanceId,State.Name]"

.PHONY: aws-ec2-login
aws-ec2-login:
	@instance_id=$$(cd $(TF_DIR) && terraform output -raw ec2_instance_id); \
	echo "instance_id: $$instance_id"; \
	aws ssm start-session --region $(AWS_REGION) --target $$instance_id

.PHONY: aws-ec2-docker-ps
aws-ec2-docker-ps:
	@instance_id=$$(cd $(TF_DIR) && terraform output -raw ec2_instance_id); \
	cmd_id=$$(aws ssm send-command --region $(AWS_REGION) \
		--instance-ids $$instance_id \
		--document-name "AWS-RunShellScript" \
		--parameters 'commands=["cd /opt/agent && sudo docker compose -p agent -f docker-compose.agent.yaml --env-file .env ps"]' \
		--query "Command.CommandId" --output text); \
	sleep 3; \
	aws ssm get-command-invocation --region $(AWS_REGION) \
		--command-id $$cmd_id --instance-id $$instance_id \
		--query "StandardOutputContent" --output text
