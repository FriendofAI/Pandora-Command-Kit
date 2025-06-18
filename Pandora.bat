@echo off
cd /d %~dp0
:: Check for admin
net session >nul 2>&1
if %errorLevel% == 0 (
    powershell -NoProfile -ExecutionPolicy Bypass -File "PandoraApp.ps1"
) else (
    powershell -NoProfile -ExecutionPolicy Bypass -Command "Write-Host '[!] Pandora needs to be run as Administrator for full functionality.' -ForegroundColor Yellow; Write-Host 'Please right-click Pandora.bat and choose Run as administrator, or open PowerShell/Terminal as admin and run PandoraApp.ps1.'; Write-Host ''; Read-Host 'Press Enter to exit...'"
) 