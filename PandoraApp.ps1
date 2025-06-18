# PandoraApp.ps1 - Main CLI Interface

# Start logging
$logDir = Join-Path $PSScriptRoot 'Logs'
if (!(Test-Path $logDir)) { New-Item -ItemType Directory -Path $logDir | Out-Null }
$logFile = Join-Path $logDir ("PandoraLog_" + (Get-Date -Format 'yyyyMMdd_HHmmss') + ".txt")
Start-Transcript -Path $logFile -Append

# Admin check
if (-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Host "[!] Please run Pandora as Administrator for full functionality." -ForegroundColor Yellow
}

function Show-Menu {
    Clear-Host
    Write-Host "==========================================="
    Write-Host "      PANDORA'S APP - SYSTEM ORACLE        "
    Write-Host "==========================================="
    Write-Host "[1]  Curiosity - System Scan"
    Write-Host "[2]  Sickness - Temp Cleaner"
    Write-Host "[3]  Deceit - Privacy Scan"
    Write-Host "[4]  Control - Startup Manager"
    Write-Host "[5]  GitHub Installer"
    Write-Host "[6]  Model + Tool Portals"
    Write-Host "[7]  Dev Environment Report"
    Write-Host "[8]  System Backup"
    Write-Host "[9]  Driver Updater"
    Write-Host "[10] View Logs"
    Write-Host "[11] Exit with Hope"
    Write-Host "==========================================="
}

function Run-Module($module) {
    $modulePath = Join-Path $PSScriptRoot "Modules/$module.ps1"
    if (Test-Path $modulePath) {
        Write-Host "[Pandora] Running $module..." -ForegroundColor Magenta
        . $modulePath
    } else {
        Write-Host "[!] Module $module not found." -ForegroundColor Red
    }
    Write-Host "Press Enter to return to menu..."
    [void][System.Console]::ReadLine()
}

while ($true) {
    Show-Menu
    $choice = Read-Host "Select a tool (1-11)"
    switch ($choice) {
        1 { Run-Module "Curiosity" }
        2 { Run-Module "Sickness" }
        3 { Run-Module "Deceit" }
        4 { Run-Module "Control" }
        5 { Run-Module "InstallFromGit" }
        6 { Run-Module "ModelPortals" }
        7 { Run-Module "DevCheck" }
        8 { Run-Module "Memorykeeper" }
        9 { Run-Module "Sentinel" }
        10 { Run-Module "ViewLogs" }
        11 { Run-Module "Hope"; break }
        default { Write-Host "Invalid selection. Please choose 1-11." -ForegroundColor Yellow }
    }
}

Stop-Transcript