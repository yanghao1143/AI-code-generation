// OpenAPI 类型已在 ./types 生成，这里对齐并复用。
import type { paths, components } from "./types";
import { emitToast } from "../utils/toast";
import { normalizePerms, ensureArticlesPerm } from "../utils/permissions";

const BASE = "/api/v1";

function authHeaders() {
  const token = localStorage.getItem("authToken") || "dev-token";
  const permsRaw = (localStorage.getItem("userPerms") || "articles").trim();
  const perms = normalizePerms(permsRaw);
  return {
    Authorization: `Bearer ${token}`,
    "X-User-Permissions": perms,
    "X-Request-Id": crypto.randomUUID(),
    "Content-Type": "application/json",
  } as Record<string, string>;
}

// JWT 过期拦截：在发起请求前统一校验并提示
function decodeJwtPayload(token: string): Record<string, unknown> | null {
  try {
    const parts = token.split(".");
    if (parts.length !== 3) return null;
    const payload = parts[1].replace(/-/g, "+").replace(/_/g, "/");
    const json = atob(payload);
    return JSON.parse(json);
  } catch {
    return null;
  }
}

function ensureTokenValid(): void {
  const token = localStorage.getItem("authToken") || "dev-token";
  const parts = token.split(".");
  // 仅当 token 看起来是 JWT 时进行过期校验
  if (parts.length === 3) {
    const p = decodeJwtPayload(token);
    const exp = (p?.["exp"] as number | undefined) ?? undefined;
    if (typeof exp === "number" && exp > 0) {
      const nowSec = Math.floor(Date.now() / 1000);
      if (exp <= nowSec) {
        // 过期：清理并提示
        localStorage.removeItem("authToken");
        localStorage.removeItem("userId");
        emitToast("warning", "登录已过期，请重新登录", 4000);
        try {
          window.dispatchEvent(
            new CustomEvent("app:auth-expired", { detail: { reason: "token_expired" } }),
          );
        } catch {}
        throw new Error("Token expired");
      }
    }
  }
}

export type Article = {
  id: string;
  title: string;
  content: string;
  created_at?: string;
  updated_at?: string;
};

// LLM list item shapes aligned with backend
export type LLMProvider = {
  id: string;
  name: string;
  status: string;
};

export type LLMModel = {
  providerId: string;
  modelId: string;
  capabilities?: string[];
  maxTokens?: number;
  costPer1KTokens?: number;
  status?: string;
};

// 以 OpenAPI 定义对齐 SSE 查询参数类型
export type ArticlesStreamQuery = NonNullable<
  paths["/api/v1/articles/stream"]["get"]["parameters"]["query"]
>;

// Minimal typed client using generated OpenAPI types where applicable
export async function listArticles(): Promise<Article[]> {
  ensureTokenValid();
  if (!ensureArticlesPerm("read", "读取文章需要 articles 或 articles:read")) {
    throw new Error("PermissionDenied");
  }
  const res = await fetch(`${BASE}/articles`, { headers: authHeaders() });
  if (!res.ok) throw new Error(`HTTP ${res.status}`);
  const data = await res.json();
  // API uses unified response { code, message, data: { items: [...] } }
  const items = (data?.data?.items as Article[]) || [];
  return Array.isArray(items) ? items : [];
}

// List articles with pagination & filters, returning list + optional page meta
export type ArticlesListQuery = {
  pageSize?: number;
  afterId?: string;
  authorId?: string;
  qTitle?: string;
  qContent?: string;
  // Legacy
  limit?: number;
  offset?: number;
  q?: string;
};

export type ArticlesPage = {
  items: Article[];
  page?: {
    pageSize?: number;
    nextAfterId?: string;
    hasMore?: boolean;
    total?: number;
  };
};

