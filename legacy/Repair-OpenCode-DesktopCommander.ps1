[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
$workspace = $PSScriptRoot
$patcher = Join-Path $workspace 'patch-asar-tray-font-v2.js'
$backupRoot = Join-Path $workspace 'backups'
$timestamp = Get-Date -Format 'yyyyMMdd-HHmmss'
$backupDir = Join-Path $backupRoot "$timestamp-opencode-dc-update-repair"
$node = (Get-Command node -ErrorAction Stop).Source
$projectRoot = Split-Path $PSScriptRoot -Parent
$asarModule = Join-Path $projectRoot 'node_modules\@electron\asar\lib\asar.js'
if(-not(Test-Path -LiteralPath $asarModule)){$asarModule=Join-Path $projectRoot 'vendor\node_modules\@electron\asar\lib\asar.js'}

if (-not (Test-Path -LiteralPath $patcher)) { throw "Patcher missing: $patcher" }
if (-not (Test-Path -LiteralPath $asarModule)) { throw "@electron/asar runtime missing: $asarModule" }

$apps = @(
    [pscustomobject]@{ Name = 'OpenCode'; Kind = 'opencode'; Process = 'OpenCode'; Asar = "$env:LOCALAPPDATA\Programs\@opencode-aidesktop\resources\app.asar" },
    [pscustomobject]@{ Name = 'Desktop Commander'; Kind = 'desktopcommander'; Process = 'Desktop Commander'; Asar = "$env:LOCALAPPDATA\Programs\Desktop Commander Pyidaungsu\resources\app.asar" }
)

New-Item -ItemType Directory -Path $backupDir -Force | Out-Null
$env:SK_ASAR_MODULE = $asarModule
foreach ($item in $apps) {
    if (-not (Test-Path -LiteralPath $item.Asar)) { throw "$($item.Name) app.asar was not found: $($item.Asar)" }
    Get-Process -Name $item.Process -ErrorAction SilentlyContinue | Stop-Process -Force
    $backup = Join-Path $backupDir ("{0}.app.asar" -f $item.Kind)
    Copy-Item -LiteralPath $item.Asar -Destination $backup -Force
    & $node $patcher $item.Kind $item.Asar
    if ($LASTEXITCODE -ne 0) { throw "$($item.Name) patcher failed; original is retained at $backup" }
    Write-Output "REPAIRED=$($item.Name)"
    Write-Output "BACKUP=$backup"
}
Write-Output 'Completed. OpenCode and Desktop Commander: X hides to notification area; OpenCode supports --sk-start-in-tray.'
