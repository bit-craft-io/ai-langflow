import re
import pykakasi

class Katakana:

  def __init__(self):
    self.kksi = pykakasi.kakasi()

  def convert(self, text: str) -> str:
    tokens = re.split(r"(\d+)", text)
    result = []
    for token in tokens:
      if token.isdigit():
        result.append(token)
      else:
        converted = "".join([item["kana"] for item in self.kksi.convert(token)])
        result.append(converted)
    return "".join(result)