export async function listArticlesPaged(
  params: ArticlesListQuery = {},
): Promise<ArticlesPage> {
  ensureTokenValid();
  if (!ensureArticlesPerm("read", "读取文章需要 articles 或 articles:read")) {
    throw new Error("PermissionDenied");
  }
  const qs = new URLSearchParams();
  if (params.pageSize && params.pageSize > 0)
    qs.set("pageSize", String(params.pageSize));
  if (params.afterId) qs.set("afterId", params.afterId);
  if (params.authorId) qs.set("authorId", params.authorId);
  if (params.qTitle) qs.set("qTitle", params.qTitle);
  if (params.qContent) qs.set("qContent", params.qContent);
  if (params.limit && params.limit > 0) qs.set("limit", String(params.limit));
  if (params.offset && params.offset >= 0)
    qs.set("offset", String(params.offset));
  if (params.q) qs.set("q", params.q);

  const res = await fetch(`${BASE}/articles?${qs.toString()}`, {
    headers: authHeaders(),
  });
  const data = await res.json();
  if (!res.ok) {
    const code = data?.code || "Error";
    throw new Error(`${res.status} ${code}`);
  }
  const items = (data?.data?.items as Article[]) || [];
  const page = data?.data?.page as ArticlesPage["page"] | undefined;
  return { items: Array.isArray(items) ? items : [], page };
}

export async function createArticle(
  input: { title: string; content: string; authorId: string; tags?: string[] },
): Promise<Article> {
  ensureTokenValid();
  if (!ensureArticlesPerm("create", "创建文章需要 articles 或 articles:create")) {
    throw new Error("PermissionDenied");
  }
  const res = await fetch(`${BASE}/articles`, {
    method: "POST",
    headers: authHeaders(),
    body: JSON.stringify(input),
  });
  const data = await res.json();
  if (!res.ok) {
    const code = data?.code || "Error";
    throw new Error(`${res.status} ${code}`);
  }
  return data?.data as Article;
}

export async function getArticle(id: string): Promise<Article> {
  ensureTokenValid();
  if (!ensureArticlesPerm("read", "读取文章需要 articles 或 articles:read")) {
    throw new Error("PermissionDenied");
  }
  const res = await fetch(`${BASE}/articles/${encodeURIComponent(id)}`, {
    headers: authHeaders(),
  });
  const data = await res.json();
  if (!res.ok) {
    const code = data?.code || "Error";
    throw new Error(`${res.status} ${code}`);
  }
  return data?.data as Article;
}

export async function updateArticle(
  id: string,
  input: Partial<Pick<Article, "title" | "content">>,
): Promise<Article> {
  ensureTokenValid();
  if (!ensureArticlesPerm("update", "更新文章需要 articles 或 articles:update")) {
    throw new Error("PermissionDenied");
  }
  const res = await fetch(`${BASE}/articles/${encodeURIComponent(id)}`, {
    method: "PUT",
    headers: authHeaders(),
    body: JSON.stringify(input),
  });
  const data = await res.json();
  if (!res.ok) {
    const code = data?.code || "Error";
    throw new Error(`${res.status} ${code}`);
  }
  return data?.data as Article;
}

export async function deleteArticle(
  id: string,
): Promise<{ deleted: boolean; id: string }> {
  ensureTokenValid();
  if (!ensureArticlesPerm("delete", "删除文章需要 articles 或 articles:delete")) {
    throw new Error("PermissionDenied");
  }
  const res = await fetch(`${BASE}/articles/${encodeURIComponent(id)}`, {
    method: "DELETE",
    headers: authHeaders(),
  });
  const data = await res.json();
  if (!res.ok) {
    const code = data?.code || "Error";
    throw new Error(`${res.status} ${code}`);
  }
  return data?.data as { deleted: boolean; id: string };
}

