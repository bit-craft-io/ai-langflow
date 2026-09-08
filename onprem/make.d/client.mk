-include make.d/.env
export
SHELL := /bin/bash

# ========================================
# menu
# ----------------------------------------
TASKS += \
	client-text-only:LangflowBridgeのCUIクライアントを起動(テキスト入力・テキスト出力) \
	client-text-audio:LangflowBridgeのCUIクライアントを起動(テキスト入力・音声出力) \
	client-voice-audio:LangflowBridgeのCUIクライアントを起動(音声入力・音声出力)
# ========================================
# command
# ----------------------------------------
.PHONY: client-text-only
client-text-only:
	$(VENV_PYTHON) client/python/workflow.py

.PHONY: client-text-audio
client-text-audio:
	$(VENV_PYTHON) client/python/workflow.py --audio play

.PHONY: client-voice-audio
client-voice-audio:
	$(VENV_PYTHON) client/python/workflow.py --input voice --audio play
