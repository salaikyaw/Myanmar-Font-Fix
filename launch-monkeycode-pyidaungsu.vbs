Option Explicit
Dim shell, ps, launcher
Set shell = CreateObject("WScript.Shell")
ps = shell.ExpandEnvironmentStrings("%SystemRoot%\System32\WindowsPowerShell\v1.0\powershell.exe")
launcher = "C:\SK_AI\projects\agents-workspace\codex\myanmar-font-fix\launch-monkeycode-pyidaungsu.ps1"
shell.Run """" & ps & """ -NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File """ & launcher & """", 0, False
