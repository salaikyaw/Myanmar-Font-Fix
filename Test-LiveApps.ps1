# Explicitly disruptive smoke test: use ONLY after the user has saved all app work.
[CmdletBinding()]
param([Parameter(Mandatory=$true)][switch]$SavedWorkConfirmed,[string[]]$Only)
if(-not $SavedWorkConfirmed){throw 'Saved-work confirmation required'}
$ErrorActionPreference='Stop'
$catalog=Get-Content (Join-Path $PSScriptRoot 'apps.json') -Raw|ConvertFrom-Json
$apps=@($catalog)
function Stop-ScopedApp($app){
  $exe=[Environment]::ExpandEnvironmentVariables($app.exe)
  $base=Split-Path $exe
  $name=[IO.Path]::GetFileNameWithoutExtension($exe)
  Get-Process -Name $name -ErrorAction SilentlyContinue | ForEach-Object {
    try{$p=$_.Path}catch{$p=$null}
    if($p -and ($p -eq $exe -or ($app.id -eq 'factory' -and $p.StartsWith($base+'\',[StringComparison]::OrdinalIgnoreCase)))){Stop-Process -Id $_.Id -Force -ErrorAction SilentlyContinue}
  }
  Start-Sleep -Seconds 2
}
if(-not $Only){foreach($a in $apps){Stop-ScopedApp $a}}
$rows=@()
foreach($a in $apps){
  if($Only -and $a.id -notin $Only){continue}
  Stop-ScopedApp $a
  # Stop only this project's font helper for this specific app, not other shells.
  Get-CimInstance Win32_Process -Filter "Name='powershell.exe'" | Where-Object {$_.CommandLine -like ('*'+$PSScriptRoot+'\Launch-App.ps1*') -and $_.CommandLine -match ('-App\s+'+[regex]::Escape($a.id)+'(?:\s|$)')} | ForEach-Object {Stop-Process -Id $_.ProcessId -Force -ErrorAction SilentlyContinue}
  Get-CimInstance Win32_Process -Filter "Name='node.exe'" | Where-Object {$_.CommandLine -like ('*'+$PSScriptRoot+'\inject-font.cjs*') -and $_.CommandLine -match ('\s'+$a.port+'\s')} | ForEach-Object {Stop-Process -Id $_.ProcessId -Force -ErrorAction SilentlyContinue}
  $started=Get-Date
  Write-Output "TEST_START=$($a.id)"
  $helper=Start-Process powershell.exe -WindowStyle Hidden -PassThru -ArgumentList ('-NoProfile -NonInteractive -ExecutionPolicy Bypass -WindowStyle Hidden -File "'+$PSScriptRoot+'\Launch-App.ps1" -App '+$a.id)
  $p=Join-Path $env:LOCALAPPDATA "Myanmar-Font-Fix\status\$($a.id).json"
  $deadline=(Get-Date).AddSeconds(85);$result=$null
  do{
    Start-Sleep -Seconds 2
    if((Test-Path $p) -and (Get-Item $p).LastWriteTime -ge $started){
      try{$result=Get-Content $p -Raw|ConvertFrom-Json}catch{}
      if($result.ok){break}
      if($helper.HasExited){break}
    }
  }while((Get-Date) -lt $deadline)
  $row=[pscustomobject]@{app=$a.id;ok=($result.ok -eq $true);rendererCount=$result.rendererCount;reason=$result.reason;tested=(Get-Date).ToString('o')}
  $rows+=$row;$row|ConvertTo-Json -Compress|Write-Output
  Stop-ScopedApp $a
  if(-not $helper.HasExited){Stop-Process -Id $helper.Id -Force -ErrorAction SilentlyContinue}
  Get-CimInstance Win32_Process -Filter "Name='node.exe'" | Where-Object {$_.CommandLine -like ('*'+$PSScriptRoot+'\inject-font.cjs*') -and $_.CommandLine -match ('\s'+$a.port+'\s')} | ForEach-Object {Stop-Process -Id $_.ProcessId -Force -ErrorAction SilentlyContinue}
}
$suffix=if($Only){'-'+($Only -join '-')}else{''}
$out=Join-Path $env:LOCALAPPDATA ("Myanmar-Font-Fix\live-test-results$suffix.json")
$rows|ConvertTo-Json -Depth 5|Set-Content $out -Encoding UTF8
Write-Output "RESULTS=$out"
