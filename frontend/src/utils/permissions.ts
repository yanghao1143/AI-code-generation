export type ArticleAction = "read" | "create" | "update" | "delete";

export function getPermsSet(): Set<string> {
  const permsStr = (localStorage.getItem("userPerms") || "").trim();
  const list = permsStr
    .split(/[\s,]+/)
    .map((s) => s.trim())
    .filter(Boolean);
  return new Set(list);
}

// 返回是否具有 articles 总权限或指定子权限
export function hasArticlesPerm(action?: ArticleAction): boolean {
  const set = getPermsSet();
  if (set.has("articles")) return true;
  if (!action) return set.has("articles");
  return set.has(`articles:${action}`);
}

// 将权限列表规范化为逗号串（工具函数，便于后续统一）
export function normalizePerms(val: string | string[]): string {
  const arr = Array.isArray(val)
    ? val
    : val
        .split(/[\s,]+/)
        .map((s) => s.trim())
        .filter(Boolean);
  return arr.join(",");
}

export function ensureArticlesPerm(action?: ArticleAction, reason?: string): boolean {
  const ok = hasArticlesPerm(action);
  if (!ok) {
    const msg =
      reason ||
      (action === "read"
        ? "权限不足：需要 articles 或 articles:read"
        : action === "create"
        ? "权限不足：需要 articles 或 articles:create"
        : action === "update"
        ? "权限不足：需要 articles 或 articles:update"
        : action === "delete"
        ? "权限不足：需要 articles 或 articles:delete"
        : "权限不足：缺少 articles 相关权限");
    emitToast("warning", msg);
    // 统一上报权限不足事件，便于后续统计与埋点
    try {
      window.dispatchEvent(
        new CustomEvent("app:permission-denied", {
          detail: { domain: "articles", action: action || "any", message: msg },
        }),
      );
    } catch {}
  }
  return ok;
}
import { emitToast } from "./toast";