const fs = require('node:fs');
const path = require('node:path');
const [portText, app, stateDir] = process.argv.slice(2);
const port = Number(portText);
if (!Number.isInteger(port) || port < 19431 || port > 19440 || !/^[a-z]+$/.test(app)) throw Error('Invalid target');
const css = fs.readFileSync(path.join(__dirname, 'font.css'), 'utf8');
const appConfig=JSON.parse(fs.readFileSync(path.join(__dirname,'apps.json'),'utf8')).find(a=>a.id===app&&a.port===port);
if(!appConfig)throw Error('App/port mismatch');
const marker = 'myanmar-font-fix-v1';
const once=process.argv.includes('--once');
const source = `(()=>{const install=()=>{if(document.getElementById('${marker}'))return;const s=document.createElement('style');s.id='${marker}';s.textContent=${JSON.stringify(css)};(document.head||document.documentElement).appendChild(s)};install();document.addEventListener('DOMContentLoaded',install,{once:true})})()`;
let counter = 0;
function rpc(ws, method, params={}) {
  return new Promise((resolve,reject)=>{
    const id=++counter;
    const cleanup=()=>{clearTimeout(timer);ws.removeEventListener('message',receive)};
    const receive=e=>{let m;try{m=JSON.parse(e.data)}catch{return}if(m.id!==id)return;cleanup();m.error?reject(Error(m.error.message)):resolve(m.result)};
    const timer=setTimeout(()=>{cleanup();reject(Error('CDP timeout: '+method))},15000);
    ws.addEventListener('message',receive);ws.send(JSON.stringify({id,method,params}));
  });
}
const registered=new Set();
async function patch(target) {
  const u=new URL(target.webSocketDebuggerUrl);
  if (!['127.0.0.1','localhost'].includes(u.hostname) || Number(u.port)!==port) throw Error('Non-local CDP refused');
  const ws=new WebSocket(u);
  try {
    await new Promise((resolve,reject)=>{const t=setTimeout(()=>reject(Error('WebSocket timeout')),5000);ws.onopen=()=>{clearTimeout(t);resolve()};ws.onerror=()=>{clearTimeout(t);reject(Error('WebSocket failed'))}});
    if(!registered.has(target.id)){await rpc(ws,'Page.addScriptToEvaluateOnNewDocument',{source});registered.add(target.id)}
    await rpc(ws,'Runtime.evaluate',{expression:source});
    const r=await rpc(ws,'Runtime.evaluate',{expression:`(async()=>{await document.fonts.load('16px MyanmarFontFix','မြန်မာစာ');const sample=document.createElement('span');sample.textContent='မြန်မာစာ';sample.style.position='fixed';sample.style.visibility='hidden';document.body.appendChild(sample);const out={marker:!!document.getElementById('${marker}'),body:getComputedStyle(document.body).fontFamily,sample:getComputedStyle(sample).fontFamily,fontLoaded:document.fonts.check('16px MyanmarFontFix','မြန်မာစာ')};sample.remove();return out})()`,awaitPromise:true,returnByValue:true});
    if(r.exceptionDetails)throw Error('Font evaluation failed');
    return r.result.value;
  } finally {ws.close()}
}
async function main(){
  fs.mkdirSync(stateDir,{recursive:true});let lastSuccess=Date.now(),last='';
  while(Date.now()-lastSuccess<60000){
    try{
      const targets=await fetch(`http://127.0.0.1:${port}/json/list`,{signal:AbortSignal.timeout(2500)}).then(r=>r.json());
      // Only the app's local renderers; never remote login pages or embedded websites.
      const pages=targets.filter(t=>{
        if(t.type!=='page'||!t.webSocketDebuggerUrl)return false;
        if(appConfig.primaryOrigins){try{const u=new URL(t.url);return appConfig.primaryOrigins.includes(u.protocol+'//'+u.host)}catch{return false}}
        return /^(file:|app:|tauri:|https?:\/\/(tauri\.localhost|localhost|127\.0\.0\.1)([:/]|$))/.test(t.url);
      });
      const results=[];for(const page of pages)results.push(await patch(page));
      const ok=results.length>0&&results.every(r=>r.marker&&r.fontLoaded&&r.sample.includes('MyanmarFontFix'));
      if(ok)lastSuccess=Date.now();
      const record=JSON.stringify({app,ok,rendererCount:results.length,results});
      if(record!==last){fs.writeFileSync(path.join(stateDir,app+'.json'),JSON.stringify({time:new Date().toISOString(),...JSON.parse(record)},null,2));last=record}
      if(once){console.log(record);process.exitCode=ok?0:1;return}
    }catch(error){
      if(once){console.log(JSON.stringify({app,ok:false,reason:error.message}));process.exitCode=1;return}
      /* Startup/reload is retried for a bounded time; no chat contents are logged. */
    }
    await new Promise(r=>setTimeout(r,3000));
  }
  fs.writeFileSync(path.join(stateDir,app+'.json'),JSON.stringify({app,ok:false,reason:'App closed or renderer unavailable for 60 seconds',time:new Date().toISOString()}));
}
main().catch(()=>{process.exitCode=1});
