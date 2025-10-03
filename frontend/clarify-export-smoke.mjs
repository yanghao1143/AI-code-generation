// Clarify Export smoke test (Markdown + optional PDF/DOCX via Pandoc)
// Usage: npm run smoke:clarify-export
// Env:
// - API_BASE_ALIAS: http://localhost:8081/api (default)
// - AUTH_TOKEN: dev-token
// - USER_PERMS: ai.clarify
// - APPROVAL_TICKET: required for PDF/DOCX export (X-Approval-Ticket)

import { randomUUID } from 'node:crypto'

const ALIAS = process.env.API_BASE_ALIAS || 'http://localhost:8081/api'
const TOKEN = process.env.AUTH_TOKEN || 'dev-token'
const PERMS = process.env.USER_PERMS || 'ai.clarify'
const CLIENT_IP = process.env.CLIENT_IP || '198.51.100.9'
const APPROVAL_TICKET = process.env.APPROVAL_TICKET || ''
const SERVER = ALIAS.replace(/\/?api$/, '')

function headers(includeJson = true) {
  const h = {
    Authorization: `Bearer ${TOKEN}`,
    'X-User-Permissions': PERMS,
    'X-Request-Id': randomUUID(),
    'X-Forwarded-For': CLIENT_IP,
  }
  if (includeJson) h['Content-Type'] = 'application/json'
  if (APPROVAL_TICKET) h['X-Approval-Ticket'] = APPROVAL_TICKET
  return h
}

async function testExportMd() {
  const url = `${ALIAS}/clarify/export`
  const body = {
    prompt: 'clarify-export-smoke',
    language: 'zh-CN',
    format: 'md',
  }
  const res = await fetch(url, { method: 'POST', headers: headers(true), body: JSON.stringify(body) })
  const rid = res.headers.get('X-Request-Id') || 'unknown'
  let json
  try { json = await res.json() } catch (_) { json = null }
  const ok = res.status === 200 && json && ((json.code === 'OK') || json.ok === true) && json.data && json.data.fileName
  return { ok, status: res.status, rid, data: json?.data }
}

async function downloadAndCheck(path, expectedContentTypePrefix) {
  const url = path.startsWith('http') ? path : `${SERVER}${path}`
  const res = await fetch(url, { headers: headers(false) })
  const ct = res.headers.get('Content-Type') || ''
  const buf = await res.arrayBuffer()
  const size = buf.byteLength
  const ctOk = expectedContentTypePrefix ? ct.startsWith(expectedContentTypePrefix) : true
  return { ok: res.status === 200 && size > 0 && ctOk, status: res.status, size, contentType: ct }
}

async function testExportPdfDocx() {
  if (!APPROVAL_TICKET) {
    return { skipped: true, reason: 'APPROVAL_TICKET not set' }
  }
  // PDF
  const pdfRes = await fetch(`${ALIAS}/clarify/export/pdf`, { method: 'POST', headers: headers(true) })
  let pdfJson
  try { pdfJson = await pdfRes.json() } catch (_) { pdfJson = null }
  const pdfOk = pdfRes.status === 200 && pdfJson && ((pdfJson.code === 'OK') || pdfJson.ok === true) && pdfJson.data && pdfJson.data.download
  let pdfDownload = { ok: false }
  if (pdfOk) {
    pdfDownload = await downloadAndCheck(pdfJson.data.download, 'application/pdf')
  }

  // DOCX
  const docxRes = await fetch(`${ALIAS}/clarify/export/docx`, { method: 'POST', headers: headers(true) })
  let docxJson
  try { docxJson = await docxRes.json() } catch (_) { docxJson = null }
  const docxOk = docxRes.status === 200 && docxJson && ((docxJson.code === 'OK') || docxJson.ok === true) && docxJson.data && docxJson.data.download
  let docxDownload = { ok: false }
  if (docxOk) {
    docxDownload = await downloadAndCheck(docxJson.data.download, 'application/vnd.openxmlformats-officedocument.wordprocessingml.document')
  }

  return {
    skipped: false,
    pdf: { ok: pdfOk && pdfDownload.ok, status: pdfRes.status, download: pdfJson?.data?.download, contentType: pdfDownload.contentType, size: pdfDownload.size },
    docx: { ok: docxOk && docxDownload.ok, status: docxRes.status, download: docxJson?.data?.download, contentType: docxDownload.contentType, size: docxDownload.size },
  }
}

async function run() {
  const md = await testExportMd()
  console.log(`Clarify Export MD: status=${md.status} ok=${md.ok} file=${md.data?.fileName || ''}`)
  if (!md.ok) {
    console.error('Clarify export md failed');
    process.exit(1)
  }

  const rich = await testExportPdfDocx()
  if (rich.skipped) {
    console.log(`Clarify Export PDF/DOCX: skipped (${rich.reason})`)
  } else {
    console.log(`Clarify Export PDF: status=${rich.pdf.status} ok=${rich.pdf.ok} contentType=${rich.pdf.contentType || ''} size=${rich.pdf.size || 0}`)
    console.log(`Clarify Export DOCX: status=${rich.docx.status} ok=${rich.docx.ok} contentType=${rich.docx.contentType || ''} size=${rich.docx.size || 0}`)
    if (!rich.pdf.ok || !rich.docx.ok) {
      console.error('Clarify export pdf/docx failed')
      process.exit(1)
    }
  }
}

if (import.meta.url.endsWith('/clarify-export-smoke.mjs')) {
  run().catch(err => { console.error('Clarify export smoke error:', err); process.exit(1) })
}

export { testExportMd, testExportPdfDocx }