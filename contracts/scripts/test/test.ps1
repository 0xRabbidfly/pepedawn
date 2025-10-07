# Test Script for PepedawnRaffle Contract (PowerShell)
# Usage: .\scripts\test.ps1 [profile]

param(
    [string]$Profile = "ci"
)

Write-Host "🧪 Running tests with profile: $Profile" -ForegroundColor Cyan

# Load environment variables if .env exists
if (Test-Path ".env") {
    Write-Host "📋 Loading environment variables..." -ForegroundColor Yellow
    Get-Content .env | ForEach-Object { 
        if ($_ -match "^([^#][^=]+)=(.*)$") { 
            [Environment]::SetEnvironmentVariable($matches[1], $matches[2], "Process") 
        } 
    }
}

# Run tests based on profile
switch ($Profile) {
    "unit" {
        Write-Host "🔬 Running unit tests (mocked dependencies)..." -ForegroundColor Green
        forge test --profile unit
    }
    "integration" {
        Write-Host "🔗 Running integration tests (workflow with mocks)..." -ForegroundColor Green
        forge test --profile integration
    }
    "deployed" {
        Write-Host "🌐 Running deployed contract tests..." -ForegroundColor Green
        if (-not $env:SEPOLIA_RPC_URL) {
            Write-Host "❌ SEPOLIA_RPC_URL not set. Please set it in .env file" -ForegroundColor Red
            exit 1
        }
        forge test --profile deployed
    }
    "vrf" {
        Write-Host "🎲 Running VRF tests (requires funded subscription)..." -ForegroundColor Green
        if (-not $env:SEPOLIA_RPC_URL) {
            Write-Host "❌ SEPOLIA_RPC_URL not set. Please set it in .env file" -ForegroundColor Red
            exit 1
        }
        forge test --profile vrf
    }
    "security" {
        Write-Host "🔒 Running security tests..." -ForegroundColor Green
        forge test --profile security
    }
    "all" {
        Write-Host "🎯 Running all tests (excluding VRF)..." -ForegroundColor Green
        forge test --profile all
    }
    "ci" {
        Write-Host "🚀 Running CI tests (fast, reliable)..." -ForegroundColor Green
        forge test --profile ci
    }
    default {
        Write-Host "❌ Unknown profile: $Profile" -ForegroundColor Red
        Write-Host "Available profiles: unit, integration, deployed, vrf, security, all, ci" -ForegroundColor Yellow
        exit 1
    }
}

Write-Host "✅ Tests completed successfully!" -ForegroundColor Green
