const fs = require('fs');
const path = require('path');

function usage() {
  console.error('Usage: node Export-AntigravityConversationReader.js <title> <transcript.jsonl> <output.html>');
  process.exit(2);
}

const [, , title, input, output] = process.argv;
if (!title || !input || !output) usage();

const entries = [];
let invalid = 0;
for (const line of fs.readFileSync(input, 'utf8').split(/\r?\n/)) {
  if (!line.trim()) continue;
  try {
    const row = JSON.parse(line);
    entries.push({
      index: Number(row.step_index) || entries.length + 1,
      createdAt: row.created_at || '',
      source: row.source || 'UNKNOWN',
      type: row.type || 'UNKNOWN',
      status: row.status || '',
      content: typeof row.content === 'string' ? row.content : JSON.stringify(row.content ?? ''),
    });
  } catch { invalid += 1; }
}

const payload = JSON.stringify(entries).replace(/</g, '\\u003c').replace(/>/g, '\\u003e').replace(/&/g, '\\u0026');
const safeTitle = title.replace(/[<&>]/g, '');
const html = `<!doctype html>
<html lang="en"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">
<title>${safeTitle} — recovered Antigravity conversation</title>
<style>
  :root { color-scheme: dark; font-family: Pyidaungsu, "Myanmar Text", system-ui, sans-serif; background:#111827; color:#e5e7eb; }
  body { margin:0; background:#111827; } header { position:sticky; top:0; z-index:2; padding:14px 18px; background:#172033; border-bottom:1px solid #34405a; }
  h1 { font-size:18px; margin:0 0 8px; } .sub { color:#aab7cf; font-size:13px; } .tools { display:flex; gap:8px; flex-wrap:wrap; margin-top:10px; }
  input,select,button { background:#0f172a; color:#e5e7eb; border:1px solid #45526c; border-radius:6px; padding:7px 9px; font:inherit; } input { min-width:260px; flex:1; }
  button { cursor:pointer; } button:disabled { opacity:.45; cursor:default; } main { max-width:1100px; margin:0 auto; padding:16px; } .count { color:#9fb0d0; font-size:13px; margin:0 0 12px; }
  article { background:#172033; border:1px solid #2e3a53; border-radius:8px; margin:10px 0; overflow:hidden; } .meta { padding:8px 11px; color:#b9c6de; background:#202c42; font-size:12px; display:flex; gap:10px; flex-wrap:wrap; }
  pre { margin:0; padding:12px; white-space:pre-wrap; overflow-wrap:anywhere; tab-size:2; font-family:Pyidaungsu, "Myanmar Text", "Cascadia Mono", Consolas, monospace; font-size:13px; line-height:1.45; }
  .pager { display:flex; gap:10px; justify-content:center; align-items:center; padding:14px 0 26px; } .hint { color:#93a4c5; font-size:12px; margin-top:7px; }
</style></head><body>
<header><h1>${safeTitle}</h1><div class="sub">Recovered read-only view. This page renders at most 80 entries at a time, so it does not invoke Antigravity's heavy conversation/diff renderer.</div>
<div class="tools"><select id="source"><option value="ALL">All sources</option><option value="USER_EXPLICIT">Your messages</option><option value="MODEL">Model responses</option><option value="SYSTEM">System events</option></select><input id="search" placeholder="Search recovered conversation text…"><button id="apply">Apply filter</button><button id="clear">Clear</button></div><div class="hint">Local data only. No network request is made by this reader.</div></header>
<main><div class="count" id="count"></div><section id="items"></section><div class="pager"><button id="prev">Previous</button><span id="page"></span><button id="next">Next</button></div></main>
<script id="data" type="application/json">${payload}</script>
<script>
(() => {
  const rows = JSON.parse(document.getElementById('data').textContent); const size=80;
  let filtered=rows, current=0;
  const el=id=>document.getElementById(id), items=el('items');
  function draw(){ const pages=Math.max(1,Math.ceil(filtered.length/size)); current=Math.min(current,pages-1); items.replaceChildren();
    for(const r of filtered.slice(current*size,current*size+size)){const a=document.createElement('article'),m=document.createElement('div'),p=document.createElement('pre');m.className='meta';m.textContent='#'+r.index+' · '+r.source+' · '+r.type+(r.status?' · '+r.status:'')+(r.createdAt?' · '+r.createdAt:'');p.textContent=r.content;a.append(m,p);items.append(a);}
    el('count').textContent=filtered.length+' matching entries out of '+rows.length+' recovered entries';el('page').textContent='Page '+(current+1)+' / '+pages;el('prev').disabled=current===0;el('next').disabled=current>=pages-1;
  }
  function apply(){const source=el('source').value, query=el('search').value.trim().toLocaleLowerCase();filtered=rows.filter(r=>(source==='ALL'||r.source===source)&&(!query||r.content.toLocaleLowerCase().includes(query)));current=0;draw();}
  el('apply').onclick=apply;el('clear').onclick=()=>{el('source').value='ALL';el('search').value='';apply()};el('search').addEventListener('keydown',e=>{if(e.key==='Enter')apply()});el('prev').onclick=()=>{current--;draw();scrollTo({top:0,behavior:'smooth'})};el('next').onclick=()=>{current++;draw();scrollTo({top:0,behavior:'smooth'})};draw();
})();
</script></body></html>`;

fs.mkdirSync(path.dirname(output), { recursive: true });
fs.writeFileSync(output, html, 'utf8');
console.log(JSON.stringify({ title, entries: entries.length, invalidLines: invalid, output, bytes: Buffer.byteLength(html) }));
