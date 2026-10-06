$ErrorActionPreference = 'Stop'
$timestamp = Get-Date -Format 'yyyyMMdd-HHmmss'
$config = "$env:USERPROFILE\.config\opencode\opencode.json"
$archive = "$env:LOCALAPPDATA\Programs\@opencode-aidesktop\resources\app.asar"
$backupDir = "C:\SK_AI\projects\agents-workspace\codex\myanmar-font-fix\backups\2026-08-11"
$patcher = 'C:\SK_AI\projects\agents-workspace\codex\myanmar-font-fix\patch-asar-font.js'

New-Item -ItemType Directory -Path $backupDir -Force | Out-Null
Copy-Item $config (Join-Path $backupDir "opencode.json.$timestamp.bak")
Copy-Item $archive (Join-Path $backupDir "OpenCode-1.18.16-app.asar.$timestamp.bak")

$raw = Get-Content $config -Raw
$parts = [regex]::Split($raw, '(?m)^\s*\{\s*\r?\n\s*"mcpServers"\s*:', 2)
if ($parts.Count -ne 2) { throw 'Expected the appended mcpServers document was not found' }
$primary = $parts[0].TrimEnd()
$json = $primary | ConvertFrom-Json

$desktopCommander = [pscustomobject]@{
  type = 'local'
  command = @('npx', '-y', '@wonderwhy-er/desktop-commander@latest')
  enabled = $true
}
$json.mcp | Add-Member -NotePropertyName 'desktop-commander' -NotePropertyValue $desktopCommander -Force

foreach ($name in @('localserver_core','localserver_coding','localserver_automation','localserver_collaboration','localserver_data','localserver_research','localserver_cloud','localserver_system')) {
  $entry = $json.mcp.$name
  if ($entry -and $entry.headers) {
    $entry.headers.Authorization = 'Bearer {env:MCP_GATEWAY_AUTH_TOKEN}'
  }
}

$json | ConvertTo-Json -Depth 32 | Set-Content $config -Encoding utf8
$null = Get-Content $config -Raw | ConvertFrom-Json

Get-Process OpenCode -ErrorAction SilentlyContinue | Stop-Process -Force
& node $patcher $archive 'out\renderer\index.html' 'node_modules/{@lydell,@msgpackr-extract,@parcel,msgpackr-extract}'
if ($LASTEXITCODE -ne 0) { throw 'OpenCode ASAR font patch failed' }

Write-Output "REPAIRED_CONFIG=$config"
Write-Output "REPAIRED_FONT=$archive"
