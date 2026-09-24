param([switch]$ParentMenu)
# Multi-App Myanmar Font Repair Script - SK AI Foundation
$ErrorActionPreference = 'SilentlyContinue'
. (Join-Path (Split-Path $PSScriptRoot -Parent) 'Select-FontMenu.ps1')

# Helper paths
$projectRoot = Split-Path $PSScriptRoot -Parent
$statusScript = Join-Path $PSScriptRoot 'check-patch-status.js'
$patcher = Join-Path $PSScriptRoot 'patch-asar-font.js'
$asarCandidates = @(
    (Join-Path $projectRoot 'node_modules\@electron\asar\lib\asar.js'),
    (Join-Path $projectRoot 'vendor\node_modules\@electron\asar\lib\asar.js')
)
$env:ASAR_MODULE = $asarCandidates | Where-Object { Test-Path -LiteralPath $_ } | Select-Object -First 1

function Show-Header {
    Clear-Host
    Write-Host "==========================================================" -ForegroundColor Cyan
    Write-Host "   Antigravity & Multi-App Myanmar Font Fixer v3.0        " -ForegroundColor Cyan
    Write-Host "   SK AI Foundation - Auto + Manual System                " -ForegroundColor Cyan
    Write-Host "==========================================================" -ForegroundColor Cyan
    Write-Host ""
}

# --- Individual Patch Functions ---

function Patch-Antigravity {
    Write-Host "`n[+] Patching Antigravity..." -ForegroundColor Yellow
    Write-Host "    Closing Antigravity..." -ForegroundColor DarkYellow
    $proc = Get-Process Antigravity -ErrorAction SilentlyContinue
    if ($proc) {
        $proc | Stop-Process -Force
        $proc | Wait-Process -Timeout 10
    }
    Start-Sleep -Seconds 2
    & node (Join-Path $PSScriptRoot 'patch-antigravity-font.js')
    if ($LASTEXITCODE -eq 0) {
        Write-Host "[OK] Antigravity patched successfully!" -ForegroundColor Green
    } else {
        Write-Host "[!] Antigravity patch failed or already applied." -ForegroundColor DarkYellow
    }
    # Auto-restart Antigravity
    $agyExe = "$env:LOCALAPPDATA\Programs\antigravity\Antigravity.exe"
    if (Test-Path $agyExe) {
        Write-Host "    Restarting Antigravity..." -ForegroundColor DarkYellow
        Start-Process $agyExe
    }
}

