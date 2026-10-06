Option Explicit
Dim shell, qwenExe, injector
Set shell = CreateObject("WScript.Shell")
qwenExe = "C:\Program Files\Qwen\Qwen.exe"
injector = "C:\SK_AI\projects\agents-workspace\codex\myanmar-font-fix\inject-qwen-font.js"
shell.Run """" & qwenExe & """ --remote-debugging-address=127.0.0.1 --remote-debugging-port=9225", 1, False
shell.Run "node.exe """ & injector & """", 0, False
