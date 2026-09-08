import { useState, useRef, useCallback, useEffect } from "react";

/**
 * Langflow WebSocket Bridge Client
 * 対象サーバ: LangflowWSServer (websockets, /api/v1/run/{flow_id} ストリーミング中継 + VOICEVOX音声合成)
 *
 * プロトコル(サーバ実装準拠):
 *   送信: 生テキスト(JSON化しない) — websocket.send(text)
 *
 *   受信(テキストフレーム, JSON):
 *     { type: "speech_text", text: string }                        文単位で逐次届く
 *     { type: "speech_done", aborted?: boolean, reason?: string }  1リクエスト分の応答完了
 *     { type: "periodic_update", message: unknown }                push(5秒毎)
 *
 *   受信(バイナリフレーム):
 *     直前の speech_text に対応するWAV音声データ(ArrayBuffer)
 *     ※ 全文が音声化されるとは限らない(VOICEVOX失敗時は音声フレーム無し)
 */

type ConnectionState = "disconnected" | "connecting" | "connected" | "error";

interface SpeechTextMsg {
  type: "speech_text";
  text: string;
}
interface SpeechDoneMsg {
  type: "speech_done";
  aborted?: boolean;
  reason?: string;
}
interface PeriodicUpdateMsg {
  type: "periodic_update";
  message: unknown;
}
type InboundText = SpeechTextMsg | SpeechDoneMsg | PeriodicUpdateMsg;

interface LogEntry {
  id: string;
  kind: "sent" | "speech" | "done" | "push" | "system" | "error";
  timestamp: string;
  text: string;
  meta?: string;
  hasAudio?: boolean;
}

const genId = () => Math.random().toString(36).slice(2, 10);

const nowLabel = () =>
  new Date().toLocaleTimeString("ja-JP", { hour12: false }) +
  "." +
  String(new Date().getMilliseconds()).padStart(3, "0");

const ABORT_REASON_LABEL: Record<string, string> = {
  idle_timeout: "チャンク受信タイムアウト",
  max_chars: "文字数上限超過",
  max_sentences: "文数上限超過",
  duplicate: "同一文繰り返し検知",
};

