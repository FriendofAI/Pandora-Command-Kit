Write-Host "[Curiosity] System scan started..." -ForegroundColor Green

# OS and Computer Info
Write-Host "OS Version: $(Get-CimInstance Win32_OperatingSystem | Select-Object -ExpandProperty Caption)"
Write-Host "Build Number: $(Get-CimInstance Win32_OperatingSystem | Select-Object -ExpandProperty BuildNumber)"
Write-Host "Computer Name: $env:COMPUTERNAME"

# CPU Info
$cpu = Get-CimInstance Win32_Processor | Select-Object -First 1 Name
Write-Host "CPU: $($cpu.Name)"

# RAM Info
$ram = (Get-CimInstance Win32_ComputerSystem).TotalPhysicalMemory / 1GB
Write-Host ("RAM: {0:N2} GB" -f $ram)

# GPU Info (basic)
$gpu = Get-CimInstance Win32_VideoController | Select-Object -First 1 Name
if ($gpu) {
    Write-Host "GPU: $($gpu.Name)"
} else {
    Write-Host "GPU: Not detected"
}

# Hard Drives and Free Space
Write-Host "Drives:"
Get-CimInstance Win32_LogicalDisk -Filter "DriveType=3" | ForEach-Object {
    $size = $_.Size / 1GB
    $free = $_.FreeSpace / 1GB
    Write-Host ("  Drive {0}: {1:N2} GB total, {2:N2} GB free" -f $_.DeviceID, $size, $free)
}

# Speaker Info
Write-Host "Speakers/Audio Devices:"
$audio = Get-CimInstance Win32_SoundDevice | Select-Object -ExpandProperty Name
if ($audio) {
    $audio | ForEach-Object { Write-Host "  $_" }
} else {
    Write-Host "  No audio devices found."
}

# Python, VS Code, Anaconda presence
Write-Host "\nChecking for developer tools..."
$python = Get-Command python -ErrorAction SilentlyContinue
if ($python) { Write-Host "Python: Found ($($python.Source))" } else { Write-Host "Python: Not found" }

$vscode = Get-Command code -ErrorAction SilentlyContinue
if ($vscode) { Write-Host "VS Code: Found ($($vscode.Source))" } else { Write-Host "VS Code: Not found" }

$conda = Get-Command conda -ErrorAction SilentlyContinue
if ($conda) { Write-Host "Anaconda: Found ($($conda.Source))" } else { Write-Host "Anaconda: Not found" }

Write-Host "\n[Curiosity] System scan complete." 