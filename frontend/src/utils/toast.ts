export type ToastType = "info" | "success" | "warning" | "error";

export type ToastPayload = {
  type: ToastType;
  message: string;
  timeoutMs?: number;
};

export function emitToast(type: ToastType, message: string, timeoutMs = 3000): void {
  if (typeof window === "undefined") return;
  const detail: ToastPayload = { type, message, timeoutMs };
  window.dispatchEvent(new CustomEvent("app:toast", { detail }));
}