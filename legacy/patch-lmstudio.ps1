#Requires -RunAsAdministrator
$ErrorActionPreference = 'Stop'
$path = Join-Path $env:ProgramFiles 'LM Studio\resources\app\.webpack\renderer\index.html'
$backupDir = Join-Path $PSScriptRoot ('backups\lmstudio-' + (Get-Date -Format yyyyMMdd))
$backup = Join-Path $backupDir 'LM-Studio-0.4.20-index.html'
$marker = 'sk-pyidaungsu-font-fix'
$style = @'
<style id="sk-pyidaungsu-font-fix">
html, body, input, textarea, button, [contenteditable="true"], [role="textbox"] {
  font-family: "Pyidaungsu", "Myanmar Text", "Noto Sans Myanmar", system-ui, sans-serif !important;
}
pre, code, kbd, samp, .monaco-editor, .xterm {
  font-family: "Cascadia Mono", Consolas, monospace !important;
}
</style>
'@
New-Item -ItemType Directory -Path $backupDir -Force | Out-Null
if (-not (Test-Path $backup)) { Copy-Item $path $backup }
$html = Get-Content $path -Raw
if ($html -notmatch $marker) {
  $html = $html.Replace('<head>', "<head>$style")
  [System.IO.File]::WriteAllText($path, $html, [System.Text.UTF8Encoding]::new($false))
}
Write-Output "PATCHED=$path"
