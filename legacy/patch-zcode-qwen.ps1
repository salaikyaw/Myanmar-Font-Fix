#Requires -RunAsAdministrator
$ErrorActionPreference = 'Stop'
$root = $PSScriptRoot
$backup = Join-Path $root 'backups\2026-08-05'
$patcher = Join-Path $root 'patch-asar-font.js'
New-Item -ItemType Directory -Path $backup -Force | Out-Null

$apps = @(
  @{
    Name = 'ZCode';
    Archive = 'C:\Program Files\ZCode\resources\app.asar';
    Backup = Join-Path $backup 'ZCode-3.6.5-app.asar';
    UnpackDir = 'node_modules/{node-pty,ssh2}'
  },
  @{
    Name = 'Qwen';
    Archive = 'C:\Program Files\Qwen\resources\app.asar';
    Backup = Join-Path $backup 'Qwen-1.0.3-app.asar';
    UnpackDir = ''
  }
)

foreach ($app in $apps) {
  Get-Process $app.Name -ErrorAction SilentlyContinue | Stop-Process -Force
  if (-not (Test-Path $app.Backup)) { Copy-Item $app.Archive $app.Backup }
  & node $patcher $app.Archive 'out\renderer\index.html' $app.UnpackDir
  if ($LASTEXITCODE -ne 0) { throw "Failed to patch $($app.Name)" }
}

Write-Output 'PATCHED=ZCode,Qwen'
