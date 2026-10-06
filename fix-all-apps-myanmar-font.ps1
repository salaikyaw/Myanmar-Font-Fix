# 4. VS Code / Kilo Code / Cline
# ---------------------------------------------------------
Write-Host "`n[=== VS Code & Cline Extension ===]" -ForegroundColor Magenta
$vscodeSettings = "$env:APPDATA\Code\User\settings.json"
if (Test-Path $vscodeSettings) {
    Write-Host "[+] Updating VS Code settings.json..." -ForegroundColor Yellow
    try {
        $vsNode = @'
const fs = require('fs');
const p = process.argv[1];
try {
  let raw = fs.readFileSync(p, 'utf8');
  if (raw.charCodeAt(0) === 0xFEFF) raw = raw.slice(1);
  const clean = raw.replace(//*[\s\S]*?*/|([^\\:]|^)//.*$/gm, '$1').replace(/,(\s*[\]}])/g, '$1');
  let json = JSON.parse(clean);
  json['editor.fontFamily'] = '"JetBrains Mono", Consolas, "Pyidaungsu", monospace';
  json['terminal.integrated.fontFamily'] = '"JetBrains Mono", Consolas, "Pyidaungsu", monospace';
  json['chat.editor.fontFamily'] = '"Pyidaungsu", "Myanmar Text", "Noto Sans Myanmar", system-ui, sans-serif';
  json['markdown.preview.fontFamily'] = '"Pyidaungsu", "Myanmar Text", "Noto Sans Myanmar", system-ui, sans-serif';
  json['kilo-code.fontFamily'] = '"Pyidaungsu", "Myanmar Text", "Noto Sans Myanmar", system-ui, sans-serif';
  fs.writeFileSync(p, JSON.stringify(json, null, 2), 'utf8');
} catch (e) {
  console.error(e.message);
}
'@
        node -e $vsNode $vscodeSettings
        if ($LASTEXITCODE -eq 0) { Write-Host "[OK] VS Code settings updated!" -ForegroundColor Green }
    } catch { Write-Host "[!]  VS Code settings error: $_" -ForegroundColor Red }
} else {
    Write-Host "[-] VS Code settings.json not found." -ForegroundColor DarkGray
}

# Patch VS Code workbench CSS across all commit directories
$vscodeRoot = "$env:LOCALAPPDATA\Programs\Microsoft VS Code"
if (Test-Path $vscodeRoot) {
    $cssCandidates = @()
    Get-ChildItem $vscodeRoot -Directory | ForEach-Object {
        $c = Join-Path $_.FullName "resources\app\out\vs\workbench\workbench.desktop.main.css"
        if (Test-Path $c) { $cssCandidates += $c }
    }
    $directCss = Join-Path $vscodeRoot "resources\app\out\vs\workbench\workbench.desktop.main.css"
    if (Test-Path $directCss) { $cssCandidates += $directCss }

    $vsSafeCss = @'
/* === SK AI - Pyidaungsu Myanmar Font === */
:root {
  --vscode-font-family: "Pyidaungsu", "Myanmar Text", "Noto Sans Myanmar", system-ui, -apple-system, sans-serif !important;
  --vscode-editor-font-family: "JetBrains Mono", Consolas, "Pyidaungsu", monospace !important;
}
.monaco-workbench {
  font-family: "Pyidaungsu", "Myanmar Text", "Noto Sans Myanmar", system-ui, -apple-system, sans-serif;
  font-variant-ligatures: normal !important;
}
.monaco-editor, .monaco-editor .inputarea, .monaco-editor textarea {
  font-family: "JetBrains Mono", Consolas, "Pyidaungsu", monospace !important;
  font-variant-ligatures: normal !important;
}
.interactive-session, .chat-editor, [class*="chat-"], [class*="interactive-"],
.quick-input-widget, .monaco-list-row .label-name, .notifications-toasts {
  font-family: "Pyidaungsu", "Myanmar Text", "Noto Sans Myanmar", system-ui, -apple-system, sans-serif !important;
  font-variant-ligatures: normal !important;
}
.codicon, [class*="codicon"], [class*="codicon-"], i[class*="codicon"] {
  font-family: codicon !important;
}
/* === End SK AI Patch === */
'@
    foreach ($cssFile in $cssCandidates) {
        $bak = "$cssFile.pyidaungsu-bak"
        if (Test-Path $bak) {
            Copy-Item -Path $bak -Destination $cssFile -Force
        } else {
            Copy-Item -Path $cssFile -Destination $bak -Force
        }
        $origCss = Get-Content -Path $cssFile -Raw -Encoding UTF8
        Set-Content -Path $cssFile -Value ($vsSafeCss + "`n" + $origCss) -Encoding UTF8 -NoNewline
        Write-Host "[OK] Patched VS Code workbench CSS: $cssFile" -ForegroundColor Green
    }
}

# Patch Cline Extension Webviews in VS Code
$clineExtBase = Join-Path $env:USERPROFILE ".vscode\extensions"
if (Test-Path $clineExtBase) {
    $clineDirs = Get-ChildItem $clineExtBase -Directory | Where-Object { $_.Name -like "*claude-dev*" -or $_.Name -like "*cline*" }
    $clineMarker = 'sk-cline-pyidaungsu-font'
    $clineStyle = @"
<style id="$clineMarker">
html, body, body *:not(svg):not(path):not([class*="codicon"]):not([class*="icon"]):not(i) {
  font-family: "Pyidaungsu", "Myanmar Text", "Noto Sans Myanmar", system-ui, -apple-system, sans-serif !important;
  font-variant-ligatures: normal !important;
  text-rendering: optimizeLegibility !important;
}
pre, pre *, code, code *, .xterm, .xterm * {
  font-family: "JetBrains Mono", "Cascadia Mono", Consolas, monospace !important;
}
</style>
"@
    foreach ($d in $clineDirs) {
        $htmlFiles = @(
            Join-Path $d.FullName "next\webview-ui\build\index.html",
            Join-Path $d.FullName "legacy\webview-ui\build\index.html"
        )
        foreach ($hf in $htmlFiles) {
            if (Test-Path $hf) {
                $content = Get-Content $hf -Raw -Encoding UTF8
                if ($content -match $clineMarker) {
                    $content = $content -replace '<style id="sk-cline-pyidaungsu-font">[\s\S]*?</style>', $clineStyle
                    Set-Content -Path $hf -Value $content -Encoding UTF8 -NoNewline
                    Write-Host "[OK] Updated Cline Webview: $hf" -ForegroundColor Green
                } else {
                    Copy-Item $hf "$hf.bak" -Force
                    $content = $content.Replace("</head>", "$clineStyle`n</head>")
                    Set-Content -Path $hf -Value $content -Encoding UTF8 -NoNewline
                    Write-Host "[OK] Patched Cline Webview: $hf" -ForegroundColor Green
                }
            }
        }
    }
}

# =========================================================
# Multi-App Myanmar Font Fixer v2.0 - SK AI Foundation
# Apps: OpenCode, Antigravity, Jan, Desktop Commander,
#       ZCode, Kilo Code/VSCode, Monkey Code, Zed
# Updated: 2026-08-19
# =========================================================
$ErrorActionPreference = 'SilentlyContinue'
$timestamp  = Get-Date -Format 'yyyyMMdd-HHmmss'
$patcher    = 'C:\SK_AI\projects\agents-workspace\codex\myanmar-font-fix\patch-asar-font.js'
$backupBase = "C:\SK_AI\projects\agents-workspace\codex\myanmar-font-fix\backups\$timestamp"
$asarNode   = 'file:///C:/SK_AI/projects/agents-workspace/zcode/ZCodeProject/_asar-inspect/node_modules/@electron/asar/lib/asar.js'
$env:ASAR_MODULE = 'C:\SK_AI\projects\agents-workspace\zcode\ZCodeProject\_asar-inspect\node_modules\@electron\asar\lib\asar.js'

Write-Host ""
Write-Host "==========================================================" -ForegroundColor Cyan
Write-Host "   Myanmar Font Auto-Fixer v2.0 - SK AI Foundation        " -ForegroundColor Cyan
Write-Host "==========================================================" -ForegroundColor Cyan
Write-Host ""

New-Item -ItemType Directory -Path $backupBase -Force | Out-Null

# ---------------------------------------------------------
# 1. Close running apps first
# ---------------------------------------------------------
$appsToClose = @('OpenCode','Jan','desktop-commander','Antigravity','ZCode','monkeycode','monkeycode-desktop')
foreach ($app in $appsToClose) {
    $proc = Get-Process $app -ErrorAction SilentlyContinue
    if ($proc) {
        Write-Host "[*] Closing $app..." -ForegroundColor DarkYellow
        $proc | Stop-Process -Force
    }
}
Start-Sleep -Seconds 2

# ---------------------------------------------------------
# 2. ASAR HTML Patch: OpenCode / Jan / Desktop Commander
# ---------------------------------------------------------
Write-Host "`n[=== ASAR HTML Patch ===]" -ForegroundColor Magenta
$asarTargets = @(
    @{ Name="OpenCode";         Asar="$env:LOCALAPPDATA\Programs\@opencode-aidesktop\resources\app.asar"; Target="out\renderer\index.html"; Unpack="node_modules/{@lydell,@msgpackr-extract,@parcel,msgpackr-extract}" },
    @{ Name="Jan AI";           Asar="$env:LOCALAPPDATA\Programs\jan\resources\app.asar";                Target="dist\index.html";          Unpack="node_modules" },
    @{ Name="Desktop Commander";Asar="$env:APPDATA\npm\node_modules\@wonderwhy-er\desktop-commander\resources\app.asar"; Target="index.html"; Unpack="" }
)
foreach ($item in $asarTargets) {
    if (Test-Path $item.Asar) {
        Write-Host "[+] $($item.Name) - Patching..." -ForegroundColor Yellow
        Copy-Item $item.Asar (Join-Path $backupBase "$($item.Name)-app.asar.bak") -Force
        if ($item.Unpack -ne "") { & node $patcher $item.Asar $item.Target $item.Unpack }
        else                     { & node $patcher $item.Asar $item.Target }
        if ($LASTEXITCODE -eq 0) { Write-Host "[OK] $($item.Name) patched!" -ForegroundColor Green }
        else                     { Write-Host "[!]  $($item.Name) patch error." -ForegroundColor Red }
    } else {
        Write-Host "[-] $($item.Name) not found. Skipped." -ForegroundColor DarkGray
    }
}

# ---------------------------------------------------------
# 3. Antigravity - preload.js + utils.js injection (ASAR patch)
# ---------------------------------------------------------
Write-Host "`n[=== Antigravity Font Patch ===]" -ForegroundColor Magenta
$agyAsar = "$env:LOCALAPPDATA\Programs\antigravity\resources\app.asar"
$agyPatcher = 'C:\SK_AI\projects\agents-workspace\codex\myanmar-font-fix\patch-antigravity-font.js'
if (Test-Path $agyAsar) {
    Write-Host "[+] Antigravity - Patching preload.js + utils.js..." -ForegroundColor Yellow
    $env:AGY_BACKUP_PATH = Join-Path $backupBase "Antigravity-app.asar.bak"
    & node $agyPatcher
    if ($LASTEXITCODE -eq 0) { Write-Host "[OK] Antigravity font injected!" -ForegroundColor Green }
    else                     { Write-Host "[!]  Antigravity patch failed." -ForegroundColor Red }
} else {
    Write-Host "[-] Antigravity not found. Skipped." -ForegroundColor DarkGray
}


# ---------------------------------------------------------
# 4. VS Code & Cline Extension - Webview + settings.json
# ---------------------------------------------------------
Write-Host "`n[=== VS Code & Cline Extension Font Patch ===]" -ForegroundColor Magenta
$vscodeSettings = "$env:APPDATA\Code\User\settings.json"
if (Test-Path $vscodeSettings) {
    Write-Host "[+] Updating VS Code settings..." -ForegroundColor Yellow
    try {
        $vsNode = @'
const fs = require('fs');
const p = process.argv[1];
try {
  let raw = fs.readFileSync(p, 'utf8');
  if (raw.charCodeAt(0) === 0xFEFF) raw = raw.slice(1);
  const clean = raw.replace(/\/\*[\s\S]*?\*\/|([^\\:]|^)\/\/.*$/gm, '$1').replace(/,(\s*[\]}])/g, '$1');
  let json = JSON.parse(clean);
  json['editor.fontFamily'] = '"JetBrains Mono", Consolas, "Pyidaungsu", monospace';
  json['terminal.integrated.fontFamily'] = '"JetBrains Mono", Consolas, "Pyidaungsu", monospace';
  json['chat.editor.fontFamily'] = '-apple-system, BlinkMacSystemFont, "Segoe UI", "Pyidaungsu", "Myanmar Text", sans-serif';
  json['markdown.preview.fontFamily'] = '-apple-system, BlinkMacSystemFont, "Segoe UI", "Pyidaungsu", "Myanmar Text", sans-serif';
  json['kilo-code.fontFamily'] = '"Pyidaungsu", "Myanmar Text", "Noto Sans Myanmar", system-ui, sans-serif';
  fs.writeFileSync(p, JSON.stringify(json, null, 2), 'utf8');
  process.exit(0);
} catch (e) {
  console.error(e.message);
  process.exit(1);
}
'@
        node -e $vsNode $vscodeSettings
        if ($LASTEXITCODE -eq 0) { Write-Host "[OK] VS Code settings updated!" -ForegroundColor Green }
    } catch { Write-Host "[!]  VS Code settings error: $_" -ForegroundColor Red }
} else {
    Write-Host "[-] VS Code settings.json not found." -ForegroundColor DarkGray
}

