[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
$root = $PSScriptRoot
$projectRoot = Split-Path $PSScriptRoot -Parent
$asarModule = Join-Path $projectRoot 'node_modules\@electron\asar\lib\asar.js'
if(-not(Test-Path -LiteralPath $asarModule)){$asarModule=Join-Path $projectRoot 'vendor\node_modules\@electron\asar\lib\asar.js'}
$asarPath = Join-Path $env:LOCALAPPDATA 'Programs\antigravity\resources\app.asar'

if (Get-Process Antigravity -ErrorAction SilentlyContinue) {
    throw 'Close Antigravity first. No archive was changed.'
}
if (-not (Test-Path -LiteralPath $asarModule)) { throw "ASAR module is unavailable: $asarModule" }
if (-not (Test-Path -LiteralPath $asarPath)) { throw "Antigravity archive is unavailable: $asarPath" }

$env:ASAR_MODULE = $asarModule
$env:AGY_ASAR = $asarPath
$env:AGY_BACKUP_ROOT = Join-Path $root 'backups'

# New app versions need the scoped Myanmar/local-HTTPS patch first. Existing
# patched versions return ALREADY_PATCHED and remain untouched.
$fontOutput = & node (Join-Path $root 'patch-antigravity-font.js') 2>&1
$fontOutput | ForEach-Object { Write-Output $_ }
if ($LASTEXITCODE -ne 0) { throw 'Base Antigravity font patch failed.' }

# A fresh base patch intentionally starts with the broad compatibility rule;
# immediately narrow it so long chats do not restyle every virtualized node.
if ($fontOutput -match 'PATCHED_SUCCESSFULLY') {
    & node (Join-Path $root 'repair-antigravity-font-performance.js')
    if ($LASTEXITCODE -ne 0) { throw 'Font performance repair failed.' }
}

& node (Join-Path $root 'Install-AntigravityConversationGuard.js')
if ($LASTEXITCODE -ne 0) { throw 'Conversation click guard installation failed.' }
& node (Join-Path $root 'Upgrade-AntigravityConversationGuard.js')
if ($LASTEXITCODE -ne 0) { throw 'Conversation route guard installation failed.' }

Write-Output 'ANTIGRAVITY_UPDATE_REPAIR_COMPLETE'
