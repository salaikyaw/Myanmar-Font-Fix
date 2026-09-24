Option Explicit
Dim shell, env, fso, scriptDir, janExe, injector
Set shell = CreateObject("WScript.Shell")
Set env = shell.Environment("Process")
Set fso = CreateObject("Scripting.FileSystemObject")
scriptDir = fso.GetParentFolderName(WScript.ScriptFullName)
janExe = shell.ExpandEnvironmentStrings("%LOCALAPPDATA%\Programs\Jan\Jan.exe")
injector = fso.BuildPath(scriptDir, "inject-jan-font.js")
env("WEBVIEW2_ADDITIONAL_BROWSER_ARGUMENTS") = "--remote-debugging-address=127.0.0.1 --remote-debugging-port=9223"
shell.Run """" & janExe & """", 1, False
shell.Run "node.exe """ & injector & """", 0, False
