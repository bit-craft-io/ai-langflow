import time
import uuid


class SessionManager:
    def __init__(self, timeout=60.0):
        self._sessions: dict[str, dict] = {}
        self._timeout = timeout

    def get_id(self, key: str = "default") -> str:
        now = time.time()
        s = self._sessions.get(key)
        if s is None or (now - s["last_access"]) > self._timeout:
            s = {"id": str(uuid.uuid4()), "last_access": now}
            self._sessions[key] = s
        else:
            s["last_access"] = now
        return s["id"]
