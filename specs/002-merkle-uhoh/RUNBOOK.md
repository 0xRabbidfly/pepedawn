# PEPEDAWN Deployment & Testing Runbook

**Purpose**: Clean, repeatable deployment and testing cycle for PepedawnRaffle contract  
**Last Updated**: October 8, 2025  
**Target Network**: Sepolia Testnet  
**Prerequisites**: Git Bash or PowerShell, Foundry installed, MetaMask configured

---

## Prerequisites Checklist

Before starting, verify you have:

- [ ] Foundry installed (`forge --version`)
- [ ] Node.js 18+ (`node --version`)
- [ ] Git Bash or PowerShell
- [ ] MetaMask wallet with Sepolia ETH (at least 0.1 ETH)
- [ ] Sepolia RPC URL (e.g., from drpc.org or Alchemy)
- [ ] Chainlink VRF Subscription ID (see Setup section)

---

## Phase 0: Environment Setup (One-Time)

### 0.1 Configure Environment Variables

Create or update `contracts/.env`:

```bash
# Wallet Configuration
PRIVATE_KEY=your_private_key_here_without_0x_prefix

# Network Configuration
SEPOLIA_RPC_URL=https://sepolia.drpc.org

# Chainlink VRF Configuration (Sepolia)
VRF_COORDINATOR=0x9DdfaCa8183c41ad55329BdeeD9F6A8d53168B1B
VRF_SUBSCRIPTION_ID=your_subscription_id
VRF_KEY_HASH=0x787d74caea10b2b357790d5b5247c2f63d1d91572a9846f780606e4d953677ae

# Contract Addresses
CREATORS_ADDRESS=your_creators_wallet_address
EMBLEM_VAULT_ADDRESS=0x82FbD1c8fBe0a8f6Eb684dd49a4D7D2e62b2d7Fc # Emblem Vault Sepolia

# Contract Address (filled after deployment)
CONTRACT_ADDRESS=
```

