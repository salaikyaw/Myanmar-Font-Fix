const fs = require('fs');
const statusPath = 'C:/SK_AI/projects/Myanmar-Font-Fix/legacy/jan-font-status.json';
const port = 9223;

const css = `
  html, body, body *:not(svg):not(path):not([class*="codicon"]):not([class*="icon-font"]),
  input, textarea, button, [contenteditable="true"], [role="textbox"] {
    font-family: "Pyidaungsu", "Myanmar Text", "Noto Sans Myanmar", system-ui, sans-serif !important;
    font-variant-ligatures: normal !important;
    text-rendering: optimizeLegibility !important;
  }
  pre, pre *, code, code *, kbd, kbd *, samp, samp * {
    font-family: "Cascadia Mono", Consolas, monospace !important;
  }
`;

const source = `(() => {
  const marker = 'sk-pyidaungsu-font-fix';
  const install = () => {
    let style = document.getElementById(marker);
    if (!style) {
      style = document.createElement('style');
      style.id = marker;
      (document.head || document.documentElement).appendChild(style);
    }
    style.textContent = ${JSON.stringify(css)};
  };
  install();
  document.addEventListener('DOMContentLoaded', install, { once: true });
  return {
    marker: !!document.getElementById(marker),
    bodyFont: document.body ? getComputedStyle(document.body).fontFamily : null,
    url: location.href
  };
})()`;

const delay = (ms) => new Promise((resolve) => setTimeout(resolve, ms));

async function findPage() {
  for (let i = 0; i < 60; i++) {
    try {
      const targets = await fetch(`http://127.0.0.1:${port}/json`).then((r) => r.json());
      const page = targets.find((target) => target.type === 'page' && /^http:\/\/tauri\.localhost\//.test(target.url));
      if (page) return page;
    } catch {}
    await delay(500);
  }
  throw new Error('Jan DevTools page was not found');
}

async function main() {
  const page = await findPage();
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
  await new Promise((resolve, reject) => {
    ws.onopen = resolve;
    ws.onerror = reject;
  });
  const send = (method, params = {}) => new Promise((resolve, reject) => {
    const requestId = ++id;
    pending.set(requestId, { resolve, reject });
    ws.send(JSON.stringify({ id: requestId, method, params }));
  });
  await send('Page.enable');
  await send('Page.addScriptToEvaluateOnNewDocument', { source });
  const result = await send('Runtime.evaluate', { expression: source, returnByValue: true });
  if (result.exceptionDetails) {
    throw new Error(result.exceptionDetails.exception?.description || result.exceptionDetails.text || 'Jan CSS injection failed');
  }
  const value = result.result?.value || {};
  fs.writeFileSync(statusPath, JSON.stringify({ ok: value.marker === true, ...value, resultType: result.result?.type, checkedAt: new Date().toISOString() }, null, 2));
  ws.close();
}

main().catch((error) => {
  fs.writeFileSync(statusPath, JSON.stringify({ ok: false, error: error.message, checkedAt: new Date().toISOString() }, null, 2));
  process.exitCode = 1;
});
