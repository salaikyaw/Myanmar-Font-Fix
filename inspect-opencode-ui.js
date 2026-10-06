const port = process.argv[2] || 9226;

async function main() {
  const targets = await fetch(`http://127.0.0.1:${port}/json`).then((response) => response.json());
  const page = targets.find((target) => target.type === 'page');
  if (!page) throw new Error('OpenCode renderer target not found');
  const socket = new WebSocket(page.webSocketDebuggerUrl);
  await new Promise((resolve, reject) => { socket.onopen = resolve; socket.onerror = reject; });
  const result = await new Promise((resolve, reject) => {
    socket.onmessage = (event) => {
      const message = JSON.parse(event.data);
      if (message.id !== 1) return;
      message.error ? reject(new Error(message.error.message)) : resolve(message.result);
    };
    socket.send(JSON.stringify({
      id: 1,
      method: 'Runtime.evaluate',
      params: {
        expression: `JSON.stringify({
          href: location.href,
          text: document.body.innerText.slice(0, 5000),
          links: Array.from(document.querySelectorAll('a')).map((a) => ({ text: a.innerText, href: a.href })).slice(0, 100),
          buttons: Array.from(document.querySelectorAll('button')).map((button) => button.innerText).filter(Boolean).slice(0, 100)
        })`,
        returnByValue: true
      }
    }));
  });
  console.log(result.result.value);
  socket.close();
}

main().catch((error) => { console.error(error); process.exitCode = 1; });
