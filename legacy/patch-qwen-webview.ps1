#Requires -RunAsAdministrator
$ErrorActionPreference = 'Stop'
Get-Process Qwen -ErrorAction SilentlyContinue | Stop-Process -Force
& node (Join-Path $PSScriptRoot 'patch-qwen-webview.js')
if ($LASTEXITCODE -ne 0) { throw 'Qwen webview font patch failed' }
Write-Output 'PATCHED=QwenWebview'
