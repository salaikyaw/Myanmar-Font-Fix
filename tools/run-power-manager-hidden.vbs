Option Explicit
Dim sh, rc
Set sh = CreateObject("WScript.Shell")
rc = sh.Run("powershell.exe -NoProfile -NonInteractive -ExecutionPolicy Bypass -WindowStyle Hidden -File ""C:\SK_AI\projects\agents-workspace\verdent\local management\battery-manager\power-manager.ps1""", 0, True)
WScript.Quit rc
