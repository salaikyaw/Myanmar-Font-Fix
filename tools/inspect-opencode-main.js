const asar = require('C:\\Users\\salai\\AppData\\Local\\npm-cache\\_npx\\4315e37b584fe5e3\\node_modules\\@electron\\asar\\lib\\asar.js');

const archive = process.argv[2] || 'C:\\Users\\salai\\AppData\\Local\\Programs\\@opencode-aidesktop\\resources\\app.asar';
const files = asar.listPackage(archive);
const candidates = files.filter((name) => /(?:main|index)\.js$/i.test(name)).slice(0, 200);
console.log(`candidates=${JSON.stringify(candidates)}`);
const mainPath = files.find((name) => /(?:^|[\\/])out[\\/]main[\\/]index\.js$/i.test(name));
if (!mainPath) throw new Error('OpenCode main index was not found in archive listing.');
const source = asar.extractFile(archive, mainPath.replace(/^[/\\]/, '')).toString('utf8');

console.log(`length=${source.length}`);
console.log(`trayMarker=${source.includes('sk-tray-font-v2-opencode')}`);
console.log(`trayImport=${/import electron, \{[^}]*\bTray\b[^}]*\} from "electron";/.test(source)}`);
console.log(`startInTray=${source.includes('--sk-start-in-tray')}`);
console.log(`prefix=${JSON.stringify(source.slice(0, 1200))}`);

const patterns = [
  'from"electron"',
  "from'electron'",
  'require("electron")',
  'BrowserWindow',
  'new BrowserWindow',
  'ready-to-show',
  'win.show()',
  'showInactive',
  'window-all-closed',
  'before-quit',
  '.on("close"',
  ".on('close'",
  'app.whenReady',
  'second-instance',
];

for (const pattern of patterns) {
  let offset = 0;
  let count = 0;
  while (count < 8) {
    const index = source.indexOf(pattern, offset);
    if (index < 0) break;
    const start = Math.max(0, index - 450);
    const end = Math.min(source.length, index + pattern.length + 700);
    console.log(`\nPATTERN=${pattern} INDEX=${index}\n${source.slice(start, end)}`);
    offset = index + pattern.length;
    count += 1;
  }
  if (count === 0) console.log(`PATTERN=${pattern} NOT_FOUND`);
}