function Patch-MonkeyCode {
    Write-Host "`n[+] Patching MonkeysCode IDE & MonkeyCode..." -ForegroundColor Yellow
    $procs = Get-Process MonkeysCode, monkeycode-desktop -ErrorAction SilentlyContinue
    foreach ($p in $procs) {
        $p | Stop-Process -Force
        $p | Wait-Process -Timeout 10
    }
    Start-Sleep -Seconds 1

    # 1. MonkeysCode IDE (VS Code Fork)
    $monkeyBase = "$env:LOCALAPPDATA\Programs\MonkeysCode"
    $cssPath   = Join-Path $monkeyBase "resources\app\out\vs\workbench\workbench.desktop.main.css"

    if (Test-Path $cssPath) {
        $cssBackup = "$cssPath.pyidaungsu-bak"
        if (-not (Test-Path $cssBackup)) {
            Copy-Item -Path $cssPath -Destination $cssBackup -Force
        }

        $currentBackup="$cssPath.mff-$((Get-FileHash -LiteralPath $cssPath -Algorithm SHA256).Hash.Substring(0,12)).bak"
        if(-not(Test-Path $currentBackup)){Copy-Item -LiteralPath $cssPath -Destination $currentBackup}
        $css = (Get-Content -Path $cssPath -Raw -Encoding UTF8) -replace '(?s)/\* === SK AI - Pyidaungsu Myanmar Font === \*/.*?/\* === End SK AI Patch === \*/',''
        $pyidaungsuCss = @'
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
        Set-Content -Path $cssPath -Value ($pyidaungsuCss + "`n" + $css) -Encoding UTF8 -NoNewline
        Write-Host "  [OK] MonkeysCode IDE workbench CSS patched with full AI chat support!" -ForegroundColor Green

        # User settings.json
        $userDir = "$env:APPDATA\MonkeysCode\User"
        $settingsFile = Join-Path $userDir "settings.json"
        if (-not (Test-Path $userDir)) { New-Item -ItemType Directory -Path $userDir -Force | Out-Null }
        $nodeScript = @'
const fs = require('fs');
const p = process.argv[1];
let settings = {};
if (fs.existsSync(p)) {
  try {
    let raw = fs.readFileSync(p, 'utf8');
    if (raw.charCodeAt(0) === 0xFEFF) raw = raw.slice(1);
    const clean = raw.replace(//*[\s\S]*?*/|([^\\:]|^)//.*$/gm, '$1').replace(/,(\s*[\]}])/g, '$1');
    settings = JSON.parse(clean);
  } catch (e) {}
}
settings['editor.fontFamily'] = '"JetBrains Mono", Consolas, "Pyidaungsu", monospace';
settings['editor.fontSize'] = 14;
settings['terminal.integrated.fontFamily'] = '"JetBrains Mono", Consolas, "Pyidaungsu", monospace';
settings['chat.editor.fontFamily'] = '"Pyidaungsu", "Myanmar Text", "Noto Sans Myanmar", system-ui, sans-serif';
settings['markdown.preview.fontFamily'] = '"Pyidaungsu", "Myanmar Text", "Noto Sans Myanmar", system-ui, sans-serif';
settings['workbench.fontAliasing'] = 'antialiased';
fs.writeFileSync(p, JSON.stringify(settings, null, 2), 'utf8');
'@
        node -e $nodeScript $settingsFile
        Write-Host "  [OK] MonkeysCode settings.json updated!" -ForegroundColor Green
    }

    # 2. Older WebView2 MonkeyCode Launcher
    $wvExe = "$env:LOCALAPPDATA\MonkeyCode\monkeycode-desktop.exe"
    if (Test-Path $wvExe) {
        $monkeyExt = Join-Path $PSScriptRoot 'monkeycode-extension'
        if (Test-Path $monkeyExt) {
            $desktopPath = [Environment]::GetFolderPath('Desktop')
            $wshShell = New-Object -ComObject WScript.Shell
            $shortcut = $wshShell.CreateShortcut((Join-Path $desktopPath "MonkeyCode (Pyidaungsu).lnk"))
            $shortcut.TargetPath = "wscript.exe"
            $shortcut.Arguments = '"' + (Join-Path $PSScriptRoot 'launch-monkeycode-pyidaungsu.vbs') + '"'
            $shortcut.IconLocation = "$wvExe,0"
            $shortcut.Description = "MonkeyCode with Pyidaungsu Font"
            $shortcut.Save()
            Write-Host "  [OK] Desktop shortcut created for MonkeyCode WebView2!" -ForegroundColor Green
        }
    }
}

function Patch-OpenCode {
    Write-Host "`n[+] Patching OpenCode..." -ForegroundColor Yellow
    Write-Host "    Closing OpenCode..." -ForegroundColor DarkYellow
    $proc = Get-Process OpenCode -ErrorAction SilentlyContinue
    if ($proc) {
        $proc | Stop-Process -Force
        $proc | Wait-Process -Timeout 10
    }
    Start-Sleep -Seconds 2
    $opencodeAsar = "$env:LOCALAPPDATA\Programs\@opencode-aidesktop\resources\app.asar"
    & node $patcher $opencodeAsar "out\renderer\index.html" "node_modules/{@lydell,@msgpackr-extract,@parcel,msgpackr-extract}"
    if ($LASTEXITCODE -eq 0) {
        Write-Host "[OK] OpenCode patched!" -ForegroundColor Green
    } else {
        Write-Host "[!] OpenCode patch failed." -ForegroundColor Red
    }
}

function Patch-Jan {
    Write-Host "`n[+] Starting Jan AI with runtime Pyidaungsu injection..." -ForegroundColor Yellow
    Write-Host "    Closing Jan..." -ForegroundColor DarkYellow
    $proc = Get-Process Jan -ErrorAction SilentlyContinue
    if ($proc) {
        $proc | Stop-Process -Force
        $proc | Wait-Process -Timeout 10
    }
    $janLauncher = Join-Path $PSScriptRoot 'launch-jan-pyidaungsu.vbs'
    $janStatus = Join-Path $PSScriptRoot 'jan-font-status.json'
    if (-not (Test-Path -LiteralPath $janLauncher)) {
        Write-Host "[!] Jan runtime launcher is missing." -ForegroundColor Red
        return
    }
    Remove-Item -LiteralPath $janStatus -Force -ErrorAction SilentlyContinue
    Start-Process -FilePath "$env:SystemRoot\System32\wscript.exe" -ArgumentList "`"$janLauncher`""
    $deadline = (Get-Date).AddSeconds(35)
    do {
        Start-Sleep -Milliseconds 500
        if (Test-Path -LiteralPath $janStatus) {
            try { $live = Get-Content -LiteralPath $janStatus -Raw | ConvertFrom-Json } catch { $live = $null }
            if ($live.ok -eq $true -and $live.bodyFont -match 'Pyidaungsu') {
                Write-Host "[OK] Jan live renderer verified with Pyidaungsu." -ForegroundColor Green
                return
            }
        }
    } while ((Get-Date) -lt $deadline)
    Write-Host "[!] Jan started but live font verification timed out." -ForegroundColor Red
}

function Patch-VSCode {
    Write-Host "`n[+] Patching VS Code & Cline Extension..." -ForegroundColor Yellow
    
    # 1. Patch both staged Cline WebView bundles. Cline exposes no font setting;
    # its chat UI uses its own CSS variables rather than editor.fontFamily.
    $clinePatcher = Join-Path $PSScriptRoot 'patch-cline-font.ps1'
    if (Test-Path -LiteralPath $clinePatcher) {
        & powershell -NoProfile -ExecutionPolicy Bypass -File $clinePatcher
    } else {
        Write-Host "  [!] Cline font patcher not found: $clinePatcher" -ForegroundColor Red
    }

    # 2. Patch VS Code workbench CSS across all commit directories
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
            if (-not (Test-Path $bak)) {
                Copy-Item -Path $cssFile -Destination $bak -Force
            }
            $currentBackup="$cssFile.mff-$((Get-FileHash -LiteralPath $cssFile -Algorithm SHA256).Hash.Substring(0,12)).bak"
            if(-not(Test-Path $currentBackup)){Copy-Item -LiteralPath $cssFile -Destination $currentBackup}
            $origCss = (Get-Content -Path $cssFile -Raw -Encoding UTF8) -replace '(?s)/\* === SK AI - Pyidaungsu Myanmar Font === \*/.*?/\* === End SK AI Patch === \*/',''
            Set-Content -Path $cssFile -Value ($vsSafeCss + "`n" + $origCss) -Encoding UTF8 -NoNewline
            Write-Host "  [OK] Patched VS Code workbench CSS: $cssFile" -ForegroundColor Green
        }
    }

    # 3. Update VS Code User settings.json
    $vsCfg = Join-Path $env:APPDATA "Code\User\settings.json"
    if (Test-Path $vsCfg) {
        $nodeScript = @'
const fs = require('fs');
const p = process.argv[1];
try {
  let raw = fs.readFileSync(p, 'utf8');
  if (raw.charCodeAt(0) === 0xFEFF) raw = raw.slice(1);
  const clean = raw.replace(/\/\*[\s\S]*?\*\/|([^\\:]|^)\/\/.*$/gm, '$1').replace(/,(\s*[\]}])/g, '$1');
  let json = JSON.parse(clean);
  json['editor.fontFamily'] = '"JetBrains Mono", Consolas, "Pyidaungsu", monospace';
  json['terminal.integrated.fontFamily'] = '"JetBrains Mono", Consolas, "Pyidaungsu", monospace';
  json['chat.editor.fontFamily'] = '"Pyidaungsu", "Myanmar Text", "Noto Sans Myanmar", system-ui, sans-serif';
  json['markdown.preview.fontFamily'] = '"Pyidaungsu", "Myanmar Text", "Noto Sans Myanmar", system-ui, sans-serif';
  json['kilo-code.fontFamily'] = '"Pyidaungsu", "Myanmar Text", "Noto Sans Myanmar", system-ui, sans-serif';
  fs.writeFileSync(p, JSON.stringify(json, null, 2), 'utf8');
  process.exit(0);
} catch (e) {
  console.error(e.message);
  process.exit(1);
}
'@
        node -e $nodeScript $vsCfg
        if ($LASTEXITCODE -eq 0) {
            Write-Host "  [OK] VS Code settings.json updated with Pyidaungsu font!" -ForegroundColor Green
        } else {
            Write-Host "  [!] Failed to update VS Code settings.json" -ForegroundColor Red
        }
    } else {
        Write-Host "  [-] VS Code settings.json not found." -ForegroundColor DarkGray
    }
}

