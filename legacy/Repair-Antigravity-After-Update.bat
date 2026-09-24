@echo off
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0Repair-Antigravity-After-Update.ps1"
if errorlevel 1 (
  echo.
  echo Repair did not run. Ensure Antigravity is fully closed, then run this file again.
  pause
  exit /b 1
)
echo.
echo Antigravity repair finished. You may open Antigravity now.
pause
