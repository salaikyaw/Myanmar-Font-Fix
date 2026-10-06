@echo off
setlocal
set "SCRIPT_DIR=%~dp0"
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%SCRIPT_DIR%Repair-OpenCode-DesktopCommander.ps1"
set "EXIT_CODE=%ERRORLEVEL%"
if not "%EXIT_CODE%"=="0" (
  echo.
  echo Repair failed. The output above includes the backup path; no account or token files were changed.
  pause
  exit /b %EXIT_CODE%
)
echo.
echo Repair complete. Reopen OpenCode or Desktop Commander normally. Desktop Commander has tray behavior; OpenCode receives font-only repair.
pause
exit /b 0
