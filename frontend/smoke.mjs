// Simple smoke test for platform endpoints
// Usage: npm run smoke
// Notes:
// - Set API_BASE to backend base (e.g., http://localhost:8081/api or http://localhost:8080/api/v1)
// - Clarify WS/SSE tests require permissions: X-User-Permissions: ai.clarify

import { randomUUID } from 'node:crypto';
import WebSocket from 'ws';

const BASE = process.env.API_BASE || 'http://localhost:8080/api/v1';
const TOKEN = process.env.AUTH_TOKEN || 'dev-token';
const PERMS = process.env.USER_PERMS || 'articles';
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

async function getArticles() {
  const res = await fetch(`${BASE}/articles`, { headers: headers() });
  return { status: res.status };
}

async function createArticle(i) {
  const res = await fetch(`${BASE}/articles`, {
    method: 'POST',
    headers: headers(),
    body: JSON.stringify({ title: `smoke-${i}`, content: 'hello' })
  });
  return { status: res.status };
}

function clarifyHeaders() {
  return {
    Authorization: `Bearer ${TOKEN}`,
    'X-User-Permissions': 'ai.clarify',
    'X-Request-Id': randomUUID(),
    'X-Forwarded-For': CLIENT_IP,
    'Content-Type': 'application/json'
  };
}

async function testClarifySSE() {
  const clarBase = process.env.API_BASE_ALIAS || BASE.replace('/api/v1', '/api');
  const url = `${clarBase}/clarify/stream?prompt=平台澄清SSE测试&language=zh-CN`;
  const res = await fetch(url, { headers: clarifyHeaders() });
  const rid = res.headers.get('X-Request-Id') || 'unknown';
  if (res.status !== 200) {
    return { ok: false, status: res.status, rid };
  }
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
      if (chunk.startsWith('data: ')) {
        dataFrames++;
      } else if (chunk.startsWith('event: done')) {
        doneEvent = true;
      }
    }
  }
  return { ok: doneEvent && dataFrames >= 3, status: res.status, rid, frames: dataFrames, doneEvent };
}

async function testClarifyWS() {
  const clarBase = process.env.API_BASE_ALIAS || BASE.replace('/api/v1', '/api');
  const url = `${clarBase.replace('http', 'ws')}/clarify/stream/ws?prompt=平台澄清WS测试&language=zh-CN`;
  const headers = clarifyHeaders();
  return await new Promise((resolve) => {
    const ws = new WebSocket(url, { headers });
    let frames = 0;
    let doneEvent = false;
    ws.on('message', (data) => {
      try {
        const obj = JSON.parse(data.toString());
        if (obj.event === 'done') doneEvent = true;
        if (obj.type) frames++;
      } catch (_) {}
    });
    ws.on('open', () => {
      // no-op
    });
    ws.on('error', (err) => {
      resolve({ ok: false, error: err.message, frames, doneEvent });
    });
    ws.on('close', () => {
      resolve({ ok: doneEvent && frames >= 3, frames, doneEvent });
    });
    // Safety timeout
    setTimeout(() => {
      try { ws.close(); } catch (_) {}
    }, Number(process.env.WS_TIMEOUT_MS || 3000));
  });
}

async function run() {
  const runs = Number(process.env.RUNS || 8);
  const concurrent = Number(process.env.CONCURRENCY || 4);
  const tasks = [];
  for (let i = 0; i < runs; i++) {
    tasks.push(i % 2 === 0 ? () => getArticles() : () => createArticle(i));
  }

  let ok = 0, limited = 0, other = 0;
  for (let i = 0; i < tasks.length; i += concurrent) {
    const batch = tasks.slice(i, i + concurrent).map(fn => fn());
    const results = await Promise.all(batch);
    for (const r of results) {
      if (r.status === 200) ok++;
      else if (r.status === 429) limited++;
      else other++;
    }
  }
  console.log(`Smoke Summary: OK=${ok} LIMITED=${limited} OTHER=${other}`);
  if (limited === 0) {
    console.warn('Warning: no 429 observed — consider tightening RATE_LIMIT_RPS/BURST or increasing concurrency');
  }

  // Clarify SSE & WS smoke
  const sse = await testClarifySSE();
  console.log(`Clarify SSE: status=${sse.status} frames=${sse.frames} done=${sse.doneEvent} ok=${sse.ok}`);
  const ws = await testClarifyWS();
  console.log(`Clarify WS: frames=${ws.frames} done=${ws.doneEvent} ok=${ws.ok}${ws.error ? ' error='+ws.error : ''}`);
  if (!sse.ok || !ws.ok) {
    throw new Error('Clarify stream smoke failed');
  }
}

run().catch(err => {
  console.error('Smoke failed:', err);
  process.exit(1);
});