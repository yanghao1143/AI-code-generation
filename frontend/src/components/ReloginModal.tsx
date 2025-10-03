import React, { useEffect, useState } from "react";
import { UiButton } from "./UiButton";
import { Link } from "react-router-dom";

export function ReloginModal() {
  const [open, setOpen] = useState(false);
  const [reason, setReason] = useState<string>("");

  useEffect(() => {
    const handler = (e: Event) => {
      const ce = e as CustomEvent<{ reason?: string }>;
      setReason(ce.detail?.reason || "token_expired");
      setOpen(true);
    };
    window.addEventListener("app:auth-expired", handler as EventListener);
    return () => {
      window.removeEventListener("app:auth-expired", handler as EventListener);
    };
  }, []);

  if (!open) return null;

  const clearCreds = () => {
    try {
      localStorage.removeItem("authToken");
      localStorage.removeItem("userId");
    } catch {}
    setOpen(false);
  };

  return (
    <div
      role="dialog"
      aria-modal="true"
      aria-label="重新登录提示"
      className="ui-modal-backdrop"
    >
      <div className="ui-panel ui-modal">
        <h3 className="ui-title">登录已过期</h3>
        <p className="ui-status">
          原因：{reason === "token_expired" ? "Token 过期" : reason}
        </p>
        <p className="ui-status ui-status--small">
          请重新获取并填入有效的 JWT 到顶部的 Token 输入框。
        </p>
        <div className="ui-actions">
          <UiButton variant="ghost" onClick={() => setOpen(false)}>稍后</UiButton>
          <UiButton variant="ghost" onClick={clearCreds}>清空凭据</UiButton>
          <Link to="/" onClick={() => setOpen(false)} className="ui-btn ui-btn--ghost">去首页</Link>
        </div>
      </div>
    </div>
  );
}