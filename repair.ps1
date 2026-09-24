param([ValidateSet('Menu','Install','Status')][string]$Mode='Menu')
$ErrorActionPreference='Stop'
$catalog=Get-Content (Join-Path $PSScriptRoot 'apps.json') -Raw | ConvertFrom-Json
$apps=@($catalog)
function Install-Launchers {
  $shell=New-Object -ComObject WScript.Shell
  $desktop=[Environment]::GetFolderPath('Desktop')
  $backup=Join-Path $env:LOCALAPPDATA ('Myanmar-Font-Fix\backups\shortcuts-'+(Get-Date -Format yyyyMMdd-HHmmss))
  foreach($app in $apps){
    $exe=[Environment]::ExpandEnvironmentVariables($app.exe)
    if(-not(Test-Path -LiteralPath $exe)){Write-Host "NOT INSTALLED: $($app.name)";continue}
    $p=Join-Path $desktop ($app.name+' (Pyidaungsu).lnk')
    if(Test-Path -LiteralPath $p){New-Item -ItemType Directory $backup -Force|Out-Null;Copy-Item -LiteralPath $p -Destination $backup}
    $s=$shell.CreateShortcut($p);$s.TargetPath="$env:SystemRoot\System32\wscript.exe"
    $s.Arguments='"'+(Join-Path $PSScriptRoot 'Launch-App.vbs')+'" '+$app.id
    $s.WorkingDirectory=$PSScriptRoot;$s.IconLocation="$exe,0";$s.Description='App-local Myanmar font; no vendor files modified';$s.Save()
    Write-Host "READY (not live-verified): $($app.name)"
  }
  $p=Join-Path $desktop 'Run-Repair-Font.lnk'
  if(Test-Path $p){New-Item -ItemType Directory $backup -Force|Out-Null;Copy-Item -LiteralPath $p -Destination $backup}
  $s=$shell.CreateShortcut($p);$s.TargetPath=Join-Path $PSScriptRoot 'Run-Repair-Font.bat';$s.WorkingDirectory=$PSScriptRoot;$s.Save()
}
function Show-Status {
  foreach($app in $apps){
    $installed=Test-Path ([Environment]::ExpandEnvironmentVariables($app.exe))
    $p=Join-Path $env:LOCALAPPDATA "Myanmar-Font-Fix\status\$($app.id).json"
    Write-Host "$($app.name): Installed=$installed"
    if(Test-Path $p){Get-Content $p}else{Write-Host '  Not live-tested yet'}
  }
}
if($Mode -eq 'Install'){Install-Launchers;exit}
if($Mode -eq 'Status'){Show-Status;exit}
. (Join-Path $PSScriptRoot 'Select-FontMenu.ps1')
$items=@(for($i=0;$i -lt $apps.Count;$i++){
  [pscustomobject]@{Key=[string]($i+1);Label="Launch $($apps[$i].name) with Pyidaungsu"}
})
$items+=@(
  [pscustomobject]@{Key='I';Label='Install/update app shortcuts (no app restarts)'},
  [pscustomobject]@{Key='T';Label='Install CMD/PowerShell Myanmar profiles'},
  [pscustomobject]@{Key='L';Label='Legacy repairs: Antigravity, MonkeyCode, OpenCode, Jan, VS Code, ZCode, Zed, Verdent'},
  [pscustomobject]@{Key='D';Label='OpenCode + DC font/tray repair (save and close both first)'},
  [pscustomobject]@{Key='W';Label='Qwen Pyidaungsu launcher'},
  [pscustomobject]@{Key='S';Label='Status (last verification)'},
  [pscustomobject]@{Key='Q';Label='Quit'}
)
$quit=$false
while(-not $quit){
 $choice=Select-FontMenu -Items $items
 $showResult=$true
 switch($choice){
  'I' {Install-Launchers}
  'T' {& (Join-Path $PSScriptRoot 'Install-Terminal.ps1')}
  'L' {
    & powershell.exe -NoProfile -ExecutionPolicy Bypass -File (Join-Path $PSScriptRoot 'legacy\repair.ps1') -ParentMenu
    if($LASTEXITCODE -eq 20){$quit=$true}
    $showResult=$false
  }
  'D' {& powershell.exe -NoProfile -ExecutionPolicy Bypass -File (Join-Path $PSScriptRoot 'legacy\Repair-OpenCode-DesktopCommander.ps1')}
  'W' {Start-Process "$env:SystemRoot\System32\wscript.exe" -ArgumentList ('"'+(Join-Path $PSScriptRoot 'legacy\launch-qwen-pyidaungsu.vbs')+'"')}
  'S' {Show-Status}
  'Q' {$quit=$true;continue}
  default { $index=0;if([int]::TryParse($choice,[ref]$index) -and $index -ge 1 -and $index -le $apps.Count){Start-Process "$env:SystemRoot\System32\wscript.exe" -ArgumentList ('"'+(Join-Path $PSScriptRoot 'Launch-App.vbs')+'" '+$apps[$index-1].id)} }
 }
 if(-not $quit -and $showResult -and (Wait-FontMenuResult) -eq 'Quit'){$quit=$true}
}
