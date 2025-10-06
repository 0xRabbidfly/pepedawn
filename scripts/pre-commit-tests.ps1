# Pre-commit tests script for Windows PowerShell

Write-Host "🔍 Running pre-commit checks..." -ForegroundColor Cyan

# Run smart contract tests
Write-Host "🧪 Running smart contract tests..." -ForegroundColor Yellow
Set-Location contracts

# Test files to run (matching GitHub Actions)
$testFiles = @(
    "test/BasicDeployment.t.sol",
    "test/AccessControl.t.sol", 
    "test/InputValidation.t.sol",
    "test/Wager.t.sol",
    "test/WinnerSelection.t.sol",
    "test/Distribution.t.sol",
    "test/EmergencyControls.t.sol",
    "test/Governance.t.sol",
    "test/Round.t.sol",
    "test/Security.t.sol",
    "test/ScenarioFullRound.t.sol"
)

# Run each test file
foreach ($testFile in $testFiles) {
    Write-Host "Running $testFile..." -ForegroundColor Green
    forge test --match-path $testFile
    if ($LASTEXITCODE -ne 0) {
        Write-Host "❌ Test failed: $testFile" -ForegroundColor Red
        exit 1
    }
}

Write-Host "✅ All smart contract tests passed!" -ForegroundColor Green

# Run frontend linting
Write-Host "🔍 Running frontend linting..." -ForegroundColor Yellow
Set-Location ../frontend
npm run lint
if ($LASTEXITCODE -ne 0) {
    Write-Host "❌ Frontend linting failed!" -ForegroundColor Red
    exit 1
}

Write-Host "✅ All pre-commit checks passed!" -ForegroundColor Green