function Patch-ZCode {
    Write-Host "`n[+] Patching ZCode..." -ForegroundColor Yellow
    Write-Host "    Closing ZCode..." -ForegroundColor DarkYellow
    $proc = Get-Process ZCode -ErrorAction SilentlyContinue
    if ($proc) {
        $proc | Stop-Process -Force
        $proc | Wait-Process -Timeout 10
    }
    Start-Sleep -Seconds 2
    $zPatcher = Join-Path $PSScriptRoot 'patch-zcode-qwen.ps1'
    if (Test-Path $zPatcher) {
        & powershell -ExecutionPolicy Bypass -File $zPatcher
        Write-Host "[OK] ZCode patched!" -ForegroundColor Green
    } else {
        Write-Host "[-] ZCode patcher not found." -ForegroundColor DarkGray
    }
}

function Patch-Zed {
    Write-Host "`n[+] Patching Zed Editor settings..." -ForegroundColor Yellow
    $nodeScript = @'
const fs = require('fs');
const path = require('path');
const zedCfg = path.join(process.env.APPDATA, 'Zed', 'settings.json');
if (fs.existsSync(zedCfg)) {
  try {
    let content = fs.readFileSync(zedCfg, 'utf8');
    let jsonClean = content.replace(/\/\*[\s\S]*?\*\/|([^\\:]|^)\/\/.*$/gm, '$1').replace(/,(\s*[\]}])/g, '$1');
    let json = JSON.parse(jsonClean);
    json.ui_font_family = 'Pyidaungsu, Noto Sans Myanmar, Segoe UI';
    json.buffer_font_family = 'JetBrains Mono, Pyidaungsu, Noto Sans Myanmar';
    fs.writeFileSync(zedCfg, JSON.stringify(json, null, 2), 'utf8');
    process.exit(0);
  } catch (e) {
    console.error(e.message);
    process.exit(1);
  }
} else {
  process.exit(2);
}
'@
    node -e $nodeScript
    if ($LASTEXITCODE -eq 0) {
        Write-Host "[OK] Zed editor settings updated successfully!" -ForegroundColor Green
    } elseif ($LASTEXITCODE -eq 2) {
        Write-Host "[-] Zed settings.json not found." -ForegroundColor DarkGray
    } else {
        Write-Host "[!] Failed to update Zed settings." -ForegroundColor Red
    }
}

