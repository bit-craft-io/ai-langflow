import asyncio
import time
from prompt_toolkit import PromptSession
from prompt_toolkit.formatted_text import HTML

class InputWriteTimer:
    def __init__(self, timeout: float = 10.0):
        self.timeout = timeout

    async def ask(self, prompt: str) -> str | None:
        timeout = self.timeout
        state = {"last_time": time.time(), "last_text": ""}
        session = PromptSession()

        def on_text_changed(buf):
            if buf.text != state["last_text"]:
                state["last_text"] = buf.text
                state["last_time"] = time.time()

        session.default_buffer.on_text_changed += on_text_changed

        async def watchdog():
            while True:
                await asyncio.sleep(0.1)

                if timeout == 0:
                    session.message = HTML(f"<style fg='ansiyellow'>[------]</style> {prompt}")
                else:
                    elapsed = time.time() - state["last_time"]
                    remaining = max(0.0, timeout - elapsed)
                    session.message = HTML(f"<style fg='ansiyellow'>[{remaining:>5.1f}s]</style> {prompt}")

                if session.app:
                    session.app.invalidate()

                if elapsed >= timeout:
                    current_text = session.default_buffer.text.strip()
                    session.app.exit(result=current_text if current_text else "__TIMEOUT_EMPTY__")
                    break

        watchdog_task = asyncio.create_task(watchdog())

        try:
            result = await session.prompt_async()
            return None if result == "__TIMEOUT_EMPTY__" else result.strip()
        except (KeyboardInterrupt, Exception):
            return None
        finally:
            if not watchdog_task.done():
                watchdog_task.cancel()