# ADR-0011: Make ベースの対話式メニューで運用コマンドを統一する

## Status
Accepted（既存コードから採用済みと判断）

## Context
（不明）

## Decision
- `on-premises/Makefile` はデフォルトターゲット `menu` を持ち、`make.d/*.mk` を `include` して読み込んだファイル群からグループ名（ファイル名ベース: `_common`, `wsl`, `docker`, `server`, `python`, `tools`）とその中の `TASKS +=` に列挙されたタスク名を対話的に選択させるインタラクティブメニューを `awk`/`sed` でMakefile自身を自己解析することで実現している。
- 個別タスクを直接指定して実行することも可能（例: `make docker-build`）。
- `make.d/_common.mk`, `make.d/wsl.mk`, `make.d/docker.mk`, `make.d/server.mk`, `make.d/python.mk`, `make.d/tools.mk` の6ファイルが `Makefile` から `include` されている。
- `make.d/tools.mk` は `tools/win-ops/*.py`（`mic_on.py`, `mic_off.py`, `spk_on.py`, `spk_off.py`, `setup.py`）をベンチマーク対象の `.venv` 内Pythonから呼び出し、マイク・スピーカーの有効化/無効化や Windows 側セットアップ、`nvidia-smi` によるGPU VRAM確認を行う。

## Consequences
（不明）
