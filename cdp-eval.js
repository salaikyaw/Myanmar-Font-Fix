const port = process.argv[2] || 9226;
const expression = process.argv.slice(3).join(' ') || 'document.body.innerText';

async function main() {
  const targets = await fetch(`http://127.0.0.1:${port}/json`).then((response) => response.json());
  const page = targets.find((target) => target.type === 'page' && target.url === 'http://tauri.localhost/')
    || targets.find((target) => target.type === 'page');
  if (!page) throw new Error('OpenCode renderer target not found');
  const socket = new WebSocket(page.webSocketDebuggerUrl);
  await new Promise((resolve, reject) => { socket.onopen = resolve; socket.onerror = reject; });
  const result = await new Promise((resolve, reject) => {
    socket.onmessage = (event) => {
      const message = JSON.parse(event.data);
      if (message.id !== 1) return;
      message.error ? reject(new Error(message.error.message)) : resolve(message.result);
    };
    socket.send(JSON.stringify({ id: 1, method: 'Runtime.evaluate', params: { expression, awaitPromise: true, returnByValue: true } }));
  });
  console.log(JSON.stringify(result.result.value));
  socket.close();
  setTimeout(() => process.exit(0), 50);
}

main().catch((error) => { console.error(error); process.exit(1); });
