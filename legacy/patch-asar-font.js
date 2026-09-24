const fs = require('fs');
const os = require('os');
const path = require('path');

(async () => {
const asar = await import('file:///C:/SK_AI/projects/Myanmar-Font-Fix/vendor/node_modules/@electron/asar/lib/asar.js');

const [archive, entry, unpackDir] = process.argv.slice(2);
if (!archive || !entry) {
  throw new Error('Usage: node patch-asar-font.js <archive> <index-entry>');
}

const marker = 'sk-pyidaungsu-font-fix';
const style = `<style id="${marker}">
/* Preserve code fonts; force Pyidaungsu through app-specific UI font rules. */
html, body, body *:not(svg):not(path):not([class*="codicon"]):not([class*="icon-font"]),
input, textarea, button, [contenteditable="true"], [role="textbox"] {
  font-family: "Pyidaungsu", "Myanmar Text", "Noto Sans Myanmar", system-ui, sans-serif !important;
  font-variant-ligatures: normal !important;
  text-rendering: optimizeLegibility !important;
}
pre, pre *, code, code *, kbd, kbd *, samp, samp *, .monaco-editor, .monaco-editor *, .xterm, .xterm * {
  font-family: "JetBrainsMono Nerd Font Mono", "Cascadia Mono", Consolas, "Pyidaungsu", monospace !important;
}
</style>`;

const work = fs.mkdtempSync(path.join(os.tmpdir(), 'sk-pyidaungsu-asar-'));
try {
  asar.extractAll(archive, work);
  const indexPath = path.join(work, ...entry.split(/[\\/]+/));
  let html = fs.readFileSync(indexPath, 'utf8');
  if (!html.includes(marker)) {
    if (!html.includes('</head>')) throw new Error(`No </head> in ${entry}`);
    html = html.replace('</head>', `${style}\n</head>`);
    fs.writeFileSync(indexPath, html, 'utf8');
  }
  const replacement = `${archive}.new`;
  if (fs.existsSync(replacement)) fs.rmSync(replacement, { force: true });
  await asar.createPackageWithOptions(work, replacement, unpackDir ? { unpackDir } : {});
  fs.copyFileSync(replacement, archive);
  fs.rmSync(replacement, { force: true });
  fs.rmSync(`${replacement}.unpacked`, { recursive: true, force: true });
  console.log(`PATCHED=${archive}`);
} finally {
  fs.rmSync(work, { recursive: true, force: true });
}
})().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
