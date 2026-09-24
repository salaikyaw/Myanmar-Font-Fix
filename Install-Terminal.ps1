$ErrorActionPreference='Stop'
$dir=Join-Path $env:LOCALAPPDATA 'Microsoft\Windows Terminal\Fragments\Myanmar-Font-Fix'
$target=Join-Path $dir 'profiles.json'
New-Item -ItemType Directory $dir -Force|Out-Null
if(Test-Path $target){
  $backup=Join-Path $env:LOCALAPPDATA 'Myanmar-Font-Fix\backups'
  New-Item -ItemType Directory $backup -Force|Out-Null
  Copy-Item -LiteralPath $target -Destination (Join-Path $backup ('terminal-'+(Get-Date -Format yyyyMMdd-HHmmss)+'.json'))
}
$ps=(Get-Command pwsh.exe -ErrorAction SilentlyContinue).Source
if(-not $ps){$ps="$env:SystemRoot\System32\WindowsPowerShell\v1.0\powershell.exe"}
$profiles=@(
  @{guid='{2ce76ea4-fce6-48c3-9c24-f998740ab201}';name='PowerShell (Myanmar)';commandline=('"'+$ps+'" -NoLogo -NoExit -ExecutionPolicy Bypass -File "'+(Join-Path $PSScriptRoot 'Terminal-UTF8.ps1')+'"');font=@{face='Pyidaungsu';size=13};startingDirectory='%USERPROFILE%';hidden=$false},
  @{guid='{2ce76ea4-fce6-48c3-9c24-f998740ab202}';name='CMD (Myanmar)';commandline=('cmd.exe /k "'+(Join-Path $PSScriptRoot 'Terminal-UTF8.cmd')+'"');font=@{face='Pyidaungsu';size=13};startingDirectory='%USERPROFILE%';hidden=$false}
)
[IO.File]::WriteAllText($target,(@{profiles=$profiles}|ConvertTo-Json -Depth 8),[Text.UTF8Encoding]::new($false))
$shell=New-Object -ComObject WScript.Shell
foreach($profile in $profiles){
  $s=$shell.CreateShortcut((Join-Path ([Environment]::GetFolderPath('Desktop')) ($profile.name+'.lnk')))
  $s.TargetPath=(Get-Command wt.exe -ErrorAction Stop).Source
  $s.Arguments='-p "'+$profile.name+'"';$s.Save()
}
Write-Host 'Installed two independent Windows Terminal profiles. Restart Terminal to load them.'
Write-Host 'Pyidaungsu is proportional: some CLI tables/cursor positioning may remain imperfect.'
Write-Host 'Legacy conhost and individual TUI shaping bugs are not fixed by UTF-8 alone.'
