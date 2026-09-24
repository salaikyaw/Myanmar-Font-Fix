[CmdletBinding()]
param(
    [int]$Port = 9237,
    [switch]$Once
)

$ErrorActionPreference = 'Stop'
$sourceDir = 'C:\Program Files\Verdent'
$localDir = Join-Path $env:LOCALAPPDATA 'Programs\Verdent-Pyidaungsu'
$localExe = Join-Path $localDir 'Verdent.exe'
$styleId = 'sk-pyidaungsu-verdent-runtime'

function Get-Version([string]$Path) {
    if (-not (Test-Path -LiteralPath $Path)) { return $null }
    return (Get-Item -LiteralPath $Path).VersionInfo.ProductVersion
}

function Sync-VerdentCopy {
    $sourceExe = Join-Path $sourceDir 'Verdent.exe'
    if (-not (Test-Path -LiteralPath $sourceExe)) {
        throw "Verdent is not installed at $sourceDir"
    }

    $sourceVersion = Get-Version $sourceExe
    $localVersion = Get-Version $localExe
    $didSync = $false
    if ((-not $localVersion) -or ($sourceVersion -ne $localVersion)) {
        New-Item -ItemType Directory -Path $localDir -Force | Out-Null
        & robocopy.exe $sourceDir $localDir /E /COPY:DAT /DCOPY:DAT /R:2 /W:1 /NFL /NDL /NJH /NJS /NP | Out-Null
        if ($LASTEXITCODE -ge 8) {
            throw "Verdent update sync failed with robocopy exit code $LASTEXITCODE"
        }
        $didSync = $true
    }

    $localAsar = Join-Path $localDir 'resources\app.asar'
    $vendorAsar = Join-Path $localDir 'resources\app.asar.vendor'
    if ($didSync -or -not (Test-Path -LiteralPath $vendorAsar)) {
        Copy-Item -LiteralPath $localAsar -Destination $vendorAsar -Force
    }
    elseif ((Get-FileHash -LiteralPath $localAsar).Hash -ne (Get-FileHash -LiteralPath $vendorAsar).Hash) {
        Copy-Item -LiteralPath $vendorAsar -Destination $localAsar -Force
    }
}

function Invoke-CdpExpression([string]$WebSocketUrl, [string]$Expression) {
    $socket = [System.Net.WebSockets.ClientWebSocket]::new()
    try {
        $uri = [Uri]$WebSocketUrl
        $socket.ConnectAsync($uri, [Threading.CancellationToken]::None).GetAwaiter().GetResult()
        $request = @{
            id = 1
            method = 'Runtime.evaluate'
            params = @{
                expression = $Expression
                returnByValue = $true
                awaitPromise = $true
            }
        } | ConvertTo-Json -Compress -Depth 8
        $bytes = [Text.Encoding]::UTF8.GetBytes($request)
        $segment = [ArraySegment[byte]]::new($bytes)
        $socket.SendAsync($segment, [Net.WebSockets.WebSocketMessageType]::Text, $true, [Threading.CancellationToken]::None).GetAwaiter().GetResult()

        $buffer = New-Object byte[] 65536
        $response = [Text.StringBuilder]::new()
        do {
            $received = $socket.ReceiveAsync([ArraySegment[byte]]::new($buffer), [Threading.CancellationToken]::None).GetAwaiter().GetResult()
            [void]$response.Append([Text.Encoding]::UTF8.GetString($buffer, 0, $received.Count))
        } until ($received.EndOfMessage)
        return ($response.ToString() | ConvertFrom-Json)
    }
    finally {
        if ($socket.State -eq [Net.WebSockets.WebSocketState]::Open) {
            $socket.CloseAsync([Net.WebSockets.WebSocketCloseStatus]::NormalClosure, 'done', [Threading.CancellationToken]::None).GetAwaiter().GetResult()
        }
        $socket.Dispose()
    }
}

function Set-VerdentFont {
    $css = @'
html, body, body *:not(svg):not(path):not([class*="codicon"]):not([class*="icon"]):not(i) {
  font-family: Pyidaungsu, "Myanmar Text", "Noto Sans Myanmar", system-ui, sans-serif !important;
  font-variant-ligatures: normal !important;
}
pre, code, kbd, samp, .monaco-editor, .monaco-editor *, .xterm, .xterm * {
  font-family: "JetBrains Mono", "Cascadia Mono", Consolas, monospace !important;
}
'@
    $expression = @"
(() => {
  let style = document.getElementById('$styleId');
  if (!style) {
    style = document.createElement('style');
    style.id = '$styleId';
    (document.head || document.documentElement).appendChild(style);
  }
  style.textContent = $(ConvertTo-Json $css -Compress);
  return { marker: !!document.getElementById('$styleId'), font: getComputedStyle(document.body).fontFamily, title: document.title };
})()
"@

    $targets = Invoke-RestMethod -Uri "http://127.0.0.1:$Port/json" -TimeoutSec 2
    $results = foreach ($target in @($targets | Where-Object { $_.type -eq 'page' -and $_.webSocketDebuggerUrl })) {
        $response = Invoke-CdpExpression -WebSocketUrl $target.webSocketDebuggerUrl -Expression $expression
        $response.result.result.value
    }
    return @($results)
}

Sync-VerdentCopy

$main = Get-CimInstance Win32_Process -Filter "Name='Verdent.exe'" -ErrorAction SilentlyContinue |
    Where-Object { $_.ExecutablePath -eq $localExe -and $_.CommandLine -match "remote-debugging-port=$Port" } |
    Select-Object -First 1
if (-not $main) {
    # Verdent enforces a cross-install single-instance lock. After an update it
    # commonly leaves the Program Files copy running with --updated; that copy
    # absorbs the launch request and prevents the CDP font injector from ever
    # reaching a renderer. Close only Verdent processes, then start the managed
    # Pyidaungsu copy as the new primary instance.
    Get-Process Verdent -ErrorAction SilentlyContinue | Stop-Process -Force
    $stopDeadline = (Get-Date).AddSeconds(10)
    while ((Get-Process Verdent -ErrorAction SilentlyContinue) -and (Get-Date) -lt $stopDeadline) {
        Start-Sleep -Milliseconds 250
    }
    Start-Process -FilePath $localExe -ArgumentList "--remote-debugging-port=$Port" | Out-Null
}

$deadline = (Get-Date).AddSeconds(30)
do {
    try {
        $result = Set-VerdentFont
        if ($result.Count -gt 0) { break }
    }
    catch {
        Start-Sleep -Milliseconds 500
    }
} while ((Get-Date) -lt $deadline)

if (-not $result -or $result.Count -eq 0) {
    throw 'Verdent started but its renderer was not reachable for font injection.'
}

if ($Once) {
    $result | ConvertTo-Json -Compress
    exit 0
}

while (Get-Process Verdent -ErrorAction SilentlyContinue) {
    Start-Sleep -Seconds 4
    try { [void](Set-VerdentFont) } catch { }
}
