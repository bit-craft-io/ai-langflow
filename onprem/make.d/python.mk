-include make.d/.env
export
SHELL := /bin/bash

# ========================================
# menu
# ----------------------------------------
TASKS += \
	python-install:Python環境をインストール \
	python-setup:Python仮想環境をセットアップ
# ========================================
# command
# ----------------------------------------
ifndef ROOT_MK_INCLUDED
    ROOT_MK_INCLUDED := 1
	ROOT_DIR := $(shell pwd)
    export VENV_PYTHON := $(ROOT_DIR)/.venv/bin/python3
    export VENV_PIP    := $(ROOT_DIR)/.venv/bin/pip
endif

.PHONY: python-install
python-install:
	sudo apt update
	sudo apt install -y python3 python3-pip python3-venv
	sudo apt install -y portaudio19-dev libpulse0

.PHONY: python-setup
python-setup:
	@# 独立した Python 仮想環境（.venv）を作成
	python3 -m venv .venv

	@# 音声認識・再生・音声合成・HTTPリクエスト用
	$(VENV_PIP) install speechrecognition pyaudio pyttsx3 requests
	@# bridge backend との WebSocket 通信用（client/python/workflow.py）
	$(VENV_PIP) install websockets
	@# マルチメディアアプリ開発用（効果音・BGM再生に使用）
	$(VENV_PIP) install pygame
	@# LangGraph（AIエージェントのグラフ構造制御）
	$(VENV_PIP) install langgraph langchain-core langchain-openai
	@# CUI（ターミナル上の選択肢UI・1文字入力検知）
	$(VENV_PIP) install inquirerpy readchar
	@# 高速ローカル音声認識（Whisper）・録音・音声判定・AI推論用
	$(VENV_PIP) install faster-whisper sounddevice numpy silero-vad torch
	@# パッケージ管理・ビルド補助用
	$(VENV_PIP) install setuptools
	@# Web API サーバー構築・起動用
	$(VENV_PIP) install fastapi uvicorn
	@# JMESPath（JSONクエリライブラリ）のインストール
	$(VENV_PIP) install jmespath

	@# source .venv/bin/activate を自動化
	@grep -qF "source .venv/bin/activate" .envrc || { \
		echo "# add $$(date +'%Y.%m.%d') direnv" >> .envrc; \
		echo 'source .venv/bin/activate' >> .envrc; \
		printf "\n" >> .envrc; \
	}
	direnv allow

