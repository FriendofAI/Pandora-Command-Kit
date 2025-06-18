Write-Host "[Sickness] Temp cleaner started..." -ForegroundColor Green

# Paths
$userTemp = $env:TEMP
$winTemp = "C:\Windows\Temp"

# Helper to get file stats and sample files
function Get-DirStats($path) {
    if (Test-Path $path) {
        $files = Get-ChildItem -Path $path -Recurse -Force -ErrorAction SilentlyContinue | Where-Object { -not $_.PSIsContainer }
        $count = $files.Count
        $size = ($files | Measure-Object -Property Length -Sum).Sum
        $sample = $files | Select-Object -First 5 -ExpandProperty FullName
        return @{Count=$count; Size=$size; Sample=$sample; Files=$files}
    } else {
        return @{Count=0; Size=0; Sample=@(); Files=@()}
    }
}

# User Temp
$userStats = Get-DirStats $userTemp
Write-Host "User Temp: $($userStats.Count) files, $([math]::Round($userStats.Size/1MB,2)) MB"
if ($userStats.Sample.Count -gt 0) {
    Write-Host "  Sample files:"
    $userStats.Sample | ForEach-Object { Write-Host "    $_" }
} else {
    Write-Host "  No files found."
}

# Windows Temp
$winStats = Get-DirStats $winTemp
Write-Host "Windows Temp: $($winStats.Count) files, $([math]::Round($winStats.Size/1MB,2)) MB"
if ($winStats.Sample.Count -gt 0) {
    Write-Host "  Sample files:"
    $winStats.Sample | ForEach-Object { Write-Host "    $_" }
} else {
    Write-Host "  No files found."
}

# Recycle Bin
$shell = New-Object -ComObject Shell.Application
$recycleBin = $shell.Namespace(0xA)
$recycleCount = 0
$recycleSize = 0
$recycleSample = @()
if ($recycleBin) {
    foreach ($item in $recycleBin.Items()) {
        $recycleCount++
        $recycleSize += $item.Size
        if ($recycleSample.Count -lt 5) { $recycleSample += $item.Name }
    }
}
Write-Host "Recycle Bin: $recycleCount items, $([math]::Round($recycleSize/1MB,2)) MB"
if ($recycleSample.Count -gt 0) {
    Write-Host "  Sample items:"
    $recycleSample | ForEach-Object { Write-Host "    $_" }
} else {
    Write-Host "  No items found."
}

$totalFiles = $userStats.Count + $winStats.Count + $recycleCount
$totalSize = $userStats.Size + $winStats.Size + $recycleSize
Write-Host ("\nTotal: {0} files/items, {1:N2} MB" -f $totalFiles, [math]::Round($totalSize/1MB,2))

# Confirm
$confirm = Read-Host "Proceed with cleaning? (Y/N)"
if ($confirm -match '^(Y|y)') {
    $undeleted = @()
    # Clean user temp
    if (Test-Path $userTemp) {
        foreach ($file in $userStats.Files) {
            try {
                Remove-Item -Path $file.FullName -Force -ErrorAction Stop
            } catch {
                $undeleted += @{Path=$file.FullName; Error=$_.Exception.Message}
            }
        }
    }
    # Clean Windows temp
    if (Test-Path $winTemp) {
        foreach ($file in $winStats.Files) {
            try {
                Remove-Item -Path $file.FullName -Force -ErrorAction Stop
            } catch {
                $undeleted += @{Path=$file.FullName; Error=$_.Exception.Message}
            }
        }
    }
    # Empty Recycle Bin
    try {
        Clear-RecycleBin -Force -ErrorAction SilentlyContinue
    } catch {}
    if ($undeleted.Count -gt 0) {
        Write-Host "\n[Sickness] Could not delete $($undeleted.Count) files. Sample errors:"
        $undeleted | Select-Object -First 5 | ForEach-Object {
            Write-Host "  $($_.Path): $($_.Error)"
        }
        Write-Host "\nNote: Some files could not be deleted because they are in use by running programs or the system. This is normal for temp files. Try closing open applications and running the cleaner again if you want to remove more."
    } else {
        Write-Host "\n[Sickness] All temp files deleted successfully."
    }
    Write-Host "\n[Sickness] Temp files and Recycle Bin cleaned."
} else {
    Write-Host "\n[Sickness] Cleaning cancelled."
}
Write-Host "[Sickness] Temp cleaner complete." 