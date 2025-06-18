Write-Host "[Deceit] Privacy scan started..." -ForegroundColor Green

$fixes = @()
$recommendations = @()
$actionsTaken = @()

# --- Windows Telemetry Checks ---
Write-Host "\nChecking Windows telemetry settings..."
$telemetryKeys = @(
    'HKLM:\SOFTWARE\Policies\Microsoft\Windows\DataCollection',
    'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\DataCollection'
)
$telemetryFound = $false
foreach ($key in $telemetryKeys) {
    if (Test-Path $key) {
        $val = Get-ItemProperty -Path $key -ErrorAction SilentlyContinue | Select-Object -Property AllowTelemetry, DataCollectionAllowedTelemetry
        if ($val.AllowTelemetry -ne $null -and $val.AllowTelemetry -ne 0) {
            Write-Host "  [!] Telemetry is ENABLED: $key AllowTelemetry = $($val.AllowTelemetry)" -ForegroundColor Yellow
            Write-Host "      - This setting allows Microsoft to collect diagnostic and usage data."
            $fixes += @{Key=$key; Name='AllowTelemetry'}
            $recommendations += "Set AllowTelemetry to 0 for maximum privacy."
            $telemetryFound = $true
        }
        if ($val.DataCollectionAllowedTelemetry -ne $null -and $val.DataCollectionAllowedTelemetry -ne 0) {
            Write-Host "  [!] Telemetry is ENABLED: $key DataCollectionAllowedTelemetry = $($val.DataCollectionAllowedTelemetry)" -ForegroundColor Yellow
            Write-Host "      - This setting allows Microsoft to collect diagnostic and usage data."
            $fixes += @{Key=$key; Name='DataCollectionAllowedTelemetry'}
            $recommendations += "Set DataCollectionAllowedTelemetry to 0 for maximum privacy."
            $telemetryFound = $true
        }
    }
}
if (-not $telemetryFound) {
    Write-Host "  No explicit telemetry settings found in registry or telemetry is already minimized." -ForegroundColor Green
}

# --- Advertising ID ---
Write-Host "\nChecking Windows Advertising ID..."
$adIdKey = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\AdvertisingInfo'
$adIdFound = $false
if (Test-Path $adIdKey) {
    $adId = Get-ItemProperty -Path $adIdKey -ErrorAction SilentlyContinue | Select-Object -ExpandProperty Enabled
    if ($adId -eq 1) {
        Write-Host "  [!] Advertising ID is ENABLED." -ForegroundColor Yellow
        Write-Host "      - This allows apps to use your advertising ID for tracking."
        $fixes += @{Key=$adIdKey; Name='Enabled'}
        $recommendations += "Set Advertising ID to 0 to disable personalized ads."
        $adIdFound = $true
    }
}
if (-not $adIdFound) {
    Write-Host "  Advertising ID is already disabled or not found." -ForegroundColor Green
}

# --- Browser Extension Scan (Chrome/Edge/Firefox) ---
Write-Host "\nScanning for browser extensions..."
$privacyRisks = @('Grammarly', 'Honey', 'Loom', 'Zoom', 'Avast', 'AVG', 'McAfee', 'Norton', 'Superfish', 'Hola VPN', 'Web of Trust', 'AnyDesk', 'TeamViewer')
$foundRiskyExtensions = $false

function List-Chrome-Extensions {
    $chromePath = "$env:LOCALAPPDATA\Google\Chrome\User Data\Default\Extensions"
    if (Test-Path $chromePath) {
        Write-Host "  Chrome extensions found:" -ForegroundColor Cyan
        Get-ChildItem -Path $chromePath | ForEach-Object {
            $extId = $_.Name
            $manifest = Join-Path $_.FullName 'manifest.json'
            if (Test-Path $manifest) {
                $name = (Get-Content $manifest -Raw | ConvertFrom-Json).name
                Write-Host "    $name ($extId)"
                if ($privacyRisks -contains $name) {
                    Write-Host "      [!] Privacy risk: $name" -ForegroundColor Red
                    $foundRiskyExtensions = $true
                }
            }
        }
    } else {
        Write-Host "  Chrome not detected."
    }
}

