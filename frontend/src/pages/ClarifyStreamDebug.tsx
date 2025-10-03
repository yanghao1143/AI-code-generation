import React, { useEffect, useRef, useState } from "react";
import { UiButton } from "../components/UiButton";
import { FormHint } from "../components/FormHint";
import { emitToast } from "../utils/toast";
import { connectClarifyWs } from "../api/clarifyWs";

type Frame = { type?: string; event?: string; data?: unknown };

export default function ClarifyStreamDebug() {
  const [prompt, setPrompt] = useState(
    "一个简易文章发布系统：用户可以创建/查看/编辑/删除文章；支持标签与搜索。",
  );
  const [language, setLanguage] = useState("zh-CN");
  const [sseRunning, setSseRunning] = useState(false);
  const [wsRunning, setWsRunning] = useState(false);
  const [frames, setFrames] = useState<Frame[]>([]);
  const wsRef = useRef<WebSocket | null>(null);

  useEffect(() => {
    return () => {
      try {
        wsRef.current?.close();
      } catch {}
    };
  }, []);

  const startSSE = async () => {
    setFrames([]);
    setSseRunning(true);
    try {
      const qs = new URLSearchParams();
      qs.set("prompt", prompt);
      qs.set("language", language);
      const res = await fetch(`/api/clarify/stream?${qs.toString()}`, {
        headers: {
          Authorization: `Bearer ${localStorage.getItem("authToken") || "dev-token"}`,
          "X-User-Permissions": localStorage.getItem("userPerms") || "ai.clarify",
          "X-Request-Id": (crypto as any).randomUUID?.() || String(Date.now()),
        },
      });
      if (!res.ok || !res.body) throw new Error(`HTTP ${res.status}`);
      const reader = res.body.getReader();
      const decoder = new TextDecoder();
      let buf = "";
      while (true) {
        const { value, done } = await reader.read();
        if (done) break;
        buf += decoder.decode(value, { stream: true });
        while (true) {
          const idx = buf.indexOf("\n\n");
          if (idx === -1) break;
          const chunk = buf.slice(0, idx);
          buf = buf.slice(idx + 2);
          if (chunk.startsWith("data: ")) {
            const txt = chunk.slice("data: ".length);
            try {
              const obj = JSON.parse(txt);
              setFrames((prev) => [...prev, obj]);
            } catch {
              setFrames((prev) => [...prev, { data: txt }]);
            }
          } else if (chunk.startsWith("event: done")) {
            setFrames((prev) => [...prev, { event: "done", data: { ok: true } }]);
          }
        }
      }
      emitToast("success", "SSE 流完成");
    } catch (err) {
      emitToast("error", (err as Error)?.message || String(err));
    } finally {
      setSseRunning(false);
    }
  };

  const startWS = () => {
    setFrames([]);
    setWsRunning(true);
    try {
      const ws = connectClarifyWs(prompt, language, {
        onOpen() {
          emitToast("info", "WebSocket 已连接");
        },
        onMessage(obj) {
          setFrames((prev) => [...prev, obj as Frame]);
        },
        onError() {
          emitToast("error", "WebSocket 错误");
        },
        onClose() {
          setWsRunning(false);
          emitToast("success", "WebSocket 已关闭");
        },
      });
      wsRef.current = ws;
    } catch (err) {
      setWsRunning(false);
      emitToast("error", (err as Error)?.message || String(err));
    }
  };

  const stopWS = () => {
    try {
      wsRef.current?.close();
    } catch {}
  };

  return (
    <div className="ui-panel">
      <h2 className="ui-title">Clarify Stream 调试（SSE / WebSocket）</h2>
      <FormHint>
        请确保顶部权限包含 <code>ai.clarify</code>，并已登录（默认 dev-token）。浏览器连接 WS 时使用
        Sec-WebSocket-Protocol 传递 token 与权限。后端已支持该方式鉴权。
      </FormHint>
      <div className="ui-row ui-row--gap-md ui-mb-md">
        <label className="ui-flex-1">
          <div className="ui-label">Prompt</div>
          <textarea
            className="ui-input"
            rows={3}
            value={prompt}
            onChange={(e) => setPrompt(e.target.value)}
          />
        </label>
        <label>
          <div className="ui-label">Language</div>
          <select className="ui-input" value={language} onChange={(e) => setLanguage(e.target.value)}>
            <option value="zh-CN">中文（zh-CN）</option>
            <option value="en-US">English (en-US)</option>
          </select>
        </label>
      </div>
      <div className="ui-row ui-row--gap-md">
        <UiButton onClick={startSSE} disabled={sseRunning || wsRunning}>
          {sseRunning ? "SSE 运行中…" : "开始 SSE"}
        </UiButton>
        <UiButton variant="ghost" onClick={startWS} disabled={wsRunning || sseRunning}>
          {wsRunning ? "WS 运行中…" : "开始 WS"}
        </UiButton>
        <UiButton variant="ghost" onClick={stopWS} disabled={!wsRunning}>
          关闭 WS
        </UiButton>
      </div>

      <div className="ui-mt-md">
        <h3 className="ui-subtitle">Frames</h3>
        {frames.length === 0 ? (
          <div className="ui-text">尚无帧</div>
        ) : (
          <ul className="ui-list">
            {frames.map((f, i) => (
              <li key={`f-${i}`}>
                <pre className="ui-code">{JSON.stringify(f, null, 2)}</pre>
              </li>
            ))}
          </ul>
        )}
      </div>
    </div>
  );
}