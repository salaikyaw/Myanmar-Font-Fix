[CmdletBinding()]
param([Parameter(Mandatory=$true)][string]$App)
$ErrorActionPreference='Stop'
$state=Join-Path $env:LOCALAPPDATA 'Myanmar-Font-Fix\status'
New-Item -ItemType Directory -Path $state -Force | Out-Null
function Get-FontListeners([int]$Port) {
  foreach($line in (& "$env:SystemRoot\System32\netstat.exe" -ano -p tcp)){
    $parts=$line.Trim() -split '\s+'
    if($parts.Count -eq 5 -and $parts[3] -eq 'LISTENING' -and $parts[1] -match (':'+$Port+'$')){
      [pscustomobject]@{LocalAddress=($parts[1] -replace ':\d+$','').Trim('[',']');OwningProcess=[int]$parts[4]}
    }
  }
}
try {
  $catalog=Get-Content (Join-Path $PSScriptRoot 'apps.json') -Raw | ConvertFrom-Json
  $cfg=$catalog | Where-Object id -eq $App
  if(-not $cfg){throw "Unknown app: $App"}
  $exe=[Environment]::ExpandEnvironmentVariables($cfg.exe)
  if($App -eq 'factory'){
    $latest=Get-ChildItem (Split-Path $exe) -Directory -Filter 'app-*' | Sort-Object {try{[version]($_.Name.Substring(4))}catch{[version]'0.0'}} -Descending | Select-Object -First 1
    if($latest -and (Test-Path (Join-Path $latest.FullName 'factory-desktop.exe'))){$exe=Join-Path $latest.FullName 'factory-desktop.exe'}
  }
  if(-not(Test-Path -LiteralPath $exe)){throw "Not installed: $exe"}
  $node=(Get-Command node.exe -ErrorAction Stop).Source
  $major=[int]((& $node --version) -replace '^v(\d+).*','$1')
  if($major -lt 22){throw 'Node.js 22 or newer is required'}
  $created=$false
  $mutex=[Threading.Mutex]::new($true,"Local\MyanmarFontFix-$App",[ref]$created)
  if(-not $created){$mutex.Dispose();exit 0}
  try {
    $processes=@(Get-CimInstance Win32_Process -Filter ("Name='"+[IO.Path]::GetFileName($exe)+"'") | Where-Object {$_.ExecutablePath -eq $exe})
    $listener=@(Get-FontListeners $cfg.port)
    if($listener){
      $owner=Get-CimInstance Win32_Process -Filter "ProcessId=$($listener[0].OwningProcess)"
      $valid=($owner.ExecutablePath -eq $exe)
      if($cfg.engine -eq 'webview2'){
        $cursor=$owner
        for($i=0;$i -lt 8 -and $cursor;$i++){
          if($cursor.ExecutablePath -eq $exe){$valid=$true;break}
          $cursor=Get-CimInstance Win32_Process -Filter "ProcessId=$($cursor.ParentProcessId)"
        }
      }
      if(-not $valid -or @($listener | Where-Object {$_.LocalAddress -notin @('127.0.0.1','::1')}).Count){throw 'Debug port is not owned by this app on loopback; refusing attachment'}
    }elseif($processes.Count){throw 'Please save work, fully exit this app (including tray), then use its Pyidaungsu shortcut. No process was killed.'}
    else {
      $flags="--remote-debugging-address=127.0.0.1 --remote-debugging-port=$($cfg.port)"
      if($cfg.engine -eq 'webview2'){
        # Some WebView2/Tauri apps clear inherited arguments; use the executable policy as well.
        $policy='HKCU:\Software\Policies\Microsoft\Edge\WebView2\AdditionalBrowserArguments'
        $valueName=[IO.Path]::GetFileName($exe)
        $prior=Get-ItemProperty -LiteralPath $policy -Name $valueName -ErrorAction SilentlyContinue
        $backup=Join-Path (Split-Path $state) ($App+'-webview-policy-original.json')
        if(-not(Test-Path $backup)){
          @{name=$valueName;existed=($null -ne $prior);value=if($prior){$prior.$valueName}else{$null}} | ConvertTo-Json | Set-Content $backup -Encoding UTF8
        }
        $extra=if($prior){[string]$prior.$valueName}else{''}
        $extra=($extra -replace '--remote-debugging-(port|address)(=|\s+)\S+','').Trim()
        New-Item -Path $policy -Force | Out-Null
        New-ItemProperty -LiteralPath $policy -Name $valueName -PropertyType String -Value "$extra $flags" -Force | Out-Null
        $env:WEBVIEW2_ADDITIONAL_BROWSER_ARGUMENTS="$extra $flags"
        Start-Process -FilePath $exe -WorkingDirectory (Split-Path $exe) -ArgumentList ('"--edge-webview-switches='+$flags+'"')
      }
      else {Start-Process -FilePath $exe -WorkingDirectory (Split-Path $exe) -ArgumentList $flags}
      $deadline=(Get-Date).AddSeconds(40)
      do {Start-Sleep -Milliseconds 1000;$listener=@(Get-FontListeners $cfg.port)}while(-not $listener -and (Get-Date) -lt $deadline)
      if(-not $listener){throw 'App does not expose its local renderer with the requested flag; no files were patched'}
      if(@($listener | Where-Object {$_.LocalAddress -notin @('127.0.0.1','::1')}).Count){throw 'Non-loopback debug listener detected; exit the app and do not use this launcher'}
      $owner=Get-CimInstance Win32_Process -Filter "ProcessId=$($listener[0].OwningProcess)"
      $valid=($owner.ExecutablePath -eq $exe)
      if($cfg.engine -eq 'webview2'){
        $cursor=$owner
        for($i=0;$i -lt 8 -and $cursor;$i++){
          if($cursor.ExecutablePath -eq $exe){$valid=$true;break}
          $cursor=Get-CimInstance Win32_Process -Filter "ProcessId=$($cursor.ParentProcessId)"
        }
      }
      if(-not $valid){throw 'Started debug listener is not owned by this app; refusing attachment'}
    }
    & $node (Join-Path $PSScriptRoot 'inject-font.cjs') $cfg.port $App $state
    if($LASTEXITCODE -ne 0){throw 'Font injector failed'}
  }finally{$mutex.ReleaseMutex();$mutex.Dispose()}
}catch{
  $message=$_.Exception.Message
  @{app=$App;ok=$false;reason=$message;time=(Get-Date).ToString('o')} | ConvertTo-Json | Set-Content (Join-Path $state "$App.json") -Encoding UTF8
  $notice=New-Object -ComObject WScript.Shell
  [void]$notice.Popup($message,10,'Myanmar Font Fix',48)
  exit 1
}
