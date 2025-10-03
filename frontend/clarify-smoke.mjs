// Clarify SSE & WS smoke test (Node)
// Usage: npm run smoke:clarify
// Env:
// - API_BASE_ALIAS: http://localhost:8081/api (default)
// - AUTH_TOKEN: dev-token
// - USER_PERMS: ai.clarify
// - WS_TIMEOUT_MS: 3000

import { randomUUID } from 'node:crypto';
import WebSocket from 'ws';

const ALIAS = process.env.API_BASE_ALIAS || 'http://localhost:8081/api';
const TOKEN = process.env.AUTH_TOKEN || 'dev-token';
const PERMS = process.env.USER_PERMS || 'ai.clarify';
const CLIENT_IP = process.env.CLIENT_IP || '198.51.100.9';

function headers() {
  return {
    Authorization: `Bearer ${TOKEN}`,
    'X-User-Permissions': PERMS,
    'X-Request-Id': randomUUID(),
    'X-Forwarded-For': CLIENT_IP,
    'Content-Type': 'application/json'
  };
}

async function testSSE() {
  const url = `${ALIAS}/clarify/stream?prompt=clarify-sse-test&language=zh-CN`;
  const res = await fetch(url, { headers: headers() });
  const rid = res.headers.get('X-Request-Id') || 'unknown';
  if (res.status !== 200) return { ok: false, status: res.status, rid };
  const reader = res.body.getReader();
  const decoder = new TextDecoder();
  let buf = '';
  let dataFrames = 0;
  let doneEvent = false;
  while (true) {
    const { value, done } = await reader.read();
    if (done) break;
    buf += decoder.decode(value, { stream: true });
    while (true) {
      const idx = buf.indexOf('\n\n');
      if (idx === -1) break;
      const chunk = buf.slice(0, idx);
      buf = buf.slice(idx + 2);
      if (chunk.startsWith('data: ')) dataFrames++;
      else if (chunk.startsWith('event: done')) doneEvent = true;
    }
  }
  return { ok: doneEvent && dataFrames >= 3, status: res.status, rid, frames: dataFrames, doneEvent };
}

async function testWS() {
  const url = `${ALIAS.replace('http', 'ws')}/clarify/stream/ws?prompt=clarify-ws-test&language=zh-CN`;
  const hdrs = headers();
  return await new Promise((resolve) => {
    const ws = new WebSocket(url, { headers: hdrs });
    let frames = 0;
    let doneEvent = false;
    ws.on('message', (data) => {
      try {
        const obj = JSON.parse(data.toString());
        if (obj.event === 'done') doneEvent = true;
        if (obj.type) frames++;
      } catch (_) {}
    });
    ws.on('error', (err) => resolve({ ok: false, error: err.message, frames, doneEvent }));
    ws.on('close', () => resolve({ ok: doneEvent && frames >= 3, frames, doneEvent }));
    setTimeout(() => { try { ws.close(); } catch (_) {} }, Number(process.env.WS_TIMEOUT_MS || 3000));
  });
}

async function run() {
  const sse = await testSSE();
  console.log(`Clarify SSE: status=${sse.status} frames=${sse.frames} done=${sse.doneEvent} ok=${sse.ok}`);
  const ws = await testWS();
  console.log(`Clarify WS: frames=${ws.frames} done=${ws.doneEvent} ok=${ws.ok}${ws.error ? ' error='+ws.error : ''}`);
  if (!sse.ok || !ws.ok) {
    console.error('Clarify stream smoke failed');
    process.exit(1);
  }
}

if (import.meta.url.endsWith('/clarify-smoke.mjs')) {
  run().catch(err => {
    console.error('Clarify smoke error:', err);
    process.exit(1);
  });
}

export { testSSE, testWS }