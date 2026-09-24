const fs = require('fs');
const path = require('path');
const { pathToFileURL } = require('url');

const asarModule = 'C:\\SK_AI\\projects\\Myanmar-Font-Fix\\vendor\\node_modules\\@electron\\asar\\lib\\asar.js';

async function checkStatus() {
  const status = {
    antigravity: { installed: false, patched: false, path: '' },
    opencode: { installed: false, patched: false, path: '' },
    jan: { installed: false, patched: false, path: '' },
    desktopcommander: { installed: false, patched: false, path: '' },
    monkeycode: { installed: false, patched: false, path: '' },
    vscode: { installed: false, patched: false, path: '' },
    zed: { installed: false, patched: false, path: '' }
  };

  try {
    if (!fs.existsSync(asarModule)) {
      console.log(JSON.stringify({ error: 'ASAR module not found' }));
      return;
    }
    const asar = await import(pathToFileURL(asarModule).href);

    // 1. Antigravity
    const agyAsar = path.join(process.env.LOCALAPPDATA, 'Programs', 'antigravity', 'resources', 'app.asar');
    status.antigravity.path = agyAsar;
    if (fs.existsSync(agyAsar)) {
      status.antigravity.installed = true;
      try {
        const preload = asar.extractFile(agyAsar, 'dist/preload.js').toString('utf8');
        const utils = asar.extractFile(agyAsar, 'dist/utils.js').toString('utf8');
        const main = asar.extractFile(agyAsar, 'dist/main.js').toString('utf8');
        status.antigravity.patched = preload.includes('sk-pyidaungsu-agy-v2') &&
                                     utils.includes('sk-pyidaungsu-agy-v2') &&
                                     main.includes('sk-antigravity-local-cert-v1');
      } catch (e) {
        status.antigravity.patched = false;
      }
    }

    // 2. OpenCode
    const opencodeAsar = path.join(process.env.LOCALAPPDATA, 'Programs', '@opencode-aidesktop', 'resources', 'app.asar');
    status.opencode.path = opencodeAsar;
    if (fs.existsSync(opencodeAsar)) {
      status.opencode.installed = true;
      try {
        const html = asar.extractFile(opencodeAsar, path.join('out', 'renderer', 'index.html')).toString('utf8');
        status.opencode.patched = html.includes('sk-pyidaungsu-font-fix');
      } catch (e) {
        status.opencode.patched = false;
      }
    }

    // 3. Jan
    const janExe = path.join(process.env.LOCALAPPDATA, 'Programs', 'Jan', 'Jan.exe');
    const janLauncher = path.join(__dirname, 'launch-jan-pyidaungsu.vbs');
    const janStatus = path.join(__dirname, 'jan-font-status.json');
    status.jan.path = janExe;
    if (fs.existsSync(janExe)) {
      status.jan.installed = true;
      try {
        const live = fs.existsSync(janStatus) ? JSON.parse(fs.readFileSync(janStatus, 'utf8')) : {};
        status.jan.patched = fs.existsSync(janLauncher);
        status.jan.liveVerified = live.ok === true && /Pyidaungsu/i.test(live.bodyFont || '');
      } catch (e) {
        status.jan.patched = fs.existsSync(janLauncher);
      }
    }

    // 4. Desktop Commander
    const dcAsar = path.join(process.env.LOCALAPPDATA, 'Programs', 'Desktop Commander Pyidaungsu', 'resources', 'app.asar');
    status.desktopcommander.path = dcAsar;
    if (fs.existsSync(dcAsar)) {
      status.desktopcommander.installed = true;
      try {
        const main = asar.extractFile(dcAsar, 'dist-ts/main.js').toString('utf8');
        status.desktopcommander.patched = main.includes('Pyidaungsu');
      } catch (e) {
        status.desktopcommander.patched = false;
      }
    }

    // 5. MonkeyCode & MonkeysCode IDE
    const monkeyExe = path.join(process.env.LOCALAPPDATA, 'MonkeyCode', 'monkeycode-desktop.exe');
    const monkeysIdeCss = path.join(process.env.LOCALAPPDATA, 'Programs', 'MonkeysCode', 'resources', 'app', 'out', 'vs', 'workbench', 'workbench.desktop.main.css');
    status.monkeycode.path = fs.existsSync(monkeysIdeCss) ? monkeysIdeCss : monkeyExe;
    if (fs.existsSync(monkeysIdeCss)) {
      status.monkeycode.installed = true;
      try {
        const css = fs.readFileSync(monkeysIdeCss, 'utf8');
        status.monkeycode.patched = css.includes('mc-input-wrapper') || css.includes('SK AI - Pyidaungsu');
      } catch (e) {
        status.monkeycode.patched = false;
      }
    } else if (fs.existsSync(monkeyExe) || fs.existsSync(path.join(process.env.LOCALAPPDATA, 'com.chaitin.baizhi.monkeycode'))) {
      status.monkeycode.installed = true;
      const launcher = path.join(process.env.USERPROFILE, 'Desktop', 'MonkeyCode (Pyidaungsu).lnk');
      const font = path.join(process.env.LOCALAPPDATA, 'Microsoft', 'Windows', 'Fonts', 'Pyidaungsu-2.5_Regular.ttf');
      status.monkeycode.patched = fs.existsSync(launcher) && fs.existsSync(font);
    }

    // 6. VS Code / Kilo Code
    const vscodeSettings = path.join(process.env.APPDATA, 'Code', 'User', 'settings.json');
    const vscodeRoot = path.join(process.env.LOCALAPPDATA, 'Programs', 'Microsoft VS Code');
    status.vscode.path = vscodeSettings;
    if (fs.existsSync(vscodeSettings) || fs.existsSync(vscodeRoot)) {
      status.vscode.installed = true;
      let anyPatched = false;
      if (fs.existsSync(vscodeRoot)) {
        try {
          const dirs = fs.readdirSync(vscodeRoot);
          for (const d of dirs) {
            const c = path.join(vscodeRoot, d, 'resources', 'app', 'out', 'vs', 'workbench', 'workbench.desktop.main.css');
            if (fs.existsSync(c)) {
              const css = fs.readFileSync(c, 'utf8');
              if (css.includes('SK AI - Pyidaungsu')) anyPatched = true;
            }
          }
        } catch (e) {}
      }
      status.vscode.patched = anyPatched;
    }

    // 7. Zed
    const zedSettings = path.join(process.env.APPDATA, 'Zed', 'settings.json');
    status.zed.path = zedSettings;
    if (fs.existsSync(zedSettings)) {
      status.zed.installed = true;
      try {
        const settings = JSON.parse(fs.readFileSync(zedSettings, 'utf8'));
        status.zed.patched = settings['ui_font_family'] && settings['ui_font_family'].includes('Pyidaungsu');
      } catch (e) {
        status.zed.patched = false;
      }
    }

    // 8. Verdent
    const verdentExe = 'C:\\Program Files\\Verdent\\Verdent.exe';
    const verdentLocal = path.join(process.env.LOCALAPPDATA, 'Programs', 'Verdent-Pyidaungsu', 'Verdent.exe');
    const verdentLauncher = path.join(__dirname, 'launch-verdent-pyidaungsu.ps1');
    status.verdent = { installed: false, patched: false, path: verdentLocal };
    if (fs.existsSync(verdentExe)) {
      status.verdent.installed = true;
      status.verdent.patched = fs.existsSync(verdentLocal) && fs.existsSync(verdentLauncher);
    }

    console.log(JSON.stringify(status, null, 2));
  } catch (err) {
    console.log(JSON.stringify({ error: err.message }));
  }
}

checkStatus();
