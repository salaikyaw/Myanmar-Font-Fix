$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$app = Join-Path $env:LOCALAPPDATA 'MonkeyCode\monkeycode-desktop.exe'
$injector = Join-Path $PSScriptRoot 'inject-monkeycode-pyidaungsu.js'
$node = (Get-Command node.exe -ErrorAction Stop).Source

if (-not (Test-Path -LiteralPath $app)) { throw "MonkeyCode executable was not found: $app" }
if (-not (Test-Path -LiteralPath $injector)) { throw "MonkeyCode font injector was not found: $injector" }
if (-not (Test-Path -LiteralPath $node)) { throw "Node.js was not found: $node" }

# Scope CDP to this MonkeyCode launch only.  It listens on loopback and is never
# written to the user-wide WEBVIEW2_ADDITIONAL_BROWSER_ARGUMENTS environment value.
$createdNew = $false
$guard = [Threading.Mutex]::new($true, 'Local\MonkeyCodeDesktopPyidaungsu', [ref]$createdNew)
if (-not $createdNew) { $guard.Dispose(); exit 0 }
try {
    $ready = $false
    try {
        $targets = Invoke-RestMethod 'http://127.0.0.1:9231/json/list' -TimeoutSec 2
        $ready = @($targets | Where-Object { $_.url -like 'http://tauri.localhost/*' }).Count -gt 0
    } catch {}
    if (-not $ready) {
        # Recent builds clear inherited WebView2 arguments. Use the documented
        # executable-specific override, never the '*' / all-applications value.
        $policy = 'HKCU:\Software\Policies\Microsoft\Edge\WebView2\AdditionalBrowserArguments'
        New-Item -Path $policy -Force | Out-Null
        New-ItemProperty -Path $policy -Name 'monkeycode-desktop.exe' -PropertyType String -Value '--remote-debugging-address=127.0.0.1 --remote-debugging-port=9231' -Force | Out-Null
        Get-Process monkeycode-desktop -ErrorAction SilentlyContinue | Stop-Process
        Start-Sleep -Seconds 1
        $env:WEBVIEW2_ADDITIONAL_BROWSER_ARGUMENTS = '--remote-debugging-address=127.0.0.1 --remote-debugging-port=9231'
        Start-Process -FilePath $app -WorkingDirectory (Split-Path $app) -ArgumentList '"--edge-webview-switches=--remote-debugging-port=9231 --remote-debugging-address=127.0.0.1"'
    }
    & $node $injector 9231
} finally { $guard.ReleaseMutex(); $guard.Dispose() }
