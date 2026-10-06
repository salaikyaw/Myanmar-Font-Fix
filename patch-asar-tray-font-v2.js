// Update-safe app.asar repair for the two named Electron applications.
// It adds: (1) Close -> tray behaviour, (2) a visible tray menu, and
// (3) Pyidaungsu CSS on their UI surfaces.  It intentionally never edits
// account, token, MCP, Docker, or Windows-wide font settings.
const fs = require('fs');
const os = require('os');
const path = require('path');
const { execFileSync } = require('child_process');

async function loadAsar() {
  if (process.env.SK_ASAR_MODULE && fs.existsSync(process.env.SK_ASAR_MODULE)) {
    return require(process.env.SK_ASAR_MODULE);
  }
  try { return require('@electron/asar'); } catch (_) {}
  throw new Error('Cannot locate @electron/asar. Set SK_ASAR_MODULE to its lib\\asar.js path.');
}

function removeOldOpenCodePatch(text) {
  return text.replace(/\/\* sk-tray-keepalive \*\/[\s\S]*?\/\* sk-tray-keepalive-end \*\//g, '');
}

function patchOpenCode(source) {
  let text = removeOldOpenCodePatch(source)
    .replace(/\/\* sk-tray-font-v2-opencode \*\/[\s\S]*?\/\* sk-tray-font-v2-opencode-end \*\//g, '')
    .replace(
      /win\.once\("ready-to-show", \(\) => \{\s*if \(process\.argv\.includes\("--sk-start-in-tray"\)\) \{\s*__skTrayEnsure\(\);\s*win\.hide\(\);\s*\} else \{\s*win\.show\(\);\s*\}\s*\}\);/g,
      'win.once("ready-to-show", () => {\n    win.show();\n  });'
    );

  const electronImport = /import electron, \{([^}]+)\} from "electron";/;
  const importMatch = text.match(electronImport);
  if (!importMatch) throw new Error('OpenCode Electron ESM import anchor was not found.');
  if (!/(?:^|,)\s*Tray\s*(?:,|$)/.test(importMatch[1])) {
    text = text.replace(
      electronImport,
      (_all, names) => `import electron, {${names.trimEnd()}, Tray } from "electron";`
    );
  }

  const createWindowAnchor = 'function createMainWindow(id = randomUUID()) {';
  if (!text.includes(createWindowAnchor)) {
    throw new Error('OpenCode createMainWindow anchor was not found.');
  }
  const trayBlock = `/* sk-tray-font-v2-opencode */
let __skTrayRef = null;
let __skTrayAllowQuit = false;
function __skTrayRestore() {
  const win = getLastFocusedWindow() ?? BrowserWindow.getAllWindows()[0];
  if (!win || win.isDestroyed()) return;
  if (win.isMinimized()) win.restore();
  win.show();
  win.focus();
}
function __skTrayEnsure() {
  if (__skTrayRef || process.platform === "darwin") return;
  let icon = nativeImage.createFromPath(iconPath());
  if (icon.isEmpty()) icon = nativeImage.createFromPath(process.execPath);
  if (icon.isEmpty()) icon = nativeImage.createEmpty();
  __skTrayRef = new Tray(icon);
  __skTrayRef.setToolTip("OpenCode — running in tray");
  __skTrayRef.setContextMenu(Menu.buildFromTemplate([
    { label: "Open OpenCode", click: __skTrayRestore },
    { type: "separator" },
    { label: "Quit OpenCode", click: () => { __skTrayAllowQuit = true; app.quit(); } }
  ]));
  __skTrayRef.on("click", __skTrayRestore);
  __skTrayRef.on("double-click", __skTrayRestore);
}
app.on("browser-window-created", (_event, win) => {
  win.on("close", (event) => {
    if (__skTrayAllowQuit || process.platform === "darwin") return;
    event.preventDefault();
    __skTrayEnsure();
    win.hide();
  });
});
app.on("before-quit", () => { __skTrayAllowQuit = true; });
/* sk-tray-font-v2-opencode-end */
${createWindowAnchor}`;
  text = text.replace(createWindowAnchor, trayBlock);

  const showAnchor = `win.once("ready-to-show", () => {
    win.show();
  });`;
  if (!text.includes(showAnchor)) {
    throw new Error('OpenCode ready-to-show anchor was not found.');
  }
  text = text.replace(
    showAnchor,
    `win.once("ready-to-show", () => {
    if (process.argv.includes("--sk-start-in-tray")) {
      __skTrayEnsure();
      win.hide();
    } else {
      win.show();
    }
  });`
  );
  return text;
}

function patchDesktopCommander(source) {
  let text = source.replace(/\/\* sk-tray-font-v2-dc \*\/[\s\S]*?\/\* sk-tray-font-v2-dc-end \*\//g, '');
  const hiddenOption = 'show: !process.argv.includes("--sk-start-in-tray"),';
  if (!text.includes(hiddenOption)) {
    const optionAnchor = 'frame: true,\n        show: true,';
    if (!text.includes(optionAnchor)) throw new Error('DC initial visibility anchor missing');
    text = text.replace(optionAnchor, `frame: true,\n        ${hiddenOption}`);
  }
  const readyTail = '        mainWindow.show();\n    });\n    // Set the window title';
  const hiddenTail = '        if (process.argv.includes("--sk-start-in-tray")) { __skTrayEnsure(); } else { mainWindow.show(); }\n    });\n    // Set the window title';
  if (!text.includes(hiddenTail)) {
    if (!text.includes(readyTail)) throw new Error('DC ready visibility anchor missing');
    text = text.replace(readyTail, hiddenTail);
  }
  const electronImport = 'const { app, BrowserWindow, shell, screen, session, powerMonitor, clipboard, net, dialog } = require("electron");';
  if (text.includes(electronImport)) {
    text = text.replace(electronImport, 'const { app, BrowserWindow, shell, screen, session, powerMonitor, clipboard, net, dialog, Tray, Menu, nativeImage } = require("electron");');
  } else if (!text.includes('Tray, Menu, nativeImage')) {
    throw new Error('Desktop Commander Electron import anchor was not found.');
  }
  if (text.includes('sk-tray-font-v2-dc')) return text;
  const anchor = 'let mainWindow = null;';
  if (!text.includes(anchor)) throw new Error('Desktop Commander mainWindow anchor was not found.');
  const insert = `${anchor}
/* sk-tray-font-v2-dc */
let __skTrayRef = null;
let __skTrayAllowQuit = false;
const __skFontCss = 'html,body,body *:not(svg):not(path):not([class*="codicon"]):not([class*="icon-font"]),input,textarea,button,[contenteditable="true"],[role="textbox"]{font-family:"Pyidaungsu","Myanmar Text","Noto Sans Myanmar",system-ui,sans-serif!important;text-rendering:optimizeLegibility!important}pre,pre *,code,code *,kbd,kbd *,samp,samp *,.monaco-editor,.monaco-editor *,.xterm,.xterm *{font-family:"JetBrainsMono Nerd Font Mono","Cascadia Mono",Consolas,"Pyidaungsu",monospace!important}';
function __skTrayRestore() {
    if (!mainWindow || mainWindow.isDestroyed()) return;
    if (mainWindow.isMinimized()) mainWindow.restore();
    mainWindow.show();
    mainWindow.focus();
}
function __skTrayEnsure() {
    if (__skTrayRef) return;
    let icon = nativeImage.createFromPath(appIconPath);
    if (icon.isEmpty()) icon = nativeImage.createFromPath(process.execPath);
    if (icon.isEmpty()) icon = nativeImage.createEmpty();
    __skTrayRef = new Tray(icon);
    __skTrayRef.setToolTip("Desktop Commander — running in tray");
    __skTrayRef.setContextMenu(Menu.buildFromTemplate([
        { label: "Open Desktop Commander", click: __skTrayRestore },
        { type: "separator" },
        { label: "Quit Desktop Commander", click: () => { __skTrayAllowQuit = true; app.quit(); } }
    ]));
    __skTrayRef.on("click", __skTrayRestore);
}
app.on("browser-window-created", (_event, win) => {
    win.webContents.on("did-finish-load", () => { void win.webContents.insertCSS(__skFontCss).catch(() => {}); });
    win.on("close", (event) => {
        if (__skTrayAllowQuit || process.platform === "darwin") return;
        event.preventDefault();
        __skTrayEnsure();
        win.hide();
    });
});
app.on("second-instance", __skTrayRestore);
app.on("before-quit", () => { __skTrayAllowQuit = true; });
/* sk-tray-font-v2-dc-end */`;
  return text.replace(anchor, insert);
}

function patchFontHtml(html) {
  const marker = 'sk-pyidaungsu-font-fix-v2';
  if (html.includes(marker)) return html;
  const style = `<style id="${marker}">
html,body,body *:not(svg):not(path):not([class*="codicon"]):not([class*="icon-font"]),input,textarea,button,[contenteditable="true"],[role="textbox"]{font-family:"Pyidaungsu","Myanmar Text","Noto Sans Myanmar",system-ui,sans-serif!important;text-rendering:optimizeLegibility!important}
pre,pre *,code,code *,kbd,kbd *,samp,samp *,.monaco-editor,.monaco-editor *,.xterm,.xterm *{font-family:"JetBrainsMono Nerd Font Mono","Cascadia Mono",Consolas,"Pyidaungsu",monospace!important}
</style>`;
  if (!html.includes('</head>')) throw new Error('OpenCode renderer HTML has no </head> anchor.');
  return html.replace('</head>', `${style}\n</head>`);
}

async function main() {
  const [kind, archive] = process.argv.slice(2);
  if (!['opencode', 'desktopcommander'].includes(kind) || !archive) {
    throw new Error('Usage: node patch-asar-tray-font-v2.js <opencode|desktopcommander> <app.asar>');
  }
  const asar = await loadAsar();
  const work = fs.mkdtempSync(path.join(os.tmpdir(), `sk-${kind}-repair-`));
  const replacement = `${archive}.sk-new`;
  try {
    asar.extractAll(archive, work);
    const mainRel = kind === 'opencode' ? 'out\\main\\index.js' : 'dist-ts\\main.js';
    const mainFile = path.join(work, ...mainRel.split(/[\\/]+/));
    let mainText = fs.readFileSync(mainFile, 'utf8');
    mainText = kind === 'opencode' ? patchOpenCode(mainText) : patchDesktopCommander(mainText);
    fs.writeFileSync(mainFile, mainText, 'utf8');
    execFileSync(process.execPath, ['--check', mainFile], { stdio: 'pipe' });
    if (kind === 'opencode') {
      const htmlFile = path.join(work, 'out', 'renderer', 'index.html');
      fs.writeFileSync(htmlFile, patchFontHtml(fs.readFileSync(htmlFile, 'utf8')), 'utf8');
    }
    fs.rmSync(replacement, { force: true });
    await asar.createPackage(work, replacement);
    fs.copyFileSync(replacement, archive);
    console.log(`PATCHED=${kind}:${archive}`);
  } finally {
    fs.rmSync(replacement, { force: true });
    fs.rmSync(work, { recursive: true, force: true });
  }
}
main().catch((error) => { console.error(error.stack || error); process.exitCode = 1; });
