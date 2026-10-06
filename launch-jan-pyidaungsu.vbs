Option Explicit
Dim shell, env, janExe, injector
Set shell = CreateObject("WScript.Shell")
Set env = shell.Environment("Process")
janExe = "C:\Users\salai\AppData\Local\Programs\Jan\Jan.exe"
injector = "C:\SK_AI\projects\agents-workspace\codex\myanmar-font-fix\inject-jan-font.js"
env("WEBVIEW2_ADDITIONAL_BROWSER_ARGUMENTS") = "--remote-debugging-address=127.0.0.1 --remote-debugging-port=9223"
shell.Run """" & janExe & """", 1, False
shell.Run "node.exe """ & injector & """", 0, False
