#!/usr/bin/env node
/*
 * patch-qoder-css.cjs - Myanmar font for Qoder (Electron + React, 0.4.x)
 *
 * Why not the CDP injector: Qoder's CLI parser rejects Chromium switches
 * ("Qoder.exe: bad option: --remote-debugging-port=19440"), so the app exits
 * before it ever opens a debug port. There is nothing to attach to.
 *
 * Instead this patcher rewrites out/renderer/index.html INSIDE resources/app.asar
 * with the same byte length, so the asar header (file table, offsets) stays valid
 * and no repack is needed. The original bytes are saved next to the asar, and
 * --restore puts them back.
 *
 * Usage:
 *   node patch-qoder-css.cjs                 # patch the installed Qoder
 *   node patch-qoder-css.cjs --exe <Qoder.exe>
 *   node patch-qoder-css.cjs --asar <app.asar>   # offline / test copy
 *   node patch-qoder-css.cjs --restore
 */
const fs = require('node:fs');
const path = require('node:path');

const MARKER = 'myanmar-font-fix-v1';
const ENTRY = ['out', 'renderer', 'index.html'];

function arg(name) {
  const i = process.argv.indexOf(name);
  return i > 0 ? process.argv[i + 1] : null;
}
const restore = process.argv.includes('--restore');

function resolveAsar() {
  const explicit = arg('--asar');
  if (explicit) return path.resolve(explicit);
  const exe = arg('--exe') || path.join(process.env.LOCALAPPDATA || '', 'Programs', 'Qoder', 'Qoder.exe');
  const asar = path.join(path.dirname(path.resolve(exe)), 'resources', 'app.asar');
  if (!fs.existsSync(asar)) throw Error('Qoder app.asar not found: ' + asar);
  return asar;
}

// --- asar ------------------------------------------------------------------
// [0..3]=4, [4..7]=header pickle size, [8..11]=string size, [12..15]=json length
function readHeader(buf) {
  const jsonLen = buf.readUInt32LE(12);
  return { header: JSON.parse(buf.toString('utf8', 16, 16 + jsonLen)), base: 8 + buf.readUInt32LE(4) };
}
function node(header, parts) {
  let cur = header;
  for (const p of parts) {
    if (!cur.files || !cur.files[p]) return null;
    cur = cur.files[p];
  }
  return cur;
}

// --- html patch ------------------------------------------------------------
function minifyCss(css) {
  return css
    .replace(/\/\*[\s\S]*?\*\//g, '')
    .replace(/\s+/g, ' ')
    .replace(/\s*([{};:,])\s*/g, '$1')
    .replace(/;}/g, '}')
    .trim();
}
function compactHtml(html) {
  return html
    .replace(/<!--(?!\[if)[\s\S]*?-->/g, '')
    .replace(/>\s+</g, '><')
    .replace(/\s*\n\s*/g, ' ')
    .replace(/ {2,}/g, ' ');
}
function inject(html, styleTag) {
  if (!html.includes('</head>')) throw Error('index.html has no </head>');
  return html.replace('</head>', styleTag + '</head>');
}

function build(original, css) {
  const styleTag = '<style id="' + MARKER + '">' + css + '</style>';
  const limit = Buffer.byteLength(original, 'utf8');
  for (const candidate of [original, compactHtml(original)]) {
    const patched = inject(candidate, styleTag);
    const size = Buffer.byteLength(patched, 'utf8');
    if (size <= limit) return Buffer.from(patched + ' '.repeat(limit - size), 'utf8');
  }
  throw Error('Not enough room in index.html to inline the stylesheet');
}

function main() {
  const asarPath = resolveAsar();
  const backupPath = asarPath + '.mff-index-backup.json';
  const buf = fs.readFileSync(asarPath);
  const { header, base } = readHeader(buf);
  const entry = node(header, ENTRY);
  if (!entry || entry.files) throw Error('Entry not found in asar: ' + ENTRY.join('/'));

  const start = base + Number(entry.offset);
  const size = Number(entry.size);
  const current = buf.subarray(start, start + size);
  const currentText = current.toString('utf8');
  const patched = currentText.includes(MARKER);

  if (restore) {
    if (!patched) { console.log('Qoder: not patched, nothing to restore'); return; }
    if (!fs.existsSync(backupPath)) throw Error('Backup missing: ' + backupPath);
    const backup = JSON.parse(fs.readFileSync(backupPath, 'utf8'));
    const original = Buffer.from(backup.originalBase64, 'base64');
    if (original.length !== size) throw Error('Backup size does not match this install (app updated?)');
    fs.writeFileSync(asarPath, Buffer.concat([buf.subarray(0, start), original, buf.subarray(start + size)]));
    console.log('Qoder: original index.html restored');
    return;
  }

  if (patched) {
    console.log('Qoder: currently patched with asar marker (' + MARKER + '). Please run with --restore to keep Electron integrity intact.');
    return;
  }

  console.log('Qoder: using native-launch via Windows SystemLink (Pyidaungsu) and User settings.json.');
  console.log('In-place app.asar modification is intentionally disabled to avoid Electron integrity checksum failures.');
}

try {
  main();
} catch (error) {
  console.error('Qoder patch error: ' + error.message);
  process.exit(1);
}
