$ErrorActionPreference='Stop'
$backup=Join-Path $env:LOCALAPPDATA 'Myanmar-Font-Fix\openworker-webview-policy-original.json'
if(-not(Test-Path $backup)){Write-Host 'No OpenWorker policy backup; nothing changed.';exit}
$record=Get-Content $backup -Raw|ConvertFrom-Json
if($record.name -ne 'openworker-desktop.exe'){throw 'Unexpected backup target'}
$policy='HKCU:\Software\Policies\Microsoft\Edge\WebView2\AdditionalBrowserArguments'
if($record.existed){Set-ItemProperty -LiteralPath $policy -Name $record.name -Value $record.value}
else{Remove-ItemProperty -LiteralPath $policy -Name $record.name -ErrorAction SilentlyContinue}
Write-Host 'Original OpenWorker-only WebView2 arguments restored. Fully exit/reopen OpenWorker.'
