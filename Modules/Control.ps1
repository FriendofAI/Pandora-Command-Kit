Write-Host "[Control] Startup manager started..." -ForegroundColor Green

$backupDir = Join-Path $PSScriptRoot '../Backups/Startup'
if (!(Test-Path $backupDir)) { New-Item -ItemType Directory -Path $backupDir | Out-Null }

function Remove-StartupItem {
    param($item)
    if ($item.Type -like '*Registry') {
        $backupFile = Join-Path $backupDir $item.BackupFile
        $entry = @{Path=$item.Path; Name=$item.RegName; Value=$item.RegValue}
        $entry | ConvertTo-Json | Set-Content $backupFile
        if (Get-ItemProperty -Path $item.Path -Name $item.RegName -ErrorAction SilentlyContinue) {
            try {
                Remove-ItemProperty -Path $item.Path -Name $item.RegName -Force
            } catch {
                throw $_
            }
        }
    } elseif ($item.Type -like '*Startup Folder') {
        $backupFile = Join-Path $backupDir $item.BackupFile
        Copy-Item $item.Location $backupFile -Force
        Remove-Item $item.Location -Force
    } elseif ($item.Type -eq 'Scheduled Task') {
        $backupFile = Join-Path $backupDir $item.BackupFile
        Export-ScheduledTask -TaskName $item.Name -TaskPath $item.Location -Xml | Set-Content $backupFile
        Unregister-ScheduledTask -TaskName $item.Name -TaskPath $item.Location -Confirm:$false
    }
}

function Get-StartupItems {
    $items = @()
    # --- Startup Folders ---
    $userStartup = Join-Path $env:APPDATA 'Microsoft\Windows\Start Menu\Programs\Startup'
    $allStartup = Join-Path $env:ProgramData 'Microsoft\Windows\Start Menu\Programs\Startup'
    function Add-StartupFolderItems($folder, $scope) {
        if (Test-Path $folder) {
            Get-ChildItem -Path $folder -File | ForEach-Object {
                $items += [PSCustomObject]@{
                    Name = $_.Name
                    Location = $_.FullName
                    Type = "$scope Startup Folder"
                    BackupFile = "StartupFolder_" + $_.Name + ".bak"
                }
            }
        }
    }
    Add-StartupFolderItems $userStartup 'User'
    Add-StartupFolderItems $allStartup 'All Users'
    # --- Registry: Run/RunOnce (User & Machine) ---
    $regPaths = @(
        @{Path='HKCU:\Software\Microsoft\Windows\CurrentVersion\Run'; Scope='User'},
        @{Path='HKCU:\Software\Microsoft\Windows\CurrentVersion\RunOnce'; Scope='User'},
        @{Path='HKLM:\Software\Microsoft\Windows\CurrentVersion\Run'; Scope='Machine'},
        @{Path='HKLM:\Software\Microsoft\Windows\CurrentVersion\RunOnce'; Scope='Machine'}
    )
    foreach ($reg in $regPaths) {
        if (Test-Path $reg.Path) {
            $vals = Get-ItemProperty -Path $reg.Path
            foreach ($name in $vals.PSObject.Properties | Where-Object { $_.Name -notlike 'PS*' }) {
                $regScope = $reg.Scope
                $regPath = $reg.Path
                $regName = $name.Name
                $regValue = $vals.$($name.Name)
                $items += [PSCustomObject]@{
                    Name = $regName
                    Location = $regPath
                    Type = "$regScope Registry"
                    BackupFile = "Registry_" + $regScope + "_" + $regName + ".bak.json"
                    Path = $regPath
                    RegName = $regName
                    RegValue = $regValue
                }
            }
        }
    }
    # --- Scheduled Tasks (Logon) ---
    $tasks = Get-ScheduledTask | Where-Object { $_.Triggers | Where-Object { $_.AtLogOn } }
    foreach ($task in $tasks) {
        $items += [PSCustomObject]@{
            Name = $task.TaskName
            Location = $task.TaskPath
            Type = 'Scheduled Task'
            BackupFile = "Task_" + $task.TaskName.Replace('\\','_') + ".bak.xml"
        }
    }
    return $items
}

