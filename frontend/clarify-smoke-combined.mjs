// Clarify combined smoke: SSE, WebSocket, and Export
// Usage: npm run smoke:clarify-all
// Env (examples):
//   API_BASE_ALIAS=http://localhost:8081
//   AUTH_TOKEN=dev-token
//   USER_PERMS=ai.clarify
//   APPROVAL_TICKET= (optional, required for PDF/DOCX)

import { testSSE, testWS } from './clarify-smoke.mjs'
import { testExportMd, testExportPdfDocx } from './clarify-export-smoke.mjs'

async function runAll() {
  // Stream SSE
  const sse = await testSSE()
  console.log(`Clarify SSE: status=${sse.status} frames=${sse.frames} done=${sse.doneEvent} ok=${sse.ok}`)

  // Stream WS
  const ws = await testWS()
  console.log(`Clarify WS: frames=${ws.frames} done=${ws.doneEvent} ok=${ws.ok}${ws.error ? ' error='+ws.error : ''}`)

  // Export MD
  const md = await testExportMd()
  console.log(`Clarify Export MD: status=${md.status} ok=${md.ok} file=${md.data?.fileName || ''}`)

  // Export PDF/DOCX (skippable if no APPROVAL_TICKET)
  const rich = await testExportPdfDocx()
  if (rich.skipped) {
    console.log(`Clarify Export PDF/DOCX: skipped (${rich.reason})`)
  } else {
    console.log(`Clarify Export PDF: status=${rich.pdf.status} ok=${rich.pdf.ok} contentType=${rich.pdf.contentType || ''} size=${rich.pdf.size || 0}`)
    console.log(`Clarify Export DOCX: status=${rich.docx.status} ok=${rich.docx.ok} contentType=${rich.docx.contentType || ''} size=${rich.docx.size || 0}`)
  }

  const allOk = sse.ok && ws.ok && md.ok && (rich.skipped || (rich.pdf.ok && rich.docx.ok))
  if (!allOk) {
    console.error('Clarify combined smoke failed')
    process.exit(1)
  }
}

if (import.meta.url.endsWith('/clarify-smoke-combined.mjs')) {
  runAll().catch(err => { console.error('Clarify combined smoke error:', err); process.exit(1) })
}

export { runAll }