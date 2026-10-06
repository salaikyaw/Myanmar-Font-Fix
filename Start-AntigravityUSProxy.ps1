[CmdletBinding()]
param(
    [switch]$Restart
)

$ErrorActionPreference = 'Stop'

$root = Split-Path -Parent $PSCommandPath
$sidecar = Join-Path $root 'Start-AntigravityHiddifySidecar.ps1'
$antigravityExe = Join-Path $env:LOCALAPPDATA 'Programs\antigravity\Antigravity.exe'
$proxyArgument = '--proxy-server=socks5://127.0.0.1:12334'

if (-not (Test-Path -LiteralPath $sidecar)) { throw "Hiddify sidecar launcher is missing: $sidecar" }
if (-not (Test-Path -LiteralPath $antigravityExe)) { throw "Antigravity is not installed: $antigravityExe" }

& $sidecar -WaitForReady

$existing = Get-Process -Name 'Antigravity' -ErrorAction SilentlyContinue
if ($existing -and -not $Restart) {
    throw 'Antigravity is already running without this launcher. Re-run with -Restart to apply the app-only US proxy.'
}
if ($existing -and $Restart) {
    $main = $existing | Where-Object { $_.MainWindowHandle -ne 0 } | Select-Object -First 1
    if ($main) { [void]$main.CloseMainWindow(); Start-Sleep -Seconds 5 }
    $remaining = Get-Process -Name 'Antigravity' -ErrorAction SilentlyContinue
    if ($remaining) { $remaining | Stop-Process -Force }
    Start-Sleep -Seconds 2
}

Start-Process -FilePath $antigravityExe -ArgumentList @($proxyArgument)
Write-Output 'ANTIGRAVITY_LAUNCHED_WITH_APP_ONLY_US_PROXY=True'
Write-Output 'GLOBAL_WINDOWS_PROXY_CHANGED=False'
