const path = require('path');
const fs = require('fs');
const os = require('os');
const { pathToFileURL } = require('url');

(async () => {
  const asarModule = process.env.ASAR_MODULE || 'C:\\SK_AI\\projects\\Myanmar-Font-Fix\\vendor\\node_modules\\@electron\\asar\\lib\\asar.js';
  if (!asarModule || !fs.existsSync(asarModule)) {
    throw new Error('Set ASAR_MODULE to the installed @electron/asar lib/asar.js path.');
  }
  const asar = await import(pathToFileURL(asarModule).href);
  const asarPath = path.join(process.env.LOCALAPPDATA, 'Programs', 'antigravity', 'resources', 'app.asar');
  
  if (!fs.existsSync(asarPath)) {
    console.error('Antigravity asar not found at:', asarPath);
    process.exit(1);
  }

  const marker = 'sk-pyidaungsu-agy-v2';
  
  // Extract and check preload.js & utils.js
  const preloadBuf = asar.extractFile(asarPath, 'dist/preload.js');
  let preloadTxt = preloadBuf.toString('utf8');
  
  const utilsBuf = asar.extractFile(asarPath, 'dist/utils.js');
  let utilsTxt = utilsBuf.toString('utf8');

  const mainBuf = asar.extractFile(asarPath, 'dist/main.js');
  let mainTxt = mainBuf.toString('utf8');
  const certMarker = 'sk-antigravity-local-cert-v1';

  if (preloadTxt.includes(marker) && utilsTxt.includes(marker) && mainTxt.includes(certMarker)) {
    console.log('ALREADY_PATCHED');
    process.exit(0);
  }

  // Keep the font rule narrow.  A universal `body *` selector made every
  // virtualised chat node restyle while scrolling a long conversation, which
  // can block Antigravity's renderer.  Normal UI inherits from body; editable
  // and message/prose surfaces are explicitly covered without touching every
  // icon or code/editor node in the document.
  const css = `
    html, body {
      font-family: Pyidaungsu, "Myanmar Text", "Noto Sans Myanmar", system-ui, -apple-system, sans-serif !important;
      font-variant-ligatures: normal !important;
    }
    input, textarea, button, select, [contenteditable="true"], [role="textbox"],
    [class*="message"], [class*="chat"], [class*="markdown"], [class*="prose"] {
      font-family: Pyidaungsu, "Myanmar Text", "Noto Sans Myanmar", system-ui, -apple-system, sans-serif !important;
      font-variant-ligatures: normal !important;
    }
    pre, pre *, code, code *, .xterm, .xterm *, .monaco-editor, .monaco-editor * {
      font-family: "JetBrains Mono", "Cascadia Mono", Consolas, "Pyidaungsu", monospace !important;
    }
  `.replace(/\r?\n\s*/g, ' ').trim();

  // Inject into preload.js
  const preloadInjection = `
// ${marker}
(function() {
  function injectFont() {
    if (document.getElementById('sk-myanmar-font')) return;
    const style = document.createElement('style');
    style.id = 'sk-myanmar-font';
    style.textContent = '${css.replace(/'/g, "\\'")}';
    (document.head || document.documentElement).appendChild(style);
  }
  if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', injectFont);
  } else {
    injectFont();
  }
})();
`;

  if (!preloadTxt.includes(marker)) {
    preloadTxt = preloadTxt + '\n' + preloadInjection;
  }

  // Inject into utils.js before loadURL
  const utilsInjection = `
    // ${marker}
    const myanmarCss = '${css.replace(/'/g, "\\'")}';
    win.webContents.on('dom-ready', () => {
      win.webContents.insertCSS(myanmarCss).catch(() => {});
    });
    win.webContents.on('did-finish-load', () => {
      win.webContents.insertCSS(myanmarCss).catch(() => {});
    });
`;

  if (!utilsTxt.includes(marker)) {
    if (utilsTxt.includes('void win.loadURL(url);')) {
      utilsTxt = utilsTxt.replace('void win.loadURL(url);', utilsInjection + '\n    void win.loadURL(url);');
    }
  }

  // Antigravity's workspace is a loopback HTTPS server with a self-signed
  // certificate.  Keep the exception strictly local so the loading view is
  // removed even when Electron's session verify hook is registered late.
  if (!mainTxt.includes(certMarker)) {
    const certInjection = `
// ${certMarker}
electron_1.app.on('certificate-error', (event, _webContents, url, _error, _certificate, callback) => {
  try {
    const hostname = new URL(url).hostname;
    if (hostname === '127.0.0.1' || hostname === 'localhost') {
      event.preventDefault();
      callback(true);
      return;
    }
  } catch (_) {}
  callback(false);
});
`;
    const insertionPoint = 'const electron_1 = require("electron");';
    if (!mainTxt.includes(insertionPoint)) {
      throw new Error('Could not locate the Antigravity main-module insertion point.');
    }
    mainTxt = mainTxt.replace(insertionPoint, insertionPoint + certInjection);
  }

  const workDir = fs.mkdtempSync(path.join(os.tmpdir(), 'agy-patch-'));
  try {
    asar.extractAll(asarPath, workDir);
    fs.writeFileSync(path.join(workDir, 'dist', 'preload.js'), preloadTxt, 'utf8');
    fs.writeFileSync(path.join(workDir, 'dist', 'utils.js'), utilsTxt, 'utf8');
    fs.writeFileSync(path.join(workDir, 'dist', 'main.js'), mainTxt, 'utf8');

    const tmpAsar = asarPath + '.tmp';
    await asar.createPackageWithOptions(workDir, tmpAsar, {});
    
    // Backup original if backup path provided or in same dir
    const backupPath = process.env.AGY_BACKUP_PATH || (asarPath + '.bak');
    if (!fs.existsSync(backupPath)) {
      fs.copyFileSync(asarPath, backupPath);
    }

    fs.copyFileSync(tmpAsar, asarPath);
    fs.rmSync(tmpAsar, { force: true });
    if (fs.existsSync(tmpAsar + '.unpacked')) {
      fs.rmSync(tmpAsar + '.unpacked', { recursive: true, force: true });
    }
    console.log('PATCHED_SUCCESSFULLY');
  } finally {
    fs.rmSync(workDir, { recursive: true, force: true });
  }
})();
