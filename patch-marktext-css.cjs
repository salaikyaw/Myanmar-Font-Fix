'use strict';
const fs = require('node:fs');
const path = require('node:path');

// MarkText rejects --remote-debugging-port (its arg parser exits with "bad option").
// Use the app's built-in customCss preference to inject font CSS permanently.
// The CSS uses a unicode-range @font-face alias so only Myanmar codepoints
// resolve to a locally installed Unicode font (Pyidaungsu, Myanmar Text, etc.).
// Latin glyphs, icons, and code fonts keep their original type.

const prefsPath = path.join(process.env.APPDATA || '', 'marktext', 'preferences.json');
const backupPath = path.join(process.env.APPDATA || '', 'marktext', 'preferences.json.bak-myanmar-font-fix');

const myanmarCss = `@font-face {
  font-family: "MyanmarFontFix";
  src: local("Pyidaungsu"), local("Myanmar Text"), local("Noto Sans Myanmar");
  unicode-range: U+1000-109F, U+A9E0-A9FF, U+AA60-AA7F;
}
html, body, p, span:not([class*="icon"]), div:not([class*="icon"]),
input, textarea, select, button, label, li, td, th, a, h1, h2, h3, h4,
[contenteditable="true"], [role="textbox"] {
  font-family: "MyanmarFontFix", "Open Sans", "Segoe UI", system-ui, sans-serif !important;
  font-variant-ligatures: normal;
}
pre, pre *, code, code *, kbd, samp {
  font-family: "MyanmarFontFix", "DejaVu Sans Mono", "Cascadia Mono", Consolas, monospace !important;
}`;

if (!fs.existsSync(prefsPath)) {
  console.error('ERROR: MarkText preferences.json not found at', prefsPath);
  console.error('Launch MarkText at least once before patching.');
  process.exit(1);
}

const prefs = JSON.parse(fs.readFileSync(prefsPath, 'utf8'));

// Backup original preferences if not already backed up
if (!fs.existsSync(backupPath)) {
  fs.copyFileSync(prefsPath, backupPath);
  console.log('Backup created:', backupPath);
}

prefs.customCss = myanmarCss;

fs.writeFileSync(prefsPath, JSON.stringify(prefs, null, '\t'), 'utf8');
console.log('SUCCESS: preferences.json updated with Myanmar font CSS');
