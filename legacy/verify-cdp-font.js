const port = Number(process.argv[2]);
if (!port) throw new Error('Usage: node verify-cdp-font.js <port>');
const delay = (ms) => new Promise((resolve) => setTimeout(resolve, ms));

async function main() {
  let page;
  for (let i = 0; i < 40 && !page; i++) {
    try {
      const targets = await fetch(`http://127.0.0.1:${port}/json`).then((r) => r.json());
      page = targets.find((target) => target.type === 'webview') || targets.find((target) => target.type === 'page');
    } catch {}
    if (!page) await delay(500);
  }
  if (!page) throw new Error(`No page on port ${port}`);
  const ws = new WebSocket(page.webSocketDebuggerUrl);
  const pending = new Map();
  let id = 0;
  ws.onmessage = (event) => {
    const message = JSON.parse(event.data);
    const waiter = pending.get(message.id);
    if (waiter) {
      pending.delete(message.id);
      message.error ? waiter.reject(new Error(message.error.message)) : waiter.resolve(message.result);
    }
  };
  await new Promise((resolve, reject) => { ws.onopen = resolve; ws.onerror = reject; });
  const send = (method, params = {}) => new Promise((resolve, reject) => {
    const requestId = ++id;
    pending.set(requestId, { resolve, reject });
    ws.send(JSON.stringify({ id: requestId, method, params }));
  });
  const expression = `(async () => {
    const leaf = [...document.querySelectorAll('body *')].find((e) => !e.children.length && /[\\u1000-\\u109f]/.test(e.textContent || ''));
    const sidecarEntry = performance.getEntriesByType('resource').find((entry) => {
      try { return new URL(entry.name).origin.startsWith('http://127.0.0.1:'); } catch { return false; }
    });
    const sidecarUrl = sidecarEntry ? new URL(sidecarEntry.name) : null;
    const sidecarOrigin = sidecarUrl?.origin || null;
    let mcpProbe = null;
    if (sidecarOrigin) {
      try {
        const headers = sidecarUrl?.username ? {
          Authorization: 'Basic ' + btoa(decodeURIComponent(sidecarUrl.username) + ':' + decodeURIComponent(sidecarUrl.password))
        } : {};
        const response = await fetch(sidecarOrigin + '/mcp', { credentials: 'include', headers });
        const data = await response.json().catch(() => null);
        mcpProbe = {
          status: response.status,
          names: data && typeof data === 'object' ? Object.keys(data) : [],
          summary: data && typeof data === 'object' ? Object.fromEntries(Object.entries(data).map(([name, value]) => [name, {
            status: value?.status || value?.state || value?.type || null,
            error: value?.error || null
          }])) : {}
        };
      } catch (error) {
        mcpProbe = { status: 'FETCH_ERROR', error: error.message };
      }
    }
    return {
      marker: !!document.getElementById('sk-pyidaungsu-font-fix'),
      bodyFont: document.body ? getComputedStyle(document.body).fontFamily : null,
      myanmarFont: leaf ? getComputedStyle(leaf).fontFamily : null,
      myanmarText: leaf ? leaf.textContent.slice(0, 80) : null,
      localStorageKeys: Object.keys(localStorage),
      sessionStorageKeys: Object.keys(sessionStorage),
      resourceOrigins: [...new Set(performance.getEntriesByType('resource').map((entry) => {
        try { return new URL(entry.name).origin; } catch { return null; }
      }).filter(Boolean))],
      mcpProbe,
      url: location.href
    };
  })()`;
  const result = await send('Runtime.evaluate', { expression, returnByValue: true, awaitPromise: true });
  console.log(JSON.stringify(result.result?.value || result, null, 2));
  ws.close();
}

main().catch((error) => { console.error(error); process.exitCode = 1; });
