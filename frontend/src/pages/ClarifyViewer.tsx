import React, { useRef, useState } from "react";
import { UiButton } from "../components/UiButton";
import { FormHint } from "../components/FormHint";
import { emitToast } from "../utils/toast";
import { normalizePerms } from "../utils/permissions";
import {
  clarifyGenerate,
  clarifyToMarkdown,
  clarifyStreamLive,
  clarifyExportMarkdown,
  downloadClarifyDoc,
  getClarifyDocUrl,
  clarifyExportPdf,
  clarifyExportDocx,
  type ClarifyGenerateResponse,
} from "../api/client";

export default function ClarifyViewer() {
  const [prompt, setPrompt] = useState(
    "一个简易文章发布系统：用户可以创建、查看、编辑和删除文章；支持标签与搜索。",
  );
  const [language, setLanguage] = useState("zh-CN");
  const [loading, setLoading] = useState(false);
  const [streaming, setStreaming] = useState(false);
  const [resp, setResp] = useState<ClarifyGenerateResponse | null>(null);
  const [error, setError] = useState<string | null>(null);
  const abortRef = useRef<AbortController | null>(null);
  // SSE 进度与事件日志
  const [sseFrames, setSseFrames] = useState(0);
  const [progReq, setProgReq] = useState(0);
  const [progDesign, setProgDesign] = useState(0);
  const [progTasks, setProgTasks] = useState(0);
  const [progDone, setProgDone] = useState(false);
  const [eventLog, setEventLog] = useState<string[]>([]);
  const [exporting, setExporting] = useState(false);
  const [exportingPdf, setExportingPdf] = useState(false);
  const [exportingDocx, setExportingDocx] = useState(false);
  const [lastExportName, setLastExportName] = useState<string | null>(null);
  const [lastExportFormat, setLastExportFormat] = useState<string | null>(null);
  const [exportHistory, setExportHistory] = useState<{ fileName: string; format: string; url: string; when: number }[]>([]);
  const [approvalTicket, setApprovalTicket] = useState("");

  const pushExport = (info: { fileName?: string; format?: string }) => {
    const name = String(info.fileName || "");
    if (!name) return;
    const fmt = String(info.format || "md");
    const url = getClarifyDocUrl(name);
    setExportHistory((prev) => [{ fileName: name, format: fmt, url, when: Date.now() }, ...prev].slice(0, 20));
  };

  const onGenerate = async () => {
    setError(null);
    setLoading(true);
    try {
      const data = await clarifyGenerate({ prompt, language, useStructured: true });
      setResp(data);
      emitToast("success", "生成完成");
    } catch (err) {
      const msg = (err as Error)?.message || String(err);
      setError(msg);
      emitToast("error", msg);
    } finally {
      setLoading(false);
    }
  };

  const markdown = resp ? clarifyToMarkdown(resp, { title: prompt.slice(0, 40), language }) : "";

  const copyMarkdown = async () => {
    if (!markdown) return;
    try {
      await navigator.clipboard.writeText(markdown);
      emitToast("success", "已复制 Markdown 到剪贴板");
    } catch {
      emitToast("error", "复制失败，请手动选择复制");
    }
  };

  const onStream = async () => {
    if (streaming) return;
    setError(null);
    setResp(null);
    // 重置进度
    setSseFrames(0);
    setProgReq(0);
    setProgDesign(0);
    setProgTasks(0);
    setProgDone(false);
    setEventLog([]);
    const controller = new AbortController();
    abortRef.current = controller;
    setStreaming(true);
    try {
      await clarifyStreamLive(
        { prompt, language },
        {
          signal: controller.signal,
          onEvent: (evt, aggregate) => {
            // 累积计数（基于聚合结果长度）
            setResp({ ...aggregate });
            setProgReq((aggregate.requirements || []).length);
            setProgDesign((aggregate.design || []).length);
            setProgTasks((aggregate.tasks || []).length);
            // 帧计数（遇到类型事件即视为一帧）
            if (evt?.type) setSseFrames((n) => n + 1);
            if (evt?.type === "done") setProgDone(true);
            // 事件日志
            const tag = evt?.type || "message";
            const raw = evt?.raw ? String(evt.raw).slice(0, 180) : "";
            setEventLog((logs) => {
              const line = raw ? `${tag}: ${raw}` : tag;
              const next = [line, ...logs];
              return next.slice(0, 20);
            });
          },
        },
      );
      emitToast("success", "流式生成完成");
    } catch (err) {
      const msg = (err as Error)?.message || String(err);
      setError(msg);
      emitToast("error", msg);
    } finally {
      setStreaming(false);
      abortRef.current = null;
    }
  };

  const onCancelStream = () => {
    try {
      abortRef.current?.abort();
    } catch {}
  };

  const onRetryStream = () => {
    if (streaming) return;
    onStream();
  };

  const onClearOutput = () => {
    setResp(null);
    setError(null);
    setSseFrames(0);
    setProgReq(0);
    setProgDesign(0);
    setProgTasks(0);
    setProgDone(false);
    setEventLog([]);
  };

  const onExportBackend = async () => {
    setError(null);
    setExporting(true);
    try {
      const info = await clarifyExportMarkdown(prompt, language);
      setLastExportName(info.fileName || null);
      setLastExportFormat(info.format || null);
      pushExport(info);
      emitToast("success", `后端导出成功：${info.fileName}`);
    } catch (err) {
      const msg = (err as Error)?.message || String(err);
      setError(msg);
      emitToast("error", msg);
    } finally {
      setExporting(false);
    }
  };

  const onDownloadLatest = async () => {
    if (!lastExportName) {
      emitToast("warning", "尚无导出记录，请先执行后端导出");
      return;
    }
    try {
      const { blob, fileName } = await downloadClarifyDoc(lastExportName);
      const url = URL.createObjectURL(blob);
      const a = document.createElement("a");
      a.href = url;
      a.download = fileName || lastExportName || "clarify.md";
      document.body.appendChild(a);
      a.click();
      a.remove();
      URL.revokeObjectURL(url);
      emitToast("success", `下载完成：${fileName || lastExportName}`);
    } catch (err) {
      const msg = (err as Error)?.message || String(err);
      setError(msg);
      emitToast("error", msg);
    }
  };

  const onExportPdf = async () => {
    setError(null);
    const ticket = approvalTicket.trim();
    if (!ticket) {
      emitToast("warning", "请输入审批票据（X-Approval-Ticket）后再导出 PDF");
      return;
    }
    setExportingPdf(true);
    try {
      const info = await clarifyExportPdf(ticket);
      setLastExportName(info.fileName || null);
      setLastExportFormat(info.format || null);
      pushExport(info);
      // 导出成功后立即下载
      const { blob } = await downloadClarifyDoc(info.fileName);
      const url = URL.createObjectURL(blob);
      const a = document.createElement("a");
      a.href = url;
      a.download = info.fileName || "clarify.pdf";
      document.body.appendChild(a);
      a.click();
      a.remove();
      URL.revokeObjectURL(url);
      emitToast("success", `PDF 导出并下载完成：${info.fileName}`);
    } catch (err) {
      const msg = (err as Error)?.message || String(err);
      setError(msg);
      emitToast("error", msg);
    } finally {
      setExportingPdf(false);
    }
  };

  const onExportDocx = async () => {
    setError(null);
    const ticket = approvalTicket.trim();
    if (!ticket) {
      emitToast("warning", "请输入审批票据（X-Approval-Ticket）后再导出 Word");
      return;
    }
    setExportingDocx(true);
    try {
      const info = await clarifyExportDocx(ticket);
      setLastExportName(info.fileName || null);
      setLastExportFormat(info.format || null);
      pushExport(info);
      // 导出成功后立即下载
      const { blob } = await downloadClarifyDoc(info.fileName);
      const url = URL.createObjectURL(blob);
      const a = document.createElement("a");
      a.href = url;
      a.download = info.fileName || "clarify.docx";
      document.body.appendChild(a);
      a.click();
      a.remove();
      URL.revokeObjectURL(url);
      emitToast("success", `Word(DOCX) 导出并下载完成：${info.fileName}`);
    } catch (err) {
      const msg = (err as Error)?.message || String(err);
      setError(msg);
      emitToast("error", msg);
    } finally {
      setExportingDocx(false);
    }
  };

  const buildDownloadCurl = (name: string): string => {
    const token = localStorage.getItem("authToken") || "dev-token";
    const permsRaw = (localStorage.getItem("userPerms") || "articles").trim();
    const perms = normalizePerms(permsRaw);
    const url = getClarifyDocUrl(name);
    const reqId = (typeof crypto !== "undefined" && (crypto as any).randomUUID) ? (crypto as any).randomUUID() : String(Date.now());
    const out = name.replace(/"/g, "");
    return `curl -fL -sS \
  -H "Authorization: Bearer ${token}" \
  -H "X-User-Permissions: ${perms}" \
  -H "X-Request-Id: ${reqId}" \
  -o "${out}" \
  "${url}"`;
  };

  const onCopyCurl = async () => {
    if (!lastExportName) {
      emitToast("warning", "尚无导出记录，请先执行后端导出");
      return;
    }
    const txt = buildDownloadCurl(lastExportName);
    try {
      await navigator.clipboard.writeText(txt);
      emitToast("success", "已复制受限下载 curl 命令到剪贴板");
    } catch {
      emitToast("error", "复制失败，请手动选中复制");
    }
  };

  const onCopyCurlByName = async (name: string) => {
    const txt = buildDownloadCurl(name);
    try {
      await navigator.clipboard.writeText(txt);
      emitToast("success", "已复制受限下载 curl 命令到剪贴板");
    } catch {
      emitToast("error", "复制失败，请手动选中复制");
    }
  };

  const onDownloadByName = async (name: string) => {
    try {
      const { blob, fileName } = await downloadClarifyDoc(name);
      const url = URL.createObjectURL(blob);
      const a = document.createElement("a");
      a.href = url;
      a.download = fileName || name;
      document.body.appendChild(a);
      a.click();
      a.remove();
      URL.revokeObjectURL(url);
      emitToast("success", `下载完成：${fileName || name}`);
    } catch (err) {
      const msg = (err as Error)?.message || String(err);
      setError(msg);
      emitToast("error", msg);
    }
  };

  const downloadMarkdown = () => {
    if (!markdown) return;
    try {
      const blob = new Blob([markdown], { type: "text/markdown" });
      const url = URL.createObjectURL(blob);
      const a = document.createElement("a");
      const safeTitle = prompt.replace(/[^\w\u4e00-\u9fa5]+/g, "-").slice(0, 60) || "clarify";
      a.href = url;
      a.download = `${safeTitle}.md`;
      document.body.appendChild(a);
      a.click();
      a.remove();
      URL.revokeObjectURL(url);
      emitToast("success", "已下载 Markdown");
    } catch {
      emitToast("error", "下载失败");
    }
  };

  return (
    <div className="ui-panel">
      <h2 className="ui-title">Clarify Viewer（本地 Markdown 预览）</h2>
      <p className="ui-text">同步生成 Clarify 结果并在浏览器中转为 Markdown，支持复制与下载。</p>
      <div className="ui-row ui-row--gap-md ui-mb-md">
        <label className="ui-flex-1">
          <div className="ui-label">Prompt</div>
          <textarea
            className="ui-input"
            rows={4}
            value={prompt}
            onChange={(e) => setPrompt(e.target.value)}
            placeholder="请输入要澄清的业务或需求"
          />
        </label>
        <label>
          <div className="ui-label">Language</div>
          <select
            className="ui-input"
            value={language}
            onChange={(e) => setLanguage(e.target.value)}
          >
            <option value="zh-CN">中文（zh-CN）</option>
            <option value="en-US">English (en-US)</option>
          </select>
        </label>
      </div>

      <FormHint>
        使用前请在顶部 Permissions 中加入 <code>ai.clarify</code>；请求会附带 Authorization 与 X-User-Permissions。
      </FormHint>

      <div className="ui-row ui-row--gap-md ui-mt-md">
        <UiButton onClick={onGenerate} disabled={loading}>
          {loading ? "生成中…" : "同步生成"}
        </UiButton>
        <UiButton variant="ghost" onClick={onStream} disabled={streaming}>
          {streaming ? "流式生成中…" : "SSE 流式生成"}
        </UiButton>
        <UiButton variant="ghost" onClick={onCancelStream} disabled={!streaming}>
          取消流式
        </UiButton>
        <UiButton variant="ghost" onClick={onRetryStream} disabled={streaming}>
          重试流式
        </UiButton>
        <UiButton variant="ghost" onClick={onClearOutput}>
          清空输出
        </UiButton>
        <UiButton variant="ghost" onClick={onExportBackend} disabled={exporting}>
          {exporting ? "后端导出中…" : "后端导出 Markdown"}
        </UiButton>
        <UiButton variant="ghost" onClick={onExportPdf} disabled={exportingPdf}>
          {exportingPdf ? "导出 PDF 中…" : "导出 PDF"}
        </UiButton>
        <UiButton variant="ghost" onClick={onExportDocx} disabled={exportingDocx}>
          {exportingDocx ? "导出 Word 中…" : "导出 Word"}
        </UiButton>
        <a className="ui-btn ui-btn--ghost" href="/clarify" aria-label="跳转 Clarify 主页面">Clarify 页面</a>
        <a className="ui-btn ui-btn--ghost" href="/clarify/stream" aria-label="跳转 Clarify 流式调试">Clarify Stream</a>
        <a className="ui-btn ui-btn--ghost" href="/openapi" aria-label="查看 OpenAPI">OpenAPI 预览</a>
      </div>
      <div className="ui-text ui-mt-xs" role="status">
        状态：{streaming ? "流式生成中…" : (loading ? "生成中…" : "空闲")}（SSE 帧：{sseFrames}；Req：{progReq}，Design：{progDesign}，Tasks：{progTasks}；Done：{progDone ? "是" : "否"}）
      </div>
      {error ? <div className="ui-error ui-mt-xs" role="alert">{error}</div> : null}

      {eventLog.length > 0 && (
        <div className="ui-mt-sm" aria-label="事件日志">
          <div className="ui-subtitle">事件日志（最近 20 条）</div>
          <ul className="ui-list">
            {eventLog.map((line, i) => (
              <li key={i} className="ui-text" style={{ fontFamily: "monospace" }}>{line}</li>
            ))}
          </ul>
        </div>
      )}

      <div className="ui-mt-lg">
        <h3 className="ui-subtitle">Markdown 预览</h3>
        {resp ? (
          <>
            <div className="ui-row ui-row--gap-sm ui-mb-sm">
              <UiButton variant="ghost" onClick={copyMarkdown}>复制 Markdown</UiButton>
              <UiButton variant="ghost" onClick={downloadMarkdown}>下载 Markdown</UiButton>
            </div>
            <pre className="ui-code" style={{ maxHeight: 520, overflow: "auto" }}>{markdown}</pre>
          </>
        ) : (
          <div className="ui-text">尚无数据，请先点击同步生成</div>
        )}
      </div>

      <div className="ui-row ui-row--gap-md ui-mt-md">
        <label className="ui-flex-1">
          <div className="ui-label">Approval Ticket</div>
          <input
            className="ui-input"
            type="text"
            value={approvalTicket}
            onChange={(e) => setApprovalTicket(e.target.value)}
            placeholder="请输入审批票据（X-Approval-Ticket）以导出 PDF/DOCX"
          />
        </label>
      </div>

      {lastExportName && (
        <div className="ui-mt-md">
          <h3 className="ui-subtitle">最近后端导出</h3>
          <div className="ui-text">
            文件：<code>{lastExportName}</code>
            {lastExportFormat && (
              <span className="ui-ml-sm">（格式：<code>{lastExportFormat}</code>）</span>
            )}
          </div>
          <div className="ui-row ui-row--gap-sm ui-mt-sm">
            <UiButton variant="ghost" onClick={onDownloadLatest}>直接下载</UiButton>
            <UiButton variant="ghost" onClick={onCopyCurl}>复制 curl 下载命令</UiButton>
          </div>
        </div>
      )}

      {exportHistory.length > 0 && (
        <div className="ui-mt-md" aria-label="导出历史">
          <h3 className="ui-subtitle">导出历史</h3>
          <ul className="ui-list">
            {exportHistory.map((rec) => (
              <li key={`${rec.fileName}-${rec.when}`} className="ui-row ui-row--gap-sm ui-align-center">
                <div className="ui-flex-1">
                  <span className="ui-text">文件：</span>
                  <code>{rec.fileName}</code>
                  <span className="ui-ml-sm ui-text">格式：</span>
                  <code>{rec.format}</code>
                  <span className="ui-ml-sm ui-text">下载链接：</span>
                  <code>{rec.url}</code>
                </div>
                <div className="ui-row ui-row--gap-sm">
                  <UiButton variant="ghost" onClick={() => onDownloadByName(rec.fileName)}>直接下载</UiButton>
                  <UiButton variant="ghost" onClick={() => onCopyCurlByName(rec.fileName)}>复制 curl</UiButton>
                </div>
              </li>
            ))}
          </ul>
        </div>
      )}
    </div>
  );
}