function Patch-Verdent {
    Write-Host "`n[+] Repairing Verdent with safe runtime font injection..." -ForegroundColor Yellow
    $verdentExe = "C:\Program Files\Verdent\Verdent.exe"
    if (-not (Test-Path $verdentExe)) {
        Write-Host "  [-] Verdent not found at $verdentExe" -ForegroundColor DarkGray
        return
    }

    $launcher = Join-Path $PSScriptRoot "launch-verdent-pyidaungsu.ps1"
    if (-not (Test-Path $launcher)) {
        Write-Host "  [!] Verdent runtime launcher not found." -ForegroundColor Red
        return
    }

    try {
        $result = & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $launcher -Once
        if ($result -match '"marker":true' -and $result -match 'Pyidaungsu') {
            Write-Host "  [OK] Verdent launched and live renderer verified with Pyidaungsu." -ForegroundColor Green
        } else {
            throw "Unexpected verification result: $result"
        }
    }
    catch {
        Write-Host "  [!] Verdent runtime repair failed: $($_.Exception.Message)" -ForegroundColor Red
    }
}

function Restart-Explorer {
    Write-Host "`n[*] Restarting Windows Explorer to apply environment variable updates..." -ForegroundColor Yellow
    Stop-Process -Name explorer -Force -ErrorAction SilentlyContinue
    Write-Host "[OK] Explorer restarted! Environment variables refreshed." -ForegroundColor Green
}