// Stream articles with filters/pagination via SSE over fetch
// Collects `event: item` frames into an array and resolves when stream closes
export async function streamListArticles(
  params: ArticlesStreamQuery = {},
): Promise<Article[]> {
  ensureTokenValid();
  if (!ensureArticlesPerm("read", "读取文章需要 articles 或 articles:read")) {
    throw new Error("PermissionDenied");
  }
  const qs = new URLSearchParams();
  qs.set("mode", "list");
  if (params.pageSize && params.pageSize > 0)
    qs.set("pageSize", String(params.pageSize));
  if (params.limit && params.limit > 0) qs.set("limit", String(params.limit));
  if (params.offset && params.offset >= 0)
    qs.set("offset", String(params.offset));
  if (params.afterId) qs.set("afterId", params.afterId);
  if (params.authorId) qs.set("authorId", params.authorId);
  if (params.qTitle) qs.set("qTitle", params.qTitle);
  if (params.qContent) qs.set("qContent", params.qContent);
  // OpenAPI 未声明的标签/时间等筛选参数不再发送，保持规范对齐
  if (params.heartbeatMs && params.heartbeatMs > 0)
    qs.set("heartbeatMs", String(params.heartbeatMs));
  if (params.follow) qs.set("follow", "true");
  if (params.followMaxMs && params.followMaxMs > 0)
    qs.set("followMaxMs", String(params.followMaxMs));
  if (params.followBufferMs && params.followBufferMs > 0)
    qs.set("followBufferMs", String(params.followBufferMs));
  if (params.followBatchMax && params.followBatchMax > 0)
    qs.set("followBatchMax", String(params.followBatchMax));
  if (params.q) qs.set("q", params.q);

  const url = `${BASE}/articles/stream?${qs.toString()}`;
  const res = await fetch(url, {
    headers: { ...authHeaders(), Accept: "text/event-stream" },
  });
  if (!res.ok) {
    // best-effort read json error
    let code = "Error";
    try {
      const data = await res.json();
      code = data?.code || code;
    } catch (err) {
      void err; // ignore parse errors
    }
    throw new Error(`${res.status} ${code}`);
  }
  const reader = res.body?.getReader();
  if (!reader) return [];
  const dec = new TextDecoder();
  const items: Article[] = [];
  let buf = "";
  let currentEvent = "";
  while (true) {
    const { done, value } = await reader.read();
    if (done) break;
    buf += dec.decode(value, { stream: true });
    let idx;
    while ((idx = buf.indexOf("\n")) >= 0) {
      const line = buf.slice(0, idx).replace(/\r$/, "");
      buf = buf.slice(idx + 1);
      const trimmed = line.trim();
      if (!trimmed) {
        // event boundary
        currentEvent = "";
        continue;
      }
      if (trimmed.startsWith(":")) {
        // heartbeat comment
        continue;
      }
      if (trimmed.startsWith("event:")) {
        currentEvent = trimmed.slice("event:".length).trim();
        continue;
      }
      if (trimmed.startsWith("data:")) {
        const payload = trimmed.slice("data:".length).trim();
        if (currentEvent === "item") {
          try {
            const a = JSON.parse(payload) as Article;
            items.push(a);
          } catch (err) {
            void err; // ignore malformed frames
          }
        }
        continue;
      }
    }
  }
  return items;
}

// ===================== Billing =====================
export async function listPlans(): Promise<string[]> {
  const res = await fetch(`${BASE}/billing/plans`, { headers: authHeaders() });
  const data = await res.json();
  if (!res.ok) {
    const code = data?.code || "Error";
    throw new Error(`${res.status} ${code}`);
  }
  const plans = (data?.data?.plans as string[]) || (data?.data?.items as string[]) || [];
  return Array.isArray(plans) ? plans : [];
}

export async function listInvoices(): Promise<string[]> {
  const res = await fetch(`${BASE}/billing/invoices`, {
    headers: authHeaders(),
  });
  const data = await res.json();
  if (!res.ok) {
    const code = data?.code || "Error";
    throw new Error(`${res.status} ${code}`);
  }
  const invoices = (data?.data?.invoices as string[]) || (data?.data?.items as string[]) || [];
  return Array.isArray(invoices) ? invoices : [];
}

export async function createOrder(
  req: components["schemas"]["BillingCreateOrderRequest"],
): Promise<{ orderId: string; productId: string; amount: number; currency: string }> {
  const res = await fetch(`${BASE}/billing/orders`, {
    method: "POST",
    headers: authHeaders(),
    body: JSON.stringify(req),
  });
  const data = await res.json();
  if (!res.ok) {
    const code = data?.code || "Error";
    throw new Error(`${res.status} ${code}`);
  }
  return data?.data as {
    orderId: string;
    productId: string;
    amount: number;
    currency: string;
  };
}

