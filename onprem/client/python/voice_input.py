import asyncio
import time
import warnings

import numpy as np
import sounddevice as sd
import torch
from faster_whisper import WhisperModel

# silero-vadの内部torch.jit.loadが出すFutureWarning(torch.export移行案内)はノイズなので抑制
warnings.filterwarnings("ignore", category=FutureWarning, module=r"torch\.jit\._serialization")
from silero_vad import load_silero_vad, VADIterator


class InputSpeakTimer:
    _model: WhisperModel | None = None  # モデルロード重い→クラス変数キャッシュ
    _vad_model = None  # silero-vadモデルも共有キャッシュ

    def __init__(
            self,
            model_size: str = "small",
            device: str = "cpu",
            compute_type: str = "int8",
            sample_rate: int = 16000,
            silence_timeout: float = 1.5,
            max_wait: float = 20.0,
            vad_threshold: float = 0.5,  # 0.0-1.0、高いほど発話判定厳しい
    ):
        self.sample_rate = sample_rate
        self.silence_timeout = silence_timeout
        self.max_wait = max_wait

        if InputSpeakTimer._model is None:
            InputSpeakTimer._model = WhisperModel(
                model_size, device=device, compute_type=compute_type
            )
        self.model = InputSpeakTimer._model

        if InputSpeakTimer._vad_model is None:
            InputSpeakTimer._vad_model = load_silero_vad()
        self.vad_iterator = VADIterator(
            InputSpeakTimer._vad_model,
            sampling_rate=sample_rate,
            threshold=vad_threshold,
        )

    async def ask(self, prompt: str = "") -> str | None:
        print(f"{prompt} [録音待機... 発話開始で自動録音]")

        loop = asyncio.get_running_loop()
        frames: list[np.ndarray] = []
        state = {"last_voice_time": time.time(), "started": False}

        # 🌟 silero-vad 推奨チャンクサイズ: 16kHz時512サンプル固定
        frame_size = 512

        def callback(indata, frame_count, time_info, status):
            audio = indata[:, 0].copy()
            chunk_tensor = torch.from_numpy(audio)

            speech_dict = self.vad_iterator(chunk_tensor, return_seconds=True)

            if speech_dict is not None and "start" in speech_dict:
                state["started"] = True
                state["last_voice_time"] = time.time()
            elif speech_dict is not None and "end" in speech_dict:
                state["last_voice_time"] = time.time()  # end検出時点を無音起点に

            if state["started"]:
                frames.append(audio)

        stream = sd.InputStream(
            samplerate=self.sample_rate,
            channels=1,
            dtype="float32",
            blocksize=frame_size,
            callback=callback,
        )

        start_time = time.time()
        with stream:
            while True:
                await asyncio.sleep(0.05)
                now = time.time()

                if not state["started"] and (now - start_time) > self.max_wait:
                    self.vad_iterator.reset_states()
                    return None

                if state["started"] and (now - state["last_voice_time"]) > self.silence_timeout:
                    break

        self.vad_iterator.reset_states()  # 🌟 次回呼び出し用に内部状態リセット必須

        if not frames:
            return None

        audio_data = np.concatenate(frames)

        segments, _ = await loop.run_in_executor(
            None, lambda: self.model.transcribe(audio_data, language=None)
        )
        text = "".join(seg.text for seg in segments).strip()
        return text if text else None