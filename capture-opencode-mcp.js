const port = 9226;
const delay = (ms) => new Promise((resolve) => setTimeout(resolve, ms));

async function main() {
  const targets = await fetch(`http://127.0.0.1:${port}/json`).then((r) => r.json());
  const page = targets.find((target) => target.type === 'page');
  if (!page) throw new Error('OpenCode renderer target not found');
  const ws = new WebSocket(page.webSocketDebuggerUrl);
  const pending = new Map();
  let id = 0;
  let matched = null;
  const mcpRequests = new Map();
  const extraHeaders = new Map();
  ws.onmessage = (event) => {
    const message = JSON.parse(event.data);
    const waiter = pending.get(message.id);
    if (waiter) {
      pending.delete(message.id);
      message.error ? waiter.reject(new Error(message.error.message)) : waiter.resolve(message.result);
      return;
    }
    if (message.method === 'Network.responseReceived') {
      const response = message.params.response;
      try {
        const url = new URL(response.url);
        if (url.hostname === '127.0.0.1' && url.pathname === '/mcp' && response.status === 200) {
          matched = { requestId: message.params.requestId, status: response.status, url: `${url.origin}${url.pathname}` };
        }
      } catch {}
    }
    if (message.method === 'Network.requestWillBeSent') {
      try {
        const url = new URL(message.params.request.url);
        if (url.hostname === '127.0.0.1' && url.pathname === '/mcp') {
          mcpRequests.set(message.params.requestId, message.params.request.url);
        }
      } catch {}
    }
    if (message.method === 'Network.requestWillBeSentExtraInfo') {
      extraHeaders.set(message.params.requestId, message.params.headers || {});
    }
  };
  await new Promise((resolve, reject) => { ws.onopen = resolve; ws.onerror = reject; });
  const send = (method, params = {}) => new Promise((resolve, reject) => {
    const requestId = ++id;
    pending.set(requestId, { resolve, reject });
    ws.send(JSON.stringify({ id: requestId, method, params }));
  });
  await send('Network.enable');
  await send('Page.enable');
  for (let i = 0; i < 120 && !matched; i++) {
    for (const [requestId, url] of mcpRequests) {
      const headers = extraHeaders.get(requestId);
      const authorization = headers?.Authorization || headers?.authorization;
      if (!authorization) continue;
      try {
        const response = await fetch(url, { headers: { Authorization: authorization } });
        if (response.ok) {
          const data = await response.json();
          const summary = Object.fromEntries(Object.entries(data).map(([name, value]) => [name, {
            status: value?.status || value?.state || value?.type || null,
            error: value?.error || null
          }]));
          console.log(JSON.stringify({ httpStatus: response.status, serverCount: Object.keys(summary).length, summary }, null, 2));
          ws.close();
          return;
        }
      } catch {}
    }
    await delay(500);
  }
  if (!matched) throw new Error('OpenCode made no successful /mcp request after reload');
  let body = null;
  for (let i = 0; i < 20 && body == null; i++) {
    try { body = (await send('Network.getResponseBody', { requestId: matched.requestId })).body; } catch { await delay(250); }
  }
  const data = body ? JSON.parse(body) : null;
  const summary = data && typeof data === 'object'
    ? Object.fromEntries(Object.entries(data).map(([name, value]) => [name, {
        status: value?.status || value?.state || value?.type || null,
        error: value?.error || null
      }]))
    : {};
  console.log(JSON.stringify({ httpStatus: matched.status, serverCount: Object.keys(summary).length, summary }, null, 2));
  ws.close();
}

main().catch((error) => { console.error(error); process.exitCode = 1; });
