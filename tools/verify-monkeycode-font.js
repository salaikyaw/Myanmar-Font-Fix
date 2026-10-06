async function main() {
  const pages = await fetch('http://127.0.0.1:9231/json/list').then(r => r.json());
  const page = pages.find(p => p.type === 'page' && p.url === 'http://tauri.localhost/');
  if (!page) throw Error('MonkeyCode renderer missing');
  const socket = new WebSocket(page.webSocketDebuggerUrl);
  await new Promise((resolve, reject) => { socket.onopen = resolve; socket.onerror = reject; });
  const expression = `JSON.stringify({marker:!!document.getElementById('sk-pyidaungsu-monkeycode-font-v4'),fontAvailable:document.fonts.check('16px Pyidaungsu'),inputs:[...document.querySelectorAll('textarea,input,[contenteditable="true"],[role="textbox"]')].filter(e=>e.getClientRects().length).map(e=>({tag:e.tagName,font:getComputedStyle(e).fontFamily})),myanmar:[...document.querySelectorAll('body *')].filter(e=>e.getClientRects().length && [...e.childNodes].some(n=>n.nodeType===3 && /[\\u1000-\\u109f]/.test(n.textContent))).slice(0,20).map(e=>({tag:e.tagName,font:getComputedStyle(e).fontFamily}))})`;
  socket.send(JSON.stringify({id:1,method:'Runtime.evaluate',params:{expression,returnByValue:true}}));
  await new Promise(resolve => socket.onmessage = e => { const m=JSON.parse(e.data); if(m.id===1){ console.log(m.result?.result?.value || JSON.stringify(m.error)); resolve(); }});
  socket.close();
}
main().catch(e=>{console.error(e.message);process.exitCode=1});
