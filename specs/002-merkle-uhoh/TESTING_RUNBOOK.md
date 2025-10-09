# PEPEDAWN Complete Testing Runbook

**Purpose**: Step-by-step guide for testing the complete PepedawnRaffle lifecycle  
**Last Updated**: October 8, 2025  
**Target Network**: Sepolia Testnet  
**Expected Duration**: 45-60 minutes (including VRF wait time)

---

## Overview

This runbook walks you through a complete round test:

1. **Deploy & Verify** - Deploy contract to Sepolia, verify on Etherscan
2. **Round Setup** - Create and open Round 1
3. **User Testing (UI)** - Place bets and submit proofs via frontend
4. **Close & Snapshot** - Close round and take participants snapshot
5. **Merkle Participants** - Generate participants file, upload to IPFS, commit root
6. **VRF & Winners** - Request randomness, wait for fulfillment, select winners
7. **Merkle Winners** - Generate winners file, upload to IPFS, commit root
8. **Claims (UI)** - View winners and test claim flow
9. **Verification** - Confirm everything worked correctly

---

## Prerequisites Checklist

Before starting, verify:

- [ ] **Foundry installed** - `forge --version` (should show 0.2.x)
- [ ] **Node.js 18+** - `node --version`
- [ ] **Git Bash or PowerShell** - Windows PowerShell 7.x recommended
- [ ] **MetaMask wallet** - With Sepolia ETH (0.2+ ETH for testing)
- [ ] **Multiple test wallets** - At least 3 wallets in MetaMask for realistic testing
- [ ] **Sepolia RPC URL** - From drpc.org, Alchemy, or Infura
- [ ] **Chainlink VRF Subscription** - Created and funded at vrf.chain.link
- [ ] **Emblem Vault NFTs** - 10 test NFTs ready to transfer to contract

---

## Phase 0: Environment Setup

### 0.1 Configure Environment Variables

Create `contracts/.env` with your configuration:

```bash
# Wallet Configuration
PRIVATE_KEY=your_private_key_here_without_0x_prefix

# Network Configuration (Use drpc.org for better rate limits)
SEPOLIA_RPC_URL=https://sepolia.drpc.org

# Chainlink VRF Configuration (Sepolia)
VRF_COORDINATOR=0x9DdfaCa8183c41ad55329BdeeD9F6A8d53168B1B
VRF_SUBSCRIPTION_ID=your_subscription_id
VRF_KEY_HASH=0x787d74caea10b2b357790d5b5247c2f63d1d91572a9846f780606e4d953677ae

# Contract Addresses
CREATORS_ADDRESS=your_creators_wallet_address
EMBLEM_VAULT_ADDRESS=0x82FbD1c8fBe0a8f6Eb684dd49a4D7D2e62b2d7Fc

# Contract Address (filled after deployment)
CONTRACT_ADDRESS=

# IPFS Configuration (Optional - enables automatic uploads)
# Get Pinata JWT from: https://app.pinata.cloud/ → API Keys → New Key
PINATA_JWT=your_pinata_jwt_here
```