# Patch Cline Extension Webviews in VS Code
$clineExtBase = Join-Path $env:USERPROFILE ".vscode\extensions"
if (Test-Path $clineExtBase) {
    $clineDirs = Get-ChildItem $clineExtBase -Directory | Where-Object { $_.Name -like "*claude-dev*" -or $_.Name -like "*cline*" }
    $clineMarker = 'sk-cline-pyidaungsu-font'
    $clineStyle = @"
<style id="$clineMarker">
html, body, body *:not(svg):not(path):not([class*="codicon"]):not([class*="icon"]):not(i) {
  font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", "Pyidaungsu", "Myanmar Text", "Noto Sans Myanmar", system-ui, sans-serif !important;
  font-variant-ligatures: normal !important;
  text-rendering: optimizeLegibility !important;
}
pre, pre *, code, code *, .xterm, .xterm * {
  font-family: "JetBrains Mono", "Cascadia Mono", Consolas, "Pyidaungsu", monospace !important;
}
</style>
"@
    foreach ($d in $clineDirs) {
        $htmlFiles = @(
            Join-Path $d.FullName "next\webview-ui\build\index.html",
            Join-Path $d.FullName "legacy\webview-ui\build\index.html"
        )
        foreach ($hf in $htmlFiles) {
            if (Test-Path $hf) {
                $content = Get-Content $hf -Raw -Encoding UTF8
                if ($content -notmatch $clineMarker) {
                    Copy-Item $hf "$hf.bak" -Force
                    $content = $content.Replace("</head>", "$clineStyle`n</head>")
                    Set-Content -Path $hf -Value $content -Encoding UTF8 -NoNewline
                    Write-Host "[OK] Patched Cline Webview: $hf" -ForegroundColor Green
                } else {
                    Write-Host "[-] Cline Webview already patched: $hf" -ForegroundColor DarkGray
                }
            }
        }
    }
}

