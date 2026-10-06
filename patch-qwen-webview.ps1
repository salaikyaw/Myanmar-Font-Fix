#Requires -RunAsAdministrator
$ErrorActionPreference = 'Stop'
Get-Process Qwen -ErrorAction SilentlyContinue | Stop-Process -Force
& node 'C:\SK_AI\projects\agents-workspace\codex\myanmar-font-fix\patch-qwen-webview.js'
if ($LASTEXITCODE -ne 0) { throw 'Qwen webview font patch failed' }
Write-Output 'PATCHED=QwenWebview'
