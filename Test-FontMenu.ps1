$ErrorActionPreference='Stop'
. (Join-Path $PSScriptRoot 'Select-FontMenu.ps1')
$choices=[string[]]@('1','2','3','4','5','6','7','8','9','10','I','T','L','D','W','S','Q')
function Step($index,$buffer,$key,$char){Update-FontMenuSelection -Index $index -Count $choices.Count -Buffer $buffer -Key $key -Character $char -Choices $choices}
if((Step 0 '' 'UpArrow' '').Index -ne 16){throw 'Up wrap failed'}
if((Step 16 '' 'DownArrow' '').Index -ne 0){throw 'Down wrap failed'}
$s=Step 0 '' 'D1' '1';$s=Step $s.Index $s.Buffer 'D0' '0'
if($s.Index -ne 9 -or (Step $s.Index $s.Buffer 'Enter' '').Value -ne '10'){throw 'Qoder numeric selection failed'}
if((Step 9 '' 'Enter' '').Value -ne '10'){throw 'Qoder arrow selection failed'}
if((Step 0 '' 'Escape' '').Value -ne 'Q'){throw 'Escape failed'}
$s=Step 0 '' 'D' 'd'
if((Step $s.Index $s.Buffer 'Enter' '').Value -ne 'D'){throw 'Legacy DC shortcut failed'}
if((Step 0 '999' 'Enter' '').Done){throw 'Invalid input accepted'}
if((Step 9 '10' 'Backspace' '').Buffer -ne '1'){throw 'Backspace failed'}
Write-Output 'PASS: arrows, wrap, Qoder 10, letter mode, Escape, invalid input, Backspace'
