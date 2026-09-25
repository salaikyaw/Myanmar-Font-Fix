$ErrorActionPreference='Stop'
$catalog=Get-Content (Join-Path $PSScriptRoot 'apps.json') -Raw|ConvertFrom-Json
$apps=@($catalog)
if($apps.Count -ne 11){throw "Expected eleven apps, got $($apps.Count)"}
if(@($apps|Select-Object -ExpandProperty port -Unique).Count -ne 11){throw 'Duplicate ports'}
foreach($a in $apps){
  if($a.port -lt 19431 -or $a.port -gt 19441){throw 'Port outside private app range'}
  if(-not (Test-Path ([Environment]::ExpandEnvironmentVariables($a.exe)))){Write-Warning "Not installed here: $($a.name)"}
}
Get-ChildItem $PSScriptRoot -Filter '*.ps1' | ForEach-Object {
  $tokens=$null;$parseErrors=$null
  [void][Management.Automation.Language.Parser]::ParseFile($_.FullName,[ref]$tokens,[ref]$parseErrors)
  if($parseErrors){throw "$($_.Name): $($parseErrors.Message -join '; ')"}
}
& node --check (Join-Path $PSScriptRoot 'inject-font.cjs')
if($LASTEXITCODE){throw 'JavaScript syntax check failed'}
$launcher=Get-Content (Join-Path $PSScriptRoot 'Launch-App.ps1') -Raw
$injector=Get-Content (Join-Path $PSScriptRoot 'inject-font.cjs') -Raw
if($launcher -notmatch '19500\.\.19599' -or $launcher -notmatch 'Test-ListenerOwner'){throw 'Safe fallback-port ownership logic missing'}
if($injector -notmatch 'port > 19599'){throw 'Injector fallback-port boundary missing'}
& node (Join-Path $PSScriptRoot 'test-config.cjs')
if($LASTEXITCODE){throw 'App-origin regression test failed'}
$fragment=Join-Path $env:LOCALAPPDATA 'Microsoft\Windows Terminal\Fragments\Myanmar-Font-Fix\profiles.json'
if(Test-Path $fragment){$f=Get-Content $fragment -Raw|ConvertFrom-Json;if($f.profiles.Count -ne 2){throw 'Terminal fragment mismatch'}}
Write-Host 'PASS: eleven app entries, unique ports, PowerShell syntax, JavaScript syntax, terminal fragment.'
Write-Host 'This is a configuration test, not visual rendering proof. Use menu S and app-by-app live tests.'