function Restore-StartupItem {
    param($file)
    if ($file.Name -like 'StartupFolder_*') {
        $target = $file.Name.Substring(13)
        $dest = Join-Path (Join-Path $env:APPDATA 'Microsoft\Windows\Start Menu\Programs\Startup') $target
        Copy-Item $file.FullName $dest -Force
        Write-Host "[Control] Restored $target to Startup Folder." -ForegroundColor Green
    } elseif ($file.Name -like 'Registry_*') {
        $json = Get-Content $file.FullName | ConvertFrom-Json
        Set-ItemProperty -Path $json.Path -Name $json.Name -Value $json.Value -Force
        Write-Host "[Control] Restored $($json.Name) to $($json.Path)." -ForegroundColor Green
    } elseif ($file.Name -like 'Task_*') {
        Register-ScheduledTask -Xml (Get-Content $file.FullName -Raw) -TaskName ($file.Name -replace '^Task_|\.bak\.xml$','')
        Write-Host "[Control] Restored scheduled task $($file.Name)." -ForegroundColor Green
    }
}

while ($true) {
    Write-Host "\n==================== HELP ====================" -ForegroundColor Cyan
    Write-Host "Enter a number (e.g., 3) to REMOVE a current startup item." -ForegroundColor Yellow
    Write-Host "Enter 'R#' (e.g., R2) to RESTORE a backed-up item." -ForegroundColor Yellow
    Write-Host "Enter 'Q' to quit." -ForegroundColor Yellow
    Write-Host "==============================================" -ForegroundColor Cyan
    $startupItems = Get-StartupItems
    $backups = Get-ChildItem -Path $backupDir -File
    Write-Host "\nCurrent Startup Items (Remove):"
    if ($startupItems.Count -eq 0) {
        Write-Host "  No startup items found." -ForegroundColor Green
    } else {
        for ($i=0; $i -lt $startupItems.Count; $i++) {
            $item = $startupItems[$i]
            Write-Host ("[{0}] {1} | {2} | {3}" -f ($i+1), $item.Name, $item.Type, $item.Location)
        }
    }
    Write-Host "\nBacked-up Startup Items (Restore):"
    if ($backups.Count -eq 0) {
        Write-Host "  No startup item backups found." -ForegroundColor Yellow
    } else {
        for ($i=0; $i -lt $backups.Count; $i++) {
            Write-Host ("[R{0}] {1}" -f ($i+1), $backups[$i].Name)
        }
    }
    Write-Host "\nEnter your selection:"
    $choice = Read-Host "Selection"
    $choice = $choice.Trim()
    if ($choice -match '^[0-9]+$') {
        $num = [int]$choice
        Write-Host "[Debug] Parsed number selection: $num"
        if ($num -ge 1 -and $num -le $startupItems.Count) {
            $item = $startupItems[$num-1]
            Write-Host "Backing up and disabling/removing: $($item.Name) ($($item.Type))..."
            try {
                Remove-StartupItem $item
                Write-Host "[Control] $($item.Name) removed from startup and backed up." -ForegroundColor Green
            } catch {
                Write-Host "[Control] Failed to remove $($item.Name): $($_.Exception.Message)" -ForegroundColor Red
            }
        } else {
            Write-Host "Invalid selection: number out of range." -ForegroundColor Red
        }
    } elseif ($choice -match '^R([0-9]+)$') {
        $idx = [int]$matches[1] - 1
        if ($idx -ge 0 -and $idx -lt $backups.Count) {
            $file = $backups[$idx]
            try {
                Restore-StartupItem $file
            } catch {
                Write-Host "[Control] Failed to restore $($file.Name): $($_.Exception.Message)" -ForegroundColor Red
            }
        } else {
            Write-Host "Invalid restore selection." -ForegroundColor Red
        }
    } elseif ($choice -match '^(Q|q)$' -or $choice -eq '') {
        break
    } else {
        Write-Host "Invalid selection. Please enter a number to remove, 'R#' to restore, or 'Q' to quit." -ForegroundColor Red
    }
}
Write-Host "[Control] Startup manager complete." 