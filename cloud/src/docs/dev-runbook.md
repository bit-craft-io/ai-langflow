# dev環境 運用ランブック（起動→動作確認→削除）

`envs/dev`（コスト最小構成、`cloud/README.md`「コスト最小構成」参照）を、ゼロの状態から起動して
動作確認し、また元（ECR/Secretsのみ残す、または完全に何もない状態）に戻すまでの一連の手順。
「壊す/作り直す運用が前提」（`cloud/README.md`参照）なので、使わない期間はここに書いた削除手順で
畳んでおく想定。

実行はすべてWSL上を想定（`/mnt/s/...`ではなくWSLネイティブ側での実行を推奨する箇所は都度明記）。

## 0. 準備（初回のみ）

```bash
cd ~/_bot/cloud
make _setup_all   # wslu/npm/jqをインストール
```

## 1. AWS認証

`cloud/make.d/.env`の`AWS_PROFILE`にプロファイル名を設定してから実行する。
以降のコマンドはすべて`cloud/`ディレクトリ（`make`が実行できる場所）で実行する想定。

```bash
make aws-login     # aws sso login
make aws-whoami    # aws sts get-caller-identity（確認）
```

## 2. ECRリポジトリだけ先に作る

```bash
make tf-ecr   # terraform apply -target=module.ecr
```

ここでEC2（`module.ec2`）はまだ作らない。先にEC2まで作ると、ECRにイメージが無い状態で
user-dataが`docker compose up`を実行してしまい、bridge/langflowコンテナの起動に失敗する
（このステップと4番目のステップ「イメージpush」の順序がレースコンディション回避のポイント）。

## 3. Secretsの箱だけ先に作る

```bash
make tf-secrets   # terraform apply -target=module.secrets
```

## 4. Secretsに実値を投入

EC2初回起動時のuser-dataはリトライなしの一発取得でSecrets Managerから値を読むため、
**EC2を作る前**にここで実値を入れておく（`cloud/README.md`参照）。

```bash
make tf-secrets-push
```

`LANGFLOW_API_KEY`/`GOOGLE_API_KEY`/`LANGFLOW_SUPERUSER_PASSWORD`を対話プロンプトで入力する
（コマンドライン引数ではなく環境変数経由でスクリプトへ渡すため、shell履歴には残らない。
`put_secrets.sh`のコメント参照）。

## 5. 3つのイメージをECRへpush

```bash
make ecr-image-push-all
```

既にpush済みでも、`image_tag_mutability=IMMUTABLE`のため同一タグへの再pushは失敗するだけで
実害はないので、状態が不明な場合はこのまま実行してよい
（個別に実行したい場合は`ecr-image-push-bridge`/`ecr-image-push-langflow`/`ecr-image-push-voicevox`）。

## 6. 残り全部をapply（EC2作成）

```bash
make tf-apply
```

これでEC2がECRの3イメージ・Secretsの実値を使って起動する。

## 7. イメージだけ更新したい場合（EC2が既に存在する状態）

`terraform apply`ではuser-dataは再実行されないため、pushスクリプト実行後、対象EC2上で手動実行する
（各`build_and_push_*.sh`末尾の案内どおり）。

```bash
make ecr-image-push-bridge   # 更新したいイメージだけでよい
make aws-ec2-login           # SSMで対話セッションに入る
```

```bash
# ↑のSSMセッション内で実行
sudo docker compose -p agent -f docker-compose.agent.yaml --env-file .env pull <service>
sudo docker compose -p agent -f docker-compose.agent.yaml --env-file .env up -d <service>
```

## 8. 動作確認（frontendデバッグクライアントでAWSと疎通確認）

`/mnt/s/...`上で直接`npm install`すると、WSLのDrvFsマウント越しの書き込みで
`esbuild`のpostinstallスクリプトが壊れて失敗することがある（原因・詳細はメモリ参照）。
WSLネイティブ側（ext4）にコピーしてから実行する。

```bash
mkdir -p ~/dev
cp -r /mnt/s/current/bot/on-premises/server/bridge/frontend ~/dev/bridge-frontend
cd ~/dev/bridge-frontend

npm install
npm run dev
```

ブラウザで表示されたURL（デフォルト`http://localhost:5174`）を開き、接続先欄に
`ws://<EC2のパブリックIP>:8765`（`make aws-ec2-ip`で確認）を入力して接続確認する。

セキュリティグループが`terraform.tfvars`の`dev_client_cidr_blocks`に絞られているため、
今アクセスしている端末のグローバルIP（`curl -s https://checkip.amazonaws.com`で確認）が
一致していないと繋がらない点に注意。

## 9. 削除（完全に畳む場合）

Terraformの依存グラフ上でネットワークにぶら下がっているものが一緒に消えるが、
S3 deployバケット・IAMロール等ネットワークに依存しないリソースは別途`module.ec2`を
指定しないと残るため、両方明示的に実行する（順不同、`envs/dev/main.tf`のコメント参照）。

```bash
make tf-destroy-network
make tf-destroy-ec2

# ECRリポジトリも含めて完全に消す場合
make tf-destroy-ecr

# Secrets Managerも含めて完全に消す場合
make tf-destroy-secrets
```

ECR/Secretsまで消すと、次回起動時は本ランブックの2〜6を全部やり直しになる
（イメージ再push・実値再投入が必要）。単にコストを抑えたいだけの期間であれば、
`module.network`と`module.ec2`だけ消してECR/Secretsは残しておく方が再開が速い。

## 10. 削除後の確認

```bash
make aws-payable-check
```

EC2が本当に消えているかだけをピンポイントで見たい場合:

```bash
make aws-ec2-status
```

## 参考: 起動中のEC2にSSMで入ってコンテナ状態を見る

```bash
make aws-ec2-login   # SSMで対話セッションに入る
```

対話セッションに入らず、コンテナ状態だけ1回取得したい場合:

```bash
make aws-ec2-docker-ps
```
