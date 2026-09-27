Option Explicit
Dim shell, fso, root, filePath, command
If WScript.Arguments.Count <> 1 Then WScript.Quit 2
filePath = WScript.Arguments(0)
Set shell = CreateObject("WScript.Shell")
Set fso = CreateObject("Scripting.FileSystemObject")
root = fso.GetParentFolderName(WScript.ScriptFullName)
command = """C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe"" -NoLogo -NoProfile " & _
          "-NonInteractive -ExecutionPolicy Bypass -WindowStyle Hidden -File """ & root & _
          "\Launch-App.ps1"" -App mdhero -FilePath """ & filePath & """"
shell.Run command, 0, False
