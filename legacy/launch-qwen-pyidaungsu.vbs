Option Explicit
Dim shell, fso, scriptDir, qwenExe, injector
Set shell = CreateObject("WScript.Shell")
Set fso = CreateObject("Scripting.FileSystemObject")
scriptDir = fso.GetParentFolderName(WScript.ScriptFullName)
qwenExe = shell.ExpandEnvironmentStrings("%ProgramFiles%\Qwen\Qwen.exe")
injector = fso.BuildPath(scriptDir, "inject-qwen-font.js")
shell.Run """" & qwenExe & """ --remote-debugging-address=127.0.0.1 --remote-debugging-port=9225", 1, False
shell.Run "node.exe """ & injector & """", 0, False