function Install-FontSystemWide {
    Write-Host "[*] Checking and copying Pyidaungsu font to Windows system directory..." -ForegroundColor Yellow
    
    $srcDir = Join-Path $env:LOCALAPPDATA 'Microsoft\Windows\Fonts'
    $destDir = Join-Path $env:SystemRoot 'Fonts'
    
    $regularFile = "Pyidaungsu-2.5_Regular.ttf"
    $boldFile = "Pyidaungsu-2.5_Bold.ttf"
    
    $srcRegular = Join-Path $srcDir $regularFile
    $srcBold = Join-Path $srcDir $boldFile
    
    $destRegular = Join-Path $destDir $regularFile
    $destBold = Join-Path $destDir $boldFile
    
    $copied = $false

    # Check if regular font already in Windows\Fonts
    if (-not (Test-Path $destRegular)) {
        if (Test-Path $srcRegular) {
            Copy-Item -Path $srcRegular -Destination $destDir -Force -ErrorAction SilentlyContinue
            if (Test-Path $destRegular) {
                Write-Host "  [OK] Copied $regularFile to system Fonts." -ForegroundColor Green
                $copied = $true
            } else {
                Write-Host "  [!] Failed to copy $regularFile. Run as Administrator." -ForegroundColor Red
                return $false
            }
        } else {
            Write-Host "  [!] Source regular font not found: $srcRegular" -ForegroundColor Red
            return $false
        }
    } else {
        Write-Host "  [-] $regularFile already exists in system Fonts." -ForegroundColor Gray
        $copied = $true
    }
    
    # Check if bold font already in Windows\Fonts
    if (-not (Test-Path $destBold)) {
        if (Test-Path $srcBold) {
            Copy-Item -Path $srcBold -Destination $destDir -Force -ErrorAction SilentlyContinue
            if (Test-Path $destBold) {
                Write-Host "  [OK] Copied $boldFile to system Fonts." -ForegroundColor Green
            }
        }
    }
    
    # Register in HKLM
    Write-Host "[*] Registering font in HKLM Registry..." -ForegroundColor Yellow
    $regFonts = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Fonts"
    
    $currReg = Get-ItemProperty -Path $regFonts -Name "Pyidaungsu (TrueType)" -ErrorAction SilentlyContinue
    if (-not $currReg) {
        Set-ItemProperty -Path $regFonts -Name "Pyidaungsu (TrueType)" -Value $regularFile -Type String -ErrorAction SilentlyContinue
    }
    
    $currRegBold = Get-ItemProperty -Path $regFonts -Name "Pyidaungsu Bold (TrueType)" -ErrorAction SilentlyContinue
    if (-not $currRegBold) {
        Set-ItemProperty -Path $regFonts -Name "Pyidaungsu Bold (TrueType)" -Value $boldFile -Type String -ErrorAction SilentlyContinue
    }
    
    Write-Host "  [OK] Font registration verified." -ForegroundColor Green
    return $true
}

function Patch-FontLinking {
    Write-Host "`n[+] Configuring System-wide Windows Font Linking (SystemLink)..." -ForegroundColor Yellow
    
    # Check if running as Admin
    $isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
    if (-not $isAdmin) {
        Write-Host "[!] ERROR: Registry modification requires Administrator privileges." -ForegroundColor Red
        Write-Host "    Please run the 'Run-Repair-Font.bat' file by right-clicking it and choosing 'Run as Administrator'." -ForegroundColor Red
        return
    }

    # First install font system-wide
    $ok = Install-FontSystemWide
    if (-not $ok) {
        Write-Host "[!] System font installation failed. Aborting Font Linking." -ForegroundColor Red
        return
    }

    $fontsToLink = @(
        "Consolas", "Segoe UI", "Segoe UI Semibold", "Segoe UI Bold", "Segoe UI Light", "Segoe UI Semilight", 
        "Courier New", "Microsoft YaHei", "Microsoft YaHei UI", "Microsoft YaHei Bold", "Microsoft YaHei UI Bold",
        "Arial", "Tahoma", "MS Gothic", "MS PGothic"
    )

    $pyiValue = "Pyidaungsu-2.5_Regular.ttf,Pyidaungsu"
    $oldPyiValue = (Join-Path $env:LOCALAPPDATA 'Microsoft\Windows\Fonts\Pyidaungsu-2.5_Regular.ttf') + ',Pyidaungsu'
    $regPath = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\FontLink\SystemLink"

    foreach ($font in $fontsToLink) {
        $current = Get-ItemProperty -Path $regPath -Name $font -ErrorAction SilentlyContinue
        if ($current) {
            $values = $current.$font
            # Filter out any old values or duplicates
            $filteredValues = $values | Where-Object { $_ -ne $pyiValue -and $_ -ne $oldPyiValue }
            
            # Prepend the correct one
            $newValues = @($pyiValue) + $filteredValues
            Set-ItemProperty -Path $regPath -Name $font -Value $newValues -Type MultiString
            Write-Host "  [OK] Linked Pyidaungsu to $font (prepended)" -ForegroundColor Green
        } else {
            Set-ItemProperty -Path $regPath -Name $font -Value @($pyiValue) -Type MultiString
            Write-Host "  [OK] Created new link: Pyidaungsu to $font" -ForegroundColor Green
        }
    }
    $global:needsRestart = $true
    Write-Host "`n[!] System-wide Font Linking completed! You MUST restart your PC to apply these changes." -ForegroundColor Yellow
}

