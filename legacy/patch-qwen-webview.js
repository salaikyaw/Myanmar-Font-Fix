const fs = require('fs');
const os = require('os');
const path = require('path');

(async () => {
  const asar = await import('file:///C:/SK_AI/projects/Myanmar-Font-Fix/vendor/node_modules/@electron/asar/lib/asar.js');
  const archive = 'C:/Program Files/Qwen/resources/app.asar';
  const entry = 'out/renderer/index.html';
  const marker = 'sk-pyidaungsu-qwen-webview-loader';
  const css = `
    html, body, body *:not(svg):not(path):not([class*="icon"]),
    input, textarea, button, [contenteditable="true"], [role="textbox"] {
      font-family: "Pyidaungsu", "Myanmar Text", "Noto Sans Myanmar", system-ui, sans-serif !important;
      font-variant-ligatures: normal !important;
      text-rendering: optimizeLegibility !important;
    }
    pre, pre *, code, code *, kbd, kbd *, samp, samp * {
      font-family: "Cascadia Mono", Consolas, monospace !important;
    }
  `;
  const loader = `<script id="${marker}">
  (() => {
    const css = ${JSON.stringify(css)};
    const attach = (view) => {
      if (view.dataset.skPyidaungsuAttached === '1') return;
      view.dataset.skPyidaungsuAttached = '1';
      const inject = () => view.insertCSS(css).catch(() => {});
      view.addEventListener('dom-ready', inject);
      try { if (view.getURL && view.getURL()) inject(); } catch {}
    };
    const scan = () => document.querySelectorAll('webview').forEach(attach);
    new MutationObserver(scan).observe(document.documentElement, { childList: true, subtree: true });
    document.addEventListener('DOMContentLoaded', scan, { once: true });
    scan();
  })();
  </script>`;
  const work = fs.mkdtempSync(path.join(os.tmpdir(), 'sk-qwen-webview-'));
  try {
    asar.extractAll(archive, work);
    const indexPath = path.join(work, ...entry.split('/'));
    let html = fs.readFileSync(indexPath, 'utf8');
    if (!html.includes(marker)) {
      html = html.replace('</head>', `${loader}\n</head>`);
      fs.writeFileSync(indexPath, html, 'utf8');
    }
    const replacement = `${archive}.new`;
    await asar.createPackage(work, replacement);
    fs.copyFileSync(replacement, archive);
    fs.rmSync(replacement, { force: true });
    console.log(`PATCHED=${archive}`);
  } finally {
    fs.rmSync(work, { recursive: true, force: true });
  }
})().catch((error) => { console.error(error); process.exitCode = 1; });
