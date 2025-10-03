// Browser WebSocket helper for Clarify stream
// Uses Sec-WebSocket-Protocol to pass token and permissions because browsers cannot set custom headers.

export type ClarifyWsHandlers = {
  onOpen?: (ev: Event) => void;
  onMessage?: (data: unknown) => void;
  onError?: (ev: Event) => void;
  onClose?: (ev: CloseEvent) => void;
};

export function connectClarifyWs(
  prompt: string,
  language: string = "zh-CN",
  handlers: ClarifyWsHandlers = {},
): WebSocket {
  const token = localStorage.getItem("authToken") || "dev-token";
  const perms = (localStorage.getItem("userPerms") || "ai.clarify").trim();
  const protoList: string[] = [];
  if (token) protoList.push(token);
  if (perms) protoList.push(perms);
  const url = new URL(
    `${location.protocol === "https:" ? "wss" : "ws"}://${location.host}/api/clarify/stream/ws`,
  );
  url.searchParams.set("prompt", prompt);
  url.searchParams.set("language", language || "zh-CN");
  const ws = new WebSocket(url.toString(), protoList);
  ws.addEventListener("open", (ev) => handlers.onOpen?.(ev));
  ws.addEventListener("message", (ev) => {
    try {
      const obj = JSON.parse((ev as MessageEvent).data as string);
      handlers.onMessage?.(obj);
    } catch {
      handlers.onMessage?.((ev as MessageEvent).data);
    }
  });
  ws.addEventListener("error", (ev) => handlers.onError?.(ev));
  ws.addEventListener("close", (ev) => handlers.onClose?.(ev));
  return ws;
}