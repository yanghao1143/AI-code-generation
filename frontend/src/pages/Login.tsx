import React, { useState } from "react";
import { UiButton } from "../components/UiButton";
import { useNavigate, Link } from "react-router-dom";
import { emitToast } from "../utils/toast";
import { FormHint } from "../components/FormHint";
import "./login.css";
import "../components/ui-input.css";

function toCSV(val: string | string[]): string {
  const arr = Array.isArray(val)
    ? val
    : val
        .split(/[\s,]+/)
        .map((s) => s.trim())
        .filter(Boolean);
  return arr.join(",");
}

export default function Login() {
  const navigate = useNavigate();
  const [userId, setUserId] = useState<string>(localStorage.getItem("userId") || "u1");
  const [permissions, setPermissions] = useState<string>(localStorage.getItem("userPerms") || "articles");
  const [expiresInSec, setExpiresInSec] = useState<number>(3600);
  const [loading, setLoading] = useState(false);

  async function doLogin(e: React.FormEvent) {
    e.preventDefault();
    setLoading(true);
    try {
      const payload = {
        userId: userId.trim() || "u1",
        permissions: toCSV(permissions).split(",").filter(Boolean),
        expiresInSec: Math.max(60, Math.min(24 * 3600, Number(expiresInSec) || 3600)),
      };
      const res = await fetch("/api/public/auth/login", {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          "X-Request-Id": crypto.randomUUID(),
        },
        body: JSON.stringify(payload),
      });
      const body = await res.json();
      if (!res.ok) {
        const code = body?.code || "Error";
        emitToast("error", `登录失败：${res.status} ${code}`);
        return;
      }
      const data = body?.data || {};
      const token: string = data?.token || "";
      const uid: string = data?.userId || payload.userId;
      const perms: string[] = Array.isArray(data?.permissions) ? data.permissions : payload.permissions;
      if (!token) {
        emitToast("error", "登录失败：未返回 token");
        return;
      }

      // 保存凭据，复用现有 AuthBar 的解析与过期清理逻辑
      localStorage.setItem("authToken", token);
      localStorage.setItem("userId", uid);
      localStorage.setItem("userPerms", toCSV(perms));

      emitToast("success", "登录成功，即将跳转首页");
      navigate("/");
    } catch (err) {
      emitToast("error", `登录异常：${(err as Error)?.message || String(err)}`);
    } finally {
      setLoading(false);
    }
  }

  return (
    <div className="login-page ui-density--compact">
      <div className="card ui-panel">
        <h2 className="card-title ui-title">登录</h2>
        <form onSubmit={doLogin} className="form-grid">
          <label className="field">
            <span className="field-label">用户 ID</span>
            <span className="ui-input-wrapper">
              <span className="ui-input__icon" aria-hidden>👤</span>
              <input
                className="ui-input ui-input--has-icon"
                value={userId}
                onChange={(e) => setUserId(e.target.value)}
                placeholder="u1"
              />
            </span>
          </label>
          <label className="field">
            <span className="field-label">权限（逗号分隔）</span>
            <span className="ui-input-wrapper">
              <span className="ui-input__icon" aria-hidden>🔑</span>
              <input
                className="ui-input ui-input--has-icon"
                value={permissions}
                onChange={(e) => setPermissions(e.target.value)}
                placeholder="articles 或 articles:read,articles:create"
              />
            </span>
            <FormHint variant="info">示例：articles,articles:read,articles:update</FormHint>
          </label>
          <label className="field">
            <span className="field-label">有效期（秒）</span>
            {(() => {
              const invalid = !Number.isFinite(expiresInSec) || expiresInSec < 60 || expiresInSec > 86400;
              return (
                <>
                  <span className="ui-input-wrapper">
                    <span className="ui-input__icon" aria-hidden>⏱️</span>
                    <input
                      className={`ui-input ui-input--has-icon${invalid ? " ui-input--warning" : ""}`}
                      type="number"
                      min={60}
                      max={86400}
                      value={expiresInSec}
                      aria-invalid={invalid || undefined}
                      onChange={(e) => setExpiresInSec(parseInt(e.target.value || "3600", 10))}
                    />
                  </span>
                  {invalid && (
                    <FormHint variant="error">范围 60 - 86400 秒，推荐 3600</FormHint>
                  )}
                </>
              );
            })()}
          </label>
        <div className="actions ui-actions">
            <UiButton type="submit" disabled={loading}>
              {loading ? "登录中…" : "登录"}
            </UiButton>
            <Link to="/" className="ui-link">返回首页</Link>
        </div>
        </form>
        <p className="ui-status ui-status--small">
          成功后将保存 authToken/userId/userPerms 并自动跳转首页。
        </p>
      </div>
    </div>
  );
}