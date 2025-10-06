# Sepolia Contract Interaction Script (PowerShell)
param(
    [string]$Command = "check",
    [string]$Arg1 = "",
    [string]$Arg2 = ""
)

$CONTRACT_ADDRESS = "0xBa8E7795682A6d0A05F805aD45258E3d4641BFFc"

Write-Host "=== PepedawnRaffle Sepolia Interaction ===" -ForegroundColor Blue
Write-Host "Contract: $CONTRACT_ADDRESS"
Write-Host ""

# Check if environment variables are set
if (-not $env:SEPOLIA_RPC_URL) {
    Write-Host "Error: SEPOLIA_RPC_URL not set" -ForegroundColor Red
    exit 1
}

if (-not $env:PRIVATE_KEY) {
    Write-Host "Warning: PRIVATE_KEY not set (read-only mode)" -ForegroundColor Yellow
}

# Function to check contract state
function Check-State {
    Write-Host "=== Contract State ===" -ForegroundColor Blue
    
    Write-Host "Current Round ID: " -NoNewline
    cast call $CONTRACT_ADDRESS "currentRoundId()" --rpc-url $env:SEPOLIA_RPC_URL
    
    Write-Host "Emergency Paused: " -NoNewline
    cast call $CONTRACT_ADDRESS "emergencyPaused()" --rpc-url $env:SEPOLIA_RPC_URL
    
    Write-Host "Contract Paused: " -NoNewline
    cast call $CONTRACT_ADDRESS "paused()" --rpc-url $env:SEPOLIA_RPC_URL
    
    Write-Host "Owner: " -NoNewline
    cast call $CONTRACT_ADDRESS "owner()" --rpc-url $env:SEPOLIA_RPC_URL
    
    # Get current round details if exists
    $CURRENT_ROUND = cast call $CONTRACT_ADDRESS "currentRoundId()" --rpc-url $env:SEPOLIA_RPC_URL
    if ($CURRENT_ROUND -ne "0x0000000000000000000000000000000000000000000000000000000000000000") {
        Write-Host "=== Round $CURRENT_ROUND Details ===" -ForegroundColor Blue
        cast call $CONTRACT_ADDRESS "rounds(uint256)" $CURRENT_ROUND --rpc-url $env:SEPOLIA_RPC_URL
    } else {
        Write-Host "No rounds created yet" -ForegroundColor Yellow
    }
}

# Function to create round
function Create-Round {
    if (-not $env:PRIVATE_KEY) {
        Write-Host "Error: PRIVATE_KEY required for transactions" -ForegroundColor Red
        return
    }
    
    Write-Host "Creating new round..." -ForegroundColor Green
    cast send $CONTRACT_ADDRESS "createRound()" --private-key $env:PRIVATE_KEY --rpc-url $env:SEPOLIA_RPC_URL
}

# Function to open round
function Open-Round {
    param([string]$RoundId)
    
    if (-not $env:PRIVATE_KEY) {
        Write-Host "Error: PRIVATE_KEY required for transactions" -ForegroundColor Red
        return
    }
    
    if (-not $RoundId) {
        Write-Host "Error: Round ID required" -ForegroundColor Red
        return
    }
    
    Write-Host "Opening round $RoundId..." -ForegroundColor Green
    cast send $CONTRACT_ADDRESS "openRound(uint256)" $RoundId --private-key $env:PRIVATE_KEY --rpc-url $env:SEPOLIA_RPC_URL
}

# Function to place bet
function Place-Bet {
    param([string]$Tickets, [string]$EthAmount)
    
    if (-not $env:PRIVATE_KEY) {
        Write-Host "Error: PRIVATE_KEY required for transactions" -ForegroundColor Red
        return
    }
    
    if (-not $Tickets -or -not $EthAmount) {
        Write-Host "Error: Usage: Place-Bet <tickets> <eth_amount>" -ForegroundColor Red
        Write-Host "Example: Place-Bet 1 0.01"
        return
    }
    
    Write-Host "Placing bet: $Tickets tickets for $EthAmount ETH..." -ForegroundColor Green
    $weiAmount = cast --to-wei $EthAmount ether
    cast send $CONTRACT_ADDRESS "placeBet(uint256)" $Tickets --value $weiAmount --private-key $env:PRIVATE_KEY --rpc-url $env:SEPOLIA_RPC_URL
}

# Main switch
switch ($Command.ToLower()) {
    { $_ -in "check", "status", "" } {
        Check-State
    }
    "create" {
        Create-Round
    }
    "open" {
        Open-Round -RoundId $Arg1
    }
    "bet" {
        Place-Bet -Tickets $Arg1 -EthAmount $Arg2
    }
    "quick-start" {
        Write-Host "=== Quick Start: Creating and Opening Round ===" -ForegroundColor Green
        Check-State
        Write-Host ""
        Create-Round
        Write-Host ""
        Start-Sleep -Seconds 2
        Open-Round -RoundId "1"
        Write-Host ""
        Check-State
    }
    default {
        Write-Host "Usage: .\interact-sepolia.ps1 [command] [args]"
        Write-Host ""
        Write-Host "Commands:"
        Write-Host "  check, status     - Check contract state"
        Write-Host "  create           - Create new round"
        Write-Host "  open <roundId>   - Open round for betting"
        Write-Host "  bet <tickets> <eth> - Place bet (e.g., bet 1 0.01)"
        Write-Host "  quick-start      - Create and open round in one go"
        Write-Host ""
        Write-Host "Examples:"
        Write-Host "  .\interact-sepolia.ps1 check"
        Write-Host "  .\interact-sepolia.ps1 create"
        Write-Host "  .\interact-sepolia.ps1 open 1"
        Write-Host "  .\interact-sepolia.ps1 bet 1 0.01"
        Write-Host "  .\interact-sepolia.ps1 quick-start"
    }
}
