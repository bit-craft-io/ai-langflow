import threading
import queue
import pygame
import requests

from config import settings
VOICEVOX_URL=f"{settings.voicevox_url}"
SPEAKER_ID=123

def _play_audio_bytes(audio_bytes):
    with open("/tmp/output.wav", "wb") as f:
        f.write(audio_bytes)
    pygame.mixer.music.load("/tmp/output.wav")
    pygame.time.wait(50)  # デバイス起動待ち、微小ディレイ
    pygame.mixer.music.play()
    while pygame.mixer.music.get_busy():
        pygame.time.Clock().tick(10)

def _synthesize(text, speed=1.5):
    voicevox_url = VOICEVOX_URL

    """音声生成のみ(再生しない、バイト列を返す)"""
    query = requests.post(
        voicevox_url + "/audio_query",
        params={"text": text, "speaker": SPEAKER_ID}
    ).json()
    query["speedScale"] = speed

    audio = requests.post(
        voicevox_url + "/synthesis",
        params={"speaker": SPEAKER_ID},
        json=query
    )
    return audio.content

class Pipeline:
    """文をキューに投げると、裏で生成しつつ順番に再生するパイプライン"""

    def __init__(self, speed=1.5):
        pygame.mixer.init()
        self._warmup()
        self.text_queue = queue.Queue()
        self.audio_queue = queue.Queue(maxsize=2)
        self.speed = speed
        self._producer_thread = threading.Thread(target=self._produce, daemon=True)
        self._producer_thread.start()

    def _warmup(self):
        """無音バッファ再生→デバイス起動ラグを事前消化(初回カット防止)"""
        silent = pygame.mixer.Sound(buffer=bytes(4410 * 1))  # 0.05秒分の無音(44100Hz*2byte想定)
        silent.play()
        pygame.time.wait(60)

    def _produce(self):
        while True:
            text = self.text_queue.get()
            if text is None:  # バッチ終端シグナル（スレッドは終了しない）
                self.audio_queue.put(None)
                continue
            print(f"[Synthesizing] {text}")
            audio_bytes = _synthesize(text, self.speed)
            self.audio_queue.put(audio_bytes)

    def submit(self, text):
        """文が確定したら随時これを呼ぶ(ストリーム受信中に随時呼べる)"""
        if text.strip():
            self.text_queue.put(text)

    def finish_and_play_all(self):
        """入力終了を通知しつつ、生成され次第、再生をブロッキングで進める"""
        self.text_queue.put(None)
        while True:
            audio_bytes = self.audio_queue.get()
            if audio_bytes is None:
                break
            print(f"[Output Stream - Audio Playing] size={len(audio_bytes)} bytes")
            _play_audio_bytes(audio_bytes)
