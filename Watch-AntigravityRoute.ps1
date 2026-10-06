[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [string]$OutputPath,
    [ValidateRange(15, 600)]
    [int]$DurationSeconds = 240
)

$ErrorActionPreference = 'SilentlyContinue'
$deadline = (Get-Date).AddSeconds($DurationSeconds)
$last = ''
New-Item -ItemType Directory -Path (Split-Path -Parent $OutputPath) -Force | Out-Null
"# Antigravity route watch started $(Get-Date -Format o)" | Set-Content -LiteralPath $OutputPath -Encoding utf8

while ((Get-Date) -lt $deadline) {
    $portFile = Join-Path $env:APPDATA 'Antigravity\DevToolsActivePort'
    if (Test-Path -LiteralPath $portFile) {
        $port = (Get-Content -LiteralPath $portFile -ErrorAction SilentlyContinue | Select-Object -First 1)
        if ($port -match '^\d+$') {
            try {
                $raw = & curl.exe --max-time 2 -sS "http://127.0.0.1:$port/json/list"
                $pages = $raw | ConvertFrom-Json
                foreach ($page in @($pages | Where-Object { $_.type -eq 'page' -and $_.url -like 'https://127.0.0.1:*' })) {
                    $record = "$($page.title)`t$($page.url)"
                    if ($record -ne $last) {
                        "$(Get-Date -Format o)`t$record" | Add-Content -LiteralPath $OutputPath -Encoding utf8
                        $last = $record
                    }
                }
            } catch {}
        }
    }
    Start-Sleep -Milliseconds 300
}
