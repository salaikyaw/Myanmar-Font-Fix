const path = require('path');
const fs = require('fs');
const os = require('os');
const { pathToFileURL } = require('url');

const marker = 'sk-antigravity-conversation-guard-v1';
const blocked = [
  { id: '38440f63-3b9e-4888-98b7-49c3620fc595', title: 'Omniroute AWS Usage Assessment' },
  { id: 'b1131266-b48e-4c5b-9f3e-600101f37a4d', title: 'Debugging Programming Errors' },
];
function stamp() { return new Date().toISOString().replace(/[-:]/g, '').replace(/\.\d{3}Z$/, 'Z'); }

(async () => {
  const asarModule = process.env.ASAR_MODULE;
  const asarPath = process.env.AGY_ASAR || path.join(process.env.LOCALAPPDATA, 'Programs', 'antigravity', 'resources', 'app.asar');
  const backupRoot = process.env.AGY_BACKUP_ROOT;
  if (!asarModule || !fs.existsSync(asarModule)) throw new Error('ASAR_MODULE must point to @electron/asar/lib/asar.js.');
  if (!backupRoot) throw new Error('AGY_BACKUP_ROOT must be set.');
  const asar = await import(pathToFileURL(asarModule).href);
  const preloadPath = 'dist/preload.js';
  let preload = asar.extractFile(asarPath, preloadPath).toString('utf8');
  const injection = `
// ${marker}
(() => {
  const blocked = ${JSON.stringify(blocked)};
  const find = (value) => blocked.find((item) => String(value || '').includes(item.id));
  const notice = (item) => {
    if (document.getElementById('sk-antigravity-conversation-guard-notice')) return;
    const box = document.createElement('div'); box.id = 'sk-antigravity-conversation-guard-notice';
    box.textContent = '\u26a0 ' + item.title + ' is archived for safe reading. Open its recovered local HTML reader instead of this heavy Antigravity view.';
    Object.assign(box.style, {position:'fixed',zIndex:'2147483647',right:'18px',bottom:'18px',maxWidth:'440px',padding:'12px 14px',borderRadius:'8px',background:'#3b1d1d',color:'#fff',border:'1px solid #d17a7a',fontFamily:'Pyidaungsu, "Myanmar Text", system-ui, sans-serif',fontSize:'13px',boxShadow:'0 6px 24px rgba(0,0,0,.45)'});
    (document.body || document.documentElement).appendChild(box); setTimeout(() => box.remove(), 9000);
  };
  const blockEvent = (event) => {
    let node = event.target;
    for (let i=0; node && i<8; i+=1,node=node.parentElement) {
      const href = node.href || node.getAttribute?.('href') || '';
      const item = find(href);
      if (item) { event.preventDefault(); event.stopImmediatePropagation(); notice(item); return; }
      const label = (node.getAttribute?.('aria-label') || node.getAttribute?.('title') || node.innerText || '').trim();
      if (label.length > 0 && label.length < 180) { const byTitle = blocked.find((x) => label === x.title); if (byTitle) { event.preventDefault(); event.stopImmediatePropagation(); notice(byTitle); return; } }
    }
  };
  document.addEventListener('pointerdown', blockEvent, true); document.addEventListener('click', blockEvent, true);
  for (const method of ['pushState','replaceState']) { const original = history[method]; history[method] = function(...args) { const item=find(args[2]); if(item){ notice(item); return; } return original.apply(this,args); }; }
  const current = find(location.href); if (current) document.addEventListener('DOMContentLoaded', () => notice(current), {once:true});
})();
`;
  if (preload.includes(marker)) { console.log('GUARD_ALREADY_INSTALLED'); return; }
  const work = fs.mkdtempSync(path.join(os.tmpdir(), 'agy-conversation-guard-'));
  const backup = path.join(backupRoot, `${stamp()}-antigravity-conversation-guard`);
  const tmp = `${asarPath}.conversation-guard.tmp`;
  try {
    fs.mkdirSync(backup, { recursive: true }); fs.copyFileSync(asarPath, path.join(backup, 'app.asar.before-conversation-guard'));
    asar.extractAll(asarPath, work); preload += injection; fs.writeFileSync(path.join(work, preloadPath), preload, 'utf8');
    await asar.createPackageWithOptions(work, tmp, {});
    const verify = asar.extractFile(tmp, preloadPath).toString('utf8'); if (!verify.includes(marker) || !verify.includes(blocked[0].id) || !verify.includes(blocked[1].id)) throw new Error('Guard verification failed.');
    fs.copyFileSync(tmp, asarPath); console.log(`GUARD_INSTALLED backup=${backup}`);
  } finally { fs.rmSync(tmp, { force: true }); fs.rmSync(work, { recursive: true, force: true }); }
})().catch((e) => { console.error(e.stack || e.message); process.exit(1); });
