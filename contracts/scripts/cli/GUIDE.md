# PepedawnRaffle Interaction Guide

> **Note**: This guide has been updated for the new script directory structure.  
> Scripts are now organized in `contracts/scripts/cli/` for better organization.

## Setup (One-time)

### Configure Environment Variables
assuming .env is setup correctly

### Load Environment Variables

Before running any commands, load your `.env` variables:

```BASH
set -a; source contracts/.env; set +a
```

```powershell
cd contracts
Get-Content .env | ForEach-Object { 
    if ($_ -match '^([^=]+)=(.*)$') {
        [Environment]::SetEnvironmentVariable($matches[1], $matches[2], 'Process')
    }
}
```

**Note**: The PowerShell script will automatically fallback to reading from `deploy/artifacts/addresses.json` if `CONTRACT_ADDRESS` is not set in your environment.

## Available Commands

### Check Contract State (Read-Only)
```powershell
.\contracts\scripts\cli\interact.ps1 check
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
.\contracts\scripts\cli\interact.ps1 create
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
.\contracts\scripts\cli\interact.ps1 open 1
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
.\contracts\scripts\cli\interact.ps1 bet 1 0.005

# 5 tickets = 0.0225 ETH (10% discount)
.\contracts\scripts\cli\interact.ps1 bet 5 0.0225

# 10 tickets = 0.04 ETH (20% discount)
.\contracts\scripts\cli\interact.ps1 bet 10 0.04
```

### Set valid proof hash for the round (REQUIRED for proof validation)
``` BASH COMMANDS
# Replace 0x... with the keccak256 hash of the correct proof solution
cast send $CONTRACT_ADDRESS "setValidProof(uint256,bytes32)" 1 $(cast keccak256 "123") --private-key $PRIVATE_KEY --rpc-url $SEPOLIA_RPC_URL
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

## Round Status Values

When you call `check` and see the round details, the status field shows:
- `0` = Created (round created, not yet open)
- `1` = Open (accepting bets and proofs)
- `2` = Closed (no more bets, preparing for draw)
- `3` = Snapshot (participants frozen)
- `4` = VRFRequested (waiting for random number)
- `5` = Distributed (winners selected, prizes sent)
- `6` = Refunded (round closed with < 10 tickets, all participants refunded)

## Prize Distribution Logic

**Minimum Ticket Requirement**: Each round needs at least **10 total tickets** to distribute prizes.

- **If round closes with 10+ tickets**:
  - VRF draw proceeds normally
  - 10 winners selected using **weighted lottery** (same wallet can win multiple times)
  - Prize tiers: 1st=Fake Pack, 2nd=Kek Pack, 3rd-10th=Pepe Packs
  
- **If round closes with < 10 tickets**:
  - `closeRound()` automatically refunds ALL participants
  - No VRF request is made
  - Round status set to `Refunded`
  - All wagers returned to participants' wallets

## Proof Validation System

**Owner must set valid proof before opening round**:
- Call `setValidProof(roundId, proofHash)` with keccak256 hash of correct solution
- Users submit their proof attempt (only ONE attempt per wallet per round)
- If proof matches: +40% weight bonus applied, `ProofSubmitted` event emitted
- If proof doesn't match: NO bonus, `ProofRejected` event emitted, attempt consumed
- Frontend shows immediate success/failure feedback

## Wrap-up Round Workflow (Owner Operations)

# Close round when ready
# IMPORTANT: If round has < 10 tickets, closeRound() automatically refunds all participants
``` BASH COMMANDS
cast send $CONTRACT_ADDRESS "closeRound(uint256)" 1 --private-key $PRIVATE_KEY --rpc-url $SEPOLIA_RPC_URL

If round has 10+ tickets, continue with snapshot
cast send $CONTRACT_ADDRESS "snapshotRound(uint256)" 1 --private-key $PRIVATE_KEY --rpc-url $SEPOLIA_RPC_URL

Request VRF for winner selection
cast send $CONTRACT_ADDRESS "requestVrf(uint256)" 1 --private-key $PRIVATE_KEY --rpc-url $SEPOLIA_RPC_URL
```

## View Round Winners

After VRF fulfillment and prize distribution, view the winners:

```powershell
# Get all winners for round 1
.\contracts\scripts\cli\interact.ps1 winners 1

# Or use the check command to see general contract state
.\contracts\scripts\cli\interact.ps1 check
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

**Important Notes on Winner Selection:**
- **Weighted Lottery System**: Winners are selected based on their effective weight
  - More tickets = higher odds
  - Proof bonus (+40%) = even higher odds
- **Same wallet can win multiple prizes** (e.g., could win both Fake and Kek)
- Each prize is drawn independently with replacement
- Total: 10 winners, 10 packs distributed (1 Fake, 1 Kek, 8 Pepe)

**View on Etherscan:**
```
https://sepolia.etherscan.io/address/<new contract address>
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

---

## Script Directory Organization

The scripts are now organized into subdirectories for better maintainability:

### CLI Scripts (`scripts/cli/`)
- **interact.ps1** - Main CLI script for contract interaction (this guide)
- **GUIDE.md** - This interaction guide

### Foundry Scripts (`scripts/forge/`)
- **Deploy.s.sol** - Deploy the contract
- **CheckRoundState.s.sol** - Read-only state inspection
- **CheckAndOpenRound.s.sol** - Automated round creation/opening
- **ProgressRound.s.sol** - Progress round through states
- **DEPRECATED/UpdateVRFConfig.s.sol** - Deprecated (VRF config set in constructor)

### Test Scripts (`scripts/test/`)
- **test.ps1** - PowerShell test runner
- **test.sh** - Bash test runner

**Running Foundry Scripts:**
```bash
# From contracts/ directory
forge script scripts/forge/CheckRoundState.s.sol --rpc-url $SEPOLIA_RPC_URL

# Deploy script
forge script scripts/forge/Deploy.s.sol --rpc-url $SEPOLIA_RPC_URL --broadcast --verify
```