export default function LangflowBridgeClient() {
  const [url, setUrl] = useState("ws://localhost:8765");
  const [state, setState] = useState<ConnectionState>("disconnected");
  const [message, setMessage] = useState("");
  const [logs, setLogs] = useState<LogEntry[]>([]);
  const [autoScroll, setAutoScroll] = useState(true);
  const [streaming, setStreaming] = useState(false);
  const [audioEnabled, setAudioEnabled] = useState(true);
  const [nowPlayingId, setNowPlayingId] = useState<string | null>(null);

  const wsRef = useRef<WebSocket | null>(null);
  const logEndRef = useRef<HTMLDivElement | null>(null);
  const audioElRef = useRef<HTMLAudioElement | null>(null);

  // 直近の speech_text ログID(次に届くバイナリと対応付ける用)
  const pendingSpeechIdRef = useRef<string | null>(null);
  // 再生待ちキュー: {id, url}
  const audioQueueRef = useRef<{ id: string; url: string }[]>([]);
  const playingRef = useRef(false);

  const pushLog = useCallback((entry: Omit<LogEntry, "id" | "timestamp">) => {
    const id = genId();
    setLogs((prev) => [...prev, { ...entry, id, timestamp: nowLabel() }]);
    return id;
  }, []);

  useEffect(() => {
    if (autoScroll) logEndRef.current?.scrollIntoView({ behavior: "smooth" });
  }, [logs, autoScroll]);

  useEffect(() => {
    return () => {
      wsRef.current?.close();
    };
  }, []);

  const playNextInQueue = useCallback(() => {
    if (playingRef.current) return;
    const next = audioQueueRef.current.shift();
    if (!next || !audioElRef.current) {
      setNowPlayingId(null);
      return;
    }
    playingRef.current = true;
    setNowPlayingId(next.id);
    audioElRef.current.src = next.url;
    audioElRef.current.play().catch(() => {
      playingRef.current = false;
      URL.revokeObjectURL(next.url);
      playNextInQueue();
    });
  }, []);

  const handleAudioEnded = useCallback(() => {
    playingRef.current = false;
    setNowPlayingId(null);
    playNextInQueue();
  }, [playNextInQueue]);

  const connect = useCallback(() => {
    if (wsRef.current) wsRef.current.close();
    setState("connecting");
    pushLog({ kind: "system", text: `接続開始: ${url}` });

    let socket: WebSocket;
    try {
      socket = new WebSocket(url);
    } catch (e) {
      setState("error");
      pushLog({ kind: "system", text: `接続失敗: ${(e as Error).message}` });
      return;
    }
    socket.binaryType = "arraybuffer";

    socket.onopen = () => {
      setState("connected");
      pushLog({ kind: "system", text: "接続確立" });
    };

    socket.onmessage = (event) => {
      // バイナリ(音声WAV) — 直前の speech_text と対応付け
      if (event.data instanceof ArrayBuffer) {
        const blob = new Blob([event.data], { type: "audio/wav" });
        const objUrl = URL.createObjectURL(blob);
        const targetId = pendingSpeechIdRef.current;

        if (targetId) {
          setLogs((prev) =>
            prev.map((l) => (l.id === targetId ? { ...l, hasAudio: true } : l))
          );
        }

        if (audioEnabled) {
          audioQueueRef.current.push({ id: targetId ?? genId(), url: objUrl });
          playNextInQueue();
        } else {
          URL.revokeObjectURL(objUrl);
        }
        return;
      }

      // テキストフレーム(JSON)
      let parsed: InboundText | null = null;
      try {
        parsed = JSON.parse(event.data as string);
      } catch {
        pushLog({ kind: "error", text: String(event.data), meta: "JSON解析失敗" });
        return;
      }

      switch (parsed?.type) {
        case "speech_text": {
          const id = pushLog({ kind: "speech", text: parsed.text });
          pendingSpeechIdRef.current = id;
          break;
        }
        case "speech_done": {
          setStreaming(false);
          pendingSpeechIdRef.current = null;
          if (parsed.aborted) {
            pushLog({
              kind: "error",
              text: `応答が中断されました`,
              meta: ABORT_REASON_LABEL[parsed.reason ?? ""] ?? parsed.reason ?? "unknown",
            });
          } else {
            pushLog({ kind: "done", text: "応答完了" });
          }
          break;
        }
        case "periodic_update": {
          const body =
            typeof parsed.message === "string"
              ? parsed.message
              : JSON.stringify(parsed.message, null, 2);
          pushLog({ kind: "push", text: body, meta: "periodic_update" });
          break;
        }
        default:
          pushLog({ kind: "error", text: event.data as string, meta: "未知のtype" });
      }
    };

    socket.onerror = () => {
      setState("error");
      pushLog({ kind: "system", text: "接続エラー発生" });
    };

    socket.onclose = (event) => {
      setState("disconnected");
      setStreaming(false);
      pushLog({
        kind: "system",
        text: `切断 (code=${event.code}${event.reason ? `, reason=${event.reason}` : ""})`,
      });
    };

    wsRef.current = socket;
  }, [url, pushLog, audioEnabled, playNextInQueue]);

  const disconnect = useCallback(() => {
    wsRef.current?.close(1000, "manual disconnect");
  }, []);

  const sendMessage = useCallback(() => {
    if (!wsRef.current || state !== "connected" || message.trim().length === 0) return;
    wsRef.current.send(message);
    pushLog({ kind: "sent", text: message });
    setStreaming(true);
    setMessage("");
  }, [state, message, pushLog]);

  const handleKeyDown = (e: React.KeyboardEvent<HTMLTextAreaElement>) => {
    if (e.key === "Enter" && (e.metaKey || e.ctrlKey)) {
      e.preventDefault();
      sendMessage();
    }
  };

  const clearLogs = () => setLogs([]);

  const stateColor: Record<ConnectionState, string> = {
    disconnected: "#6b7280",
    connecting: "#d97706",
    connected: "#16a34a",
    error: "#dc2626",
  };
  const stateLabel: Record<ConnectionState, string> = {
    disconnected: "未接続",
    connecting: "接続中",
    connected: "接続済み",
    error: "エラー",
  };

  return (
    <div
      style={{
        fontFamily: "'JetBrains Mono', 'SFMono-Regular', Consolas, monospace",
        background: "#0d1117",
        color: "#c9d1d9",
        minHeight: "100vh",
        padding: "24px",
        boxSizing: "border-box",
      }}
    >
      <audio ref={audioElRef} onEnded={handleAudioEnded} style={{ display: "none" }} />

      <div style={{ maxWidth: 900, margin: "0 auto" }}>
        <header
          style={{
            display: "flex",
            alignItems: "center",
            justifyContent: "space-between",
            marginBottom: 20,
          }}
        >
          <h1 style={{ fontSize: 16, fontWeight: 600, letterSpacing: 1, margin: 0, color: "#e6edf3" }}>
            LANGFLOW WS BRIDGE
          </h1>
          <div style={{ display: "flex", alignItems: "center", gap: 8 }}>
            <span
              style={{
                width: 8,
                height: 8,
                borderRadius: "50%",
                background: stateColor[state],
                display: "inline-block",
              }}
            />
            <span style={{ fontSize: 12, color: "#8b949e" }}>{stateLabel[state]}</span>
          </div>
        </header>

        <section style={{ display: "flex", gap: 8, marginBottom: 16 }}>
          <input
            value={url}
            onChange={(e) => setUrl(e.target.value)}
            disabled={state === "connected" || state === "connecting"}
            placeholder="ws://localhost:8765"
            style={inputStyle({ flex: 1 })}
          />
          {state === "connected" || state === "connecting" ? (
            <button onClick={disconnect} style={btnStyle("#dc2626")}>
              切断
            </button>
          ) : (
            <button onClick={connect} style={btnStyle("#238636")}>
              接続
            </button>
          )}
        </section>

        <section
          style={{
            background: "#161b22",
            border: "1px solid #30363d",
            borderRadius: 6,
            padding: 16,
            marginBottom: 16,
          }}
        >
          <textarea
            value={message}
            onChange={(e) => setMessage(e.target.value)}
            onKeyDown={handleKeyDown}
            rows={4}
            placeholder="Langflowへ送るメッセージ (Cmd/Ctrl+Enterで送信)"
            style={{ ...inputStyle({ width: "100%" }), resize: "vertical", fontFamily: "inherit" }}
          />
          <div style={{ display: "flex", justifyContent: "space-between", alignItems: "center", marginTop: 10 }}>
            <div style={{ display: "flex", alignItems: "center", gap: 14 }}>
              <label style={{ fontSize: 12, color: "#8b949e", display: "flex", alignItems: "center", gap: 4 }}>
                <input
                  type="checkbox"
                  checked={audioEnabled}
                  onChange={(e) => setAudioEnabled(e.target.checked)}
                />
                音声自動再生
              </label>
              <span style={{ fontSize: 12, color: streaming ? "#d97706" : "#484f58" }}>
                {streaming ? "応答生成中…" : ""}
              </span>
            </div>
            <button
              onClick={sendMessage}
              disabled={state !== "connected" || message.trim().length === 0}
              style={btnStyle(state === "connected" ? "#1f6feb" : "#30363d")}
            >
              送信
            </button>
          </div>
        </section>

        <section>
          <div style={{ display: "flex", justifyContent: "space-between", alignItems: "center", marginBottom: 8 }}>
            <span style={{ fontSize: 12, color: "#8b949e" }}>LOG ({logs.length})</span>
            <div style={{ display: "flex", gap: 12, alignItems: "center" }}>
              <label style={{ fontSize: 12, color: "#8b949e", display: "flex", alignItems: "center", gap: 4 }}>
                <input type="checkbox" checked={autoScroll} onChange={(e) => setAutoScroll(e.target.checked)} />
                自動スクロール
              </label>
              <button onClick={clearLogs} style={{ ...btnStyle("#21262d"), padding: "4px 10px", fontSize: 12 }}>
                クリア
              </button>
            </div>
          </div>

          <div
            style={{
              background: "#010409",
              border: "1px solid #30363d",
              borderRadius: 6,
              height: 420,
              overflowY: "auto",
              padding: 12,
              fontSize: 12,
              lineHeight: 1.5,
            }}
          >
            {logs.length === 0 && <div style={{ color: "#484f58" }}>ログなし</div>}
            {logs.map((log) => (
              <div key={log.id} style={{ marginBottom: 10 }}>
                <div style={{ color: "#484f58" }}>
                  [{log.timestamp}] <span style={{ color: kindColor(log.kind) }}>{kindLabel(log.kind)}</span>
                  {log.meta && <span style={{ color: "#6e7681" }}> ({log.meta})</span>}
                  {log.hasAudio && (
                    <span style={{ color: nowPlayingId === log.id ? "#3fb950" : "#6e7681" }}>
                      {" "}
                      {nowPlayingId === log.id ? "▶ 再生中" : "🔊"}
                    </span>
                  )}
                </div>
                <pre
                  style={{
                    margin: "2px 0 0 0",
                    whiteSpace: "pre-wrap",
                    wordBreak: "break-all",
                    color: log.kind === "error" ? "#f85149" : "#c9d1d9",
                  }}
                >
                  {log.text}
                </pre>
              </div>
            ))}
            <div ref={logEndRef} />
          </div>
        </section>
      </div>
    </div>
  );
}

