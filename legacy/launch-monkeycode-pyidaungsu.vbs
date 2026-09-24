Option Explicit
Dim shell, fso, ps, launcher
Set shell = CreateObject("WScript.Shell")
Set fso = CreateObject("Scripting.FileSystemObject")
ps = shell.ExpandEnvironmentStrings("%SystemRoot%\System32\WindowsPowerShell\v1.0\powershell.exe")
launcher = fso.BuildPath(fso.GetParentFolderName(WScript.ScriptFullName), "launch-monkeycode-pyidaungsu.ps1")
shell.Run """" & ps & """ -NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File """ & launcher & """", 0, False
