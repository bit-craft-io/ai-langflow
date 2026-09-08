import asyncio
import json
import uuid

import websockets
import time
import requests
import jmespath
import re
from functools import partial

from utils.session_manager import SessionManager
from utils.katakana import Katakana
from config import settings

LANGFLOW_BASE_URL = settings.langflow_base_url
LANGFLOW_API_KEY = settings.langflow_api_key
LANGFLOW_FLOW_ID = settings.langflow_flow_id
LANGFLOW_STATE_FLOW_ID = settings.langflow_state_flow_id
LANGFLOW_TIMEOUT_SEC = settings.langflow_timeout_sec
WEBSOCKET_PORT = settings.websocket_port
VOICEVOX_URL = settings.voicevox_url
VOICEVOX_SPEAKER_ID=settings.voicevox_speaker_id
VOICEVOX_SPEED_SCALE = settings.voicevox_speed_scale
FETCH_STATUS_API = settings.fetch_status_api

LANGFLOW_COMPONENT_GEMINI_AI = settings.langflow_component_gemini_ai
LANGFLOW_COMPONENT_GEMINI_EMBEDDING = settings.langflow_component_gemini_embedding
LANGFLOW_GOOGLE_API_KEY = settings.langflow_google_api_key
LANGFLOW_GEMINI_MODEL_NAME = settings.langflow_gemini_model_name

def _build_payload(
    user_text: str,
    session_id: str,
    google_api_key: str | None = None,
    model_name: str | None = None,
) -> dict:
    payload: dict = {
        "input_value": user_text,
        "input_type": "chat",
        "output_type": "chat",
        "session_id": session_id,
    }
    tweaks: dict = {}
    if google_api_key:
        tweaks.setdefault(LANGFLOW_COMPONENT_GEMINI_AI, {})["api_key"] = google_api_key
        tweaks.setdefault(LANGFLOW_COMPONENT_GEMINI_EMBEDDING, {})["api_key"] = google_api_key
    if model_name:
        tweaks.setdefault(LANGFLOW_COMPONENT_GEMINI_AI, {})["model_name"] = model_name
    if tweaks:
        payload["tweaks"] = tweaks
    return payload

def _build_headers() -> dict:
    headers = {"Content-Type": "application/json"}
    if LANGFLOW_API_KEY:
        headers["x-api-key"] = LANGFLOW_API_KEY
    return headers

def _call_flow_api(payload: dict, headers: dict, flow_id: str = LANGFLOW_FLOW_ID, is_stream: bool = False) -> tuple[dict | None, float]:
    start_time = time.time()
    try:
        run_res = requests.post(
            f"{LANGFLOW_BASE_URL}/api/v1/run/{flow_id}?stream={is_stream}",
            json=payload,
            headers=headers,
            timeout=LANGFLOW_TIMEOUT_SEC,
        )
        elapsed_time = time.time() - start_time

        if not run_res.ok:
            print(f"[-] Status: {run_res.status_code}")
            print(f"[-] Response body: {run_res.text}")
        run_res.raise_for_status()
        return run_res.json(), elapsed_time

    except requests.exceptions.ConnectionError:
        print(f"[-] Network Error: Failed to reach backend service at {LANGFLOW_BASE_URL}.")
        return None, time.time() - start_time

    except Exception as e:
        print(f"[-] Runtime Exception: Unexpected failure occurred: {e}")
        return None, time.time() - start_time

def _extract_message(final_state: dict) -> str | None:
    paths = [
        "outputs[0].outputs[0].results.message.text",
        "outputs[0].outputs[0].outputs.message.message",
    ]
    for path in paths:
        value = jmespath.search(path, final_state)
        if value is not None:
            return value
    return None

def _monitor_agent_status() -> str | None:
    if not FETCH_STATUS_API:
        return None

    try:
        payload = _build_payload("", "")
        headers = _build_headers()
        final_state, _ = _call_flow_api(payload, headers, LANGFLOW_STATE_FLOW_ID)

        message_text = _extract_message(final_state) if final_state else None
        if not message_text:
            # print(f"\n[-] Error: {LANGFLOW_API_KEY}")
            print("\n[-] Error: Payload extraction failed. Output stream is empty.")

        return message_text
    except Exception as e:
        print(f"[-] Error in _monitor_agent_status: {e}")
        return None