function List-Edge-Extensions {
    $edgePath = "$env:LOCALAPPDATA\Microsoft\Edge\User Data\Default\Extensions"
    if (Test-Path $edgePath) {
        Write-Host "  Edge extensions found:" -ForegroundColor Cyan
        Get-ChildItem -Path $edgePath | ForEach-Object {
            $extId = $_.Name
            $manifest = Join-Path $_.FullName 'manifest.json'
            if (Test-Path $manifest) {
                $name = (Get-Content $manifest -Raw | ConvertFrom-Json).name
                Write-Host "    $name ($extId)"
                if ($privacyRisks -contains $name) {
                    Write-Host "      [!] Privacy risk: $name" -ForegroundColor Red
                    $foundRiskyExtensions = $true
                }
            }
        }
    } else {
        Write-Host "  Edge not detected."
    }
}

function List-Firefox-Extensions {
    $ffProfileRoot = "$env:APPDATA\Mozilla\Firefox\Profiles"
    if (Test-Path $ffProfileRoot) {
        $profiles = Get-ChildItem -Path $ffProfileRoot -Directory
        foreach ($profile in $profiles) {
            $extJson = Join-Path $profile.FullName 'extensions.json'
            if (Test-Path $extJson) {
                $exts = (Get-Content $extJson -Raw | ConvertFrom-Json).addons | Where-Object { $_.type -eq 'extension' }
                if ($exts) {
                    Write-Host "  Firefox extensions in profile $($profile.Name):" -ForegroundColor Cyan
                    foreach ($ext in $exts) {
                        Write-Host "    $($ext.defaultLocale.name) ($($ext.id))"
                        if ($privacyRisks -contains $ext.defaultLocale.name) {
                            Write-Host "      [!] Privacy risk: $($ext.defaultLocale.name)" -ForegroundColor Red
                            $foundRiskyExtensions = $true
                        }
                    }
                }
            }
        }
    } else {
        Write-Host "  Firefox not detected."
    }
}

List-Chrome-Extensions
List-Edge-Extensions
List-Firefox-Extensions

# --- Offer to Fix ---
if ($fixes.Count -gt 0 -or $adIdFound) {
    Write-Host "\nWould you like Pandora to fix these privacy risks automatically? (Y/N)"
    $fix = Read-Host "Enter Y to fix, N to skip"
    if ($fix -match '^(Y|y)') {
        foreach ($item in $fixes) {
            try {
                Set-ItemProperty -Path $item.Key -Name $item.Name -Value 0 -Force
                $actionsTaken += "Set $($item.Key) $($item.Name) to 0 (privacy mode)"
            } catch {
                $actionsTaken += "Failed to set $($item.Key) $($item.Name): $($_.Exception.Message)"
            }
        }
        if ($adIdFound) {
            try {
                Set-ItemProperty -Path $adIdKey -Name 'Enabled' -Value 0 -Force
                $actionsTaken += "Set Advertising ID to 0 (disabled)"
            } catch {
                $actionsTaken += "Failed to set Advertising ID: $($_.Exception.Message)"
            }
        }
        Write-Host "\n[Deceit] Privacy settings have been updated. You may need to restart your computer for all changes to take effect." -ForegroundColor Green
    } else {
        Write-Host "\n[Deceit] No changes made."
    }
}

if ($foundRiskyExtensions) {
    Write-Host "\n[!] Risky browser extensions detected. For your privacy, open your browser's extension manager and review/remove flagged extensions."
    Write-Host "  Chrome: chrome://extensions/"
    Write-Host "  Edge: edge://extensions/"
    Write-Host "  Firefox: about:addons"
}

# --- Summary ---
Write-Host "\n[Deceit] Privacy scan complete. Summary:"
if ($actionsTaken.Count -gt 0) {
    $actionsTaken | ForEach-Object { Write-Host "  - $_" }
} elseif ($fixes.Count -eq 0 -and -not $foundRiskyExtensions) {
    Write-Host "  No privacy risks found. Your system appears private!" -ForegroundColor Green
} else {
    Write-Host "  Review the above findings and recommendations."
    $recommendations | ForEach-Object { Write-Host "    * $_" }
} 