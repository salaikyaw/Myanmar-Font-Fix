[CmdletBinding()]
param()
$ErrorActionPreference='Stop'
$root=$PSScriptRoot
$openVbs=Join-Path $root 'Open-Markdown.vbs'
if(-not(Test-Path -LiteralPath $openVbs)){throw 'Open-Markdown.vbs is missing'}
$backupRoot=Join-Path $env:LOCALAPPDATA 'Myanmar-Font-Fix\association-backups'
New-Item -ItemType Directory -Path $backupRoot -Force | Out-Null
$backup=Join-Path $backupRoot 'md-progid-before-pyidaungsu.reg'
if(-not(Test-Path -LiteralPath $backup)){
  & "$env:SystemRoot\System32\reg.exe" export 'HKCU\Software\Classes\md' $backup /y | Out-Null
}
$userChoice='HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\FileExts\.md\UserChoice'
$progId=(Get-ItemProperty -LiteralPath $userChoice -ErrorAction Stop).ProgId
if($progId -ne 'md'){throw "The current .md default is '$progId', not MDHero. Leave the default setting unchanged."}
$commandKey="HKCU:\Software\Classes\$progId\shell\open\command"
$oldCommand=(Get-Item $commandKey -ErrorAction Stop).GetValue('')
if($oldCommand -notmatch '(?i)mdhero\.exe'){throw 'The current md ProgID is not owned by MDHero. Leave the default setting unchanged.'}
Set-ItemProperty -Path $commandKey -Name '(default)' -Value ('"'+$env:SystemRoot+'\System32\wscript.exe" //B //Nologo "'+$openVbs+'" "%1"')
& "$env:SystemRoot\System32\ie4uinit.exe" -show | Out-Null
[pscustomobject]@{ok=$true;progId=$progId;oldCommand=$oldCommand;command=(Get-Item $commandKey).GetValue('');backup=$backup}|ConvertTo-Json
