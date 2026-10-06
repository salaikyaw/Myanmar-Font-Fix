function Update-FontMenuSelection {
    param([int]$Index, [int]$Count, [string]$Buffer, [string]$Key, [string]$Character, [string[]]$Choices)
    $done=$false; $value=$null
    switch ($Key) {
        'UpArrow' { $Index=($Index+$Count-1)%$Count; $Buffer='' }
        'DownArrow' { $Index=($Index+1)%$Count; $Buffer='' }
        'Home' { $Index=0; $Buffer='' }
        'End' { $Index=$Count-1; $Buffer='' }
        'Escape' { $done=$true; $value='Q' }
        'Backspace' { if($Buffer.Length){$Buffer=$Buffer.Substring(0,$Buffer.Length-1)} }
        'Enter' {
            if(-not $Buffer){$value=$Choices[$Index];$done=$true}
            elseif($Choices -contains $Buffer){$value=$Buffer;$done=$true}
        }
        default {
            if($Character -match '^[0-9]$'){$Buffer+=$Character}
            elseif($Character -match '^[a-zA-Z]$'){$Buffer=$Character.ToUpperInvariant()}
        }
    }
    $match=[Array]::IndexOf($Choices,$Buffer)
    if($match -ge 0){$Index=$match}
    [pscustomobject]@{Index=$Index;Buffer=$Buffer;Done=$done;Value=$value}
}

function Get-FontMenuNodePath {
    try {
        $cmd=Get-Command node.exe -ErrorAction SilentlyContinue
        if($cmd){return $cmd.Source}
    } catch {}
    return $null
}

# Internal: run the Node renderer tier. Returns the chosen Key, 'Q', or $null.
# Uses a payload file + Start-Process (no pipes) so the child inherits the real
# console: stdin stays a TTY, so raw keyboard, arrows and mouse events all work.
function Invoke-FontMenuNode {
    param([object[]]$Items,[string]$Title,[string]$Subtitle,[string]$EscapeValue,[string]$NodePath)
    $payload=@{items=@();title=$Title;subtitle=$Subtitle;
        escapeText=$(if($EscapeValue -eq 'B'){'back'}else{'quit'});escapeValue=$EscapeValue}
    foreach($item in $Items){$payload.items+=[ordered]@{Key=[string]$item.Key;Label=[string]$item.Label}}
    $dir=Join-Path $PSScriptRoot '.fontmenu'
    New-Item -ItemType Directory -Force -Path $dir | Out-Null
    $stamp=[guid]::NewGuid().ToString('N')
    $itemsFile=Join-Path $dir ($stamp+'.json')
    $resultFile=Join-Path $dir ($stamp+'.result')
    $json=ConvertTo-Json -InputObject $payload -Depth 4 -Compress
    # BOM-less UTF8: PS 5.1 'Set-Content -Encoding UTF8' adds a BOM that breaks JSON.parse(#L146).
    [System.IO.File]::WriteAllText($itemsFile,$json,(New-Object System.Text.UTF8Encoding($false)))
    try {
        # -NoNewWindow: inherit this console => stdin/stdout stay attached to the real TTY.
        $proc=Start-Process -FilePath $NodePath -ArgumentList @(
            (Join-Path $PSScriptRoot 'font-menu.cjs'),
            '--items-file',$itemsFile,
            '--result-file',$resultFile
        ) -NoNewWindow -Wait -PassThru
        $code=$proc.ExitCode
        if($code -eq 0 -and (Test-Path -LiteralPath $resultFile)){
            $value=(Get-Content -LiteralPath $resultFile -Raw).Trim()
            $validKeys=@($Items|ForEach-Object{[string]$_.Key})+$EscapeValue
            if($value -and ($validKeys -contains $value)){return $value}
        }
        return $null
    } finally {
        Remove-Item -LiteralPath $itemsFile -ErrorAction SilentlyContinue
        Remove-Item -LiteralPath $resultFile -ErrorAction SilentlyContinue
    }
}