# ---------------------------------------------------------
# 5. ZCode - existing patcher
# ---------------------------------------------------------
Write-Host "`n[=== ZCode Font Patch ===]" -ForegroundColor Magenta
$zPatcher = 'C:\SK_AI\projects\agents-workspace\codex\myanmar-font-fix\patch-zcode-qwen.ps1'
if (Test-Path $zPatcher) {
    Write-Host "[+] Running ZCode patcher..." -ForegroundColor Yellow
    & powershell -ExecutionPolicy Bypass -File $zPatcher
    Write-Host "[OK] ZCode done!" -ForegroundColor Green
} else {
    Write-Host "[-] ZCode patcher not found." -ForegroundColor DarkGray
}

# ---------------------------------------------------------
# 6A. MonkeysCode IDE (VS Code Fork) - Safe CSS & Settings
# ---------------------------------------------------------
Write-Host "`n[=== MonkeysCode IDE Font Patch ===]" -ForegroundColor Magenta
$monkeysCodeBase = "$env:LOCALAPPDATA\Programs\MonkeysCode"
$monkeysCodeCss  = Join-Path $monkeysCodeBase "resources\app\out\vs\workbench\workbench.desktop.main.css"
if (Test-Path $monkeysCodeCss) {
    Write-Host "[+] Patching MonkeysCode IDE workbench CSS safely..." -ForegroundColor Yellow
    $cssBak = "$monkeysCodeCss.pyidaungsu-bak"
    if (Test-Path $cssBak) {
        Copy-Item -Path $cssBak -Destination $monkeysCodeCss -Force
    } else {
        Copy-Item -Path $monkeysCodeCss -Destination $cssBak -Force
    }

    $rawCss = Get-Content -Path $monkeysCodeCss -Raw -Encoding UTF8
    $safeCss = @'
/* === SK AI - Pyidaungsu Myanmar Font === */
:root {
  --vscode-font-family: "Pyidaungsu", "Myanmar Text", "Noto Sans Myanmar", system-ui, -apple-system, sans-serif !important;
  --vscode-editor-font-family: "JetBrains Mono", Consolas, "Pyidaungsu", monospace !important;
}
.monaco-workbench {
  font-family: "Pyidaungsu", "Myanmar Text", "Noto Sans Myanmar", system-ui, -apple-system, sans-serif;
  font-variant-ligatures: normal !important;
}
.monaco-editor, .monaco-editor .inputarea, .monaco-editor textarea {
  font-family: "JetBrains Mono", Consolas, "Pyidaungsu", monospace !important;
  font-variant-ligatures: normal !important;
}
[class*="mc-"], .mc-input-wrapper, .mc-input-wrapper textarea, .mc-input-wrapper input,
.mc-msg-body, .mc-welcome-title, .mc-welcome-subtitle, .mc-welcome-tip,
.interactive-session, .chat-editor, [class*="chat-"], [class*="interactive-"],
.quick-input-widget, .monaco-list-row .label-name, .notifications-toasts {
  font-family: "Pyidaungsu", "Myanmar Text", "Noto Sans Myanmar", system-ui, -apple-system, sans-serif !important;
  font-variant-ligatures: normal !important;
}
.codicon, [class*="codicon"], [class*="codicon-"], i[class*="codicon"] {
  font-family: codicon !important;
}
/* === End SK AI Patch === */
'@
    Set-Content -Path $monkeysCodeCss -Value ($safeCss + "`n" + $rawCss) -Encoding UTF8 -NoNewline

    $monkeysSettings = "$env:APPDATA\MonkeysCode\User\settings.json"
    if (Test-Path $monkeysSettings) {
        $nodeClean = @'
const fs = require('fs');
const p = process.argv[1];
try {
  let raw = fs.readFileSync(p, 'utf8');
  if (raw.charCodeAt(0) === 0xFEFF) raw = raw.slice(1);
  const clean = raw.replace(//*[\s\S]*?*/|([^\\:]|^)//.*$/gm, '$1').replace(/,(\s*[\]}])/g, '$1');
  let json = JSON.parse(clean);
  json['editor.fontFamily'] = '"JetBrains Mono", Consolas, "Pyidaungsu", monospace';
  json['terminal.integrated.fontFamily'] = '"JetBrains Mono", Consolas, "Pyidaungsu", monospace';
  json['chat.editor.fontFamily'] = '"Pyidaungsu", "Myanmar Text", "Noto Sans Myanmar", system-ui, sans-serif';
  json['markdown.preview.fontFamily'] = '"Pyidaungsu", "Myanmar Text", "Noto Sans Myanmar", system-ui, sans-serif';
  json['workbench.fontAliasing'] = 'antialiased';
  fs.writeFileSync(p, JSON.stringify(json, null, 2), 'utf8');
} catch (e) {}
'@
        node -e $nodeClean $monkeysSettings
    }
    Write-Host "[OK] MonkeysCode IDE patched with full AI chat support!" -ForegroundColor Green
} else {
    Write-Host "[-] MonkeysCode IDE not found. Skipped." -ForegroundColor DarkGray
}

# 6B. MonkeyCode (WebView2 / Tauri App) - Extension Patch
# ---------------------------------------------------------
Write-Host "`n[=== MonkeyCode (WebView2 / Tauri) Font Patch ===]" -ForegroundColor Magenta
$monkeyExe = "$env:LOCALAPPDATA\MonkeyCode\monkeycode-desktop.exe"
$monkeyExt = "C:\SK_AI\projects\agents-workspace\codex\myanmar-font-fix\monkeycode-extension"
if ((Test-Path $monkeyExe) -or (Test-Path "$env:LOCALAPPDATA\com.chaitin.baizhi.monkeycode")) {
    Write-Host "[+] Configuring WebView2 Pyidaungsu font extension for MonkeyCode..." -ForegroundColor Yellow
    
    if (-not (Test-Path $monkeyExt)) {
        New-Item -ItemType Directory -Path $monkeyExt -Force | Out-Null
    }

    $wvArgs = "--load-extension=""$monkeyExt"""
    [Environment]::SetEnvironmentVariable("WEBVIEW2_ADDITIONAL_BROWSER_ARGUMENTS", $wvArgs, "User")
    $env:WEBVIEW2_ADDITIONAL_BROWSER_ARGUMENTS = $wvArgs

    $desktopPath = [Environment]::GetFolderPath('Desktop')
    if (Test-Path $desktopPath) {
        $wshShell = New-Object -ComObject WScript.Shell
        $shortcut = $wshShell.CreateShortcut((Join-Path $desktopPath "MonkeyCode (Pyidaungsu).lnk"))
        $shortcut.TargetPath = "wscript.exe"
        $shortcut.Arguments = "`"C:\SK_AI\projects\agents-workspace\codex\myanmar-font-fix\launch-monkeycode-pyidaungsu.vbs`""
        $shortcut.IconLocation = "$monkeyExe,0"
        $shortcut.Description = "MonkeyCode with Pyidaungsu Font"
        $shortcut.Save()
    }

    Write-Host "[OK] Monkey Code WebView2 Pyidaungsu font extension active!" -ForegroundColor Green
} else {
    Write-Host "[-] MonkeyCode not found. Skipped." -ForegroundColor DarkGray
}

# ---------------------------------------------------------
# 7. Zed Editor - settings.json
# ---------------------------------------------------------
Write-Host "`n[=== Zed Editor ===]" -ForegroundColor Magenta
$zedCfg = "$env:APPDATA\Zed\settings.json"
if (Test-Path $zedCfg) {
    Write-Host "[+] Updating Zed font settings..." -ForegroundColor Yellow
    try {
        $zed = Get-Content $zedCfg -Raw | ConvertFrom-Json
        $zed | Add-Member -NotePropertyName 'ui_font_family'     -NotePropertyValue 'Pyidaungsu, Noto Sans Myanmar, Segoe UI' -Force
        $zed | Add-Member -NotePropertyName 'buffer_font_family' -NotePropertyValue 'JetBrains Mono, Pyidaungsu, Noto Sans Myanmar' -Force
        $zed | ConvertTo-Json -Depth 10 | Set-Content $zedCfg -Encoding utf8
        Write-Host "[OK] Zed updated!" -ForegroundColor Green
    } catch { Write-Host "[!]  Zed error." -ForegroundColor Red }
} else {
    Write-Host "[-] Zed not found. Skipped." -ForegroundColor DarkGray
}

# ---------------------------------------------------------
# 8. Verdent AI - safe runtime injection (keep ASAR integrity intact)
# ---------------------------------------------------------
Write-Host "`n[=== Verdent AI Runtime Font ===]" -ForegroundColor Magenta
$verdentExe = "C:\Program Files\Verdent\Verdent.exe"
$verdentLauncher = Join-Path $PSScriptRoot 'launch-verdent-pyidaungsu.ps1'
if ((Test-Path $verdentExe) -and (Test-Path $verdentLauncher)) {
    Write-Host "[+] Starting safe Verdent Pyidaungsu launcher..." -ForegroundColor Yellow
    $verdentResult = & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $verdentLauncher -Once
    if ($verdentResult -match '"marker":true' -and $verdentResult -match 'Pyidaungsu') {
        Write-Host "[OK] Verdent live renderer verified with Pyidaungsu!" -ForegroundColor Green
    } else { Write-Host "[!] Verdent live font verification failed." -ForegroundColor Red }
} else {
    Write-Host "[-] Verdent AI not found or runtime launcher missing. Skipped." -ForegroundColor DarkGray
}

# ---------------------------------------------------------
Write-Host ""
Write-Host "==========================================================" -ForegroundColor Cyan
Write-Host "  DONE! Restart apps to apply Pyidaungsu font.            " -ForegroundColor Green
Write-Host "  Backups: $backupBase" -ForegroundColor DarkGray
Write-Host "==========================================================" -ForegroundColor Cyan
Write-Host ""
