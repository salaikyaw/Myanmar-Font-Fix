# Scoped to this shell only. Does not rewrite the user's PowerShell profile.
$utf8=[Text.UTF8Encoding]::new($false)
[Console]::InputEncoding=$utf8
[Console]::OutputEncoding=$utf8
$global:OutputEncoding=$utf8
$env:PYTHONIOENCODING='utf-8'
$env:PYTHONUTF8='1'
Write-Host 'Myanmar UTF-8 shell ready. Run codex or other CLI normally.'
Write-Host ([string]::Concat([char]0x1019,[char]0x103C,[char]0x1014,[char]0x103A,[char]0x1019,[char]0x102C,[char]0x1005,[char]0x102C))