export async function createPayment(
  req: components["schemas"]["BillingCreatePaymentRequest"],
): Promise<{ paymentId: string; orderId: string; method: string }> {
  const res = await fetch(`${BASE}/billing/payments`, {
    method: "POST",
    headers: authHeaders(),
    body: JSON.stringify(req),
  });
  const data = await res.json();
  if (!res.ok) {
    const code = data?.code || "Error";
    throw new Error(`${res.status} ${code}`);
  }
  return data?.data as { paymentId: string; orderId: string; method: string };
}

// ===================== Observe =====================
export async function postObserveEvent(
  req: components["schemas"]["ObserveEventRequest"],
): Promise<unknown> {
  const res = await fetch(`${BASE}/observe/events`, {
    method: "POST",
    headers: authHeaders(),
    body: JSON.stringify(req),
  });
  const data = await res.json();
  if (!res.ok) {
    const code = data?.code || "Error";
    throw new Error(`${res.status} ${code}`);
  }
  return data?.data as unknown;
}

export async function getMetrics(): Promise<unknown> {
  const res = await fetch(`${BASE}/observe/metrics`, {
    headers: authHeaders(),
  });
  const data = await res.json();
  if (!res.ok) {
    const code = data?.code || "Error";
    throw new Error(`${res.status} ${code}`);
  }
  return data?.data as unknown;
}

export async function getTraces(): Promise<unknown> {
  const res = await fetch(`${BASE}/observe/traces`, { headers: authHeaders() });
  const data = await res.json();
  if (!res.ok) {
    const code = data?.code || "Error";
    throw new Error(`${res.status} ${code}`);
  }
  return data?.data as unknown;
}

// ===================== LLM =====================
export async function listLLMProviders(): Promise<LLMProvider[]> {
  const res = await fetch(`${BASE}/llm/providers`, { headers: authHeaders() });
  const data = await res.json();
  if (!res.ok) {
    const code = data?.code || "Error";
    throw new Error(`${res.status} ${code}`);
  }
  const items = (data?.data?.items as LLMProvider[]) || [];
  return Array.isArray(items) ? items : [];
}

export async function listLLMModels(): Promise<LLMModel[]> {
  const res = await fetch(`${BASE}/llm/models`, { headers: authHeaders() });
  const data = await res.json();
  if (!res.ok) {
    const code = data?.code || "Error";
    throw new Error(`${res.status} ${code}`);
  }
  const items = (data?.data?.items as LLMModel[]) || [];
  return Array.isArray(items) ? items : [];
}

export async function llmChat(
  req: components["schemas"]["LLMChatRequest"],
): Promise<unknown> {
  const res = await fetch(`${BASE}/llm/chat`, {
    method: "POST",
    headers: authHeaders(),
    body: JSON.stringify(req),
  });
  const data = await res.json();
  if (!res.ok) {
    const code = data?.code || "Error";
    throw new Error(`${res.status} ${code}`);
  }
  return data?.data as unknown;
}

export async function llmEmbeddings(
  req: components["schemas"]["LLMEmbeddingsRequest"],
): Promise<unknown> {
  const res = await fetch(`${BASE}/llm/embeddings`, {
    method: "POST",
    headers: authHeaders(),
    body: JSON.stringify(req),
  });
  const data = await res.json();
  if (!res.ok) {
    const code = data?.code || "Error";
    throw new Error(`${res.status} ${code}`);
  }
  return data?.data as unknown;
}

export async function llmModerate(
  req: components["schemas"]["LLMModerateRequest"],
): Promise<unknown> {
  const res = await fetch(`${BASE}/llm/moderate`, {
    method: "POST",
    headers: authHeaders(),
    body: JSON.stringify(req),
  });
  const data = await res.json();
  if (!res.ok) {
    const code = data?.code || "Error";
    throw new Error(`${res.status} ${code}`);
  }
  return data?.data as unknown;
}

// ===================== Clarify =====================
export type ClarifyGenerateRequest = {
  prompt: string;
  language?: string; // default zh-CN
  useStructured?: boolean;
  stream?: boolean; // backend currently ignores for sync
};

export type ClarifyGenerateResponse = {
  requirements: string[];
  design: string[];
  tasks: string[];
  openapi?: Record<string, unknown>;
  issues?: Record<string, unknown>[];
};

