import React, { useState } from "react";
import { UiButton } from "../components/UiButton";
import { FormHint } from "../components/FormHint";
import { clarifyGenerate, clarifyStream, clarifyExportMarkdown, clarifyExportPdf, clarifyExportDocx, downloadClarifyDoc, getClarifyDocUrl, type ClarifyGenerateResponse } from "../api/client";
import { normalizePerms } from "../utils/permissions";
type ExportRecord = {
  fileName: string;
  format: string;
  url: string;
  path?: string | null;
  when: number; // timestamp
};
import { emitToast } from "../utils/toast";

export default function Clarify() {
  const [prompt, setPrompt] = useState("一个简易文章发布系统：用户可以创建、查看、编辑和删除文章；支持标签与搜索。");
  const [language, setLanguage] = useState("zh-CN");
  const [loadingSync, setLoadingSync] = useState(false);
  const [loadingStream, setLoadingStream] = useState(false);
  const [result, setResult] = useState<ClarifyGenerateResponse | null>(null);
  const [error, setError] = useState<string | null>(null);
  const [exporting, setExporting] = useState(false);
  const [exportingPdf, setExportingPdf] = useState(false);
  const [exportingDocx, setExportingDocx] = useState(false);
  const [lastExportName, setLastExportName] = useState<string | null>(null);
  const [lastExportPath, setLastExportPath] = useState<string | null>(null);
  const [lastExportFormat, setLastExportFormat] = useState<string | null>(null);
  const [approvalTicket, setApprovalTicket] = useState("");
  const isBusy = loadingSync || loadingStream || exporting || exportingPdf || exportingDocx;
  const [exportHistory, setExportHistory] = useState<ExportRecord[]>([]);

  const pushExport = (info: { fileName?: string; format?: string; filePath?: string | null }) => {
    const name = String(info.fileName || "");
    if (!name) return;
    const fmt = String(info.format || "");
    const url = getClarifyDocUrl(name);
    const rec: ExportRecord = {
      fileName: name,
      format: fmt,
      url,
      path: info.filePath || null,
      when: Date.now(),
    };
    setExportHistory((prev) => [rec, ...prev].slice(0, 20));
  };

  const onSync = async () => {
    setError(null);
    setLoadingSync(true);
    try {
      const data = await clarifyGenerate({ prompt, language, useStructured: true });
      setResult(data);
    } catch (err) {
      setError((err as Error)?.message || String(err));
    } finally {
      setLoadingSync(false);
    }
  };

  const onStream = async () => {
    setError(null);
    setLoadingStream(true);
    setResult(null);
    try {
      const data = await clarifyStream({ prompt, language });
      setResult(data);
    } catch (err) {
      setError((err as Error)?.message || String(err));
    } finally {
      setLoadingStream(false);
    }
  };

  const onExport = async () => {
    setError(null);
    setExporting(true);
    try {
      const info = await clarifyExportMarkdown(prompt, language);
      setLastExportName(info.fileName || null);
      setLastExportPath(info.filePath || null);
      setLastExportFormat(info.format || null);
      pushExport(info);
      emitToast("success", `导出成功：${info.fileName}`);
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
      emitToast("warning", "尚无导出记录，请先执行导出");
      return;
    }
    try {
      const { blob, fileName } = await downloadClarifyDoc(lastExportName);
      const url = URL.createObjectURL(blob);
      const a = document.createElement("a");
      a.href = url;
      a.download = fileName || "clarify.md";
      document.body.appendChild(a);
      a.click();
      a.remove();
      URL.revokeObjectURL(url);
      emitToast("success", `下载完成：${fileName}`);
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
      setLastExportPath(info.filePath || null);
      setLastExportFormat(info.format || null);
      pushExport(info);
      // 复用下载逻辑：导出成功后立即下载
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
      setLastExportPath(info.filePath || null);
      setLastExportFormat(info.format || null);
      pushExport(info);
      // 复用下载逻辑：导出成功后立即下载
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
    const reqId = (typeof crypto !== "undefined" && crypto.randomUUID) ? crypto.randomUUID() : String(Date.now());
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
      emitToast("warning", "尚无导出记录，请先执行导出");
      return;
    }
    const txt = buildDownloadCurl(lastExportName);
    try {
      await navigator.clipboard.writeText(txt);
      emitToast("success", "已复制受限下载 curl 命令到剪贴板");
    } catch (err) {
      emitToast("error", "复制失败，请手动选中复制");
    }
  };

  const onCopyCurlByName = async (name: string) => {
    const txt = buildDownloadCurl(name);
    try {
      await navigator.clipboard.writeText(txt);
      emitToast("success", "已复制受限下载 curl 命令到剪贴板");
    } catch (err) {
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

  return (
    <div className="ui-panel">
      <h2 className="ui-title">Clarify（需求澄清）</h2>
      <p className="ui-text">输入业务描述，生成需求、设计、任务拆解，并可选择 SSE 流式返回。</p>
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
        <label className="ui-flex-1">
          <div className="ui-label">Approval Ticket</div>
          <input
            className="ui-input"
            type="text"
            value={approvalTicket}
            onChange={(e) => setApprovalTicket(e.target.value)}
            placeholder="请输入审批票据（X-Approval-Ticket）以导出 PDF"
          />
        </label>
      </div>

      <FormHint>
        使用前请在顶部 Permissions 中加入 <code>ai.clarify</code>；请求会附带 Authorization 与 X-User-Permissions。
        导出 PDF / DOCX 为受控操作，需要在此输入 <code>X-Approval-Ticket</code>。
      </FormHint>

      <div className="ui-mt-md" aria-label="Clarify 操作面板">
        <h3 className="ui-subtitle">操作面板</h3>
        <div className="ui-row ui-row--gap-md">
          <UiButton onClick={onSync} disabled={isBusy}>
            {loadingSync ? "生成中…" : "同步生成"}
          </UiButton>
          <UiButton variant="ghost" onClick={onStream} disabled={isBusy}>
            {loadingStream ? "流式生成中…" : "SSE 流式生成"}
          </UiButton>
          <UiButton variant="ghost" onClick={onExport} disabled={isBusy}>
            {exporting ? "导出中…" : "导出 Markdown"}
          </UiButton>
          <UiButton variant="ghost" onClick={onExportPdf} disabled={isBusy}>
            {exportingPdf ? "导出 PDF 中…" : "导出 PDF"}
          </UiButton>
          <UiButton variant="ghost" onClick={onExportDocx} disabled={isBusy}>
            {exportingDocx ? "导出 Word 中…" : "导出 Word"}
          </UiButton>
          <UiButton variant="ghost" onClick={onDownloadLatest} disabled={isBusy}>
            下载最近导出
          </UiButton>
          <a className="ui-btn ui-btn--ghost" href="/clarify/viewer" aria-label="跳转 Clarify Viewer">Clarify Viewer</a>
          <a className="ui-btn ui-btn--ghost" href="/openapi" aria-label="查看 OpenAPI">OpenAPI 预览</a>
        </div>
        <div className="ui-text ui-mt-xs" role="status">
          状态：{isBusy ? "运行中…" : "空闲"}
        </div>
        {error && (
          <div className="ui-error ui-mt-xs" role="alert">{error}</div>
        )}
      </div>

      {result && (
        <div className="ui-row ui-row--gap-md ui-mt-lg">
          <div className="ui-flex-1">
            <h3 className="ui-subtitle">Requirements</h3>
            <ul className="ui-list">
              {(result.requirements || []).map((r, idx) => (
                <li key={`req-${idx}`}>{r}</li>
              ))}
            </ul>
          </div>
          <div className="ui-flex-1">
            <h3 className="ui-subtitle">Design</h3>
            <ul className="ui-list">
              {(result.design || []).map((d, idx) => (
                <li key={`des-${idx}`}>{d}</li>
              ))}
            </ul>
          </div>
          <div className="ui-flex-1">
            <h3 className="ui-subtitle">Tasks</h3>
            <ul className="ui-list">
              {(result.tasks || []).map((t, idx) => (
                <li key={`task-${idx}`}>{t}</li>
              ))}
            </ul>
          </div>
        </div>
      )}

      {result?.openapi && (
        <div className="ui-mt-md">
          <h3 className="ui-subtitle">OpenAPI（片段）</h3>
          <pre className="ui-code">
            {JSON.stringify(result.openapi, null, 2)}
          </pre>
        </div>
      )}

      {lastExportName && (
        <div className="ui-mt-md">
          <h3 className="ui-subtitle">最近导出</h3>
          <div className="ui-text">
            文件：<code>{lastExportName}</code>
            {lastExportFormat && (
              <span className="ui-ml-sm">（格式：<code>{lastExportFormat}</code>）</span>
            )}
          </div>
          <div className="ui-text ui-mt-xs">
            受限下载链接（需授权）：
            <code className="ui-ml-sm">{getClarifyDocUrl(lastExportName)}</code>
          </div>
          <div className="ui-row ui-row--gap-sm ui-mt-sm">
            <UiButton variant="ghost" onClick={onDownloadLatest}>
              直接下载（使用当前登录凭证）
            </UiButton>
            <UiButton variant="ghost" onClick={onCopyCurl}>
              复制 curl 下载命令
            </UiButton>
          </div>
          {lastExportPath && (
            <div className="ui-text ui-mt-xs">服务器保存路径：<code>{lastExportPath}</code></div>
          )}
        </div>
      )}

      {exportHistory.length > 0 && (
        <div className="ui-mt-md" aria-label="导出历史">
          <h3 className="ui-subtitle">导出历史</h3>
          <ul className="ui-list">
            {exportHistory.map((rec, idx) => (
              <li key={`${rec.fileName}-${rec.when}-${idx}`} className="ui-row ui-row--gap-sm ui-align-center">
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