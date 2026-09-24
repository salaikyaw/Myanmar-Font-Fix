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

function Select-FontMenu {
    param([object[]]$Items,[string]$Title='MYANMAR FONT FIX COLLECTION',[string]$Subtitle='Up/Down: select   Enter: run   Number/letter + Enter: original mode',[ValidateSet('B','Q')][string]$EscapeValue='Q')
    $choices=[string[]]@($Items | ForEach-Object {$_.Key})
    $interactive=$Host.Name -eq 'ConsoleHost' -and -not [Console]::IsInputRedirected -and -not [Console]::IsOutputRedirected
    if(-not $interactive){
        foreach($item in $Items){Write-Host "[$($item.Key)] $($item.Label)"}
        return (Read-Host 'Number or letter').Trim().ToUpperInvariant()
    }
    $index=0; $buffer=''; $oldCursor=[Console]::CursorVisible
    try {
        [Console]::CursorVisible=$false
        while($true){
            Clear-Host
            Write-Host " $Title " -ForegroundColor Cyan
            Write-Host " $Subtitle" -ForegroundColor White
            $escapeText=if($EscapeValue -eq 'B'){'back'}else{'quit'}
            Write-Host " Esc: $escapeText   Home/End: first/last" -ForegroundColor Gray
            Write-Host ''
            # Keep selection visible even in short console windows.
            $pageSize=[Math]::Max(1,[Console]::WindowHeight-6)
            $first=[int]([Math]::Floor($index/$pageSize)*$pageSize)
            $last=[Math]::Min($Items.Count-1,$first+$pageSize-1)
            for($i=$first;$i -le $last;$i++){
                $prefix=if($i -eq $index){' > '}else{'   '}
                $line="$prefix[$($Items[$i].Key)] $($Items[$i].Label)"
                $width=[Math]::Max(1,[Console]::WindowWidth-1)
                if($line.Length -gt $width){$line=$line.Substring(0,$width)}
                if($i -eq $index){Write-Host $line.PadRight($width) -ForegroundColor Black -BackgroundColor Yellow}
                else{Write-Host $line -ForegroundColor White}
            }
            Write-Host "`n Typed: $buffer   |   Item $($index+1)/$($Items.Count)" -ForegroundColor Cyan
            $key=[Console]::ReadKey($true)
            if($key.Key -eq 'Escape'){return $EscapeValue}
            $state=Update-FontMenuSelection -Index $index -Count $Items.Count -Buffer $buffer -Key $key.Key.ToString() -Character ([string]$key.KeyChar) -Choices $choices
            $index=$state.Index; $buffer=$state.Buffer
            if($state.Done){return $state.Value}
        }
    } finally {[Console]::CursorVisible=$oldCursor}
}

function Wait-FontMenuResult {
    param([string]$Prompt='Esc/B: back to menu   Q: quit   Enter/any other key: back to menu')
    Write-Host "`n$Prompt" -ForegroundColor Cyan
    if($Host.Name -ne 'ConsoleHost' -or [Console]::IsInputRedirected){
        $answer=(Read-Host 'Select').Trim().ToUpperInvariant()
        if($answer -eq 'Q'){return 'Quit'}
        return 'Back'
    }
    $key=[Console]::ReadKey($true)
    if($key.Key -eq 'Q'){return 'Quit'}
    return 'Back'
}
