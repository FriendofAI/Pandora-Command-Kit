$logDir = Join-Path $PSScriptRoot '../Logs'
$logs = Get-ChildItem -Path $logDir -Filter '*.txt' | Sort-Object LastWriteTime -Descending
if ($logs.Count -eq 0) {
    Write-Host "[ViewLogs] No logs found." -ForegroundColor Yellow
    return
}
Write-Host "[ViewLogs] Available logs:"
for ($i=0; $i -lt $logs.Count; $i++) {
    Write-Host ("[$($i+1)] $($logs[$i].Name)")
}
$choice = Read-Host "Enter log number to view (or press Enter to cancel)"
if ($choice -match '^[0-9]+$' -and $choice -ge 1 -and $choice -le $logs.Count) {
    $logFile = $logs[$choice-1].FullName
    Write-Host "\n--- $($logs[$choice-1].Name) ---\n" -ForegroundColor Cyan
    Get-Content $logFile | ForEach-Object { Write-Host $_ }
    Write-Host "\n--- End of log ---\n"
} else {
    Write-Host "[ViewLogs] Cancelled."
} 