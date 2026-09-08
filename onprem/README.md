## 概要
- AIエージェント開発・検証のための学習用リポジトリ
### Make内容の説明
```
make
```
```
/
├── _common                               # 共通処理・初回セットアップ
│   └── _setup_all                        # 必要な環境構築処理を順番に実行
│
├── wsl                                   # WSL環境のセットアップ
│   ├── wsl-tool-install                  # 開発ツールをインストール（direnv/git-lfs/ollama）
│   ├── wsl-git_lfs-setup                 # Git LFSの設定
│   ├── wsl-ollama-model-pull             # モデルをダウンロード
│   ├── wsl-ollama-model-list             # モデル一覧を表示
│   └── wsl-ollama-model-clean            # 未使用モデルを削除
│
├── docker                                # Dockerサービス管理
│   ├── docker-up                         # コンテナを起動
│   ├── docker-down                       # コンテナを停止
│   ├── docker-purge                      # コンテナ・ボリュームを削除
│   ├── docker-build                      # イメージを作成（全体）
│   ├── docker-one-build                  # イメージを作成（個別）
│   └── docker-one-restart                # コンテナを再起動（個別）
│
├── langflow                              # Langflowデータのバックアップ・復元
│   ├── backup                            # Langflowデータをバックアップ
│   └── restore                           # Langflowデータを復元
│
├── firecrawl                             # クローラー環境の管理
│   ├── firecrawl-git-pull                # 最新ソースを取得
│   └── firecrawl-git-dell                # Git管理を削除
│
├── python                                # Python環境の構築
│   ├── python-install                    # Pythonをインストール
│   └── python-setup                      # Python環境を設定
│
├── unity                                 # Unityプロジェクトのバックアップ・復元
│   ├── unity-backup                      # Unityプロジェクトをバックアップ
│   ├── unity-backup-size                 # バックアップサイズを表示
│   ├── unity-restore                     # Unityプロジェクトを復元
│   ├── unity-init                        # 初期状態から復元
│   ├── unity-init-replace                # 初期状態としてバックアップ（クリーン）
│   └── unity-status                      # 現在の設定を確認
│
└── tools                                 # 補助ツール
    ├── windows-setup                     # Windows初期設定
    ├── mic-spk-enable                    # マイク・スピーカーを有効化
    ├── mic-spk-disable                   # マイク・スピーカーを無効化
    └── nvidia-smi                        # GPU情報を表示
```
### 設定
- 各種パス・モデル・APIキーは `make.d/.env` にまとめて定義する
- `-include` により全ての `make.d/*.mk` から読み込まれ、Docker Composeへは `--env-file make.d/.env` で渡される

| 変数 | 説明 | 既定値 |
| --- | --- | --- |
| `__DEV_CONTAINER` | `true`で開発用コンテナ(bridge-frontend等)も合わせて起動 | `true` |
| `__OLLAMA_MODEL` | `wsl-ollama-model-pull`等で取得するメインモデル | `llama3.2:1b` |
| `__WARMUP_MODEL` | 併せて取得する埋め込み用モデル | `bge-m3` |
| `__UNITY_PROJECT_DIR` | バックアップ／復元対象のUnityプロジェクト実体パス | `/mnt/s/risuna` |
| `__LANGFLOW_API_KEY` | Langflowコンテナに設定し、bridgeから利用するAPIキー | (要設定) |
| `__LANGFLOW_GOOGLE_API_KEY` | Langflowのコンポーネントで使用するGoogle APIキー | (要設定) |

### コンテナを起動の準備
```
make
```
```
--- Select Group ---
> _common
--- Select Task [_common] ---
> _setup_all

実行内容:
- WSL環境構築
- Git LFS設定
- Ollamaモデル取得
- Python環境構築
- Firecrawl取得
```
### コンテナを起動
```
make
```
```
--- Select Group ---
> docker
--- Select Task [docker] ---
> docker-up
```
### コンテナにアクセス
- [Langflow コンテナ](http://localhost:7860)（Auto Login）
- [WebSocket 通信確認](http://localhost:5173)<br />
