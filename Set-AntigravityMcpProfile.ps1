[CmdletBinding()]
param(
    [ValidateSet('Minimal', 'LocalOnly', 'NoMcp')]
    [string]$Profile = 'Minimal'
)

$ErrorActionPreference = 'Stop'

# Antigravity 2.11 reads the documented mcp_config.json server map directly;
# an undocumented `disabled` member does not prevent an entry from starting.
# Keep a small, useful default set so chat is usable before optional services
# are deliberately re-added through Antigravity's MCP Servers UI.  In
# particular, Desktop Commander starts through `npx` and can sit in a
# network-dependent bootstrap/retry loop during startup.
$configPath = Join-Path $env:USERPROFILE '.gemini\config\mcp_config.json'
$backupRoot = Join-Path $PSScriptRoot 'backups'
$timestamp = Get-Date -Format 'yyyyMMdd-HHmmss'
$backupPath = Join-Path $backupRoot "Antigravity-mcp_config.$timestamp.full.bak.json"
$retain = switch ($Profile) {
    'NoMcp' { @() }
    'LocalOnly' { @('localserver_core') }
    default { @('fetch', 'localserver_core') }
}

if (-not (Test-Path -LiteralPath $configPath)) {
    throw "Antigravity MCP config was not found: $configPath"
}

$config = Get-Content -LiteralPath $configPath -Raw | ConvertFrom-Json
if ($null -eq $config.mcpServers) {
    throw "Antigravity MCP config has no mcpServers map: $configPath"
}

# A NoMcp rescue profile intentionally writes an empty map.  When an operator
# later selects a non-empty profile, recover the original entry definitions
# from the newest suitable local backup instead of requiring secrets or a
# manual reconfiguration in the UI.
$sourceConfig = $config
$missingFromCurrent = @($retain | Where-Object { $null -eq $config.mcpServers.PSObject.Properties[$_] })
if ($missingFromCurrent.Count -gt 0) {
    $candidate = Get-ChildItem -LiteralPath $backupRoot -Filter 'Antigravity-mcp_config.*.full.bak.json' -File -ErrorAction SilentlyContinue |
        Sort-Object LastWriteTime -Descending |
        ForEach-Object {
            try {
                $parsed = Get-Content -LiteralPath $_.FullName -Raw | ConvertFrom-Json
                $hasAll = @($retain | Where-Object { $null -eq $parsed.mcpServers.PSObject.Properties[$_] }).Count -eq 0
                if ($hasAll) { [pscustomobject]@{ Config = $parsed; Path = $_.FullName } }
            } catch {}
        } |
        Select-Object -First 1
    if ($null -eq $candidate) {
        throw "No local MCP backup contains the requested profile entries: $($retain -join ', ')"
    }
    $sourceConfig = $candidate.Config
}

$selected = [ordered]@{}
foreach ($name in $retain) {
    $entry = $sourceConfig.mcpServers.PSObject.Properties[$name]
    if ($null -ne $entry) {
        # Preserve the exact existing entry, including environment references
        # and headers.  No credential is printed, copied to a new location,
        # or embedded in this script.
        $selected[$name] = $entry.Value
    }
}

if ($selected.Count -ne $retain.Count) {
    $missing = $retain | Where-Object { -not $selected.Contains($_) }
    throw "Refusing to write a partial profile; expected entry/entries missing: $($missing -join ', ')"
}

New-Item -ItemType Directory -Path $backupRoot -Force | Out-Null
Copy-Item -LiteralPath $configPath -Destination $backupPath -Force

$replacement = [ordered]@{ mcpServers = $selected }
$json = $replacement | ConvertTo-Json -Depth 32
[System.IO.File]::WriteAllText($configPath, $json + [Environment]::NewLine, [System.Text.UTF8Encoding]::new($false))

# Re-parse the exact output before reporting success.
$verified = Get-Content -LiteralPath $configPath -Raw | ConvertFrom-Json
$actual = @($verified.mcpServers.PSObject.Properties | ForEach-Object { $_.Name })
if (($actual.Count -ne $retain.Count) -or (@($retain | Where-Object { $_ -notin $actual }).Count -ne 0)) {
    throw 'Antigravity MCP profile verification failed after write.'
}

Write-Output "APPLIED_PROFILE=$Profile"
Write-Output "ACTIVE_MCP_COUNT=$($actual.Count)"
Write-Output "BACKUP=$backupPath"