// 将 Clarify 结果快速转为 Markdown，便于本地预览或复制
export function clarifyToMarkdown(
  resp: ClarifyGenerateResponse,
  opts: { title?: string; language?: string } = {},
): string {
  const title = opts.title || "Clarify 输出";
  const lang = opts.language ? `语言：${opts.language}` : "";
  const sec = (h: string, items?: string[]) => {
    const list = (items || []).map((x) => `- ${x}`).join("\n");
    return `\n## ${h}\n${list}\n`;
  };
  let md = `# ${title}\n${lang}\n`;
  md += sec("Requirements", resp.requirements);
  md += sec("Design", resp.design);
  md += sec("Tasks", resp.tasks);
  if (resp.openapi) {
    md += `\n## OpenAPI 片段\n\n\n\n\n` +
      "```json\n" +
      JSON.stringify(resp.openapi, null, 2) +
      "\n```\n";
  }
  return md;
}

// Synchronous clarify generation
export async function clarifyGenerate(
  req: ClarifyGenerateRequest,
): Promise<ClarifyGenerateResponse> {
  ensureTokenValid();
  // 权限提示（不强制拦截，后端会校验），提升可用性
  const perms = (localStorage.getItem("userPerms") || "").split(/[\,\s]+/);
  if (!perms.includes("ai.clarify")) {
    emitToast("warning", "建议在 Permissions 中添加 ai.clarify 以调用 Clarify 服务");
  }
  const res = await fetch(`${BASE}/ai/clarify/generate`, {
    method: "POST",
    headers: authHeaders(),
    body: JSON.stringify(req),
  });
  const data = await res.json().catch(() => ({}));
  if (!res.ok) {
    const code = data?.code || "Error";
    const msg = data?.message || "Clarify generate failed";
    throw new Error(`${res.status} ${code} ${msg}`);
  }
  const d = data?.data || {};
  return {
    requirements: (d?.requirements as string[]) || [],
    design: (d?.design as string[]) || [],
    tasks: (d?.tasks as string[]) || [],
    openapi: (d?.openapi as Record<string, unknown>) || undefined,
    issues: (d?.issues as Record<string, unknown>[]) || [],
  };
}

// Stream clarify artifacts via SSE; collects frames until done
export async function clarifyStream(
  params: { prompt: string; language?: string },
): Promise<ClarifyGenerateResponse> {
  ensureTokenValid();
  const qs = new URLSearchParams();
  qs.set("prompt", params.prompt);
  if (params.language) qs.set("language", params.language);
  const url = `${BASE}/ai/clarify/stream?${qs.toString()}`;
  const res = await fetch(url, {
    headers: { ...authHeaders(), Accept: "text/event-stream" },
  });
  if (!res.ok) {
    // best-effort read json error
    let code = "Error";
    let message = "Clarify stream failed";
    try {
      const data = await res.json();
      code = data?.code || code;
      message = data?.message || message;
    } catch {}
    throw new Error(`${res.status} ${code} ${message}`);
  }
  const reader = res.body?.getReader();
  if (!reader) {
    return { requirements: [], design: [], tasks: [], openapi: undefined, issues: [] };
  }
  const dec = new TextDecoder();
  let buf = "";
  let currentEvent = "";
  const result: ClarifyGenerateResponse = {
    requirements: [],
    design: [],
    tasks: [],
    openapi: undefined,
    issues: [],
  };
  while (true) {
    const { done, value } = await reader.read();
    if (done) break;
    buf += dec.decode(value, { stream: true });
    let idx;
    while ((idx = buf.indexOf("\n")) >= 0) {
      const line = buf.slice(0, idx).replace(/\r$/, "");
      buf = buf.slice(idx + 1);
      const trimmed = line.trim();
      if (!trimmed) {
        currentEvent = ""; // event boundary
        continue;
      }
      if (trimmed.startsWith(":")) {
        continue; // heartbeat
      }
      if (trimmed.startsWith("event:")) {
        currentEvent = trimmed.slice("event:".length).trim();
        continue;
      }
      if (trimmed.startsWith("data:")) {
        const payload = trimmed.slice("data:".length).trim();
        if (currentEvent === "done") {
          // final ack; we could parse {"ok":true}
          continue;
        }
        try {
          const ch = JSON.parse(payload) as { type?: string; data?: unknown };
          const t = (ch.type || "").toLowerCase();
          if (t === "requirements" && Array.isArray(ch.data)) {
            result.requirements = ch.data as string[];
          } else if (t === "design" && Array.isArray(ch.data)) {
            result.design = ch.data as string[];
          } else if (t === "tasks" && Array.isArray(ch.data)) {
            result.tasks = ch.data as string[];
          }
        } catch {}
        continue;
      }
    }
  }
  return result;
}

