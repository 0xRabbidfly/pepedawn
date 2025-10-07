# PepedawnRaffle Interaction Guide

## Setup (One-time)

### Configure Environment Variables
assuming .env is setup correctly

### Load Environment Variables

Before running any commands, load your `.env` variables:

```powershell
cd contracts
Get-Content .env | ForEach-Object { 
    if ($_ -match '^([^=]+)=(.*)$') {
        [Environment]::SetEnvironmentVariable($matches[1], $matches[2], 'Process')
    }
}
```

**Note**: The PowerShell script will automatically fallback to reading from `deploy/artifacts/addresses.json` if `CONTRACT_ADDRESS` is not set in your environment.

Or just run from the project root:
```powershell
cd Z:\Projects\pepedawn
```

## Available Commands

### Check Contract State (Read-Only)
```powershell
.\contracts\scripts\interact-sepolia.ps1 check
# or
.\contracts\scripts\interact-sepolia.ps1 status
```
**Shows formatted output with:**
- Current round ID
- Emergency pause status
- Contract pause status
- Owner address
- **Decoded round details with labels:**
  - ID, timestamps, **status (with name!)**
  - Tickets, weight, wagered (in ETH)
  - VRF info, fees, participant count

### Create New Round (Owner Only)
```powershell
.\contracts\scripts\interact-sepolia.ps1 create
```
**Requirements:**
- Must be contract owner
- Previous round must be completed (status = Distributed) or no rounds exist
- PRIVATE_KEY environment variable set

**Effect:**
- Increments `currentRoundId`
- Creates new round with 2-week duration
- Status set to `Created` (0)

### Open Round for Betting (Owner Only)
```powershell
.\contracts\scripts\interact-sepolia.ps1 open 1
```
**Requirements:**
- Must be contract owner
- Round must exist and be in `Created` status
- PRIVATE_KEY environment variable set

**Effect:**
- Changes round status from `Created` (0) → `Open` (1)
- Users can now place bets and submit proofs

### Place a Bet (Any User)
```powershell
# 1 ticket = 0.005 ETH
.\contracts\scripts\interact-sepolia.ps1 bet 1 0.005

# 5 tickets = 0.0225 ETH (10% discount)
.\contracts\scripts\interact-sepolia.ps1 bet 5 0.0225

# 10 tickets = 0.04 ETH (20% discount)
.\contracts\scripts\interact-sepolia.ps1 bet 10 0.04
```
**Requirements:**
- Round must be `Open` (status = 1)
- Correct ETH amount for ticket count
- Wallet cap: max 1.0 ETH total per round
- PRIVATE_KEY environment variable set

**Effect:**
- Adds tickets and weight to your account
- Updates round totals
- ETH held in contract until round settlement

### Quick Start (Create + Open)
```powershell
.\contracts\scripts\interact-sepolia.ps1 quick-start
```
**Does:**
1. Shows current state
2. Creates new round
3. Waits 2 seconds
4. Opens the round
5. Shows updated state

Perfect for starting a fresh round!

## Round Status Values

When you call `check` and see the round details, the status field shows:
- `0` = Created (round created, not yet open)
- `1` = Open (accepting bets and proofs)
- `2` = Closed (no more bets, preparing for draw)
- `3` = Snapshot (participants frozen)
- `4` = VRFRequested (waiting for random number)
- `5` = Distributed (winners selected, prizes sent)

## Complete Round Workflow (Owner Operations)

```powershell
# 1. Check if a round exists
.\contracts\scripts\interact-sepolia.ps1 check

# 2. Create new round (if needed)
.\contracts\scripts\interact-sepolia.ps1 create

# 3. Open round for betting
.\contracts\scripts\interact-sepolia.ps1 open 1

# Users place bets via frontend or CLI...

# 4. Close round when ready (future feature - add to script) BASH
``` BASH COMMANDS
set -a; source contracts/.env; set +a
cast send $CONTRACT_ADDRESS "closeRound(uint256)" 1 --private-key $PRIVATE_KEY --rpc-url $SEPOLIA_RPC_URL

# 5. Snapshot participants
set -a; source contracts/.env; set +a
cast send $CONTRACT_ADDRESS "snapshotRound(uint256)" 1 --private-key $PRIVATE_KEY --rpc-url $SEPOLIA_RPC_URL

# 6. Request VRF for winner selection
set -a; source contracts/.env; set +a
cast send $CONTRACT_ADDRESS "requestVRF(uint256)" 1 --private-key $PRIVATE_KEY --rpc-url $SEPOLIA_RPC_URL
```

## View Round Winners

After VRF fulfillment and prize distribution, view the winners:

```powershell
# Get all winners for round 1
.\contracts\scripts\interact-sepolia.ps1 winners 1

# Or use the check command to see general contract state
.\contracts\scripts\interact-sepolia.ps1 check
```

**Note**: The `winners` command shows raw winner data. To get organized pack tier display, you can parse the output or use the contract directly:

```powershell
# Direct contract call to get winners
cast call $env:CONTRACT_ADDRESS "getRoundWinners(uint256)" 1 --rpc-url $env:SEPOLIA_RPC_URL
```

**Winner Data Structure:**
- Each winner entry includes:
  - Wallet address
  - Prize tier (1=FAKE pack, 2=KEK pack, 3=PEPE pack)
  - VRF request ID
  - Block number

**View on Etherscan:**
```
https://sepolia.etherscan.io/address/0x3b8cB41b97a4F736F95D1b7d62D101F7a0cd251A
```

Look for these events:
- `VRFFulfilled` - Random number received
- `WinnersAssigned` - Winners selected
- `PrizeDistributed` - Prizes sent to winners

## Troubleshooting

### "PRIVATE_KEY required" Error
Make sure your `.env` file has `PRIVATE_KEY=<your_key>` and you've loaded the environment variables.

### "SEPOLIA_RPC_URL not set" Error
Add `SEPOLIA_RPC_URL=https://sepolia.drpc.org` to your `.env` file.

### "Previous round not completed" Error
A round already exists and hasn't been distributed yet. Either:
- Use `open 1` to open the existing round
- Complete the existing round workflow before creating a new one

### Check Raw Contract Output
Use `cast call` directly for debugging:
```powershell
cast call 0x3b8cB41b97a4F736F95D1b7d62D101F7a0cd251A "currentRoundId()" --rpc-url $env:SEPOLIA_RPC_URL
```

## Contract Address
**Current Deployment**: `0x3b8cB41b97a4F736F95D1b7d62D101F7a0cd251A` (VRF v2.5)

View on Etherscan: https://sepolia.etherscan.io/address/0x3b8cB41b97a4F736F95D1b7d62D101F7a0cd251A

