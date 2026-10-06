[CmdletBinding()]
param(
    [switch]$WaitForReady
)

$ErrorActionPreference = 'Stop'

# Reuse Hiddify's already-selected local profile without copying its private
# subscription data.  The generated sing-box config exposes only loopback
# proxy listeners and leaves Windows' global proxy settings untouched.
$hiddifyRoot = Join-Path $env:APPDATA 'Hiddify\hiddify'
$hiddifyCli = 'C:\Program Files\Hiddify\HiddifyCli.exe'
$configPath = Join-Path $hiddifyRoot 'data\current-config.json'
$port = 12334
$logRoot = Join-Path $env:LOCALAPPDATA 'AntigravityEgress'
$stdoutPath = Join-Path $logRoot 'hiddify-sidecar.out.log'
$stderrPath = Join-Path $logRoot 'hiddify-sidecar.err.log'

if (-not (Test-Path -LiteralPath $hiddifyCli)) { throw "Hiddify CLI not found: $hiddifyCli" }
if (-not (Test-Path -LiteralPath $configPath)) { throw "Hiddify generated config not found: $configPath" }

$listener = Get-NetTCPConnection -State Listen -LocalAddress '127.0.0.1' -LocalPort $port -ErrorAction SilentlyContinue | Select-Object -First 1
if ($null -eq $listener) {
    New-Item -ItemType Directory -Path $logRoot -Force | Out-Null
    Start-Process -FilePath $hiddifyCli `
        -ArgumentList @('-D', $hiddifyRoot, 'srun', '-c', $configPath) `
        -WorkingDirectory $hiddifyRoot `
        -WindowStyle Hidden `
        -RedirectStandardOutput $stdoutPath `
        -RedirectStandardError $stderrPath
}

if ($WaitForReady) {
    $deadline = (Get-Date).AddSeconds(20)
    do {
        Start-Sleep -Milliseconds 500
        $listener = Get-NetTCPConnection -State Listen -LocalAddress '127.0.0.1' -LocalPort $port -ErrorAction SilentlyContinue | Select-Object -First 1
    } while ($null -eq $listener -and (Get-Date) -lt $deadline)
}

$listener = Get-NetTCPConnection -State Listen -LocalAddress '127.0.0.1' -LocalPort $port -ErrorAction SilentlyContinue | Select-Object -First 1
if ($null -eq $listener) { throw "Hiddify loopback proxy did not listen on 127.0.0.1:$port" }

Write-Output "HIDDIFY_PROXY_READY=127.0.0.1:$port"
Write-Output "HIDDIFY_PROXY_PID=$($listener.OwningProcess)"