def _text_to_voicevox_wav(text: str, speaker_id: int = 1, speed_scale: float = 1.0) -> bytes | None:
    try:
        print(f"[VOICEVOX] 音声生成開始: {text}")

        # 1. 音声合成クエリ作成
        query_res = requests.post(
            f"{VOICEVOX_URL}/audio_query",
            params={"text": text, "speaker": speaker_id},
            timeout=5
        )
        query_res.raise_for_status()

        # ここで speedScale を書き換える
        query_json = query_res.json()
        query_json["speedScale"] = speed_scale

        # 2. 音声データ(WAV)生成
        synth_res = requests.post(
            f"{VOICEVOX_URL}/synthesis",
            params={"speaker": speaker_id},
            json=query_json,
            timeout=5
        )
        synth_res.raise_for_status()
        return synth_res.content  # WAVのバイナリ(bytes)
    except Exception as e:
        print(f"[-] VOICEVOX Error: {e}")
        return None

def _call_flow_api_stream(payload: dict, headers: dict, flow_id: str = LANGFLOW_FLOW_ID):
    """Langflow からのストリーミングレスポンスを 1 行ずつ yield する"""
    url = f"{LANGFLOW_BASE_URL}/api/v1/run/{flow_id}?stream=true"
    try:
        with requests.post(url, json=payload, headers=headers, timeout=LANGFLOW_TIMEOUT_SEC, stream=True) as run_res:
            run_res.raise_for_status()
            for line in run_res.iter_lines():
                if line:
                    decoded_line = line.decode("utf-8")
                    # SSE 形式（"data: {...}"）の場合は先頭の "data: " を削る処理など
                    if decoded_line.startswith("data: "):
                        decoded_line = decoded_line[6:]
                    yield decoded_line
    except Exception as e:
        print(f"[-] Streaming Error: {e}")

