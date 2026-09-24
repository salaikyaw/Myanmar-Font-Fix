$ErrorActionPreference = 'Stop'

$extensionsRoot = Join-Path $env:USERPROFILE '.vscode\extensions'
$backupRoot = Join-Path $PSScriptRoot 'backups'
$marker = 'sk-pyidaungsu-cline-font-v2'
$fontCss = @'

/* sk-pyidaungsu-cline-font-v2 */
:root {
  --vscode-font-family: "Pyidaungsu", "Myanmar Text", "Noto Sans Myanmar", system-ui, sans-serif;
  --font-sans: "Pyidaungsu", "Myanmar Text", "Noto Sans Myanmar", system-ui, sans-serif;
  --default-font-family: "Pyidaungsu", "Myanmar Text", "Noto Sans Myanmar", system-ui, sans-serif;
}
html, body,
body *:not(svg):not(path):not([class*="codicon"]):not(i[class*="icon"]),
input, textarea, button, select,
[contenteditable="true"], [role="textbox"],
[class*="markdown"], [class*="markdown"] *,
[class*="message"], [class*="message"] * {
  font-family: "Pyidaungsu", "Myanmar Text", "Noto Sans Myanmar", system-ui, sans-serif !important;
  font-variant-ligatures: normal !important;
}
pre, pre *, code, code *, kbd, samp,
.monaco-editor, .monaco-editor *, .xterm, .xterm * {
  font-family: var(--vscode-editor-font-family, "JetBrains Mono", Consolas, monospace) !important;
}
.codicon, [class*="codicon"], i[class*="icon"] {
  font-family: codicon !important;
}
'@

$cline = Get-ChildItem -LiteralPath $extensionsRoot -Directory -Filter 'saoudrizwan.claude-dev-*' |
    Sort-Object LastWriteTime -Descending |
    Select-Object -First 1
if (-not $cline) { throw "Cline extension was not found under $extensionsRoot" }

$cssFiles = @(
    (Join-Path $cline.FullName 'legacy\webview-ui\build\assets\index.css')
    (Join-Path $cline.FullName 'next\webview-ui\build\assets\index.css')
) | Where-Object { Test-Path -LiteralPath $_ }
if ($cssFiles.Count -eq 0) { throw "Cline WebView CSS was not found in $($cline.FullName)" }

$stamp = Get-Date -Format 'yyyyMMdd-HHmmss'
$backupDir = Join-Path $backupRoot "$stamp-cline-$($cline.Name)"
$changed = 0
foreach ($cssFile in $cssFiles) {
    $content = Get-Content -LiteralPath $cssFile -Raw
    if ($content.Contains($marker)) {
        Write-Host "[OK] Already patched: $cssFile" -ForegroundColor Green
        continue
    }
    New-Item -ItemType Directory -Path $backupDir -Force | Out-Null
    $bundle = if ($cssFile -match '\\legacy\\') { 'legacy' } else { 'next' }
    Copy-Item -LiteralPath $cssFile -Destination (Join-Path $backupDir "$bundle-index.css.before") -Force
    $oldPatch = '(?s)/\* sk-pyidaungsu-cline-font-v1 \*/.*\z'
    if ($content -match $oldPatch) {
        $updated = [regex]::Replace($content, $oldPatch, $fontCss)
        [IO.File]::WriteAllText($cssFile, $updated, [Text.UTF8Encoding]::new($false))
    } else {
        Add-Content -LiteralPath $cssFile -Value $fontCss -Encoding utf8
    }
    $changed++
    Write-Host "[OK] Patched Cline $bundle WebView: $cssFile" -ForegroundColor Green
}

if ($changed -gt 0) {
    Write-Host "[OK] Backup: $backupDir" -ForegroundColor Green
    Write-Host '[!] Run Developer: Reload Window in VS Code.' -ForegroundColor Yellow
}
