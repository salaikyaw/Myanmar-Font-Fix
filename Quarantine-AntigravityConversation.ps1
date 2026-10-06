[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [ValidatePattern('^[0-9a-fA-F-]{36}$')]
    [string]$ConversationId
)

$ErrorActionPreference = 'Stop'

function Remove-ConversationReference {
    param($Value, [string]$Id)

    if ($Value -is [string]) {
        if ($Value.Contains($Id)) { return [pscustomobject]@{ Keep = $false; Value = $null } }
        return [pscustomobject]@{ Keep = $true; Value = $Value }
    }
    if ($Value -is [System.Collections.IDictionary]) {
        $out = [ordered]@{}
        foreach ($key in $Value.Keys) {
            if ([string]$key -like "*$Id*") { continue }
            $item = Remove-ConversationReference -Value $Value[$key] -Id $Id
            if ($item.Keep) { $out[$key] = $item.Value }
        }
        return [pscustomobject]@{ Keep = $true; Value = $out }
    }
    if (($Value -is [System.Collections.IEnumerable]) -and -not ($Value -is [string])) {
        $out = [System.Collections.Generic.List[object]]::new()
        foreach ($entry in $Value) {
            $item = Remove-ConversationReference -Value $entry -Id $Id
            if ($item.Keep) { [void]$out.Add($item.Value) }
        }
        return [pscustomobject]@{ Keep = $true; Value = @($out) }
    }
    return [pscustomobject]@{ Keep = $true; Value = $Value }
}

$appRoot = Join-Path $env:APPDATA 'Antigravity'
$storagePath = Join-Path $appRoot 'app_storage.json'
$brainPath = Join-Path $env:USERPROFILE ".gemini\antigravity\brain\$ConversationId"
$backupRoot = Join-Path $PSScriptRoot 'backups'
$stamp = Get-Date -Format 'yyyyMMdd-HHmmss'
$backupDir = Join-Path $backupRoot "$stamp-antigravity-conversation-quarantine-$ConversationId"

if (Get-Process Antigravity -ErrorAction SilentlyContinue) {
    throw 'Close Antigravity before quarantining its selected conversation state.'
}
if (-not (Test-Path -LiteralPath $storagePath)) { throw "App storage is missing: $storagePath" }
if (-not (Test-Path -LiteralPath $brainPath)) { throw "Conversation workspace is missing: $brainPath" }

$originalStorage = Get-Content -LiteralPath $storagePath -Raw
$storage = $originalStorage | ConvertFrom-Json -AsHashtable
foreach ($key in @('aux-pane-session', 'comments')) {
    if (-not $storage.ContainsKey($key)) { continue }
    $raw = $storage[$key]
    if ($raw -isnot [string] -or -not $raw.Contains($ConversationId)) { continue }
    $parsed = $raw | ConvertFrom-Json -AsHashtable
    $clean = Remove-ConversationReference -Value $parsed -Id $ConversationId
    $storage[$key] = $clean.Value | ConvertTo-Json -Compress -Depth 100
}

$newStorage = $storage | ConvertTo-Json -Compress -Depth 100
if ($newStorage.Contains($ConversationId)) {
    throw 'Conversation reference remained in app storage after pruning; refusing to write.'
}

New-Item -ItemType Directory -Path $backupDir -Force | Out-Null
Copy-Item -LiteralPath $storagePath -Destination (Join-Path $backupDir 'app_storage.before-quarantine.json') -ErrorAction Stop
[System.IO.File]::WriteAllText($storagePath, $newStorage + [Environment]::NewLine, [System.Text.UTF8Encoding]::new($false))

$verified = Get-Content -LiteralPath $storagePath -Raw
if ($verified.Contains($ConversationId)) {
    Copy-Item -LiteralPath (Join-Path $backupDir 'app_storage.before-quarantine.json') -Destination $storagePath -Force
    throw 'App storage verification failed; original storage was restored.'
}

$workspaceTarget = Join-Path $backupDir "brain-$ConversationId"
Move-Item -LiteralPath $brainPath -Destination $workspaceTarget -ErrorAction Stop
if ((Test-Path -LiteralPath $brainPath) -or -not (Test-Path -LiteralPath $workspaceTarget)) {
    throw 'Conversation workspace move verification failed.'
}

Write-Output "QUARANTINED_CONVERSATION=$ConversationId"
Write-Output "BACKUP=$backupDir"
