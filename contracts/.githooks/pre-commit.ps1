# Pre-commit hook for PepedawnRaffle (PowerShell)
# Runs fast test suite before allowing commit

Write-Host "🧪 Running pre-commit tests..." -ForegroundColor Cyan
Write-Host ""

# Navigate to contracts directory
if (Test-Path "contracts") {
    Set-Location contracts
}

# Run fast pre-commit test suite
$env:FOUNDRY_PROFILE = "pre-commit"
forge test

if ($LASTEXITCODE -eq 0) {
    Write-Host ""
    Write-Host "✅ Pre-commit tests passed!" -ForegroundColor Green
    exit 0
} else {
    Write-Host ""
    Write-Host "❌ Pre-commit tests failed!" -ForegroundColor Red
    exit 1
}