// Live SSE streaming with incremental callbacks
export type ClarifyStreamEvent = {
  type: "requirements" | "design" | "tasks" | "done" | "message" | "error";
  data?: unknown;
  raw?: string;
};

export async function clarifyStreamLive(
  params: { prompt: string; language?: string },
  opts: {
    onEvent?: (evt: ClarifyStreamEvent, aggregate: ClarifyGenerateResponse) => void;
    signal?: AbortSignal;
  } = {},
): Promise<ClarifyGenerateResponse> {
  ensureTokenValid();
  const qs = new URLSearchParams();
  qs.set("prompt", params.prompt);
  if (params.language) qs.set("language", params.language);
  const url = `${BASE}/ai/clarify/stream?${qs.toString()}`;
  const res = await fetch(url, {
    headers: { ...authHeaders(), Accept: "text/event-stream" },
    signal: opts.signal,
  });
  if (!res.ok) {
    let code = "Error";
    let message = "Clarify stream failed";
    try {
      const data = await res.json();
      code = data?.code || code;
      message = data?.message || message;
    } catch {}
    const errMsg = `${res.status} ${code} ${message}`;
    opts.onEvent?.({ type: "error", raw: errMsg }, { requirements: [], design: [], tasks: [], openapi: undefined, issues: [] });
    throw new Error(errMsg);
  }
  const reader = res.body?.getReader();
  if (!reader) {
    return { requirements: [], design: [], tasks: [], openapi: undefined, issues: [] };
  }
  const dec = new TextDecoder();
  let buf = "";
  let currentEvent = "";
  const agg: ClarifyGenerateResponse = {
    requirements: [],
    design: [],
    tasks: [],
    openapi: undefined,
    issues: [],
  };
  while (true) {
    const { done, value } = await reader.read();
    if (done) break;
    buf += dec.decode(value, { stream: true });
    let idx;
    while ((idx = buf.indexOf("\n")) >= 0) {
      const line = buf.slice(0, idx).replace(/\r$/, "");
      buf = buf.slice(idx + 1);
      const trimmed = line.trim();
      if (!trimmed) {
        currentEvent = "";
        continue;
      }
      if (trimmed.startsWith(":")) {
        continue;
      }
      if (trimmed.startsWith("event:")) {
        currentEvent = trimmed.slice("event:".length).trim();
        continue;
      }
      if (trimmed.startsWith("data:")) {
        const payload = trimmed.slice("data:".length).trim();
        if (currentEvent === "done") {
          opts.onEvent?.({ type: "done", raw: payload }, agg);
          continue;
        }
        try {
          const ch = JSON.parse(payload) as { type?: string; data?: unknown };
          const t = (ch.type || "").toLowerCase();
          if (t === "requirements" && Array.isArray(ch.data)) {
            agg.requirements = ch.data as string[];
            opts.onEvent?.({ type: "requirements", data: ch.data }, agg);
          } else if (t === "design" && Array.isArray(ch.data)) {
            agg.design = ch.data as string[];
            opts.onEvent?.({ type: "design", data: ch.data }, agg);
          } else if (t === "tasks" && Array.isArray(ch.data)) {
            agg.tasks = ch.data as string[];
            opts.onEvent?.({ type: "tasks", data: ch.data }, agg);
          } else {
            opts.onEvent?.({ type: "message", data: ch }, agg);
          }
        } catch {
          opts.onEvent?.({ type: "message", raw: payload }, agg);
        }
        continue;
      }
    }
  }
  return agg;
}

