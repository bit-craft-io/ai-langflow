import re
from .pipeline import Pipeline

class OutputSpeak:
    """テキストストリームを受け取り、文単位でVOICEVOXへ順次投げて再生するクラス"""

    SENTENCE_END_PATTERN = re.compile(r"[。！？\n]")

    def __init__(self, speed: float = 1.5, chunk_size: int = 3):
        self.pipeline = Pipeline(speed=speed)
        self.buffer = ""
        self.full_text = ""
        self.chunk_size = chunk_size

    def feed(self, content: str) -> None:
        """ストリームから届いた断片を1つ受け取る"""
        if not content:
            return

        self.buffer += content
        self.full_text += content

        match = self.SENTENCE_END_PATTERN.search(self.buffer)
        while match:
            sentence = self.buffer[:match.end()]
            self.buffer = self.buffer[match.end():]
            self.pipeline.submit(sentence)
            match = self.SENTENCE_END_PATTERN.search(self.buffer)

    def finish(self) -> str:
        """残りバッファを送信し、再生を完了させる"""
        if self.buffer.strip():
            self.pipeline.submit(self.buffer)
            self.buffer = ""

        self.pipeline.finish_and_play_all()
        return self.full_text

    def stream(self, text_stream) -> str:
        """文字列、またはイテレータ(ジェネレータ等)のどちらも受け付ける"""
        if isinstance(text_stream, str):
            text_stream = self._chunk(text_stream)

        for content in text_stream:
            self.feed(content)
        return self.finish()

    def _chunk(self, text: str):
        """内部用: 文字列をchunk_size単位で分割するジェネレータ"""
        for i in range(0, len(text), self.chunk_size):
            yield text[i:i + self.chunk_size]