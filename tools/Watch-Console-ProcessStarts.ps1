[CmdletBinding()]
param([int]$Minutes = 30)

$ErrorActionPreference = 'SilentlyContinue'
$logDirectory = 'C:\SK_AI\logs'
$logFile = Join-Path $logDirectory 'console-process-starts.log'
$interesting = @('cmd.exe', 'powershell.exe', 'pwsh.exe', 'wscript.exe', 'cscript.exe')

New-Item -ItemType Directory -Path $logDirectory -Force | Out-Null
Add-Content -LiteralPath $logFile -Value ('{0} MONITOR_START duration={1}m' -f (Get-Date -Format 'yyyy-MM-dd HH:mm:ss.fff'), $Minutes)

function Protect-CommandLine {
    param([string]$Value)
    if ([string]::IsNullOrWhiteSpace($Value)) { return '' }
    $safe = $Value -replace '(?i)(api[-_]?key|token|password|secret)(\s*[=:]\s*|\s+)([^\s"'']+)', '$1=<redacted>'
    if ($safe.Length -gt 1200) { $safe = $safe.Substring(0, 1200) + '...' }
    return $safe
}

$deadline = (Get-Date).AddMinutes($Minutes)
$known = @{}
foreach ($process in [System.Diagnostics.Process]::GetProcesses()) {
    if (($process.ProcessName + '.exe').ToLowerInvariant() -in $interesting) {
        $known[$process.Id] = $true
    }
    $process.Dispose()
}

try {
    while ((Get-Date) -lt $deadline) {
        Start-Sleep -Milliseconds 250
        $current = @{}
        foreach ($dotNetProcess in [System.Diagnostics.Process]::GetProcesses()) {
            $processName = ($dotNetProcess.ProcessName + '.exe').ToLowerInvariant()
            $processId = $dotNetProcess.Id
            $dotNetProcess.Dispose()
            if ($processName -notin $interesting) { continue }
            $current[$processId] = $true
            if ($known.ContainsKey($processId)) { continue }

            $process = Get-CimInstance Win32_Process -Filter "ProcessId=$processId"
            if (-not $process) { continue }
            $parent = Get-CimInstance Win32_Process -Filter "ProcessId=$($process.ParentProcessID)"
            $windowProcess = Get-Process -Id $processId -ErrorAction SilentlyContinue
            $windowHandle = if ($windowProcess) { $windowProcess.MainWindowHandle } else { 0 }
            $windowTitle = if ($windowProcess) { Protect-CommandLine ([string]$windowProcess.MainWindowTitle) } else { '' }
            $commandLine = Protect-CommandLine ([string]$process.CommandLine)
            $parentCommandLine = Protect-CommandLine ([string]$parent.CommandLine)
            $entry = '{0} PROCESS={1} PID={2} PARENT={3} PPID={4} WINDOW={5} TITLE={6} CMD={7} PARENT_CMD={8}' -f `
                (Get-Date -Format 'yyyy-MM-dd HH:mm:ss.fff'), $process.Name, $processId, `
                $parent.Name, $process.ParentProcessID, $windowHandle, $windowTitle, $commandLine, $parentCommandLine
            Add-Content -LiteralPath $logFile -Value $entry
        }
        $known = $current
    }
}
finally {
    Add-Content -LiteralPath $logFile -Value ('{0} MONITOR_END' -f (Get-Date -Format 'yyyy-MM-dd HH:mm:ss.fff'))
}