// Export clarify artifacts as Markdown
export type ClarifyExportResult = {
  fileName: string;
  filePath: string;
  format: string;
};

export async function clarifyExportMarkdown(
  prompt: string,
  language?: string,
): Promise<ClarifyExportResult> {
  ensureTokenValid();
  const res = await fetch(`${BASE}/ai/clarify/export`, {
    method: "POST",
    headers: authHeaders(),
    body: JSON.stringify({ prompt, language, format: "md" }),
  });
  const data = await res.json().catch(() => ({}));
  if (!res.ok) {
    const code = data?.code || "Error";
    const msg = data?.message || "Clarify export failed";
    throw new Error(`${res.status} ${code} ${msg}`);
  }
  const d = data?.data || {};
  return {
    fileName: String(d?.fileName || ""),
    filePath: String(d?.filePath || ""),
    format: String(d?.format || "md"),
  };
}

// Export clarify artifacts as PDF (requires approval ticket)
export async function clarifyExportPdf(
  approvalTicket: string,
): Promise<ClarifyExportResult> {
  ensureTokenValid();
  const ticket = (approvalTicket || "").trim();
  if (!ticket) {
    throw new Error("需要审批票据 (X-Approval-Ticket)");
  }
  const headers = { ...authHeaders(), "X-Approval-Ticket": ticket };
  const res = await fetch(`${BASE}/ai/clarify/export/pdf`, {
    method: "POST",
    headers,
    body: JSON.stringify({ format: "pdf" }),
  });
  const data = await res.json().catch(() => ({}));
  if (!res.ok) {
    const code = data?.code || "Error";
    const msg = data?.message || "Clarify PDF export failed";
    throw new Error(`${res.status} ${code} ${msg}`);
  }
  const d = data?.data || {};
  return {
    fileName: String(d?.fileName || ""),
    filePath: String(d?.filePath || ""),
    format: String(d?.format || "pdf"),
  };
}

// Export clarify artifacts as DOCX (requires approval ticket)
export async function clarifyExportDocx(
  approvalTicket: string,
): Promise<ClarifyExportResult> {
  ensureTokenValid();
  const ticket = (approvalTicket || "").trim();
  if (!ticket) {
    throw new Error("需要审批票据 (X-Approval-Ticket)");
  }
  const headers = { ...authHeaders(), "X-Approval-Ticket": ticket };
  const res = await fetch(`${BASE}/ai/clarify/export/docx`, {
    method: "POST",
    headers,
    body: JSON.stringify({ format: "docx" }),
  });
  const data = await res.json().catch(() => ({}));
  if (!res.ok) {
    const code = data?.code || "Error";
    const msg = data?.message || "Clarify DOCX export failed";
    throw new Error(`${res.status} ${code} ${msg}`);
  }
  const d = data?.data || {};
  return {
    fileName: String(d?.fileName || ""),
    filePath: String(d?.filePath || ""),
    format: String(d?.format || "docx"),
  };
}

// Build download URL for exported clarify document
export function getClarifyDocUrl(name: string): string {
  return `${BASE}/ai/clarify/docs/${encodeURIComponent(name)}`;
}

// Download clarify document with authorization headers
export async function downloadClarifyDoc(
  name: string,
): Promise<{ blob: Blob; fileName: string; contentType: string }> {
  ensureTokenValid();
  const token = localStorage.getItem("authToken") || "dev-token";
  const permsRaw = (localStorage.getItem("userPerms") || "articles").trim();
  const perms = normalizePerms(permsRaw);
  const url = getClarifyDocUrl(name);
  const res = await fetch(url, {
    headers: {
      Authorization: `Bearer ${token}`,
      "X-User-Permissions": perms,
      "X-Request-Id": crypto.randomUUID(),
    },
  });
  if (!res.ok) {
    // Try parse error envelope for better message
    let msg = `HTTP ${res.status}`;
    try {
      const data = await res.json();
      if (data?.message) msg = `${msg} ${data.message}`;
    } catch {}
    throw new Error(msg);
  }
  const blob = await res.blob();
  const ct = res.headers.get("content-type") || "application/octet-stream";
  return { blob, fileName: name, contentType: ct };
}