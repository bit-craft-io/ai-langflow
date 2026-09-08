"""
Langflow Bridge CUI Client

docker/bridge/backend/src/server.py (LangflowWSServer) が公開する WebSocket を、
docker/bridge/frontend/src/LangflowBridgeClient.tsx と同じプロトコルで叩く
ターミナル版クライアント。

プロトコル(サーバ実装準拠):
  送信: 生テキスト(JSON化しない) — websocket.send(text)

  受信(テキストフレーム, JSON):
    { type: "speech_text", text: string }                        文単位で逐次届く
    { type: "speech_done", aborted?: boolean, reason?: string }  1リクエスト分の応答完了
    { type: "periodic_update", message: unknown }                push(5秒毎)

  受信(バイナリフレーム):
    直前の speech_text に対応するWAV音声データ(VOICEVOX)
"""

import argparse
import asyncio
import io
import json
import os
import time

import websockets

WS_URL = os.environ.get("BRIDGE_WS_URL", "ws://localhost:8765")

ABORT_REASON_LABEL = {
    "idle_timeout": "チャンク受信タイムアウト",
    "max_chars": "文字数上限超過",
    "max_sentences": "文数上限超過",
    "duplicate": "同一文繰り返し検知",
}


async def audio_player(queue: "asyncio.Queue[bytes]") -> None:
    """audio モードが play のときだけ起動。受信したWAVを順番に再生する。"""
    try:
        os.environ.setdefault("PYGAME_HIDE_SUPPORT_PROMPT", "1")
        import pygame
    except ImportError:
        print("[!] pygame が見つかりません。--audio play には `pip install pygame` が必要です。")
        while True:
            await queue.get()

    try:
        pygame.mixer.init()
    except Exception as e:
        print(f"[!] 音声再生の初期化に失敗しました: {e}")
        print("[!] テキストのみで続行します。")
        while True:
            await queue.get()

    while True:
        wav_bytes = await queue.get()
        try:
            sound = pygame.mixer.Sound(io.BytesIO(wav_bytes))
            channel = sound.play()
            while channel is not None and channel.get_busy():
                await asyncio.sleep(0.05)
        except Exception as e:
            print(f"[!] 再生エラー: {e}")


async def build_voice_input(model_size: str):
    """--input voice のときだけ呼ばれる。faster-whisper/silero-vad等の重い依存を遅延ロードする。"""
    try:
        from voice_input import InputSpeakTimer
    except ImportError as e:
        print(f"[-] 音声入力の依存関係が見つかりません: {e}")
        print("[-] `make python-setup` で faster-whisper 等をインストールしてください。")
        raise SystemExit(1)

    print(f"[*] Whisperモデル({model_size})を読み込み中... (初回はダウンロードが発生します)")
    loop = asyncio.get_running_loop()
    return await loop.run_in_executor(None, InputSpeakTimer, model_size)


def save_audio(wav_bytes: bytes, audio_dir: str, index: int) -> str:
    os.makedirs(audio_dir, exist_ok=True)
    path = os.path.join(audio_dir, f"{int(time.time() * 1000)}_{index:03d}.wav")
    with open(path, "wb") as f:
        f.write(wav_bytes)
    return path


async def receive_response(websocket, args, audio_queue) -> None:
    """1リクエスト分のレスポンス(speech_doneまで)を受信して表示する。"""
    audio_index = 0
    async for message in websocket:
        if isinstance(message, (bytes, bytearray)):
            audio_index += 1
            if args.audio == "play":
                await audio_queue.put(bytes(message))
            elif args.audio == "save":
                path = save_audio(bytes(message), args.audio_dir, audio_index)
                print(f"[AUDIO] saved: {path}")
            continue

        try:
            data = json.loads(message)
        except json.JSONDecodeError:
            print(f"[!] JSON解析失敗: {message}")
            continue

        msg_type = data.get("type")

        if msg_type == "speech_text":
            print(data.get("text", ""))

        elif msg_type == "speech_done":
            if data.get("aborted"):
                reason = data.get("reason", "")
                label = ABORT_REASON_LABEL.get(reason, reason or "unknown")
                print(f"[!] 応答が中断されました ({label})")
            return

        elif msg_type == "periodic_update":
            payload = data.get("message")
            if isinstance(payload, (dict, list)):
                payload = json.dumps(payload, ensure_ascii=False)
            print(f"[PUSH] {payload}")

        else:
            print(f"[!] 未知のtype: {data}")


async def run(args) -> None:
    print(f"Langflow Bridge CUI Client — {args.url} (audio={args.audio}, input={args.input})")
    print("Ctrl+C で終了。\n")

    audio_queue: "asyncio.Queue[bytes]" = asyncio.Queue()
    player_task = None
    if args.audio == "play":
        player_task = asyncio.create_task(audio_player(audio_queue))

    speak_timer = None
    if args.input == "voice":
        speak_timer = await build_voice_input(args.voice_model)

    try:
        async with websockets.connect(args.url, ping_interval=20, ping_timeout=20) as websocket:
            print("[+] 接続確立\n")
            while True:
                if speak_timer is not None:
                    user_text = await speak_timer.ask("[You(voice)]:")
                    if not user_text:
                        print("[!] 発話が検出されませんでした。\n")
                        continue
                    print(f"[You(voice)]: {user_text}")
                else:
                    user_text = (await asyncio.to_thread(input, "[You]: ")).strip()
                    if not user_text:
                        print("Input is Empty.\n")
                        continue

                start_time = time.time()
                await websocket.send(user_text)
                await receive_response(websocket, args, audio_queue)
                elapsed = time.time() - start_time
                print(f"[METRIC] execution_time={elapsed:.4f}s\n")

    except (websockets.exceptions.InvalidURI, OSError, ConnectionRefusedError) as e:
        print(f"[-] Network Error: Failed to reach {args.url}. ({e})")
    except websockets.exceptions.ConnectionClosed:
        print("\n[-] Server disconnected.")
    finally:
        if player_task:
            player_task.cancel()


def main() -> None:
    parser = argparse.ArgumentParser(description="Langflow Bridge CUI Client")
    parser.add_argument("--url", default=WS_URL, help=f"bridge backend の WebSocket URL (既定: {WS_URL})")
    parser.add_argument(
        "--audio",
        choices=["none", "play", "save"],
        default="none",
        help="受信したVOICEVOX音声の扱い: none=無視(既定) / play=pygameで再生 / save=audio_dirへ保存",
    )
    parser.add_argument("--audio-dir", default="audio_out", help="--audio save 時の保存先ディレクトリ")
    parser.add_argument(
        "--input",
        choices=["text", "voice"],
        default="text",
        help="入力方法: text=キーボード入力(既定) / voice=マイクから発話をWhisperで文字起こし",
    )
    parser.add_argument(
        "--voice-model",
        default="small",
        help="--input voice 時に使うfaster-whisperのモデルサイズ(既定: small)",
    )
    args = parser.parse_args()

    try:
        asyncio.run(run(args))
    except (KeyboardInterrupt, EOFError):
        print("\n[+] Exited cleanly.")
    finally:
        # asyncio.to_thread(input, ...) の待受スレッドは Ctrl+C では止まらず、
        # 通常のインタプリタ終了処理(atexitのスレッドjoin)が固まるため強制終了する。
        os._exit(0)


if __name__ == "__main__":
    main()
