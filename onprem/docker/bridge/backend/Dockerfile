FROM python:3.11-slim

WORKDIR /app

# 依存関係のインストール
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# src ディレクトリの中身をコンテナの /app 直下にコピー
COPY src/ ./

# モジュールの参照エラーを防ぐ設定
ENV PYTHONPATH=/app

# WebSocketポートの開放宣言
EXPOSE 8765

# サーバー起動 (src直下にあったファイルを指定、ws_server.py ならそれに変更)
CMD ["python", "server.py"]