# --- Action Selection Logic ---

function Run-AutoDetect {
    Write-Host "[*] Querying application patch status..." -ForegroundColor Cyan
    $statusJson = node $statusScript
    
    # Parse status
    try {
        $status = $statusJson | ConvertFrom-Json
    } catch {
        Write-Host "[!] Failed to query patch status. Running all patches instead." -ForegroundColor Red
        Run-AllPatches
        return
    }

    $toPatch = @()
    
    if ($status.antigravity.installed -and -not $status.antigravity.patched) { $toPatch += "antigravity" }
    if ($status.opencode.installed -and -not $status.opencode.patched) { $toPatch += "opencode" }
    if ($status.jan.installed -and -not $status.jan.patched) { $toPatch += "jan" }
    if ($status.monkeycode.installed -and -not $status.monkeycode.patched) { $toPatch += "monkeycode" }
    if ($status.vscode.installed -and -not $status.vscode.patched) { $toPatch += "vscode" }
    if ($status.zed.installed -and -not $status.zed.patched) { $toPatch += "zed" }
    if ($status.verdent.installed -and -not $status.verdent.patched) { $toPatch += "verdent" }

    Write-Host "`n=== Auto-Detect Results ===" -ForegroundColor Cyan
    Write-Host "  Antigravity:       Installed=$($status.antigravity.installed), Patched=$($status.antigravity.patched)"
    Write-Host "  OpenCode:          Installed=$($status.opencode.installed), Patched=$($status.opencode.patched)"
    Write-Host "  Jan AI:            Installed=$($status.jan.installed), Patched=$($status.jan.patched)"
    Write-Host "  MonkeysCode:       Installed=$($status.monkeycode.installed), Patched=$($status.monkeycode.patched)"
    Write-Host "  VS Code:           Installed=$($status.vscode.installed), Patched=$($status.vscode.patched)"
    Write-Host "  Zed:               Installed=$($status.zed.installed), Patched=$($status.zed.patched)"

    if ($toPatch.Count -eq 0) {
        Write-Host "`n[OK] All installed applications are already patched! No updates needed." -ForegroundColor Green
        return
    }

    Write-Host "`n[*] The following unpatched applications will be updated: $($toPatch -join ', ')" -ForegroundColor Yellow
    
    foreach ($app in $toPatch) {
        switch ($app) {
            "antigravity" { Patch-Antigravity }
            "opencode"    { Patch-OpenCode }
            "jan"         { Patch-Jan }
            "monkeycode"  { Patch-MonkeyCode }
            "vscode"      { Patch-VSCode }
            "zed"         { Patch-Zed }
            "verdent"     { Patch-Verdent }
        }
    }
    
    # MonkeyCode uses a process-scoped launcher; Explorer restart is not needed.
}

function Run-AllPatches {
    Write-Host "[*] Patching all installed applications..." -ForegroundColor Yellow
    Patch-Antigravity
    Patch-MonkeyCode
    Patch-OpenCode
    Patch-Jan
    Patch-VSCode
    Patch-ZCode
    Patch-Zed
    Patch-Verdent
    # No Explorer restart: it would unnecessarily interrupt unrelated apps.
}

