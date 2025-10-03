import React, { useEffect, useMemo, useRef, useState } from "react";
import { UiButton } from "../components/UiButton";
import { emitToast } from "../utils/toast";

function authHeaders() {
  const token = localStorage.getItem("authToken") || "dev-token";
  const perms = (localStorage.getItem("userPerms") || "articles").trim();
  return {
    Authorization: `Bearer ${token}`,
    "X-User-Permissions": perms,
    "X-Request-Id": (crypto as any).randomUUID?.() || String(Date.now()),
  } as Record<string, string>;
}

export default function OpenAPI() {
  const [loading, setLoading] = useState(false);
  const [spec, setSpec] = useState<any>(null);
  const [error, setError] = useState<string | null>(null);
  const [q, setQ] = useState("");
  const [tagQ, setTagQ] = useState("");

  // Try-Out panel state
  const [tryMethod, setTryMethod] = useState<string>("GET");
  const [tryPath, setTryPath] = useState<string>("");
  const [tryBody, setTryBody] = useState<string>("");
  const [sending, setSending] = useState(false);
  const [respStatus, setRespStatus] = useState<string | null>(null);
  const [respText, setRespText] = useState<string | null>(null);
  const [respError, setRespError] = useState<string | null>(null);
  const abortRef = useRef<AbortController | null>(null);
  const [respCT, setRespCT] = useState<string | null>(null);
  const [respView, setRespView] = useState<"raw" | "json">("raw");

  // Auth header editing & persistence
  const [useCustomHeaders, setUseCustomHeaders] = useState<boolean>(false);
  const [hdrAuthToken, setHdrAuthToken] = useState<string>("");
  const [hdrUserPerms, setHdrUserPerms] = useState<string>("");

  // Load persisted values
  useEffect(() => {
    try {
      const m = localStorage.getItem("openapi_try_method");
      const p = localStorage.getItem("openapi_try_path");
      const b = localStorage.getItem("openapi_try_body");
      const u = localStorage.getItem("openapi_try_use_custom_headers");
      const t = localStorage.getItem("openapi_try_authToken");
      const perms = localStorage.getItem("openapi_try_userPerms");
      if (m) setTryMethod(m);
      if (p) setTryPath(p);
      if (b) setTryBody(b);
      if (u) setUseCustomHeaders(u === "true");
      if (t) setHdrAuthToken(t);
      if (perms) setHdrUserPerms(perms);
    } catch {
      // ignore
    }
  }, []);

  // Persist on change
  useEffect(() => { try { localStorage.setItem("openapi_try_method", tryMethod); } catch {} }, [tryMethod]);
  useEffect(() => { try { localStorage.setItem("openapi_try_path", tryPath); } catch {} }, [tryPath]);
  useEffect(() => { try { localStorage.setItem("openapi_try_body", tryBody); } catch {} }, [tryBody]);
  useEffect(() => { try { localStorage.setItem("openapi_try_use_custom_headers", String(useCustomHeaders)); } catch {} }, [useCustomHeaders]);
  useEffect(() => { try { localStorage.setItem("openapi_try_authToken", hdrAuthToken); } catch {} }, [hdrAuthToken]);
  useEffect(() => { try { localStorage.setItem("openapi_try_userPerms", hdrUserPerms); } catch {} }, [hdrUserPerms]);

  const load = async () => {
    setLoading(true);
    setError(null);
    try {
      const res = await fetch("/api/v1/openapi", { headers: authHeaders() });
      const data = await res.json();
      if (!res.ok) throw new Error(`${res.status} ${data?.code || "Error"}`);
      setSpec(data?.data || data);
      emitToast("success", "OpenAPI 加载完成");
    } catch (err) {
      const msg = (err as Error)?.message || String(err);
      setError(msg);
      emitToast("error", msg);
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => { load(); }, []);

  const copyJSON = async () => {
    try {
      await navigator.clipboard.writeText(JSON.stringify(spec ?? {}, null, 2));
      emitToast("success", "已复制 OpenAPI JSON 到剪贴板");
    } catch {
      emitToast("error", "复制失败，请手动选择复制");
    }
  };

  const downloadJSON = () => {
    try {
      const blob = new Blob([JSON.stringify(spec ?? {}, null, 2)], { type: "application/json" });
      const url = URL.createObjectURL(blob);
      const a = document.createElement("a");
      a.href = url;
      a.download = "openapi.json";
      document.body.appendChild(a);
      a.click();
      a.remove();
      URL.revokeObjectURL(url);
      emitToast("success", "已下载 openapi.json");
    } catch {
      emitToast("error", "下载失败");
    }
  };

  // 过滤 paths，便于快速定位 Clarify 或其他接口
  const filteredPaths = useMemo(() => {
    const pathsObj = (spec && spec.paths) ? spec.paths : {};
    const keys = Object.keys(pathsObj || {});
    const qLower = q.trim().toLowerCase();
    const matched = qLower
      ? keys.filter((k) => k.toLowerCase().includes(qLower))
      : keys;
    const tagLower = tagQ.trim().toLowerCase();
    return matched.slice(0, 40).map((p) => {
      const schema = pathsObj[p] || {};
      // Extract operations and apply tag filter if provided
      const ops: Array<{ method: string; op: any }> = [];
      ["get", "post", "put", "delete", "patch"].forEach((m) => {
        const op = (schema as any)[m];
        if (op) {
          const tags: string[] = Array.isArray(op.tags) ? op.tags : [];
          const ok = tagLower ? tags.some((t) => t.toLowerCase().includes(tagLower)) : true;
          if (ok) ops.push({ method: m.toUpperCase(), op });
        }
      });
      return { path: p, schema, ops };
    });
  }, [spec, q, tagQ]);

  const copyFiltered = async () => {
    try {
      const obj: Record<string, any> = {};
      filteredPaths.forEach(({ path, schema }) => { obj[path] = schema; });
      await navigator.clipboard.writeText(JSON.stringify(obj, null, 2));
      emitToast("success", "已复制筛选后的 paths JSON");
    } catch {
      emitToast("error", "复制失败");
    }
  };

  function buildCurl(method: string, path: string): string {
    const token = localStorage.getItem("authToken") || "dev-token";
    const perms = (localStorage.getItem("userPerms") || "articles").trim();
    const reqId = (crypto as any).randomUUID?.() || String(Date.now());
    const url = path.startsWith("/") ? `/api/v1${path.replace(/^\/api\/v1/, "")}` : path;
    const base = `${window.location.origin}${url}`;
    const hdrs = `-H "Authorization: Bearer ${token}" \
  -H "X-User-Permissions: ${perms}" \
  -H "X-Request-Id: ${reqId}" \
  -H "Content-Type: application/json"`;
    if (method === "GET" || method === "DELETE") {
      return `curl -fL -sS -X ${method} \
  ${hdrs} \
  "${base}"`;
    }
    return `curl -fL -sS -X ${method} \
  ${hdrs} \
  -d '{"example":"payload"}' \
  "${base}"`;
  }

  const copyCurl = async (method: string, path: string) => {
    try {
      await navigator.clipboard.writeText(buildCurl(method, path));
      emitToast("success", `已复制 ${method} ${path} 的 cURL`);
    } catch {
      emitToast("error", "复制失败");
    }
  };

  // --- Try-Out helpers ---
  function getAuthValues(): { token: string; perms: string; reqId: string } {
    const token = useCustomHeaders
      ? (hdrAuthToken || "dev-token")
      : (localStorage.getItem("authToken") || "dev-token");
    const perms = useCustomHeaders
      ? (hdrUserPerms || "articles").trim()
      : (localStorage.getItem("userPerms") || "articles").trim();
    const reqId = (crypto as any).randomUUID?.() || String(Date.now());
    return { token, perms, reqId };
  }

  function buildCurlTry(method: string, path: string, body?: string): string {
    const { token, perms, reqId } = getAuthValues();
    const url = path.startsWith("/") ? `/api/v1${path.replace(/^\/api\/v1/, "")}` : path;
    const base = `${window.location.origin}${url}`;
    const hdrs = `-H "Authorization: Bearer ${token}" \
  -H "X-User-Permissions: ${perms}" \
  -H "X-Request-Id: ${reqId}" \
  -H "Content-Type: application/json"`;
    const isNoBody = method === "GET" || method === "DELETE";
    if (isNoBody || !body?.trim()) {
      return `curl -fL -sS -X ${method} \
  ${hdrs} \
  "${base}"`;
    }
    return `curl -fL -sS -X ${method} \
  ${hdrs} \
  -d '${body}' \
  "${base}"`;
  }

  const copyCurlTry = async () => {
    try {
      await navigator.clipboard.writeText(buildCurlTry(tryMethod, tryPath, tryBody));
      emitToast("success", "已复制 Try-Out 的 cURL");
    } catch {
      emitToast("error", "复制失败");
    }
  };

  const cancelTry = () => {
    if (abortRef.current) {
      abortRef.current.abort();
      emitToast("info", "已取消请求");
    }
  };

  const sendTry = async () => {
    const rawPath = tryPath.trim();
    if (!rawPath) {
      emitToast("error", "请填写路径");
      return;
    }
    const url = rawPath.startsWith("/api/v1")
      ? rawPath
      : `/api/v1${rawPath.startsWith("/") ? rawPath : `/${rawPath}`}`;
    const { token, perms, reqId } = getAuthValues();
    const headers: Record<string, string> = {
      Authorization: `Bearer ${token}`,
      "X-User-Permissions": perms,
      "X-Request-Id": reqId,
    };
    const method = tryMethod.toUpperCase();
    const isNoBody = method === "GET" || method === "DELETE";
    if (!isNoBody) headers["Content-Type"] = "application/json";
    let bodyStr: string | undefined;
    if (!isNoBody && tryBody.trim()) {
      try {
        JSON.parse(tryBody);
        bodyStr = tryBody;
      } catch {
        setRespError("请求体不是合法 JSON");
        return;
      }
    }

    setSending(true);
    setRespStatus(null);
    setRespError(null);
    setRespText(null);
    const ac = new AbortController();
    abortRef.current = ac;
    try {
      const res = await fetch(url, { method, headers, body: bodyStr, signal: ac.signal });
      const txt = await res.text();
      const ct = res.headers.get("content-type") || null;
      setRespStatus(`${res.status} ${res.statusText}`);
      setRespText(txt);
      setRespCT(ct);
      if (ct && ct.toLowerCase().includes("application/json")) setRespView("json"); else setRespView("raw");
      if (!res.ok) {
        setRespError(`HTTP ${res.status}`);
      }
      emitToast("success", "请求完成");
    } catch (err) {
      const e = err as any;
      if (e?.name === "AbortError") {
        setRespError("请求已取消");
      } else {
        setRespError((err as Error)?.message || String(err));
      }
    } finally {
      setSending(false);
    }
  };

  function renderResp(): string {
    if (!respText) return "";
    if (respView === "json") {
      try {
        const obj = JSON.parse(respText);
        return JSON.stringify(obj, null, 2);
      } catch {
        // 不是合法 JSON，回退到原始文本
        return respText;
      }
    }
    return respText;
  }

  const copyResp = async () => {
    try {
      const content = renderResp();
      if (!content) {
        emitToast("error", "暂无响应内容可复制");
        return;
      }
      await navigator.clipboard.writeText(content);
      emitToast("success", "已复制响应内容");
    } catch {
      emitToast("error", "复制失败");
    }
  };

  return (
    <div className="ui-panel">
      <h2 className="ui-title">OpenAPI 预览</h2>
      <div className="ui-row ui-row--gap-md ui-mb-md">
        <UiButton onClick={load} disabled={loading}>{loading ? "加载中…" : "刷新"}</UiButton>
        <UiButton variant="ghost" onClick={copyJSON} disabled={!spec}>复制 JSON</UiButton>
        <UiButton variant="ghost" onClick={downloadJSON} disabled={!spec}>下载 JSON</UiButton>
        <a className="ui-btn ui-btn--ghost" href="/api/v1/registry" target="_blank" rel="noreferrer">查看 Registry</a>
      </div>
      <div className="ui-row ui-row--gap-md ui-mb-md" aria-label="路径过滤">
        <label className="ui-flex-1">
          <div className="ui-label">在 paths 中搜索（例如：clarify / articles / llm）</div>
          <input
            className="ui-input"
            type="text"
            value={q}
            onChange={(e) => setQ(e.target.value)}
            placeholder="输入关键词进行过滤"
          />
        </label>
        <label className="ui-flex-1">
          <div className="ui-label">按 tag 过滤（例如：Clarify / Articles）</div>
          <input
            className="ui-input"
            type="text"
            value={tagQ}
            onChange={(e) => setTagQ(e.target.value)}
            placeholder="输入标签进行过滤"
          />
        </label>
        <UiButton variant="ghost" onClick={copyFiltered} disabled={!spec || filteredPaths.length === 0}>复制筛选 paths</UiButton>
      </div>

      {/* Try-Out 面板 */}
      <div className="ui-card ui-mb-md" aria-label="OpenAPI Try-Out">
        <div className="ui-row ui-row--gap-md">
          <label>
            <div className="ui-label">方法</div>
            <select className="ui-input" value={tryMethod} onChange={(e) => setTryMethod(e.target.value)}>
              {['GET','POST','PUT','DELETE','PATCH'].map((m) => (
                <option key={m} value={m}>{m}</option>
              ))}
            </select>
          </label>
          <label className="ui-flex-1">
            <div className="ui-label">路径（例如：/clarify/generate）</div>
            <input
              className="ui-input"
              type="text"
              value={tryPath}
              onChange={(e) => setTryPath(e.target.value)}
              placeholder="输入要请求的路径"
            />
          </label>
        </div>
        <div className="ui-mt-sm">
          <div className="ui-label">请求体（JSON，可选）</div>
          <textarea
            className="ui-input"
            rows={6}
            value={tryBody}
            onChange={(e) => setTryBody(e.target.value)}
            placeholder='例如：{"prompt":"xxx","language":"zh"}'
          />
        </div>
        <div className="ui-row ui-row--gap-md ui-mt-sm" aria-label="认证头设置">
          <label className="ui-row ui-row--gap-xs ui-align-center">
            <input
              type="checkbox"
              checked={useCustomHeaders}
              onChange={(e) => setUseCustomHeaders(e.target.checked)}
            />
            <span>使用自定义认证头</span>
          </label>
          {useCustomHeaders ? (
            <>
              <label className="ui-flex-1">
                <div className="ui-label">Auth Token（Authorization: Bearer）</div>
                <input
                  className="ui-input"
                  type="text"
                  value={hdrAuthToken}
                  onChange={(e) => setHdrAuthToken(e.target.value)}
                  placeholder="输入或粘贴 token"
                />
              </label>
              <label className="ui-flex-1">
                <div className="ui-label">User Perms（X-User-Permissions）</div>
                <input
                  className="ui-input"
                  type="text"
                  value={hdrUserPerms}
                  onChange={(e) => setHdrUserPerms(e.target.value)}
                  placeholder="例如：articles,clarify"
                />
              </label>
            </>
          ) : (
            <div className="ui-text">将使用本地存储 authToken / userPerms</div>
          )}
        </div>
        <div className="ui-row ui-row--gap-md ui-mt-sm">
          <UiButton onClick={sendTry} disabled={sending}>{sending ? "请求中…" : "发送请求"}</UiButton>
          <UiButton variant="ghost" onClick={cancelTry} disabled={!sending}>取消</UiButton>
          <UiButton variant="ghost" onClick={copyCurlTry} disabled={!tryPath}>复制 cURL</UiButton>
        </div>
        <div className="ui-mt-sm">
          {respStatus ? <div className="ui-text">状态：{respStatus}</div> : null}
          {respCT ? <div className="ui-text">内容类型：{respCT}</div> : null}
          {respError ? <div className="ui-text ui-text--danger">错误：{respError}</div> : null}
          {respText ? (
            <>
              <div className="ui-row ui-row--gap-sm ui-mb-xs">
                <UiButton variant="ghost" onClick={() => setRespView("raw")} disabled={respView === "raw"}>Raw</UiButton>
                <UiButton variant="ghost" onClick={() => setRespView("json")} disabled={respView === "json"}>JSON</UiButton>
                <UiButton variant="ghost" onClick={copyResp}>复制响应</UiButton>
              </div>
              <pre className="ui-code" style={{ maxHeight: 320, overflow: "auto" }}>{renderResp()}</pre>
            </>
          ) : (
            <div className="ui-text">响应内容将显示在此处</div>
          )}
        </div>
      </div>
      {error ? <div className="ui-text ui-text--danger">{error}</div> : null}
      <div className="ui-mt-md">
        {spec ? (
          <>
            <h3 className="ui-subtitle">筛选结果（最多展示 40 条）</h3>
            {filteredPaths.length > 0 ? (
              <ul className="ui-list">
                {filteredPaths.map(({ path, schema, ops }) => (
                  <li key={path} className="ui-mb-sm">
                    <details>
                      <summary><code>{path}</code></summary>
                      {ops && ops.length > 0 ? (
                        <ul className="ui-list ui-mt-sm">
                          {ops.map(({ method, op }) => (
                            <li key={`${path}-${method}`} className="ui-mb-xs">
                              <div className="ui-row ui-row--gap-sm ui-align-center">
                                <code>{method}</code>
                                {Array.isArray(op.tags) && op.tags.length > 0 ? (
                                  <span className="ui-ml-sm">标签：{op.tags.join(", ")}</span>
                                ) : null}
                                <UiButton variant="ghost" onClick={() => copyCurl(method, path)}>复制 cURL</UiButton>
                                <UiButton variant="ghost" onClick={() => { setTryMethod(method); setTryPath(path); emitToast("info", "已将方法与路径带入 Try-Out 面板"); }}>试用</UiButton>
                              </div>
                              {op.summary ? (
                                <div className="ui-text ui-mt-xs">{op.summary}</div>
                              ) : null}
                            </li>
                          ))}
                        </ul>
                      ) : (
                        <div className="ui-text ui-mt-xs">无匹配方法</div>
                      )}
                      <pre className="ui-code ui-mt-sm" style={{ maxHeight: 220, overflow: "auto" }}>
                        {JSON.stringify(schema, null, 2)}
                      </pre>
                    </details>
                  </li>
                ))}
              </ul>
            ) : (
              <div className="ui-text">无匹配路径</div>
            )}
            <h3 className="ui-subtitle ui-mt-md">完整 JSON</h3>
            <pre className="ui-code" style={{ maxHeight: 480, overflow: "auto" }}>{JSON.stringify(spec, null, 2)}</pre>
          </>
        ) : (
          <div className="ui-text">尚无数据</div>
        )}
      </div>
    </div>
  );
}