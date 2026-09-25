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
function Test-ListenerOwner($Listener,[string]$Exe,[bool]$WebView) {
  $owner=Get-CimInstance Win32_Process -Filter "ProcessId=$($Listener.OwningProcess)" -ErrorAction SilentlyContinue
  if(-not $owner){return $false}
  if($owner.ExecutablePath -eq $Exe){return $true}
  if($WebView){
    $cursor=$owner
    for($i=0;$i -lt 8 -and $cursor;$i++){
      if($cursor.ExecutablePath -eq $Exe){return $true}
      $cursor=Get-CimInstance Win32_Process -Filter "ProcessId=$($cursor.ParentProcessId)" -ErrorAction SilentlyContinue
    }
  }
  return $false
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
    # Count only a top-level GUI instance. Updaters and Qoder's persistent daemon use the
    # same executable but do not own a renderer window and must not block a safe relaunch.
    $processes=@(Get-CimInstance Win32_Process -Filter ("Name='"+[IO.Path]::GetFileName($exe)+"'") | Where-Object {
      $_.ExecutablePath -eq $exe -and $_.CommandLine -notmatch '\s--type=' -and $_.CommandLine -notmatch '\sdaemon-server(?:\s|$)'
    })
    $port=[int]$cfg.port
    $listener=@(Get-FontListeners $port)
    # A prior safe launch may have selected a fallback port because the configured port
    # was orphaned. Reuse it only after proving that this exact app owns it on loopback.
    $owned=$null
    foreach($candidate in @($cfg.port)+(19500..19599)){
      $candidateListeners=@(Get-FontListeners $candidate)
      if($candidateListeners.Count -and -not @($candidateListeners | Where-Object {$_.LocalAddress -notin @('127.0.0.1','::1')}).Count){
        if(Test-ListenerOwner $candidateListeners[0] $exe ($cfg.engine -eq 'webview2')){
          $owned=[pscustomobject]@{Port=[int]$candidate;Listeners=$candidateListeners};break
        }
      }
    }
    if($owned){$port=$owned.Port;$listener=@($owned.Listeners)}
    if($listener){
      $valid=Test-ListenerOwner $listener[0] $exe ($cfg.engine -eq 'webview2')
      if(-not $valid -or @($listener | Where-Object {$_.LocalAddress -notin @('127.0.0.1','::1')}).Count){
        if($processes.Count){throw 'Please save work, fully exit this app (including tray), then use its Pyidaungsu shortcut. No process was killed.'}
        # Windows can retain an orphaned TCP listener after an app update/crash. Never attach to it;
        # choose an unused loopback-only fallback port for this launch instead.
        $port=19500..19599 | Where-Object {-not @(Get-FontListeners $_)} | Select-Object -First 1
        if(-not $port){throw 'No safe local debug port is available. Restart Windows and try again.'}
        $listener=@()
      }
    }elseif($processes.Count){throw 'Please save work, fully exit this app (including tray), then use its Pyidaungsu shortcut. No process was killed.'}
    else {
      $flags="--remote-debugging-address=127.0.0.1 --remote-debugging-port=$port"
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
      $valid=Test-ListenerOwner $listener[0] $exe ($cfg.engine -eq 'webview2')
      if(-not $valid){throw 'Started debug listener is not owned by this app; refusing attachment'}
    }
    & $node (Join-Path $PSScriptRoot 'inject-font.cjs') $port $App $state
    if($LASTEXITCODE -ne 0){throw 'Font injector failed'}
  }finally{$mutex.ReleaseMutex();$mutex.Dispose()}
}catch{
  $message=$_.Exception.Message
  @{app=$App;ok=$false;reason=$message;time=(Get-Date).ToString('o')} | ConvertTo-Json | Set-Content (Join-Path $state "$App.json") -Encoding UTF8
  $notice=New-Object -ComObject WScript.Shell
  [void]$notice.Popup($message,10,'Myanmar Font Fix',48)
  exit 1
}