class LangflowWSServer:
    def __init__(self, host: str = "0.0.0.0", port: int = WEBSOCKET_PORT):
        self.host = host
        self.port = port
        self.session_mgr = SessionManager(timeout=60.0)
        # 接続中の全クライアントを管理するセットを追加
        self.clients = set()

    async def handler(self, websocket):
        session_id = self.session_mgr.get_id()
        self.clients.add(websocket)
        print(f"[+] Client connected. Session ID: {session_id}")

        SENTENCE_ENDINGS = re.compile(r'(.*?[。！？\n])')

        MAX_TOTAL_CHARS = 1000
        MAX_SENTENCES = 30
        DUPLICATE_LIMIT = 3
        CHUNK_IDLE_TIMEOUT = 15.0  # 1チャンクも来ない状態がこの秒数続いたら異常とみなす

        try:
            async for message in websocket:
                session_id = self.session_mgr.get_id()
                google_api_key = LANGFLOW_GOOGLE_API_KEY
                model_name = LANGFLOW_GEMINI_MODEL_NAME

                # 毎回新規発行
                #session_id = str(uuid.uuid4())
                print(f"[Client -> WS]: {message} (session: {session_id})")

                # payload = _build_payload(message, session_id)
                payload = _build_payload(message, session_id, google_api_key, model_name)
                print(f"[DEBUG] payload: {payload}")

                headers = _build_headers()
                loop = asyncio.get_running_loop()

                buffer = ""
                total_chars = 0
                sentence_count = 0
                last_sentence = None
                duplicate_count = 0
                aborted = False
                abort_reason = ""
                seen_ids = set()

                queue = asyncio.Queue()

                def fetch_chunks():
                    for chunk in _call_flow_api_stream(payload, headers, LANGFLOW_FLOW_ID):
                        # print(f"[RAW CHUNK]: {chunk}")  # 一時追加
                        loop.call_soon_threadsafe(queue.put_nowait, chunk)
                    loop.call_soon_threadsafe(queue.put_nowait, None)

                loop.run_in_executor(None, partial(fetch_chunks))

                while True:
                    try:
                        chunk = await asyncio.wait_for(queue.get(), timeout=CHUNK_IDLE_TIMEOUT)
                    except asyncio.TimeoutError:
                        print("[!] チャンクが一定時間届かないため強制終了します。")
                        aborted = True
                        abort_reason = "idle_timeout"
                        break

                    if chunk is None:
                        break

                    chunk_text = ""
                    try:
                        chunk_json = json.loads(chunk)
                        event = chunk_json.get("event")
                        if event == "token":
                            chunk_text = chunk_json.get("data", {}).get("chunk", "")
                        elif event == "add_message":
                            msg_data = chunk_json.get("data", {}).get("data", {})
                            msg_id = msg_data.get("id")
                            if msg_data.get("sender") == "Machine" and msg_id not in seen_ids:
                                seen_ids.add(msg_id)
                                chunk_text = msg_data.get("text", "")
                            # if chunk_text:
                            #     print(f"[Langflow Token]: {chunk_text}")
                    except (json.JSONDecodeError, TypeError):
                        chunk_text = str(chunk)

                    buffer += chunk_text
                    total_chars += len(chunk_text)

                    if total_chars > MAX_TOTAL_CHARS:
                        print("[!] 文字数上限を超えたため強制終了します。")
                        aborted = True
                        abort_reason = "max_chars"
                        break

                    matches = SENTENCE_ENDINGS.findall(buffer)
                    if matches:
                        for sentence in matches:
                            sentence_clean = sentence.strip()
                            if not sentence_clean:
                                continue

                            # 全てカタカナに変換
                            # sentence_clean = Katakana().convert(sentence_clean)
                            # print(f"[Conv Sentence]: {sentence_clean}")

                            if sentence_clean == last_sentence:
                                duplicate_count += 1
                            else:
                                duplicate_count = 0
                            last_sentence = sentence_clean

                            if duplicate_count >= DUPLICATE_LIMIT:
                                print("[!] 同一文の繰り返しを検知。強制終了します。")
                                aborted = True
                                abort_reason = "duplicate"
                                break

                            sentence_count += 1
                            if sentence_count > MAX_SENTENCES:
                                print("[!] 文数上限を超えたため強制終了します。")
                                aborted = True
                                abort_reason = "max_sentences"
                                break

                            print(f"[Send Sentence]: {sentence_clean}")
                            text_payload = json.dumps(
                                {"type": "speech_text", "text": sentence_clean}, ensure_ascii=False
                            )

                            await websocket.send(text_payload)

                            wav_bytes = await loop.run_in_executor(
                                None,
                                partial(
                                    _text_to_voicevox_wav,
                                    sentence_clean,
                                    speaker_id=VOICEVOX_SPEAKER_ID,
                                    speed_scale=VOICEVOX_SPEED_SCALE
                                )
                            )
                            if wav_bytes:
                                await websocket.send(wav_bytes)

                        buffer = SENTENCE_ENDINGS.sub('', buffer)

                    if aborted:
                        break

                # 残ったバッファ（正常終了時のみ送る）
                if not aborted and buffer.strip():
                    sentence_clean = buffer.strip()
                    text_payload = json.dumps({"type": "speech_text", "text": sentence_clean}, ensure_ascii=False)
                    await websocket.send(text_payload)
                    wav_bytes = await loop.run_in_executor(
                        None,
                        partial(
                            _text_to_voicevox_wav,
                            sentence_clean,
                            speaker_id=VOICEVOX_SPEAKER_ID,
                            speed_scale=VOICEVOX_SPEED_SCALE
                        )
                    )
                    if wav_bytes:
                        await websocket.send(wav_bytes)

                done_payload = {"type": "speech_done"}
                if aborted:
                    done_payload["aborted"] = True
                    done_payload["reason"] = abort_reason
                await websocket.send(json.dumps(done_payload, ensure_ascii=False))
                print(f"[+] Response completed for session {session_id} (aborted={aborted})")
                # ここで次の message を待つ（待ち受け継続）

        except websockets.exceptions.ConnectionClosedError:
            print("[-] Client disconnected unexpectedly.")
        finally:
            self.clients.discard(websocket)
            print(f"[+] Session terminated: {session_id}")

    async def push_loop(self, interval_seconds: float = 5.0):
        while True:
            # _call_flow_api が同期関数(requests)なので、別スレッドで実行するとブロックしない
            loop = asyncio.get_running_loop()
            message_text = await loop.run_in_executor(
                None, partial(_monitor_agent_status)
            )

            if message_text:
                print(f"[Status]: {message_text}")

                # message_text が JSON 文字列の場合は辞書に変換する
                try:
                    parsed_message = json.loads(message_text)
                except (json.JSONDecodeError, TypeError):
                    parsed_message = message_text

                data = {
                    "type": "periodic_update",
                    "message": parsed_message
                }

                if self.clients:
                    json_message = json.dumps(data, ensure_ascii=False)
                    websockets.broadcast(self.clients, json_message)
                    # print(f"[Push] Sent status to Unity: {json_message}")

            await asyncio.sleep(interval_seconds)

    async def start(self):
        asyncio.create_task(self.push_loop(interval_seconds=5.0))

        async with websockets.serve(
                self.handler,
                self.host,
                self.port,
                ping_interval=20,
                ping_timeout=20
        ):
            print(f"[+] WebSocket Server running on ws://{self.host}:{self.port}")
            # 永久ループ
            await asyncio.Future()

if __name__ == "__main__":
    server = LangflowWSServer(host="0.0.0.0", port=WEBSOCKET_PORT)
    try:
        asyncio.run(server.start())
    except KeyboardInterrupt:
        print("\n[+] Exited by user.")