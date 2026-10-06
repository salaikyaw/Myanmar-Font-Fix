[CmdletBinding()]
param(
    [int]$StartupDelaySeconds = 90,
    [int]$MaxWaitMinutes = 30,
    [int]$StableSamples = 3,
    [double]$MinimumFreeRamGb = 1.5
)

$ErrorActionPreference = 'Stop'
$openCodeExe = 'C:\Users\salai\AppData\Local\Programs\@opencode-aidesktop\OpenCode.exe'
$desktopCommanderExe = 'C:\Users\salai\AppData\Local\Programs\Desktop Commander Pyidaungsu\Desktop Commander.exe'
$logDirectory = 'C:\SK_AI\logs'
$logFile = Join-Path $logDirectory 'agent-tray-autostart.log'

New-Item -ItemType Directory -Path $logDirectory -Force | Out-Null

function Write-StartupLog {
    param([string]$Message)
    Add-Content -LiteralPath $logFile -Value ('{0} {1}' -f (Get-Date -Format 'yyyy-MM-dd HH:mm:ss'), $Message)
}

$createdNew = $false
$mutex = [System.Threading.Mutex]::new($true, 'Local\SkAiAgentTrayAutoStart', [ref]$createdNew)
if (-not $createdNew) {
    Write-StartupLog 'Another startup guard is already running; exiting.'
    exit 0
}

try {
    if ($StartupDelaySeconds -gt 0) {
        Write-StartupLog "Waiting initial startup delay: $StartupDelaySeconds seconds."
        Start-Sleep -Seconds $StartupDelaySeconds
    }

    $deadline = (Get-Date).AddMinutes($MaxWaitMinutes)
    $stable = 0
    while ((Get-Date) -lt $deadline -and $stable -lt $StableSamples) {
        $cpu = [double]((Get-CimInstance Win32_Processor | Measure-Object -Property LoadPercentage -Average).Average)
        $os = Get-CimInstance Win32_OperatingSystem
        $freeRamGb = [math]::Round(($os.FreePhysicalMemory * 1KB) / 1GB, 2)
        if ($cpu -le 45 -and $freeRamGb -ge $MinimumFreeRamGb) {
            $stable++
        }
        else {
            $stable = 0
        }
        Write-StartupLog "Resource sample: CPU=$cpu%; FreeRAM=${freeRamGb}GB; Stable=$stable/$StableSamples."
        if ($stable -lt $StableSamples) { Start-Sleep -Seconds 10 }
    }

    if ($stable -lt $StableSamples) {
        Write-StartupLog 'Resources did not become stable within the wait window; apps were not started.'
        exit 0
    }

    if (-not (Test-Path -LiteralPath $openCodeExe)) { throw "OpenCode executable missing: $openCodeExe" }
    if (-not (Get-Process OpenCode -ErrorAction SilentlyContinue)) {
        Start-Process -FilePath $openCodeExe -ArgumentList '--sk-start-in-tray'
        Write-StartupLog 'Started OpenCode directly in tray.'
    }
    else {
        Write-StartupLog 'OpenCode is already running; skipped duplicate start.'
    }

    if (-not (Test-Path -LiteralPath $desktopCommanderExe)) { throw "Desktop Commander executable missing: $desktopCommanderExe" }
    if (-not (Get-Process -Name 'Desktop Commander' -ErrorAction SilentlyContinue)) {
        Start-Process -FilePath $desktopCommanderExe -ArgumentList '--sk-start-in-tray' -WindowStyle Hidden
        Write-StartupLog 'Started Desktop Commander directly in tray.'
    }
    else {
        Write-StartupLog 'Desktop Commander is already running; skipped duplicate start.'
    }
}
catch {
    Write-StartupLog "ERROR: $($_.Exception.Message)"
    throw
}
finally {
    $mutex.ReleaseMutex()
    $mutex.Dispose()
}