function Select-FontMenu {
    param([object[]]$Items,[string]$Title='MYANMAR FONT FIX COLLECTION',[string]$Subtitle='Up/Down: select   Enter: run   Number/letter + Enter: original mode',[ValidateSet('B','Q')][string]$EscapeValue='Q')
    $choices=[string[]]@($Items | ForEach-Object {$_.Key})
    $interactive=$Host.Name -eq 'ConsoleHost' -and -not [Console]::IsInputRedirected -and -not [Console]::IsOutputRedirected
    if(-not $interactive){
        foreach($item in $Items){Write-Host "[$($item.Key)] $($item.Label)"}
        $answer=("$(Read-Host 'Number or letter')").Trim().ToUpperInvariant()
        if(-not $answer){return $EscapeValue} # redirected stdin with no data: do not spin the loop
        return $answer
    }
    $preferNode=($Env:FONT_MENU_DISABLE_NODE -ne '1')
    if($preferNode){
        $nodePath=Get-FontMenuNodePath
        if($nodePath){
            $result=Invoke-FontMenuNode -Items $Items -Title $Title -Subtitle $Subtitle -EscapeValue $EscapeValue -NodePath $nodePath
            if($result){return $result}
            # fall through to the PowerShell tier below
        }
    }
    # ---- PowerShell tier: in-place redraw (no Clear-Host => no flicker) ----
    $index=0; $buffer=''
    $pageSize=[Math]::Max(5,[Console]::WindowHeight-8)
    $width=[Math]::Max(1,[Console]::WindowWidth-1)
    $maxRows=$Items.Count
    $oldCursor=[Console]::CursorVisible
    $esc=[char]27
    function Format-FontMenuRow {
        param($Items,$i,$index,$width)
        $prefix=if($i -eq $index){' > '}else{'   '}
        $line="$prefix[$($Items[$i].Key)] $($Items[$i].Label)"
        if($line.Length -gt $width){$line=$line.Substring(0,$width)}
        return $line.PadRight($width)
    }
    try {
        [Console]::CursorVisible=$false
        [Console]::Write(($esc+'[2J'+$esc+'H')) # clear once on menu entry, then redraw in place
        Write-Host " $Title " -ForegroundColor Cyan
        Write-Host " $Subtitle" -ForegroundColor White
        Write-Host " Esc: $(if($EscapeValue -eq 'B'){'back'}else{'quit'})   Home/End: first/last" -ForegroundColor Gray
        Write-Host ''
        $printed=3+[Math]::Min($Items.Count,$pageSize)+2 # header(3) + item rows + blank + status
        while($true){
            $key=[Console]::ReadKey($true)
            if($key.Key -eq 'Escape'){return $EscapeValue}
            $state=Update-FontMenuSelection -Index $index -Count $Items.Count -Buffer $buffer -Key $key.Key.ToString() -Character ([string]$key.KeyChar) -Choices $choices
            $index=$state.Index; $buffer=$state.Buffer
            if($state.Done){return $state.Value}
            # in-place redraw: cursor up $printed rows to the frame top, overwrite rows, never Clear-Host
            [Console]::Write(($esc+"[$($printed)A"))
            $first=[int][Math]::Max(0,[Math]::Floor($index/[Math]::Max(1,$pageSize))*$pageSize)
            $last=[Math]::Min($Items.Count-1,$first+$pageSize-1)
            for($i=$first;$i -le $last;$i++){
                $row=Format-FontMenuRow -Items $Items -i $i -index $index -width $width
                if($i -eq $index){Write-Host $row -ForegroundColor Black -BackgroundColor Yellow}
                else{Write-Host $row -ForegroundColor White}
            }
            Write-Host ''
            Write-Host (" Typed: {0}  |  Item {1}/{2}" -f $buffer,($index+1),$Items.Count) -ForegroundColor Cyan
        }
    } finally {
        [Console]::CursorVisible=$oldCursor
    }
}

function Wait-FontMenuResult {
    param([string]$Prompt='Esc/B: back to menu   Q: quit   Enter/any other key: back to menu')
    Write-Host "`n$Prompt" -ForegroundColor Cyan
    if($Host.Name -ne 'ConsoleHost' -or [Console]::IsInputRedirected){
        $answer=("$(Read-Host 'Select')").Trim().ToUpperInvariant()
        if(-not $answer -or $answer -eq 'Q'){return 'Quit'} # no redirected input: exit instead of looping
        return 'Back'
    }
    $key=[Console]::ReadKey($true)
    if($key.Key -eq 'Q'){return 'Quit'}
    return 'Back'
}
