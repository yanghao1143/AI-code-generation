import { describe, it, expect, vi, beforeAll } from 'vitest';
import { clarifyStreamLive, type ClarifyGenerateResponse } from '../../api/client';

function makeSseReader(chunks: string[], signal?: AbortSignal) {
  let i = 0;
  const enc = new TextEncoder();
  return {
    getReader() {
      return {
        read: async () => {
          if (signal?.aborted) {
            throw new Error('AbortError');
          }
          if (i >= chunks.length) {
            return { done: true, value: undefined };
          }
          const v = enc.encode(chunks[i++]);
          return { done: false, value: v };
        },
      };
    },
  } as unknown as ReadableStream<Uint8Array>;
}

describe('clarifyStreamLive', () => {
  beforeAll(() => {
    // Minimal localStorage & crypto mocks for Node test env
    const store = new Map<string, string>();
    store.set('authToken', 'dev-token');
    store.set('userPerms', 'ai.clarify');
    // @ts-expect-error test env globals
    globalThis.localStorage = {
      getItem: (k: string) => store.get(k) ?? null,
      setItem: (k: string, v: string) => { store.set(k, String(v)); },
      removeItem: (k: string) => { store.delete(k); },
      clear: () => { store.clear(); },
      key: (_: number) => null,
      length: 0,
    } as unknown as Storage;
    // @ts-expect-error test env globals
    globalThis.crypto = {
      randomUUID: () => `test-${Math.random().toString(16).slice(2)}`,
    } as unknown as Crypto;
  });
  it('should process requirements/design/tasks and emit done', async () => {
    const chunks = [
      // requirements
      'event: requirements\n',
      'data: {"type":"requirements","data":["req1","req2"]}\n',
      // design
      'event: design\n',
      'data: {"type":"design","data":["d1","d2","d3"]}\n',
      // tasks + done (in same chunk ok)
      'event: tasks\n',
      'data: {"type":"tasks","data":["t1"]}\n',
      'event: done\n',
      'data: ok\n',
    ];
    const fetchMock = vi.fn(async (_url: string, _init?: RequestInit) => {
      return {
        ok: true,
        body: makeSseReader(chunks),
      } as unknown as Response;
    });
    vi.stubGlobal('fetch', fetchMock);

    const events: string[] = [];
    const out = await clarifyStreamLive({ prompt: 'p', language: 'zh-CN' }, {
      onEvent: (evt, agg) => {
        events.push(evt.type);
        // sanity: agg should be ClarifyGenerateResponse
        const a = agg as ClarifyGenerateResponse;
        expect(Array.isArray(a.requirements)).toBe(true);
        expect(Array.isArray(a.design)).toBe(true);
        expect(Array.isArray(a.tasks)).toBe(true);
      },
    });

    expect(out.requirements).toEqual(['req1', 'req2']);
    expect(out.design).toEqual(['d1', 'd2', 'd3']);
    expect(out.tasks).toEqual(['t1']);
    expect(events).toContain('requirements');
    expect(events).toContain('design');
    expect(events).toContain('tasks');
    expect(events).toContain('done');
  });

  it('should emit error event and reject on non-ok response', async () => {
    const fetchMock = vi.fn(async () => {
      return {
        ok: false,
        status: 500,
        json: async () => ({ code: 'E1000', message: 'failed' }),
      } as unknown as Response;
    });
    vi.stubGlobal('fetch', fetchMock);

    const events: string[] = [];
    await expect(
      clarifyStreamLive({ prompt: 'p' }, {
        onEvent: (evt) => {
          events.push(evt.type);
          if (evt.type === 'error') {
            expect(String(evt.raw)).toContain('500 E1000 failed');
          }
        },
      })
    ).rejects.toBeTruthy();
    expect(events).toContain('error');
  });

  it('should reject when aborted mid-stream', async () => {
    const ctrl = new AbortController();
    const chunks = [
      'event: requirements\n',
      'data: {"type":"requirements","data":["r1"]}\n',
      'event: design\n',
      'data: {"type":"design","data":["d1"]}\n',
      'event: tasks\n',
      'data: {"type":"tasks","data":["t1"]}\n',
    ];
    let firstRead = true;
    const enc = new TextEncoder();
    const reader = {
      read: async () => {
        if (firstRead) {
          firstRead = false;
          return { done: false, value: enc.encode(chunks[0] + chunks[1]) };
        }
        if (ctrl.signal.aborted) throw new Error('AbortError');
        return { done: false, value: enc.encode(chunks[2] + chunks[3]) };
      },
    };
    const fetchMock = vi.fn(async () => {
      return {
        ok: true,
        body: { getReader: () => reader },
      } as unknown as Response;
    });
    vi.stubGlobal('fetch', fetchMock);

    const p = clarifyStreamLive({ prompt: 'p' }, { signal: ctrl.signal });
    // abort after scheduling
    ctrl.abort();
    await expect(p).rejects.toBeTruthy();
  });
});