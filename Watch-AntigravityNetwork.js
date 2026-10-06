const fs = require('fs');
const path = require('path');

delete process.env.HTTP_PROXY;
delete process.env.HTTPS_PROXY;
delete process.env.ALL_PROXY;

const output = process.argv[2];
const durationSeconds = Number(process.argv[3] || 300);
if (!output) throw new Error('Usage: node Watch-AntigravityNetwork.js <output-path> [duration-seconds]');
fs.mkdirSync(path.dirname(output), { recursive: true });
fs.writeFileSync(output, `# Antigravity network watch started ${new Date().toISOString()}\n`, 'utf8');

function append(line) { fs.appendFileSync(output, `${new Date().toISOString()}\t${line}\n`, 'utf8'); }
function sanitizedUrl(value) {
  try { const u = new URL(value); return `${u.origin}${u.pathname}`; } catch { return String(value).split('?')[0]; }
}
function ids(value) {
  return [...new Set((String(value).match(/[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}/gi) || []).map(x => x.toLowerCase()))];
}

async function getPageWs() {
  const portFile = path.join(process.env.APPDATA, 'Antigravity', 'DevToolsActivePort');
  if (!fs.existsSync(portFile)) return null;
  const port = fs.readFileSync(portFile, 'utf8').trim().split(/\r?\n/)[0];
  if (!/^\d+$/.test(port)) return null;
  const response = await fetch(`http://127.0.0.1:${port}/json/list`);
  const pages = await response.json();
  return pages.find(x => x.type === 'page' && String(x.url).startsWith('https://127.0.0.1:'))?.webSocketDebuggerUrl || null;
}

async function connect() {
  const endpoint = await getPageWs();
  if (!endpoint) return false;
  append('CONNECTED');
  const ws = new WebSocket(endpoint);
  ws.onopen = () => {
    ws.send(JSON.stringify({ id: 1, method: 'Network.enable', params: { maxPostDataSize: 2048 } }));
    ws.send(JSON.stringify({ id: 2, method: 'Runtime.enable' }));
    // Capture only the clicked UI element's visible label, local href, and
    // UUID-shaped attributes before the application click handler can block
    // the renderer. It deliberately does not read conversation messages.
    ws.send(JSON.stringify({ id: 3, method: 'Runtime.evaluate', params: { expression: `(() => {
      if (window.__skAntigravityClickWatch) return 'already-installed';
      window.__skAntigravityClickWatch = true;
      document.addEventListener('pointerdown', (event) => {
        let node = event.target;
        let chosen = node;
        for (let i = 0; node && i < 8; i += 1, node = node.parentElement) {
          const label = (node.getAttribute && (node.getAttribute('aria-label') || node.getAttribute('title'))) || '';
          const text = (node.innerText || node.textContent || '').trim();
          if (label || text || node.closest?.('a')) { chosen = node; break; }
        }
        const link = chosen.closest?.('a')?.href || '';
        const label = (chosen.getAttribute?.('aria-label') || chosen.getAttribute?.('title') || chosen.innerText || chosen.textContent || '').trim().slice(0, 180);
        const attrs = [...(chosen.attributes || [])].filter(a => /id|href|data|aria|title/i.test(a.name)).map(a => a.value).join(' ');
        console.log('SK_ANTIGRAVITY_CLICK', label, link, [...new Set((attrs.match(/[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}/gi) || []))].join(','));
      }, true);
      return 'installed';
    })()`, returnByValue: true } }));
  };
  ws.onmessage = (event) => {
    let message;
    try { message = JSON.parse(event.data); } catch { return; }
    if (message.method === 'Network.requestWillBeSent') {
      const request = message.params.request || {};
      const clean = sanitizedUrl(request.url || '');
      const found = ids(`${clean}\n${request.postData || ''}`);
      if (/conversation|project|chat|history|task|session|brain|127\.0\.0\.1/i.test(clean) || found.length) {
        append(`REQUEST\t${request.method || 'GET'}\t${clean}\tUUID=${found.join(',') || '-'}`);
      }
      return;
    }
    if (message.method === 'Runtime.consoleAPICalled') {
      const values = (message.params.args || []).map(x => x.value).filter(x => typeof x === 'string');
      if (values[0] === 'SK_ANTIGRAVITY_CLICK') {
        append(`CLICK\tLABEL=${values[1] || '-'}\tHREF=${sanitizedUrl(values[2] || '')}\tUUID=${values[3] || '-'}`);
      }
    }
  };
  ws.onerror = () => append('SOCKET_ERROR');
  ws.onclose = () => append('DISCONNECTED');
  return true;
}

(async () => {
  const deadline = Date.now() + durationSeconds * 1000;
  let connected = false;
  while (Date.now() < deadline) {
    if (!connected) {
      try { connected = await connect(); } catch { append('CONNECT_RETRY'); }
    }
    await new Promise(resolve => setTimeout(resolve, 1000));
  }
  append('FINISHED');
})().catch(error => { append(`FATAL ${error.message}`); process.exitCode = 1; });
