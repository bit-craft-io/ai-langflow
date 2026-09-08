import os
import sys
import time
import requests

# Dify API base（Web共有URLでなくAPI用base_url。要環境に応じ変更）
BASE_URL = os.environ.get("DIFY_BASE_URL", "http://localhost/v1")
API_KEY = os.environ.get("DIFY_API_KEY", "app-PZnOjwNN7onsYt6N7iRjNiY2")
USER_ID = os.environ.get("DIFY_USER_ID", "local-user")

conversation_id = ""  # 会話継続用。初回は空文字


def _build_payload(user_text: str) -> dict:
    return {
        "inputs": {},
        "query": user_text,
        "response_mode": "blocking",
        "conversation_id": conversation_id,
        "user": USER_ID,
    }


def _build_headers() -> dict:
    return {
        "Content-Type": "application/json",
        "Authorization": f"Bearer {API_KEY}",
    }


def _call_chat_api(payload: dict, headers: dict) -> tuple[dict | None, float]:
    start_time = time.time()
    try:
        res = requests.post(
            f"{BASE_URL}/chat-messages",
            json=payload,
            headers=headers,
        )
        elapsed = time.time() - start_time

        if not res.ok:
            print(f"[-] Status: {res.status_code}")
            print(f"[-] Response body: {res.text}")
        res.raise_for_status()
        return res.json(), elapsed

    except requests.exceptions.ConnectionError:
        print(f"\n[-] Network Error: Failed to reach {BASE_URL}.")
        return None, time.time() - start_time

    except Exception as e:
        print(f"\n[-] Runtime Exception: {e}")
        return None, time.time() - start_time


def query_agent(user_text: str | None):
    global conversation_id

    if not user_text:
        print("Input is Empty.\n")
        return

    payload = _build_payload(user_text)
    headers = _build_headers()

    print("[*] Sending query to Dify...")
    result, elapsed = _call_chat_api(payload, headers)

    if result is None:
        return

    print(f"[METRIC] execution_time={elapsed:.4f}s")

    conversation_id = result.get("conversation_id", conversation_id)
    answer = result.get("answer")

    if answer:
        print("\n" + "=" * 60)
        print(f"[Response]: {answer}")
        print("=" * 60 + "\n")
    else:
        print("[-] Error: 'answer' field missing in response.")
        print(result)


def main():
    print("Dify Agent CLI. Ctrl+C で終了。\n")
    try:
        while True:
            user_text = input("[You]: ").strip()
            query_agent(user_text)
    except (KeyboardInterrupt, EOFError):
        print("\n[+] Exited cleanly.")


if __name__ == "__main__":
    main()