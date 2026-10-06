/*
 * App-local MonkeyCode font injector.
 * Tauri pages use http://tauri.localhost/, which Chrome extensions cannot
 * content-script into.  This uses only the launcher's loopback CDP endpoint.
 */
const port = Number(process.argv[2] || 9231);
const registeredTargets = new Set();
const css = `
html, body, body *:not(svg):not(path):not([class*="icon"]), input, textarea, button, select,
[contenteditable="true"], [role="textbox"],
[class*="message"], [class*="chat"], [class*="content"] {
  font-family: "Pyidaungsu", "Myanmar Text", "Noto Sans Myanmar", system-ui, sans-serif !important;
  font-variant-ligatures: normal !important;
}
pre, pre *, code, code *, kbd, samp, .xterm, .monaco-editor,
.monaco-editor textarea, .monaco-editor input {
  font-family: "Cascadia Mono", "JetBrains Mono", Consolas, "Pyidaungsu", "Myanmar Text", monospace !important;
}
`;

const source = `(() => {
  const marker = 'sk-pyidaungsu-monkeycode-font-v4';
  const install = () => {
    if (document.getElementById(marker)) return;
    const style = document.createElement('style');
    style.id = marker;
    style.textContent = ${JSON.stringify(css)};
    (document.head || document.documentElement).appendChild(style);
  };
  install();
  document.addEventListener('DOMContentLoaded', install, { once: true });
})();`;

function call(socket, id, method, params = {}) {
  return new Promise((resolve, reject) => {
    const onMessage = (event) => {
      const message = JSON.parse(event.data);
      if (message.id !== id) return;
      socket.removeEventListener('message', onMessage);
      message.error ? reject(new Error(message.error.message)) : resolve(message.result);
    };
    socket.addEventListener('message', onMessage);
    socket.send(JSON.stringify({ id, method, params }));
  });
}

async function injectOnce() {
  const deadline = Date.now() + 5000;
  let page;
  while (Date.now() < deadline) {
    try {
      const targets = await fetch(`http://127.0.0.1:${port}/json/list`).then((r) => r.json());
      page = targets.find((target) => target.type === 'page' && target.url === 'http://tauri.localhost/')
        || targets.find((target) => target.type === 'page' && target.url.startsWith('http://tauri.localhost/') && !target.url.includes('pet.html'));
      if (page) break;
    } catch { /* MonkeyCode's renderer is still starting. */ }
    await new Promise((resolve) => setTimeout(resolve, 250));
  }
  if (!page) throw new Error('MonkeyCode Tauri renderer did not become available');

  const socket = new WebSocket(page.webSocketDebuggerUrl);
  await new Promise((resolve, reject) => { socket.onopen = resolve; socket.onerror = reject; });
  await call(socket, 1, 'Page.enable');
  if (!registeredTargets.has(page.id)) {
    await call(socket, 2, 'Page.addScriptToEvaluateOnNewDocument', { source });
    registeredTargets.add(page.id);
  }
  await call(socket, 3, 'Runtime.evaluate', { expression: source, awaitPromise: true, returnByValue: true });
  const verified = await call(socket, 4, 'Runtime.evaluate', {
    expression: "JSON.stringify({marker:!!document.getElementById('sk-pyidaungsu-monkeycode-font-v4'),body:getComputedStyle(document.body).fontFamily,input:(()=>{const e=document.querySelector('textarea,[contenteditable=\"true\"],[role=\"textbox\"]');return e?getComputedStyle(e).fontFamily:null})()})",
    returnByValue: true,
  });
  socket.close();
  return verified.result.value;
}

async function main() {
  // Keep this loop alive for the lifetime of the app.  MonkeyCode loads its
  // Tauri document after the executable starts, and can replace that document
  // when a workspace opens.  A one-shot DevTools connection loses its CSS at
  // that moment; re-applying it is deliberately idempotent via the marker.
  let last = '';
  while (true) {
    try {
      const current = await injectOnce();
      if (current !== last) {
        console.log(current);
        last = current;
      }
    } catch (error) {
      if (last !== `ERROR:${error.message}`) {
        console.error(error.message);
        last = `ERROR:${error.message}`;
      }
    }
    await new Promise((resolve) => setTimeout(resolve, 1000));
  }
}

main().catch((error) => { console.error(error.message); process.exitCode = 1; });
