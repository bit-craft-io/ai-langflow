-include make.d/.env
export
SHELL := /bin/bash

# ========================================
# menu
# ----------------------------------------
TASKS += \
	ecr-image-push-bridge:bridgeイメージをECRへpush \
	ecr-image-push-langflow:langflowイメージをECRへpush \
	ecr-image-push-voicevox:voicevoxイメージをECRへpush \
	ecr-image-push-all:3イメージをまとめてpush
# ========================================
# command
# ----------------------------------------
.PHONY: ecr-image-push-bridge
ecr-image-push-bridge:
	@if [ -z "$(AWS_ACCOUNT_ID)" ]; then \
		echo "[ERROR] make.d/.envのAWS_ACCOUNT_IDを設定してください"; \
		exit 1; \
	fi
	-aws ecr batch-delete-image --repository-name agent-bridge --image-ids imageTag=$(IMAGE_TAG) --region $(AWS_REGION) >/dev/null 2>&1
	scripts/build_and_push_bridge.sh $(IMAGE_TAG) $(AWS_ACCOUNT_ID) $(AWS_REGION)

.PHONY: ecr-image-push-langflow
ecr-image-push-langflow:
	@if [ -z "$(AWS_ACCOUNT_ID)" ]; then \
		echo "[ERROR] make.d/.envのAWS_ACCOUNT_IDを設定してください"; \
		exit 1; \
	fi
	-aws ecr batch-delete-image --repository-name agent-langflow --image-ids imageTag=$(IMAGE_TAG) --region $(AWS_REGION) >/dev/null 2>&1
	scripts/build_and_push_langflow.sh $(IMAGE_TAG) $(AWS_ACCOUNT_ID) $(AWS_REGION)

.PHONY: ecr-image-push-voicevox
ecr-image-push-voicevox:
	@if [ -z "$(AWS_ACCOUNT_ID)" ]; then \
		echo "[ERROR] make.d/.envのAWS_ACCOUNT_IDを設定してください"; \
		exit 1; \
	fi
	-aws ecr batch-delete-image --repository-name agent-voicevox --image-ids imageTag=latest --region $(AWS_REGION) >/dev/null 2>&1
	scripts/build_and_push_voicevox.sh cpu-latest $(AWS_ACCOUNT_ID) $(AWS_REGION)

.PHONY: ecr-image-push-all
ecr-image-push-all:
	@$(MAKE) --no-print-directory ecr-image-push-bridge
	@$(MAKE) --no-print-directory ecr-image-push-langflow
	@$(MAKE) --no-print-directory ecr-image-push-voicevox
