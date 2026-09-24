const path = require('path');
const fs = require('fs');
const os = require('os');
const { pathToFileURL } = require('url');

const marker = 'sk-pyidaungsu-agy-v2';
const oldCss = 'html, body, body *:not(svg):not(path):not([class*="codicon"]):not([class*="icon"]):not(i) { font-family: Pyidaungsu, "Myanmar Text", "Noto Sans Myanmar", system-ui, -apple-system, sans-serif !important; font-variant-ligatures: normal !important; } pre, pre *, code, code *, .xterm, .xterm * { font-family: "JetBrains Mono", "Cascadia Mono", Consolas, "Pyidaungsu", monospace !important; }';
const lightCss = 'html, body { font-family: Pyidaungsu, "Myanmar Text", "Noto Sans Myanmar", system-ui, -apple-system, sans-serif !important; font-variant-ligatures: normal !important; } input, textarea, button, select, [contenteditable="true"], [role="textbox"], [class*="message"], [class*="chat"], [class*="markdown"], [class*="prose"] { font-family: Pyidaungsu, "Myanmar Text", "Noto Sans Myanmar", system-ui, -apple-system, sans-serif !important; font-variant-ligatures: normal !important; } pre, pre *, code, code *, .xterm, .xterm *, .monaco-editor, .monaco-editor * { font-family: "JetBrains Mono", "Cascadia Mono", Consolas, "Pyidaungsu", monospace !important; }';

function timestamp() {
  const d = new Date();
  const p = (n) => String(n).padStart(2, '0');
  return `${d.getFullYear()}${p(d.getMonth() + 1)}${p(d.getDate())}-${p(d.getHours())}${p(d.getMinutes())}${p(d.getSeconds())}`;
}

(async () => {
  const asarModule = process.env.ASAR_MODULE;
  const asarPath = process.env.AGY_ASAR || path.join(process.env.LOCALAPPDATA, 'Programs', 'antigravity', 'resources', 'app.asar');
  const backupRoot = process.env.AGY_BACKUP_ROOT;
  if (!asarModule || !fs.existsSync(asarModule)) throw new Error('ASAR_MODULE must point to @electron/asar/lib/asar.js.');
  if (!backupRoot) throw new Error('AGY_BACKUP_ROOT must be set.');
  if (!fs.existsSync(asarPath)) throw new Error(`Antigravity archive not found: ${asarPath}`);

  const asar = await import(pathToFileURL(asarModule).href);
  const preload = asar.extractFile(asarPath, 'dist/preload.js').toString('utf8');
  const utils = asar.extractFile(asarPath, 'dist/utils.js').toString('utf8');
  if (!preload.includes(marker) || !utils.includes(marker)) throw new Error('Expected existing Antigravity font patch markers were not found; no change was made.');
  if (!preload.includes(oldCss) || !utils.includes(oldCss)) throw new Error('Expected broad font CSS was not found; no change was made.');

  const workDir = fs.mkdtempSync(path.join(os.tmpdir(), 'agy-font-performance-'));
  const backupDir = path.join(backupRoot, `${timestamp()}-antigravity-font-performance`);
  const tmpAsar = `${asarPath}.font-performance.tmp`;
  try {
    fs.mkdirSync(backupDir, { recursive: true });
    fs.copyFileSync(asarPath, path.join(backupDir, 'app.asar.before-font-performance-fix'));
    asar.extractAll(asarPath, workDir);
    fs.writeFileSync(path.join(workDir, 'dist', 'preload.js'), preload.replace(oldCss, lightCss), 'utf8');
    fs.writeFileSync(path.join(workDir, 'dist', 'utils.js'), utils.replace(oldCss, lightCss), 'utf8');
    await asar.createPackageWithOptions(workDir, tmpAsar, {});
    const checkPreload = asar.extractFile(tmpAsar, 'dist/preload.js').toString('utf8');
    const checkUtils = asar.extractFile(tmpAsar, 'dist/utils.js').toString('utf8');
    if (!checkPreload.includes(lightCss) || !checkUtils.includes(lightCss) || checkPreload.includes(oldCss) || checkUtils.includes(oldCss)) {
      throw new Error('Rebuilt archive did not pass font-rule verification.');
    }
    fs.copyFileSync(tmpAsar, asarPath);
    console.log(`FONT_PERFORMANCE_PATCHED backup=${backupDir}`);
  } finally {
    fs.rmSync(tmpAsar, { force: true });
    fs.rmSync(workDir, { recursive: true, force: true });
  }
})().catch((error) => {
  console.error(error.stack || error.message || String(error));
  process.exit(1);
});
