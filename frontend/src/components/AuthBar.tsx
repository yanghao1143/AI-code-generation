import React, { useEffect, useState, useRef } from "react";
import { UiButton } from "./UiButton";
import { Link } from "react-router-dom";
import "./ui-input.css";

function decodeJwtPayload(token: string): Record<string, unknown> | null {
  try {
    const parts = token.split(".");
    if (parts.length !== 3) return null;
    const payload = parts[1]
      .replace(/-/g, "+")
      .replace(/_/g, "/");
    const json = atob(payload);
    return JSON.parse(json);
  } catch {
    return null;
  }
}

export function AuthBar() {
  const [token, setToken] = useState(
    localStorage.getItem("authToken") || "dev-token",
  );
  const [perms, setPerms] = useState(
    localStorage.getItem("userPerms") || "articles",
  );
  const [userId, setUserId] = useState(
    localStorage.getItem("userId") || "u1",
  );
  const expireTimer = useRef<number | null>(null);

  const clearCreds = () => {
    try {
      localStorage.removeItem("authToken");
      localStorage.removeItem("userId");
      localStorage.removeItem("userPerms");
    } catch {}
    setToken("");
    setUserId("");
    setPerms("");
  };

  useEffect(() => {
    localStorage.setItem("authToken", token);
    // 统一 JWT 字段：仅解析 sub 或 userId 作为用户 ID，减少兼容逻辑
    const p = decodeJwtPayload(token);
    if (p) {
      const uidCandidate = (p["sub"] || p["userId"]) as string | undefined;
      if (uidCandidate && typeof uidCandidate === "string") {
        setUserId(uidCandidate);
      }
      // 自动从 JWT 解析权限：优先 permissions，其次 perms/scope/roles；保持简单列表
      const rawPerms = (p["permissions"] || p["perms"] || p["scope"] || p["roles"]) as
        | string
        | string[]
        | undefined;
      if (rawPerms) {
        const toList = (val: string | string[]): string[] =>
          Array.isArray(val)
            ? val
            : val
                .split(/[\s,]+/)
                .map((s) => s.trim())
                .filter(Boolean);
        const normalized = toList(rawPerms).join(",");
        if (normalized) setPerms(normalized);
      }

      // 基于 exp 的过期清理：到期后自动清空 authToken/userId
      const exp = (p["exp"] as number | undefined) ?? undefined;
      if (expireTimer.current) {
        window.clearTimeout(expireTimer.current);
        expireTimer.current = null;
      }
      if (typeof exp === "number" && exp > 0) {
        const nowSec = Math.floor(Date.now() / 1000);
        const ms = (exp - nowSec) * 1000;
        if (ms <= 0) {
          // 已过期：立即清理
          localStorage.removeItem("authToken");
          localStorage.removeItem("userId");
          setToken("");
          setUserId("");
        } else {
          expireTimer.current = window.setTimeout(() => {
            localStorage.removeItem("authToken");
            localStorage.removeItem("userId");
            setToken("");
            setUserId("");
          }, ms);
        }
      }
    }
  }, [token]);
  useEffect(() => {
    localStorage.setItem("userPerms", perms);
  }, [perms]);
  useEffect(() => {
    localStorage.setItem("userId", userId);
  }, [userId]);

  return (
    <div className="ui-panel ui-mb-md">
      <div className="ui-row ui-row--gap-md">
        <label>
          Token:
          <input
            className="ui-input ui-inline-gap"
            value={token}
            onChange={(e) => setToken(e.target.value)}
            placeholder="dev-token"
          />
        </label>
        <label>
          Permissions:
          <input
            className="ui-input ui-inline-gap"
            value={perms}
            onChange={(e) => setPerms(e.target.value)}
            placeholder="articles 或 articles:read,articles:create,articles:update,articles:delete"
          />
        </label>
        <label>
          User ID:
          <input
            className="ui-input ui-inline-gap"
            value={userId}
            onChange={(e) => setUserId(e.target.value)}
            placeholder="u1"
          />
        </label>
        <div className="ui-actions">
          <UiButton variant="ghost" onClick={clearCreds}>清空凭据</UiButton>
          <Link to="/login" className="ui-btn ui-btn--ghost">去登录</Link>
        </div>
        <small className="ui-status ui-status--small">
          逗号分隔多个权限；示例：
          <code className="ui-inline-gap">articles:read,articles:update</code>。
          后端可使用 <code className="ui-inline-gap">articles</code> 作为总权限。
          前端请求附加 Authorization 与 X-User-Permissions；JWT 自动解析 User ID（优先 sub/userId）。
        </small>
      </div>
    </div>
  );
}