**Important**: 
- Never commit `.env` to git
- Get VRF Subscription ID from [Chainlink VRF Dashboard](https://vrf.chain.link/)
- Fund your VRF subscription with LINK tokens

### 0.2 Load Environment Variables

**PowerShell**:
```powershell
cd contracts
Get-Content .env | ForEach-Object { 
    if ($_ -match '^([^=]+)=(.*)$') {
        [Environment]::SetEnvironmentVariable($matches[1], $matches[2], 'Process')
    }
}
```

**Git Bash**:
```bash
cd contracts
set -a; source .env; set +a
```

### 0.3 Verify Environment

```powershell
# Check if variables loaded
echo $env:SEPOLIA_RPC_URL
echo $env:VRF_COORDINATOR
```

**Expected**: Should print your RPC URL and VRF coordinator address

---

## Phase 1: Contract Deployment

### 1.1 Build Contract

```powershell
cd contracts
forge build
```

**Expected**: 
```
[⠊] Compiling...
[⠊] Compiling 1 files with 0.8.20
[⠢] Solc 0.8.20 finished in X.XXs
Compiler run successful!
```

**Verify**: Check that `contracts/out/pepedawn.sol/PepedawnRaffle.json` exists

### 1.2 Run Tests (Optional but Recommended)

```powershell
forge test --gas-report
```

**Expected**: All tests pass with gas usage report

### 1.3 Deploy Contract

```powershell
# Deploy to Sepolia
forge script scripts/forge/Deploy.s.sol --rpc-url $env:SEPOLIA_RPC_URL --broadcast --verify

# Note: If verification fails during deployment, you can verify later (see Phase 2)
```

**Expected Output**:
```
Script ran successfully.

== Logs ==
  PepedawnRaffle deployed to: 0xYourNewContractAddress

## Setting up 1 EVM.

==========================

Chain 11155111

Estimated gas price: X.XXX gwei

Estimated total gas used for script: XXXXX

Estimated amount required: 0.XXXX ETH

==========================

ONCHAIN EXECUTION COMPLETE & SUCCESSFUL.
```

**Action Required**: Copy the contract address from the output

### 1.4 Update Environment Variables

Add the contract address to your `.env`:

```bash
CONTRACT_ADDRESS=0xYourNewContractAddress
```

Then reload environment (repeat step 0.2)

### 1.5 Add Contract as VRF Consumer

Go to [Chainlink VRF Dashboard](https://vrf.chain.link/):
1. Select your subscription
2. Click "Add consumer"
3. Paste your contract address
4. Confirm transaction

**Verify**: Contract address appears in consumer list

---

## Phase 2: Contract Verification (If Needed)

If verification failed during deployment, verify manually:

```powershell
node ../scripts/verify-contract.js
```

Or use forge directly:

```powershell
forge verify-contract $env:CONTRACT_ADDRESS \
    PepedawnRaffle \
    --chain sepolia \
    --constructor-args $(cast abi-encode "constructor(address,uint256,bytes32,address,address)" $env:VRF_COORDINATOR $env:VRF_SUBSCRIPTION_ID $env:VRF_KEY_HASH $env:CREATORS_ADDRESS $env:EMBLEM_VAULT_ADDRESS)
```

**Verify**: Check contract on [Sepolia Etherscan](https://sepolia.etherscan.io/)

---

## Phase 3: Round Lifecycle - Create & Open

### 3.1 Check Contract State

```powershell
.\scripts\cli\interact.ps1 check
```

**Expected Output**:
```
===========================================
📊 PepedawnRaffle Contract State
===========================================

📍 Network: sepolia (Chain ID: 11155111)
📋 Contract: 0xYourContractAddress

Current Round ID: 0
Emergency Pause: false
Contract Paused: false
Owner: 0xYourAddress

=== Round 0 Details ===
ID: 0
Start Time: 0 (Thu Jan 01 1970 00:00:00)
End Time: 0 (Thu Jan 01 1970 00:00:00)
Status: 0 (Created)
...
```

**Note**: If `currentRoundId` is 0, no rounds exist yet

### 3.2 Create New Round

```powershell
.\scripts\cli\interact.ps1 create
```

**Expected Output**:
```
Creating new round...
Transaction hash: 0xtxhash...
✅ Round created successfully!
New Round ID: 1
```

**Verify**: Run `.\scripts\cli\interact.ps1 check` again - `currentRoundId` should now be 1

### 3.3 Set Valid Proof (Required for Proof Validation)

```bash
# Set the proof hash that users must match for +40% weight bonus
cast send $env:CONTRACT_ADDRESS "setValidProof(uint256,bytes32)" 1 $(cast keccak256 "your_proof_solution") --private-key $env:PRIVATE_KEY --rpc-url $env:SEPOLIA_RPC_URL
```

**Example with simple proof**:
```bash
cast send $env:CONTRACT_ADDRESS "setValidProof(uint256,bytes32)" 1 $(cast keccak256 "pepedawn123") --private-key $env:PRIVATE_KEY --rpc-url $env:SEPOLIA_RPC_URL
```

**Expected**: Transaction succeeds, proof hash stored for round 1

### 3.4 Open Round for Betting

```powershell
.\scripts\cli\interact.ps1 open 1
```

**Expected Output**:
```
Opening round 1...
Transaction hash: 0xtxhash...
✅ Round opened successfully!
```

**Verify**: Run `.\scripts\cli\interact.ps1 check` - Status should change from `0 (Created)` to `1 (Open)`

---

## Phase 4: Frontend Setup

### 4.1 Update Frontend Configuration

```powershell
cd ../frontend

# Automatically update contract address and ABI
node ../scripts/update-configs.js
```

**Expected Output**:
```
✅ Updated deploy/artifacts/addresses.json
✅ Updated frontend/public/deploy/PepedawnRaffle-abi.json
✅ Updated frontend/src/contract-config.js
```

**Verify**: Check that `frontend/src/contract-config.js` has your new contract address

### 4.2 Install Dependencies (If Not Already Done)

```powershell
npm install
```

### 4.3 Start Frontend Dev Server

```powershell
npm run dev
```

**Expected Output**:
```
VITE v5.x.x  ready in XXX ms

➜  Local:   http://localhost:5173/
➜  Network: use --host to expose
```

### 4.4 Open Frontend in Browser

Open `http://localhost:5173/main.html` in your browser

**Connect MetaMask**:
1. Click "Connect Wallet" button
2. Approve MetaMask connection
3. Ensure you're on Sepolia network

**Verify**: 
- ✅ Wallet connected indicator shows your address
- ✅ Current round displays "Round 1"
- ✅ Round status shows "Open"
- ✅ Ticket prices displayed correctly

---

## Phase 5: User Interaction Testing (Via UI)

### 5.1 Place Bets via UI

**Test with Multiple Wallets** (recommended for realistic testing):

**Wallet 1** (Your deployer wallet):
1. Select "1 Ticket" bundle (0.005 ETH)
2. Click "Place Bet" button
3. Confirm transaction in MetaMask
4. Wait for confirmation (should take 10-30 seconds)
5. Verify: Ticket count increases in UI

**Wallet 2** (Switch to second test wallet in MetaMask):
1. Switch wallet in MetaMask (if you have multiple)
2. Refresh page or reconnect wallet
3. Select "5 Tickets" bundle (0.0225 ETH)
4. Place bet via UI
5. Confirm transaction

**Wallet 3** (Switch to third test wallet):
1. Switch wallet in MetaMask
2. Select "10 Tickets" bundle (0.04 ETH)
3. Place bet via UI
4. Confirm transaction

**Minimum Requirement**: You need **at least 10 total tickets** across all participants for prize distribution

**Verify After Each Bet**:
- ✅ Total tickets counter increases
- ✅ Total wagered (ETH) increases
- ✅ Participant count increases
- ✅ Your wallet's ticket count shows correctly
- ✅ Leaderboard updates (if visible)

### 5.2 Submit Proof via UI (Optional)

**Find the Proof Submission Section** on the main page:

**Test Case 1 - Correct Proof**:
1. Enter the correct proof: `pepedawn123` (from Phase 3.3)
2. Click "Submit Proof" button
3. Confirm transaction in MetaMask
4. Wait for confirmation
5. **Verify**: Success message appears, weight bonus indicator shows +40%

**Test Case 2 - Incorrect Proof** (with different wallet):
1. Switch to different wallet in MetaMask
2. Enter incorrect proof: `wrong_answer`
3. Submit via UI
4. **Verify**: Rejection message appears, no bonus applied

**Check Results**:
- ✅ Correct proof wallets show +40% weight badge
- ✅ Incorrect proof wallets show "No bonus"
- ✅ Proof attempts consumed (can only submit once per wallet)

### 5.3 Monitor State via CLI (Optional)

**In a separate terminal**:
```powershell
cd contracts
.\scripts\cli\interact.ps1 check
```

This lets you verify on-chain state matches UI display:
- Total tickets
- Total wagered
- Participant count
- Proof submissions

---

## Phase 6: Close Round & Snapshot

### 6.1 Close Round

```bash
cast send $env:CONTRACT_ADDRESS "closeRound(uint256)" 1 --private-key $env:PRIVATE_KEY --rpc-url $env:SEPOLIA_RPC_URL
```

**Expected**: 
- If `totalTickets` >= 10: Round status changes to `Closed (2)`
- If `totalTickets` < 10: Round status changes to `Refunded (6)` and all participants get refunds

**Verify**: Run `.\scripts\cli\interact.ps1 check`

**If Refunded**: Skip to Phase 8 (create new round with more tickets)

### 6.2 Snapshot Participants

**Only if round has >= 10 tickets**:

```bash
# Generate participants Merkle tree and upload to IPFS
node ../scripts/generate-merkle-tree.js

# Then call snapshotRound with the generated root and CID
# (Script should output the exact command to run)
cast send $env:CONTRACT_ADDRESS "snapshotRound(uint256,bytes32,string,uint256)" \
    1 \
    0xMerkleRootFromScript \
    QmIPFSHashFromScript \
    totalWeightFromScript \
    --private-key $env:PRIVATE_KEY \
    --rpc-url $env:SEPOLIA_RPC_URL
```

**Expected**: Round status changes to `Snapshot (3)`

**Verify**: 
```bash
.\scripts\cli\interact.ps1 check
```

---

## Phase 7: VRF Request & Winner Selection

### 7.1 Request VRF Randomness

```bash
cast send $env:CONTRACT_ADDRESS "requestVrf(uint256)" 1 --private-key $env:PRIVATE_KEY --rpc-url $env:SEPOLIA_RPC_URL
```

**Expected**: 
- Transaction succeeds
- Round status changes to `VRFRequested (4)`
- VRF request ID is stored

**Verify**: 
```powershell
.\scripts\cli\interact.ps1 check
```

Look for `vrfRequestId` in the output (should be non-zero)

### 7.2 Wait for VRF Fulfillment

**Important**: VRF fulfillment is automatic but takes 1-3 minutes

Check status periodically:
```powershell
# Run every 30 seconds
.\scripts\cli\interact.ps1 check
```

**Expected**: 
- Status changes from `VRFRequested (4)` to `Distributed (5)`
- This happens automatically when VRF callback fires

**Verify on Etherscan**:
1. Go to your contract on Sepolia Etherscan
2. Check "Events" tab
3. Look for:
   - `VRFRequested` - Request sent
   - `VRFFulfilled` - Random number received
   - `WinnersAssigned` - Winners selected
   - `PrizeDistributed` - Prizes distributed

### 7.3 View Winners

```powershell
.\scripts\cli\interact.ps1 winners 1
```

**Expected Output**:
```
=== Round 1 Winners ===
Winner 1: 0xAddress1 - FAKE pack (Tier 1)
Winner 2: 0xAddress2 - KEK pack (Tier 2)
Winner 3: 0xAddress3 - PEPE pack (Tier 3)
...
Winner 10: 0xAddress10 - PEPE pack (Tier 3)
```

**Note**: Same wallet can win multiple times (weighted lottery with replacement)

---

## Phase 8: View Results & Test Claims (Via UI)

Return to the browser where your frontend is running.

### 8.1 View Leaderboard

The UI should automatically update to show:
- Round status: "Distributed"
- Leaderboard with all participants
- Each participant's tickets, weight, and effective weight
- Proof bonus badges (if applicable)

### 8.2 View Winners Section

Scroll to "Winners" section on the page. You should see all 10 winners with their prize tiers and "Claim" buttons if you're a winner.

### 8.3 Test Claim Flow (If You're a Winner)

If you won a prize:

1. Click "Claim" button in winners section
2. MetaMask prompts for transaction
3. Confirm transaction
4. Wait for confirmation
5. Verify prize NFT appears in your wallet

**Check on Emblem Vault**: Go to emblem.finance and verify prize ownership

---

## Phase 9: Cleanup & Next Round

### 9.1 Verify Round Completion

```powershell
cd ../contracts
.\scripts\cli\interact.ps1 check
```

**Verify**:
- Round 1 status: `Distributed (5)`
- All fees distributed: `true`
- Ready to create Round 2

### 9.2 Create Next Round

Repeat from Phase 3:
```powershell
.\scripts\cli\interact.ps1 create
.\scripts\cli\interact.ps1 open 2
# ... continue cycle
```

---

## Troubleshooting

### Issue: "Previous round not completed"

**Cause**: Round 1 still active  
**Solution**: Complete the round lifecycle (close → snapshot → VRF → distribute)

### Issue: "PRIVATE_KEY required"

**Cause**: Environment variables not loaded  
**Solution**: Reload .env (see Phase 0.2)

### Issue: "Insufficient funds"

**Cause**: Not enough Sepolia ETH in wallet  
**Solution**: Get Sepolia ETH from faucet (sepoliafaucet.com)

### Issue: "VRF request timeout"

**Cause**: VRF fulfillment took > 1 hour  
**Solution**: Call `retryVrf(uint256 roundId)` as owner

### Issue: Round automatically refunded

**Cause**: < 10 total tickets when `closeRound()` called  
**Solution**: This is expected behavior. Create new round with more participants

### Issue: Verification fails during deployment

**Cause**: Etherscan API rate limit or network issues  
**Solution**: Verify manually using Phase 2 commands

### Issue: Frontend shows wrong contract data

**Cause**: Frontend config not updated with new contract address  
**Solution**: 
```bash
node scripts/update-configs.js
```

### Issue: "Cannot find interact.ps1"

**Cause**: Wrong directory  
**Solution**: Make sure you're in `contracts/` directory:
```powershell
cd contracts
.\scripts\cli\interact.ps1 check
```

---

## Quick Reference Commands

```powershell
# Check contract state
.\scripts\cli\interact.ps1 check

# Create & open round
.\scripts\cli\interact.ps1 create
.\scripts\cli\interact.ps1 open 1

# View winners
.\scripts\cli\interact.ps1 winners 1

# Update frontend config
cd ../frontend
node ../scripts/update-configs.js

# Start frontend
npm run dev
```

---

## Expected Timeline

| Phase | Estimated Time |
|-------|----------------|
| 0. Environment Setup | 10 minutes (one-time) |
| 1. Deployment | 5 minutes |
| 2. Verification | 2 minutes |
| 3. Create/Open Round | 2 minutes |
| 4. Frontend Setup | 3 minutes |
| 5. User Testing (via UI) | 10 minutes |
| 6. Close/Snapshot | 3 minutes |
| 7. VRF & Winners | 3-5 minutes (mostly waiting) |
| 8. View Results & Claims | 5 minutes |
| **Total** | **35-45 minutes** |

---

## Related Documentation

- **CLI Interaction Guide**: [GUIDE.md](./GUIDE.md) - Detailed command reference
- **Automation Guide**: [../../../scripts/AUTOMATION_GUIDE.md](../../../scripts/AUTOMATION_GUIDE.md) - Automation system
- **Merkle Quickstart**: [../../../specs/002-merkle/quickstart.md](../../../specs/002-merkle/quickstart.md) - Development workflow
- **Specification**: [../../../specs/002-merkle/spec.md](../../../specs/002-merkle/spec.md) - Feature specification

---

**Last Updated**: October 8, 2025  
**Version**: 1.0.0  
**Tested On**: Windows 11, PowerShell 7.x, Foundry 0.2.x
