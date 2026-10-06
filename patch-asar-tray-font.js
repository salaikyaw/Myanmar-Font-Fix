// ============================================================
// patch-asar-tray-font.js — Combined Myanmar Font + Tray Fix
// Usage: node patch-asar-tray-font.js <asar> <mainJs> [htmlPath] [unpackDir]
// ============================================================
const fs = require('fs');
const os = require('os');
const path = require('path');

(async () => {
  let asar;
  try {
    asar = require('@electron/asar');
  } catch (_) {
    asar = await import('file:///C:/SK_AI/projects/agents-workspace/zcode/ZCodeProject/_asar-inspect/node_modules/@electron/asar/lib/asar.js');
  }

  const [archive, mainJsRel, htmlRel, unpackDir] = process.argv.slice(2);
  if (!archive || !mainJsRel) {
    console.error('Usage: node patch-asar-tray-font.js <asar> <mainJs> [htmlPath] [unpackDir]');
    process.exit(1);
  }

  const TRAY_MARKER = 'sk-tray-fix';
  const FONT_MARKER = 'sk-pyidaungsu-font-fix';

  const work = fs.mkdtempSync(path.join(os.tmpdir(), 'sk-patch-'));
  try {
    await asar.extractAll(archive, work);
    console.log('[*] Extracted to', work);

    // --------------------------------------------------
    // 1. Patch main JS — Tray + Close Interception + Font
    // --------------------------------------------------
    const mainFile = path.join(work, ...mainJsRel.split(/[\\/]+/));
    if (!fs.existsSync(mainFile)) {
      console.error('[!] Main JS not found:', mainJsRel);
      process.exit(1);
    }
    let js = fs.readFileSync(mainFile, 'utf8');

    if (js.includes(TRAY_MARKER)) {
      console.log('[OK] Tray already patched — skipping');
    } else {
      // --- Replace app.quit() inside window-all-closed handler ---
      const wacIdx = js.indexOf('window-all-closed');
      let patched = false;
      if (wacIdx >= 0) {
        const quitIdx = js.indexOf('app.quit()', wacIdx);
        if (quitIdx >= 0 && quitIdx < wacIdx + 1200) {
          const trayReplace = `{/* ${TRAY_MARKER}: create tray instead of quitting */
            if(!global._skTray){
              try{
                const{Tray,Menu,BrowserWindow,nativeImage}=require("electron");
                let _p=require("path").join(__dirname,"assets","icon.png");
                if(!fs.existsSync(_p))_p=require("path").join(__dirname,"..","assets","icon.png");
                global._skTray=new Tray(fs.existsSync(_p)?_p:nativeImage.createEmpty());
                global._skTray.setToolTip(app.getName());
                global._skTray.setContextMenu(Menu.buildFromTemplate([
                  {label:"Show",click:()=>BrowserWindow.getAllWindows().forEach(w=>{w.show();w.focus();})},
                  {type:"separator"},
                  {label:"Quit",click:()=>{global._skIsQuiting=true;app.quit();}}
                ]));
                global._skTray.on("click",()=>BrowserWindow.getAllWindows().forEach(w=>{w.show();w.focus();}));
              }catch(e){console.error("SK Tray error:",e);}
            }`;
          js = js.substring(0, quitIdx) + trayReplace + js.substring(quitIdx + 'app.quit()'.length);
          patched = true;
        }
      }

      // --- Prepend: close interception + font injection ---
      const prepend = `/* ${TRAY_MARKER} — intercept close + inject font */
(function(){
  global._skIsQuiting=false;
  var{app}=require("electron");
  app.on("before-quit",()=>{global._skIsQuiting=true;});
  app.on("browser-window-created",function(e,_w){
    _w.on("close",function(ev){
      if(!global._skIsQuiting){ev.preventDefault();_w.hide();}
    });
    _w.webContents.on("did-finish-load",function(){
      _w.webContents.insertCSS('html,body,#root,#root *:not(code):not(pre){font-family:"Pyidaungsu","Myanmar Text","Noto Sans Myanmar",system-ui,sans-serif!important;text-rendering:optimizeLegibility!important}').catch(function(){});
    });
  });
})();
/* end ${TRAY_MARKER} */
`;
      js = prepend + js;

      if (patched) {
        console.log('[OK] Tray: replaced app.quit() in window-all-closed');
      } else {
        console.log('[!!] Tray: could not find app.quit() in window-all-closed — close interception still active');
      }
      fs.writeFileSync(mainFile, js, 'utf8');
      console.log('[OK] Tray patch written');
    }

    // --------------------------------------------------
    // 2. Patch HTML — Font CSS injection (if htmlPath given)
    // --------------------------------------------------
    if (htmlRel) {
      const htmlFile = path.join(work, ...htmlRel.split(/[\\/]+/));
      if (fs.existsSync(htmlFile)) {
        let html = fs.readFileSync(htmlFile, 'utf8');
        if (html.includes(FONT_MARKER)) {
          console.log('[OK] Font already patched — skipping');
        } else {
          const style = `<style id="${FONT_MARKER}">
html,body,body *:not(svg):not(path):not([class*="codicon"]):not([class*="icon-font"]),
input,textarea,button,[contenteditable="true"],[role="textbox"]{
  font-family:"Pyidaungsu","Myanmar Text","Noto Sans Myanmar",system-ui,sans-serif!important;
  text-rendering:optimizeLegibility!important;
}
pre,pre *,code,code *,kbd,kbd *,samp,samp *,.monaco-editor,.monaco-editor *,.xterm,.xterm *{
  font-family:"JetBrainsMono Nerd Font Mono","Cascadia Mono",Consolas,"Pyidaungsu",monospace!important;
}
</style>`;
          if (html.includes('</head>')) {
            html = html.replace('</head>', style + '\n</head>');
          } else {
            html = style + html;
          }
          fs.writeFileSync(htmlFile, html, 'utf8');
          console.log('[OK] Font CSS injected into', htmlRel);
        }
      } else {
        console.log('[--] HTML not found:', htmlRel);
      }
    }

    // --------------------------------------------------
    // 3. Repack asar
    // --------------------------------------------------
    const replacement = archive + '.new';
    if (fs.existsSync(replacement)) fs.rmSync(replacement, { force: true });
    const opts = unpackDir ? { unpackDir } : {};
    await asar.createPackageWithOptions(work, replacement, opts);
    fs.copyFileSync(replacement, archive);
    fs.rmSync(replacement, { force: true });
    fs.rmSync(replacement + '.unpacked', { recursive: true, force: true });
    console.log('[DONE] Patched:', archive);
  } finally {
    fs.rmSync(work, { recursive: true, force: true });
  }
})().catch((err) => {
  console.error('[ERROR]', err.message || err);
  process.exitCode = 1;
});
