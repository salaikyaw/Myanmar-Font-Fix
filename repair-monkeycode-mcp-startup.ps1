# MonkeyCode recovery: remove stale MCP startup blockers without touching credentials.
$ErrorActionPreference = 'Stop'

$root = 'C:\Users\salai\AppData\Roaming\com.chaitin.baizhi.monkeycode'
$mcpPath = Join-Path $root 'ohmyagent\mcp.json'
$configPath = Join-Path $root 'config.json'

foreach ($path in @($mcpPath, $configPath)) {
    if (-not (Test-Path -LiteralPath $path)) {
        throw "Required MonkeyCode configuration was not found: $path"
    }
}

$mcp = Get-Content -LiteralPath $mcpPath -Raw | ConvertFrom-Json -AsHashtable
$config = Get-Content -LiteralPath $configPath -Raw | ConvertFrom-Json -AsHashtable

# Preserve the previous definitions in the dated backup. MonkeyCode starts every
# configured MCP before the first reply; the stale list was entirely failing.
$mcp.servers = @()
$config.mcp_servers = [ordered]@{}

$mcp | ConvertTo-Json -Depth 20 | Set-Content -LiteralPath $mcpPath -Encoding utf8
$config | ConvertTo-Json -Depth 20 | Set-Content -LiteralPath $configPath -Encoding utf8

# Only remove the legacy MonkeyCode extension argument. It was written to the
# user-wide WebView2 environment and consequently leaked into unrelated apps.
$legacyExtension = 'C:\SK_AI\projects\agents-workspace\codex\myanmar-font-fix\monkeycode-extension'
$userArgument = [Environment]::GetEnvironmentVariable('WEBVIEW2_ADDITIONAL_BROWSER_ARGUMENTS', 'User')
if ($userArgument -and $userArgument.Contains($legacyExtension)) {
    [Environment]::SetEnvironmentVariable('WEBVIEW2_ADDITIONAL_BROWSER_ARGUMENTS', $null, 'User')
}

[pscustomobject]@{
    ActiveMcpServers = @($mcp.servers).Count
    LegacyGlobalWebViewArgumentRemoved = [bool]($userArgument -and $userArgument.Contains($legacyExtension))
} | ConvertTo-Json -Compress
