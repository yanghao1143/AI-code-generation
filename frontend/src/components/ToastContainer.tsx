import React, { useEffect, useState } from "react";

type ToastType = "info" | "success" | "warning" | "error";

type ToastItem = {
  id: string;
  type: ToastType;
  message: string;
  timeoutMs: number;
};

export function ToastContainer() {
  const [items, setItems] = useState<ToastItem[]>([]);

  useEffect(() => {
    function onToast(e: Event) {
      const ce = e as CustomEvent<{ type: ToastType; message: string; timeoutMs?: number }>;
      const { type, message, timeoutMs = 3000 } = ce.detail || { type: "info", message: "", timeoutMs: 3000 };
      const id = crypto.randomUUID();
      const item: ToastItem = { id, type, message, timeoutMs };
      setItems((prev) => [...prev, item]);
      window.setTimeout(() => {
        setItems((prev) => prev.filter((x) => x.id !== id));
      }, timeoutMs);
    }
    window.addEventListener("app:toast", onToast as EventListener);
    return () => window.removeEventListener("app:toast", onToast as EventListener);
  }, []);

  return (
    <div className="ui-toast-container" aria-live="polite" aria-atomic="false">
      {items.map((it) => (
        <div
          key={it.id}
          role="status"
          className={`ui-toast ui-toast--${it.type}`}
        >
          <strong className={`ui-toast__type ui-hint--${it.type}`}>[{it.type}]</strong>
          {it.message}
        </div>
      ))}
    </div>
  );
}