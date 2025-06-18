Write-Host "[Hope] Ending session with hope..." -ForegroundColor Green
$quotesFile = Join-Path $PSScriptRoot '../Resources/quotes.txt'
if (Test-Path $quotesFile) {
    $quotes = Get-Content $quotesFile | Where-Object { $_.Trim() -ne '' }
    if ($quotes.Count -gt 0) {
        $quote = Get-Random -InputObject $quotes
        Write-Host "\n✨ $quote ✨\n" -ForegroundColor Cyan
    }
}
Write-Host "[Hope] Goodbye! Pandora logs saved." 