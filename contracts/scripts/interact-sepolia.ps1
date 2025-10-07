# Sepolia Contract Interaction Script (PowerShell)
param(
    [string]$Command = "check",
    [string]$Arg1 = "",
    [string]$Arg2 = ""
)

# Load contract address from environment or use default
$CONTRACT_ADDRESS = $env:CONTRACT_ADDRESS
if (-not $CONTRACT_ADDRESS) {
    # Fallback to reading from addresses.json
    $addressesPath = Join-Path $PSScriptRoot "..\..\deploy\artifacts\addresses.json"
    if (Test-Path $addressesPath) {
        $addresses = Get-Content $addressesPath | ConvertFrom-Json
        $CONTRACT_ADDRESS = $addresses.'11155111'.PepedawnRaffle
    } else {
        Write-Host "Error: CONTRACT_ADDRESS not set in environment and addresses.json not found" -ForegroundColor Red
        Write-Host "Please set CONTRACT_ADDRESS environment variable or ensure deploy/artifacts/addresses.json exists" -ForegroundColor Yellow
        exit 1
    }
}

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
    $roundId = cast call $CONTRACT_ADDRESS "currentRoundId()" --rpc-url $env:SEPOLIA_RPC_URL
    $roundIdDec = [Convert]::ToInt64($roundId, 16)
    Write-Host $roundIdDec -ForegroundColor Cyan
    
    Write-Host "Emergency Paused: " -NoNewline
    $emergencyPaused = cast call $CONTRACT_ADDRESS "emergencyPaused()" --rpc-url $env:SEPOLIA_RPC_URL
    $emergencyPausedVal = if ($emergencyPaused -eq "0x0000000000000000000000000000000000000000000000000000000000000000") { "false" } else { "true" }
    Write-Host $emergencyPausedVal -ForegroundColor Cyan
    
    Write-Host "Contract Paused: " -NoNewline
    $paused = cast call $CONTRACT_ADDRESS "paused()" --rpc-url $env:SEPOLIA_RPC_URL
    $pausedVal = if ($paused -eq "0x0000000000000000000000000000000000000000000000000000000000000000") { "false" } else { "true" }
    Write-Host $pausedVal -ForegroundColor Cyan
    
    Write-Host "Owner: " -NoNewline
    $owner = cast call $CONTRACT_ADDRESS "owner()" --rpc-url $env:SEPOLIA_RPC_URL
    Write-Host $owner -ForegroundColor Cyan
    
    # Get current round details if exists
    if ($roundIdDec -gt 0) {
        Write-Host ""
        Write-Host "=== Round $roundIdDec Details ===" -ForegroundColor Blue
        
        # Get decoded round data
        $roundData = cast call $CONTRACT_ADDRESS "getRound(uint256)(uint256,uint64,uint64,uint8,uint256,uint256,uint256,uint256,uint64,bool,uint256)" $roundIdDec --rpc-url $env:SEPOLIA_RPC_URL
        $fields = $roundData -split "`n"
        
        if ($fields.Count -ge 11) {
            $statusNames = @("Created", "Open", "Closed", "Snapshot", "VRFRequested", "Distributed")
            $statusValue = [int]$fields[3]
            $statusName = if ($statusValue -lt $statusNames.Count) { $statusNames[$statusValue] } else { "Unknown" }
            
            Write-Host "  ID:                " -NoNewline; Write-Host $fields[0] -ForegroundColor Cyan
            Write-Host "  Start Time:        " -NoNewline; Write-Host $fields[1] -ForegroundColor Cyan
            Write-Host "  End Time:          " -NoNewline; Write-Host $fields[2] -ForegroundColor Cyan
            Write-Host "  Status:            " -NoNewline; Write-Host "$statusValue ($statusName)" -ForegroundColor $(if ($statusValue -eq 1) { "Green" } else { "Yellow" })
            Write-Host "  Total Tickets:     " -NoNewline; Write-Host $fields[4] -ForegroundColor Cyan
            Write-Host "  Total Weight:      " -NoNewline; Write-Host $fields[5] -ForegroundColor Cyan
            
            # Convert wei to ETH for wagered amount
            $weiAmountStr = $fields[6] -replace '\s.*$', ''  # Remove anything after space
            if ($weiAmountStr -match '^\d+$') {
                $ethAmount = [decimal]$weiAmountStr / 1000000000000000000
                Write-Host "  Total Wagered:     " -NoNewline; Write-Host ("{0:N4} ETH" -f $ethAmount) -ForegroundColor Cyan
            } else {
                Write-Host "  Total Wagered:     " -NoNewline; Write-Host $fields[6] -ForegroundColor Cyan
            }
            
            Write-Host "  VRF Request ID:    " -NoNewline; Write-Host $fields[7] -ForegroundColor Cyan
            Write-Host "  VRF Requested At:  " -NoNewline; Write-Host $fields[8] -ForegroundColor Cyan
            Write-Host "  Fees Distributed:  " -NoNewline; Write-Host $fields[9] -ForegroundColor Cyan
            Write-Host "  Participant Count: " -NoNewline; Write-Host $fields[10] -ForegroundColor Cyan
        } else {
            Write-Host "  Error parsing round data" -ForegroundColor Red
        }
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

# Function to view winners
function View-Winners {
    param([string]$RoundId)
    
    if (-not $RoundId) {
        $RoundId = cast call $CONTRACT_ADDRESS "currentRoundId()" --rpc-url $env:SEPOLIA_RPC_URL
        $RoundId = [Convert]::ToInt32($RoundId, 16)
    }
    
    Write-Host "Fetching winners for Round $RoundId..." -ForegroundColor Green
    
    # Get winners data
    $winnersData = cast call $CONTRACT_ADDRESS "getRoundWinners(uint256)" $RoundId --rpc-url $env:SEPOLIA_RPC_URL
    
    if ($winnersData) {
        Write-Host "`n=== ROUND $RoundId WINNERS ===" -ForegroundColor Cyan
        
        # Parse winner data (simplified - shows raw data)
        Write-Host "Winners Data:" -ForegroundColor Yellow
        Write-Host $winnersData
        
        Write-Host "`nPrize Tiers:" -ForegroundColor Yellow
        Write-Host "  1 = FAKE Pack" -ForegroundColor White
        Write-Host "  2 = KEK Pack" -ForegroundColor White
        Write-Host "  3 = PEPE Pack" -ForegroundColor White
        
        Write-Host "`nView detailed results on Etherscan:" -ForegroundColor Yellow
        Write-Host "https://sepolia.etherscan.io/address/$CONTRACT_ADDRESS#events" -ForegroundColor Cyan
    } else {
        Write-Host "No winners found for round $RoundId" -ForegroundColor Yellow
    }
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
    "winners" {
        View-Winners -RoundId $Arg1
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
        Write-Host "  check, status        - Check contract state"
        Write-Host "  create              - Create new round"
        Write-Host "  open <roundId>      - Open round for betting"
        Write-Host "  bet <tickets> <eth> - Place bet (e.g., bet 1 0.01)"
        Write-Host "  winners [roundId]   - View winners for round (defaults to current)"
        Write-Host "  quick-start         - Create and open round in one go"
        Write-Host ""
        Write-Host "Examples:"
        Write-Host "  .\interact-sepolia.ps1 check"
        Write-Host "  .\interact-sepolia.ps1 create"
        Write-Host "  .\interact-sepolia.ps1 open 1"
        Write-Host "  .\interact-sepolia.ps1 bet 1 0.01"
        Write-Host "  .\interact-sepolia.ps1 winners 1"
        Write-Host "  .\interact-sepolia.ps1 quick-start"
    }
}