**Important Notes**:
- Never commit `.env` to git (already in .gitignore)
- Get VRF Subscription ID from [Chainlink VRF Dashboard](https://vrf.chain.link/)
- Fund your VRF subscription with at least 5 LINK tokens
- `CREATORS_ADDRESS` receives 20% of each round's proceeds
- Get Pinata JWT from [Pinata](https://app.pinata.cloud/) → API Keys → New Key → Copy JWT
- With `PINATA_JWT` set, IPFS uploads are fully automated!

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

### 0.3 Verify Environment Loaded

```powershell
echo $env:SEPOLIA_RPC_URL
echo $env:VRF_COORDINATOR
echo $env:PRIVATE_KEY
```

**Expected**: All three variables should print their values

### 0.4 Install CLI Dependencies

```powershell
cd scripts/cli
npm install
cd ../..
```

**Expected**: Dependencies installed in `contracts/scripts/cli/node_modules/`

---

## Phase 1: Deploy & Verify Contract

### 1.1 Build Contract

```powershell
forge build
```

**Expected Output**:
```
[⠊] Compiling...
[⠊] Compiling 1 files with 0.8.20
[⠢] Solc 0.8.20 finished in X.XXs
Compiler run successful!
```

**Verify**: Check that `out/PepedawnRaffle.sol/PepedawnRaffle.json` exists

### 1.2 Run Tests (Optional but Recommended)

```powershell
forge test
```

**Expected**: All tests pass (should see green ✓ marks)

If you want gas reports:
```powershell
forge test --gas-report
```

### 1.3 Deploy to Sepolia

```powershell
forge script scripts/forge/Deploy.s.sol --rpc-url $env:SEPOLIA_RPC_URL --broadcast --verify
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

Starting contract verification...
Waiting for etherscan to detect contract deployment...
```

**⚠️ IMPORTANT**: Copy the contract address from the output!

**If verification fails**: Don't worry, we'll verify manually in next step

### 1.4 Manual Verification (If Needed)

If automatic verification failed:

```powershell
# From project root
node scripts/verify-contract.js
```

Or use forge directly:

```powershell
forge verify-contract $env:CONTRACT_ADDRESS \
    src/PepedawnRaffle.sol:PepedawnRaffle \
    --chain sepolia \
    --watch \
    --constructor-args $(cast abi-encode "constructor(address,uint256,bytes32,address,address)" $env:VRF_COORDINATOR $env:VRF_SUBSCRIPTION_ID $env:VRF_KEY_HASH $env:CREATORS_ADDRESS $env:EMBLEM_VAULT_ADDRESS)
```

**Verify Success**: Go to `https://sepolia.etherscan.io/address/YOUR_CONTRACT_ADDRESS`
- Should show green ✓ "Contract Source Code Verified"
- Can see "Read Contract" and "Write Contract" tabs

### 1.5 Update Contract Address in All Configs

**Automated Method (Recommended):**
```powershell
# From project root - updates addresses.json and all frontend configs
node scripts/update-contract-address.js 0xYourNewContractAddress
```

**Expected Output**:
```
🚀 Updating contract address...

Contract: 0xYourNewContractAddress
Chain ID: 11155111 (Sepolia)

📝 Updating contract address to: 0xYourNewContractAddress
✅ Contract address updated in addresses.json
✅ Frontend addresses updated
✅ Frontend contract-config address updated
✅ Frontend configuration updated
✅ VRF configuration updated

✅ Contract address update complete!
```

**Manual Method (Backup):**
If the automated script fails, manually edit `contracts/.env`:
```bash
CONTRACT_ADDRESS=0xYourNewContractAddress
```

Then reload environment (repeat step 0.2)

### 1.6 Add Contract as VRF Consumer

1. Go to [Chainlink VRF Dashboard](https://vrf.chain.link/)
2. Connect your wallet
3. Select your subscription
4. Click "Add consumer"
5. Paste your `CONTRACT_ADDRESS`
6. Confirm transaction in MetaMask

**Verify**: Contract address appears in "Consumers" list

---

## Phase 2: Round Setup

### 2.1 Check Initial Contract State

```powershell
cd scripts/cli
node manage-round.js status 0
```

**Expected Output**:
```
===========================================
📊 Round Status Report
===========================================
Network: sepolia (Chain ID: 11155111)
Contract: 0xYourContractAddress

❌ Round 0 does not exist or is not initialized

✨ Next Steps:
   1. Create a new round: cast send ...
```

This is normal - no rounds exist yet!

### 2.2 Create Round 1

```powershell
cd ../.. # Back to contracts/
cast send $env:CONTRACT_ADDRESS "createRound()" --private-key $env:PRIVATE_KEY --rpc-url $env:SEPOLIA_RPC_URL
```

**Expected Output**:
```
blockHash               0x...
blockNumber             XXXXX
...
status                  1 (success)
transactionHash         0x...
```

**Verify**: Check Etherscan for `RoundCreated` event

### 2.3 Transfer Prize NFTs to Contract

**⚠️ REQUIRED**: Contract needs 10 Emblem Vault NFTs to award as prizes

**Using Emblem Vault Interface**:
1. Go to your Emblem Vault holdings
2. Transfer 10 NFTs to `CONTRACT_ADDRESS`
3. Note the token IDs (you'll need them next)

**Verify**: Check contract balance on Etherscan:
```powershell
cast call $env:CONTRACT_ADDRESS "balanceOf(address)" $env:CONTRACT_ADDRESS --rpc-url $env:SEPOLIA_RPC_URL
```
Should return `10` (0x000...00a in hex)

### 2.4 Map Prize NFTs to Round 1

Map the 10 NFTs you transferred as prizes:

```powershell
# Example with token IDs 1-10
cast send $env:CONTRACT_ADDRESS "setPrizesForRound(uint256,uint256[10])" 1 "[1,2,3,4,5,6,7,8,9,10]" --private-key $env:PRIVATE_KEY --rpc-url $env:SEPOLIA_RPC_URL
```
**Replace `[1,2,3,4,5,6,7,8,9,10]`** with your actual token IDs!

**Expected**: Transaction succeeds

### 2.5 Set Valid Proof (Optional)

Set a proof puzzle for +40% weight bonus:

```powershell
# Using simple proof "pepedawn2025"
cast send $env:CONTRACT_ADDRESS "setValidProof(uint256,bytes32)" 1 $(cast keccak256 "pepedawn2025") --private-key $env:PRIVATE_KEY --rpc-url $env:SEPOLIA_RPC_URL
```

**Expected**: Transaction succeeds

**Note**: Users who submit `pepedawn2025` get +40% to their weight!

### 2.6 Open Round for Betting

```powershell
cast send $env:CONTRACT_ADDRESS "openRound(uint256)" 1 --private-key $env:PRIVATE_KEY --rpc-url $env:SEPOLIA_RPC_URL
```

**Expected Output**:
```
status                  1 (success)
```

### 2.7 Verify Round is Open

```powershell
cd scripts/cli
node manage-round.js status 1
```

**Expected Output**:
```
===========================================
📊 Round Status Report
===========================================
...

📋 Round 1 Details:
   Status: Open (1) ✅
   Start Time: Oct 08, 2025 12:34:56
   End Time: Oct 22, 2025 12:34:56
   Total Tickets: 0
   Total Wagered: 0 ETH
   Participants: 0

✨ Next Steps:
   1. Users can now place bets via frontend
   2. Owner can close round after minimum 10 tickets
```

Perfect! Round 1 is ready for betting.

---

## Phase 3: User Testing (Frontend)

### 3.1 Update Frontend Configuration

**Update ABI (If Contract Code Changed)**
```powershell
cd ../../.. # To project root
node scripts/update-abi.js
```

**Expected Output**:
```
🔧 PEPEDAWN ABI Updater Starting...

📋 Loaded ABI with 122 functions/events
💾 Created backup: frontend/src/contract-config.js.backup
✅ Frontend config ABI updated
✅ Standalone ABI file updated

✅ ABI update complete!
```

**Note**: Only run this if you've modified the contract code. For new deployments of the same contract, the address update in step 1.5 is sufficient.

### 3.2 Install Frontend Dependencies (First Time Only)

```powershell
cd frontend
npm install
```

### 3.3 Start Frontend Dev Server

```powershell
npm run dev
```

**Expected Output**:
```
VITE v5.x.x  ready in XXX ms

➜  Local:   http://localhost:5173/
➜  Network: use --host to expose
```

**Keep this terminal running!** Open a new terminal for CLI commands.

### 3.4 Open Frontend & Connect Wallet

1. Open browser to `http://localhost:5173/main.html`
2. Click "**Connect Wallet**" button
3. Approve MetaMask connection
4. Ensure you're on **Sepolia network** in MetaMask

**Verify**:
- ✅ Wallet address displays in header
- ✅ Round 1 displays
- ✅ Status shows "Open"
- ✅ Ticket prices show (1, 5, 10, 25 tickets)
- ✅ Total tickets shows "0"

### 3.5 Place Bets (Wallet 1 - Your Main Wallet)

**Test with multiple wallets for realistic lottery!**

**Wallet 1 Bet**:
1. Select "**5 Tickets**" (0.0225 ETH)
2. Click "**Place Bet**" button
3. MetaMask opens - review transaction
4. Confirm transaction
5. Wait 10-30 seconds for confirmation

**Expected**:
- ✅ Success message appears
- ✅ Total tickets: 5
- ✅ Total wagered: 0.0225 ETH
- ✅ Participants: 1
- ✅ Your wallet shows: 5 tickets

### 3.6 Place Bets (Wallet 2)

**Switch to second wallet in MetaMask**:
1. Click MetaMask extension
2. Switch to Wallet 2
3. Refresh page or click "Connect Wallet" again

**Wallet 2 Bet**:
1. Select "**10 Tickets**" (0.04 ETH)
2. Place bet
3. Confirm transaction
4. Wait for confirmation

**Expected**:
- Total tickets: 15
- Participants: 2

### 3.7 Submit Proof (Wallet 2)

**While still on Wallet 2**, test proof submission:

1. Find "**Proof Submission**" section
2. Enter: `pepedawn2025`
3. Click "**Submit Proof**"
4. Confirm transaction in MetaMask
5. Wait for confirmation

**Expected**:
- ✅ Success message
- ✅ Weight bonus badge shows "+40%"
- ✅ Wallet 2's effective weight increased

### 3.8 Place Bets (Wallet 3)

**Switch to third wallet**:

**Wallet 3 Bet**:
1. Select "**10 Tickets**" (0.04 ETH)
2. Place bet
3. Confirm transaction

**Wallet 3 Proof** (wrong answer to test rejection):
1. Enter: `wrong_answer`
2. Submit proof
3. **Expected**: Error message, no bonus applied

**Current State**:
- Total tickets: 25
- Participants: 3
- Wallet 2 has proof bonus (+40% weight)

### 3.9 Verify State via CLI (Optional)

**Open new terminal**:
```powershell
cd contracts/scripts/cli
node manage-round.js status 1
```

**Expected**:
```
Total Tickets: 25
Total Wagered: 0.1025 ETH
Participants: 3
```

Should match UI display!

---

## Phase 4: Close Round & Snapshot

### 4.1 Close Round

```powershell
cd ../../ # To contracts/
cast send $env:CONTRACT_ADDRESS "closeRound(uint256)" 1 --private-key $env:PRIVATE_KEY --rpc-url $env:SEPOLIA_RPC_URL
```

**Expected**: Transaction succeeds

**Auto-Refund Check**: 
- If < 10 tickets: Round automatically refunds all bets
- If ≥ 10 tickets: Round closes successfully, continue to snapshot

**Verify**:
```powershell
cd scripts/cli
node manage-round.js status 1
```

Should show: `Status: Closed (2)`

### 4.2 Take Snapshot

```powershell
cd ../..
cast send $env:CONTRACT_ADDRESS "snapshotRound(uint256)" 1 --private-key $env:PRIVATE_KEY --rpc-url $env:SEPOLIA_RPC_URL
```

**Expected**: Transaction succeeds

**Verify**:
```powershell
cd scripts/cli
node manage-round.js status 1
```

Should show: `Status: Snapshot (3)`

---

## Phase 5: Generate & Commit Participants (Merkle)

### 5.1 Generate Participants File

```powershell
node manage-round.js snapshot 1
```

**Expected Output**:
```
✅ Generated participants-round-1.json
   - 3 participants
   - Total tickets: 25
   - Total weight: XXXXX
   - Merkle root: 0x...

📤 Next Steps:
   1. Upload file to IPFS
   2. Commit root on-chain
```

**Verify**: File `participants-round-1.json` created in current directory

### 5.2 Review Participants File

```powershell
cat participants-round-1.json | ConvertFrom-Json | ConvertTo-Json -Depth 10
```

**Should contain**:
- All 3 participants with addresses
- Correct ticket counts (5, 10, 10)
- Weight calculations (Wallet 2 should have +40% bonus)
- Merkle root

### 5.3 Upload to IPFS (Automated!)

```powershell
node upload-to-ipfs.js participants-round-1.json
```

**Expected Output (with PINATA_JWT set)**:
```
✅ Valid participants file
   Round ID: 1
   Merkle Root: 0x282f034a...
   Participants: 5
   Total Weight: 22

✅ Pinata API key detected - uploading automatically...

🚀 Uploading to Pinata IPFS...

✅ Upload successful!

📋 IPFS CID: bafybeiabc123...

🔗 Access file at:
   https://nftstorage.link/ipfs/bafybeiabc123...
   https://ipfs.io/ipfs/bafybeiabc123...

📝 Next Step - Commit on-chain: (GRAB THIS CMD FROM TERMINAL OUTPUT)
─────────────────────────────────────────────────
cast send 0xYourContract "commitParticipantsRoot(uint256,bytes32,string)" 1 0x282f034a... "bafybeiabc123..." --private-key $PRIVATE_KEY --rpc-url $SEPOLIA_RPC_URL
cd ../..

✅ File uploaded and ready to commit!
```

**If API key not set**: You'll get manual upload instructions instead.

**Verify Upload**: Click any of the URLs shown to confirm the file is accessible.

### 5.4 Commit Participants Root On-Chain

**Copy the cast command from the upload output** and run it.

```powershell
cd ../..
# Replace MERKLE_ROOT and IPFS_CID with your actual values
cast send $env:CONTRACT_ADDRESS "commitParticipantsRoot(uint256,bytes32,string)" 1 0xYOUR_MERKLE_ROOT "YOUR_IPFS_CID" --private-key $env:PRIVATE_KEY --rpc-url $env:SEPOLIA_RPC_URL
```

**Expected**: Transaction succeeds

**Verify**:
```powershell
cd scripts/cli
node manage-round.js status 1
```

Should show:
```
Participants Root: 0x742d35C... ✅
Participants CID: QmX1234... ✅
```

---

## Phase 6: VRF Request & Winner Selection

### 6.1 Request VRF Randomness

```powershell
cd ../..
cast send $env:CONTRACT_ADDRESS "requestVrf(uint256)" 1 \
    --private-key $env:PRIVATE_KEY \
    --rpc-url $env:SEPOLIA_RPC_URL
```

**Expected**: Transaction succeeds

**Verify**:
```powershell
cd scripts/cli
node manage-round.js status 1
```

Should show:
```
Status: VRFRequested (4) ⏳
VRF Request ID: 12345 (non-zero)
```

### 6.2 Wait for VRF Fulfillment

**⏳ This takes 1-5 minutes** (sometimes up to 10 minutes on testnet)

**Monitor status every 30 seconds**:
```powershell
node manage-round.js status 1
```

**Expected transition**:
```
Status: VRFRequested (4) ⏳
↓ (wait 1-5 minutes)
Status: VRFFulfilled (5) ✅
```

**Verify on Etherscan**:
1. Go to your contract on Sepolia Etherscan
2. Click "**Events**" tab
3. Look for:
   - ✅ `VRFRequested` - Request sent (should see immediately)
   - ✅ `VRFFulfilled` - Randomness received (after 1-5 min)
   - ✅ `WinnersAssigned` - Winners selected (right after fulfillment)

**If VRF takes > 10 minutes**: Check VRF subscription has enough LINK

### 6.3 Verify Winners Selected On-Chain

Once status shows `VRFFulfilled (5)`:

```powershell
node manage-round.js status 1
```

**Expected**:
```
Status: VRFFulfilled (5) ✅
VRF Seed: 0x123abc... (non-zero)
Winners Count: 10

✨ Next Steps:
   1. Generate winners file
   2. Upload to IPFS
   3. Commit winners root
```

---

## Phase 7: Generate & Commit Winners (Merkle)

### 7.1 Generate Winners File

```powershell
node manage-round.js commit-winners 1
```

**Expected Output**:
```
✅ Generated winners-round-1.json
   - 10 winners selected
   - VRF Seed: 0x...
   - Merkle root: 0x...

📋 Winners:
   1. 0xWallet1 - Prize Tier 1 (FAKE pack)
   2. 0xWallet2 - Prize Tier 2 (KEK pack)
   3. 0xWallet3 - Prize Tier 3 (PEPE pack)
   ...

📤 Next Steps:
   1. Upload file to IPFS
   2. Commit winners root on-chain
```

**Verify**: File `winners-round-1.json` created

### 7.2 Review Winners File

```powershell
cat winners-round-1.json | ConvertFrom-Json | ConvertTo-Json -Depth 10
```

**Should contain**:
- 10 winners with addresses
- Prize tiers (1 FAKE, 2 KEK, 7 PEPE)
- Prize indices (which NFT token ID from the round)
- VRF seed for reproducibility
- Merkle root for claims

**Note**: Same wallet can win multiple times (lottery with replacement)

### 7.3 Upload Winners to IPFS (Automated!)

```powershell
node upload-to-ipfs.js winners-round-1.json
```

**Expected Output**:
```
✅ NFT.Storage API key detected - uploading automatically...

🚀 Uploading to NFT.Storage...
✅ Upload successful!

📋 IPFS CID: bafybeixyz789...

📝 Next Step - Commit on-chain:
─────────────────────────────────────────────────
cast send 0xYourContract "commitWinners(uint256,bytes32,string)" 1 0x8a2d35C... "bafybeixyz789..." --private-key $PRIVATE_KEY --rpc-url $SEPOLIA_RPC_URL
```

**Verify Upload**: Click the URLs in the output to confirm file is accessible.

### 7.4 Commit Winners Root On-Chain

**Copy the cast command from the upload output** and run it.

```powershell
cd ../..
cast send $env:CONTRACT_ADDRESS \
    "commitWinners(uint256,bytes32,string)" \
    1 \
    0xYOUR_WINNERS_MERKLE_ROOT \
    "YOUR_WINNERS_IPFS_CID" \
    --private-key $env:PRIVATE_KEY \
    --rpc-url $env:SEPOLIA_RPC_URL
```

**Example**:
```powershell
cast send $env:CONTRACT_ADDRESS \
    "commitWinners(uint256,bytes32,string)" \
    1 \
    0x8a2d35Cc6634C0532925a3b844Bc9e7595f0bEb9 \
    "QmY5678efgh..." \
    --private-key $env:PRIVATE_KEY \
    --rpc-url $env:SEPOLIA_RPC_URL
```

**Expected**: Transaction succeeds

**Verify**:
```powershell
cd scripts/cli
node manage-round.js status 1
```

Should show:
```
Status: WinnersCommitted (6) ✅
Winners Root: 0x8a2d35C... ✅
Winners CID: QmY5678... ✅

🎉 Round Complete! Winners can now claim prizes.
```

---

## Phase 8: View Winners & Test Claims (Frontend)

### 8.1 Refresh Frontend

Go back to browser where frontend is running (`http://localhost:5173/main.html`)

**Press F5 or Ctrl+R** to refresh the page

### 8.2 View Round Status

**Should now show**:
- Round status: "**Winners Committed**" or "**Distributed**"
- Total participants: 3
- Total tickets: 25
- Total wagered: 0.1025 ETH

### 8.3 View Winners List

Scroll to "**Winners**" section on the page.

**Should display**:
- 10 winner entries
- Each winner's address (truncated)
- Prize tier (FAKE / KEK / PEPE)
- Prize token ID

**Example**:
```
Winner 1: 0x1234...5678 - FAKE Pack #1
Winner 2: 0xabcd...efgh - KEK Pack #3
...
```

### 8.4 Check If You Won

Look for your wallet address(es) in the winners list.

**Possible scenarios**:
- ✅ You won 1+ prizes → "**Claim**" button appears
- ❌ You didn't win → No claim button (try with other wallets)

### 8.5 Test Claim Flow (If Winner)

If you see a "**Claim**" button next to your address:

1. Click "**Claim Prize**" button
2. **Frontend automatically**:
   - Fetches winners file from IPFS
   - Finds your winning entry
   - Generates Merkle proof client-side
   - Prepares claim transaction
3. MetaMask opens with transaction
4. Review transaction details:
   - Function: `claim(uint256 roundId, uint8 prizeTier, uint8 prizeIndex, bytes32[] proof)`
   - Gas: ~150k-200k
5. **Confirm transaction**
6. Wait 10-30 seconds

**Expected**:
- ✅ Success message: "Prize claimed successfully!"
- ✅ "Claim" button changes to "**Claimed**" or disappears
- ✅ Emblem Vault NFT transferred to your wallet

### 8.6 Verify NFT Receipt

**Check on Etherscan**:
1. Go to your wallet address on Sepolia Etherscan
2. Click "**ERC-721 Tokens**" tab
3. Should see new Emblem Vault NFT

**Check in MetaMask**:
1. Open MetaMask
2. Go to "**NFTs**" tab
3. Should see Emblem Vault NFT (may need to import manually with token ID)

**Check on Emblem Vault**:
1. Go to https://emblem.finance
2. Connect wallet
3. Navigate to your vault
4. Prize should appear in your collection

### 8.7 Test Multiple Claims (If Multiple Wins)

If your wallet won multiple prizes:

1. Each win has its own "Claim" button
2. Repeat claim process for each prize
3. Verify each NFT received

**Note**: You can claim in any order, at any time

### 8.8 Switch Wallets & Test Other Winners

**Switch to Wallet 2 or 3** in MetaMask:

1. Change wallet in MetaMask
2. Refresh frontend page
3. Connect new wallet
4. Check if this wallet won
5. If yes, test claim flow for this wallet too

This verifies claims work for multiple users!

---

## Phase 9: Verification & Cleanup

### 9.1 Verify Round Completion

```powershell
cd contracts/scripts/cli
node manage-round.js status 1
```

**Expected**:
```
Status: WinnersCommitted (6) ✅
Total Tickets: 25
Total Wagered: 0.1025 ETH
Participants: 3
Winners: 10
All Fees Distributed: true ✅

Participants Root: 0x... ✅
Participants CID: Qm... ✅
Winners Root: 0x... ✅
Winners CID: Qm... ✅

🎉 Round Complete!
```

### 9.2 Verify IPFS Files Accessible

**Participants File**:
```
https://ipfs.io/ipfs/YOUR_PARTICIPANTS_CID
```

**Winners File**:
```
https://ipfs.io/ipfs/YOUR_WINNERS_CID
```

Both should display JSON files in browser.

**If IPFS is slow**: Try alternative gateways:
- `https://cloudflare-ipfs.com/ipfs/YOUR_CID`
- `https://gateway.pinata.cloud/ipfs/YOUR_CID`
- `https://YOUR_CID.ipfs.dweb.link/`

### 9.3 Verify Prize Distributions on Etherscan

Go to contract on Sepolia Etherscan:

**Check Events tab** for Round 1:
- ✅ `RoundCreated` - Round initialization
- ✅ `RoundOpened` - Betting started
- ✅ `TicketsPurchased` (x3) - Three bets placed
- ✅ `ProofSubmitted` - Wallet 2's proof
- ✅ `RoundClosed` - Betting ended
- ✅ `RoundSnapshot` - Participants frozen
- ✅ `ParticipantsCommitted` - Merkle root stored
- ✅ `VRFRequested` - Randomness requested
- ✅ `VRFFulfilled` - Randomness received
- ✅ `WinnersAssigned` - 10 winners selected
- ✅ `WinnersCommitted` - Winners Merkle root stored
- ✅ `PrizeClaimed` (x10) - All prizes claimed (if fully tested)

**Check Internal Transactions**:
- ✅ ETH sent to `CREATORS_ADDRESS` (20% fee)
- ✅ NFTs transferred to winners via `claim()`

### 9.4 Verify Balance Changes

**Contract Balance**:
```powershell
cast balance $env:CONTRACT_ADDRESS --rpc-url $env:SEPOLIA_RPC_URL
```

Should be near 0 (minus gas for transactions)

**Creators Balance** (should have received 20% = ~0.0205 ETH):
```powershell
cast balance $env:CREATORS_ADDRESS --rpc-url $env:SEPOLIA_RPC_URL
```

### 9.5 Document Results

**Create a test report** with:
- ✅ Contract address
- ✅ Round 1 transaction hashes
- ✅ Participants IPFS CID
- ✅ Winners IPFS CID
- ✅ Number of claims processed
- ✅ Any issues encountered
- ✅ Total time taken

**Example**:
```
Test Date: Oct 8, 2025
Network: Sepolia
Contract: 0xYourContractAddress
Round: 1

Participants: 3
Tickets: 25
Wagered: 0.1025 ETH
Winners: 10
Claims: 10/10 successful

Participants CID: QmX1234...
Winners CID: QmY5678...

Duration: 45 minutes (including 3min VRF wait)
Status: ✅ ALL SYSTEMS OPERATIONAL
```

---

## Phase 10: Cleanup & Next Round (Optional)

### 10.1 Clean Up Test Files

```powershell
cd contracts/scripts/cli
rm participants-round-1.json
rm winners-round-1.json
```

These are now safely stored on IPFS, no need for local copies.

### 10.2 Prepare for Round 2 (Optional)

If testing multiple rounds:

1. Transfer 10 more NFTs to contract
2. `createRound()` - Creates Round 2
3. `setPrizesForRound(2, [...])` - Map new NFTs
4. `openRound(2)` - Open for betting
5. Repeat testing process

**Verify Round 1 Complete**:
```powershell
node manage-round.js status 1
```

Should show `WinnersCommitted (6) ✅`

**Create Round 2**:
```powershell
cd ../..
cast send $env:CONTRACT_ADDRESS "createRound()" \
    --private-key $env:PRIVATE_KEY \
    --rpc-url $env:SEPOLIA_RPC_URL
```

---

## Troubleshooting

### Issue: "Too Many Requests" or Rate Limit Error

**Cause**: RPC endpoint rate limit exceeded (common with Infura free tier)  
**Solution**: Switch to a more generous RPC endpoint:
1. Update `contracts/.env`:
   ```bash
   SEPOLIA_RPC_URL=https://sepolia.drpc.org
   ```
2. Reload environment variables (repeat step 0.2)
3. Retry the command

**Note**: The scripts now have built-in retry logic and rate limiting (100ms delays between requests), but using drpc.org is still recommended.

### Issue: "Insufficient funds for intrinsic transaction cost"

**Cause**: Not enough Sepolia ETH in deployer wallet  
**Solution**: Get more Sepolia ETH from faucets:
- https://sepoliafaucet.com
- https://faucet.quicknode.com/ethereum/sepolia
- Google "Sepolia faucet"

### Issue: "VRF subscription not found"

**Cause**: Wrong `VRF_SUBSCRIPTION_ID` or subscription not created  
**Solution**: 
1. Go to https://vrf.chain.link/
2. Create new subscription
3. Fund with 5+ LINK
4. Update `.env` with correct subscription ID

### Issue: "Contract not verified on Etherscan"

**Cause**: Verification failed during deployment  
**Solution**: Run manual verification (Phase 1.4)

### Issue: Round auto-refunded after close

**Cause**: Less than 10 total tickets when `closeRound()` called  
**Solution**: This is expected! Place more bets (need 10+ total) and create new round

### Issue: VRF takes > 10 minutes

**Cause**: Low LINK balance in subscription or network congestion  
**Solution**:
1. Check VRF subscription LINK balance
2. Add more LINK if needed
3. Wait up to 30 minutes on testnet
4. If still stuck, contact Chainlink support

### Issue: Frontend shows "Connect Wallet" but MetaMask is connected

**Cause**: Wrong network selected in MetaMask  
**Solution**: Switch to Sepolia in MetaMask network dropdown

### Issue: "Participants root already committed"

**Cause**: Trying to commit same root twice  
**Solution**: This is a safety feature. Continue to next phase (request VRF)

### Issue: Claim button doesn't appear even though I won

**Cause**: Frontend can't fetch winners file from IPFS  
**Solution**:
1. Verify winners CID is correct
2. Try alternative IPFS gateway
3. Check browser console for errors (F12)
4. Wait 1-2 minutes for IPFS propagation

### Issue: Claim transaction fails with "Invalid proof"

**Cause**: Merkle proof generation failed or wrong parameters  
**Solution**:
1. Verify `winners-round-1.json` uploaded correctly
2. Check winners Merkle root matches on-chain
3. Try refreshing page and claiming again
4. Check browser console for detailed error

### Issue: NFT not showing in MetaMask after claim

**Cause**: MetaMask doesn't auto-detect all NFTs  
**Solution**:
1. Open MetaMask → NFTs tab
2. Click "Import NFT"
3. Enter Emblem Vault contract address: `0x82FbD1c8fBe0a8f6Eb684dd49a4D7D2e62b2d7Fc`
4. Enter your prize token ID (from winners file)

---

## Expected Timeline

| Phase | Task | Estimated Time |
|-------|------|----------------|
| 0 | Environment Setup | 10 min (one-time) |
| 1 | Deploy & Verify | 5-7 min |
| 2 | Round Setup | 5 min |
| 3 | Frontend Testing | 10-15 min |
| 4 | Close & Snapshot | 2 min |
| 5 | Merkle Participants | 5 min |
| 6 | VRF Request & Wait | 1-5 min (mostly waiting) |
| 7 | Merkle Winners | 5 min |
| 8 | Claims Testing | 10 min |
| 9 | Verification | 5 min |
| **Total** | **45-60 minutes** | |

---

## Success Criteria

This test is successful if:

- ✅ Contract deploys and verifies on Sepolia
- ✅ Round 1 created and opened
- ✅ 3+ wallets successfully placed bets (10+ total tickets)
- ✅ Proof submission works (both correct and incorrect)
- ✅ Round closes and snapshot succeeds
- ✅ Participants file generated with correct Merkle root
- ✅ Participants file uploaded to IPFS and accessible
- ✅ Participants root committed on-chain
- ✅ VRF request succeeds and fulfills within 10 minutes
- ✅ Winners file generated with 10 winners
- ✅ Winners file uploaded to IPFS and accessible
- ✅ Winners root committed on-chain
- ✅ Frontend displays winners correctly
- ✅ Claim flow works (Merkle proof generated, transaction succeeds)
- ✅ NFT transferred to winner's wallet
- ✅ All events emitted correctly on Etherscan
- ✅ Creators received 20% fee

---

## Related Documentation

- **CLI Scripts README**: `contracts/scripts/cli/README.md` - Detailed command reference
- **Automation Guide**: `scripts/AUTOMATION_GUIDE.md` - CI/CD automation
- **Specification**: `specs/002-merkle/spec.md` - Technical specification
- **Old Runbook**: `specs/002-merkle-uhoh/RUNBOOK.md` - Previous deployment guide

---

## Notes for Production

**Before mainnet deployment**:

1. **Audit**: Get professional security audit
2. **VRF Subscription**: Fund with 50-100 LINK
3. **NFTs**: Use real Emblem Vault prize packs
4. **Gas**: Test all transactions on mainnet fork first
5. **IPFS**: Use multiple pinning services (NFT.Storage + Pinata + Filebase)
6. **Frontend**: Deploy to IPFS/Vercel with ENS domain
7. **Monitoring**: Set up alerts for VRF failures, low LINK balance
8. **Backup Keys**: Secure owner keys with hardware wallet

---

**Last Updated**: October 8, 2025  
**Version**: 2.0.0 (Merkle Claims System)  
**Tested On**: Windows 11, PowerShell 7.x, Foundry 0.2.x, Node.js 18.x

**Ready to test? Start with Phase 0! 🚀**
