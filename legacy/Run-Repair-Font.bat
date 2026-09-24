@echo off
chcp 65001 >nul
title Antigravity & MonkeyCode Myanmar Font Fixer / Patcher
color 0A

echo.
echo  ╔══════════════════════════════════════════════════════╗
echo  ║   Myanmar Font & Setup Launcher - SK AI Foundation   ║
echo  ╚══════════════════════════════════════════════════════╝
echo.

echo [*] Launching PowerShell repair script...
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0repair.ps1"