function Run-ManualSelection {
    function Invoke-ManualChoice([string]$choice){
        switch($choice){
            '1' { Patch-Antigravity }
            '2' { Patch-MonkeyCode }
            '3' { Patch-OpenCode }
            '4' { Patch-Jan }
            '5' { Patch-VSCode }
            '6' { Patch-ZCode }
            '7' { Patch-Zed }
            '8' { Patch-Verdent }
            '9' { Restart-Explorer }
            '10' { Patch-FontLinking }
            '11' { Start-Process wscript.exe -ArgumentList ('"' + (Join-Path $PSScriptRoot 'launch-monkeycode-pyidaungsu.vbs') + '"') }
            'A' { Run-AllPatches }
        }
    }
    $manualItems=@(
        [pscustomobject]@{Key='1';Label='Antigravity'},
        [pscustomobject]@{Key='2';Label='MonkeysCode IDE (CSS + Settings Patch)'},
        [pscustomobject]@{Key='3';Label='OpenCode'},
        [pscustomobject]@{Key='4';Label='Jan AI'},
        [pscustomobject]@{Key='5';Label='VS Code / Kilo Code / Cline Font'},
        [pscustomobject]@{Key='6';Label='ZCode'},
        [pscustomobject]@{Key='7';Label='Zed Editor'},
        [pscustomobject]@{Key='8';Label='Verdent (app.asar Patch)'},
        [pscustomobject]@{Key='9';Label='Restart Windows Explorer (manual only)'},
        [pscustomobject]@{Key='10';Label='System-wide Font Linking (optional; Admin + restart)'},
        [pscustomobject]@{Key='11';Label='MonkeyCode Desktop (NOT IDE) - Pyidaungsu launcher'},
        [pscustomobject]@{Key='A';Label='Patch All Applications'},
        [pscustomobject]@{Key='M';Label='Multi-select numbers (example: 1,3,8)'},
        [pscustomobject]@{Key='B';Label='Back to Legacy menu'},
        [pscustomobject]@{Key='Q';Label='Quit Font Fix'}
    )
    while($true){
        $selection=Select-FontMenu -Items $manualItems -Title 'LEGACY REPAIRS - MANUAL SELECTION' -EscapeValue B
        if($selection -eq 'B'){return 'Back'}
        if($selection -eq 'Q'){return 'Quit'}
        switch($selection){
            'M' {
                $multi=(Read-Host 'Numbers separated by commas (example: 1,3,8)').Trim()
                foreach($entry in ($multi -split ',')){
                    $manual=$entry.Trim()
                    if($manual -match '^(?:[1-9]|10|11)$'){Invoke-ManualChoice $manual}
                    elseif($manual){Write-Host "Skipped invalid item: $manual" -ForegroundColor Red}
                }
            }
            default {Invoke-ManualChoice $selection}
        }
        if((Wait-FontMenuResult) -eq 'Quit'){return 'Quit'}
    }
}

# --- Main Flow ---
$global:needsRestart = $false
$legacyItems=@(
    [pscustomobject]@{Key='1';Label='Auto-Detect & Patch updated apps (Recommended)'},
    [pscustomobject]@{Key='2';Label='Manual Application Selection'},
    [pscustomobject]@{Key='3';Label='System-wide Font Linking (optional; Admin + restart)'},
    [pscustomobject]@{Key='A';Label='Patch All Applications'},
    [pscustomobject]@{Key='B';Label='Back to Main menu'},
    [pscustomobject]@{Key='Q';Label='Quit Font Fix'}
)
$quitLegacy=$false
:legacyLoop while(-not $quitLegacy){
    $mode=Select-FontMenu -Items $legacyItems -Title 'LEGACY MYANMAR FONT REPAIRS' -EscapeValue B
    if($mode -eq 'B'){break legacyLoop}
    if($mode -eq 'Q'){$quitLegacy=$true;break legacyLoop}
    if($mode -eq '2'){
        if((Run-ManualSelection) -eq 'Quit'){$quitLegacy=$true;break legacyLoop}
        continue legacyLoop
    }
    switch($mode){
        '1' {Run-AutoDetect}
        '3' {Patch-FontLinking}
        'A' {Run-AllPatches}
    }
    if($mode -eq 'B' -or $quitLegacy){break}
    if((Wait-FontMenuResult) -eq 'Quit'){$quitLegacy=$true}
}

if ($global:needsRestart) {
    Write-Host ""
    Write-Host "==========================================================" -ForegroundColor Yellow
    Write-Host "   SYSTEM RESTART REQUIRED                                " -ForegroundColor Yellow
    Write-Host "==========================================================" -ForegroundColor Yellow
    Write-Host "System-wide Font Linking was applied. A PC restart is"
    Write-Host "required for these settings to take effect."
    Write-Host ""
    $restartNow = Read-Host "Would you like to restart your PC now? (Y/N)"
    if ($restartNow.ToUpper().Trim() -eq 'Y') {
        Write-Host "Restarting PC in 5 seconds... Please save all your work!" -ForegroundColor Red
        Start-Sleep -Seconds 5
        Restart-Computer -Force
    }
}
if($quitLegacy -and $ParentMenu){exit 20}
