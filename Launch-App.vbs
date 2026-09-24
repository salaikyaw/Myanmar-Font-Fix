Option Explicit
Dim shell, fso, root, app, command
Set shell = CreateObject("WScript.Shell")
Set fso = CreateObject("Scripting.FileSystemObject")
root = fso.GetParentFolderName(WScript.ScriptFullName)
If WScript.Arguments.Count <> 1 Then WScript.Quit 2
app = WScript.Arguments(0)
If InStr(app, """") > 0 Or InStr(app, " ") > 0 Then WScript.Quit 2
command = "powershell.exe -NoProfile -NonInteractive -ExecutionPolicy Bypass -WindowStyle Hidden -File """ & root & "\Launch-App.ps1"" -App " & app
shell.Run command, 0, False