function kindLabel(k: LogEntry["kind"]) {
  switch (k) {
    case "sent":
      return "SENT";
    case "speech":
      return "TEXT";
    case "done":
      return "DONE";
    case "push":
      return "PUSH";
    case "error":
      return "ERROR";
    default:
      return "SYS";
  }
}

function kindColor(k: LogEntry["kind"]) {
  switch (k) {
    case "sent":
      return "#58a6ff";
    case "speech":
      return "#3fb950";
    case "done":
      return "#a5d6ff";
    case "push":
      return "#a371f7";
    case "error":
      return "#f85149";
    default:
      return "#8b949e";
  }
}

function inputStyle(extra: React.CSSProperties = {}): React.CSSProperties {
  return {
    background: "#0d1117",
    border: "1px solid #30363d",
    borderRadius: 4,
    color: "#c9d1d9",
    padding: "8px 10px",
    fontSize: 13,
    fontFamily: "inherit",
    outline: "none",
    boxSizing: "border-box",
    ...extra,
  };
}

function btnStyle(bg: string): React.CSSProperties {
  return {
    background: bg,
    color: "#fff",
    border: "none",
    borderRadius: 4,
    padding: "8px 16px",
    fontSize: 13,
    cursor: "pointer",
    fontFamily: "inherit",
  };
}
