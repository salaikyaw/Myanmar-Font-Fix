const path = require('path');
const fs = require('fs');
const os = require('os');
const { pathToFileURL } = require('url');

const marker = 'sk-antigravity-conversation-guard-v2';
const blockedIds = ['38440f63-3b9e-4888-98b7-49c3620fc595', 'b1131266-b48e-4c5b-9f3e-600101f37a4d'];
function stamp() { return new Date().toISOString().replace(/[-:]/g, '').replace(/\.\d{3}Z$/, 'Z'); }
(async () => {
  const asarModule = process.env.ASAR_MODULE;
  const asarPath = process.env.AGY_ASAR || path.join(process.env.LOCALAPPDATA, 'Programs', 'antigravity', 'resources', 'app.asar');
  const backupRoot = process.env.AGY_BACKUP_ROOT;
  if (!asarModule || !fs.existsSync(asarModule) || !backupRoot) throw new Error('ASAR_MODULE and AGY_BACKUP_ROOT are required.');
  const asar = await import(pathToFileURL(asarModule).href);
  let preload = asar.extractFile(asarPath, 'dist/preload.js').toString('utf8');
  if (preload.includes(marker)) { console.log('GUARD_V2_ALREADY_INSTALLED'); return; }
  const injection = `
// ${marker}
(() => {
  const blocked = new Set(${JSON.stringify(blockedIds)});
  let redirecting = false;
  const detect = () => [...blocked].find((id) => String(window.location.href).includes('/c/' + id));
  const recover = () => {
    const id = detect();
    if (!id || redirecting) return;
    redirecting = true;
    // A full root navigation stops the SPA before it can construct the heavy
    // review/diff view. The conversation remains untouched in its recovery
    // backup and can be read through the generated static reader.
    window.location.replace(window.location.origin + '/?archived_conversation=' + encodeURIComponent(id));
  };
  recover();
  window.addEventListener('popstate', recover, true);
  setInterval(recover, 50);
})();
`;
  const work = fs.mkdtempSync(path.join(os.tmpdir(), 'agy-conversation-guard-v2-'));
  const backup = path.join(backupRoot, `${stamp()}-antigravity-conversation-guard-v2`);
  const tmp = `${asarPath}.conversation-guard-v2.tmp`;
  try {
    fs.mkdirSync(backup, { recursive: true }); fs.copyFileSync(asarPath, path.join(backup, 'app.asar.before-conversation-guard-v2'));
    asar.extractAll(asarPath, work); preload += injection; fs.writeFileSync(path.join(work, 'dist', 'preload.js'), preload, 'utf8');
    await asar.createPackageWithOptions(work, tmp, {});
    const verify = asar.extractFile(tmp, 'dist/preload.js').toString('utf8'); if (!verify.includes(marker)) throw new Error('V2 verification failed.');
    fs.copyFileSync(tmp, asarPath); console.log(`GUARD_V2_INSTALLED backup=${backup}`);
  } finally { fs.rmSync(tmp, { force:true }); fs.rmSync(work, { recursive:true, force:true }); }
})().catch(e => { console.error(e.stack || e.message); process.exit(1); });
