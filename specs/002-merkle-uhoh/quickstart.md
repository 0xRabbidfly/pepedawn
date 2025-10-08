# Quickstart Guide: PEPEDAWN Betting Platform

**Feature**: 002-merkle-uhoh  
**Date**: October 8, 2025  
**Audience**: Contract Owner, Users, Developers

## Owner Workflow

### ONE-TIME SETUP

**1. Chainlink VRF Subscription**
```bash
# Steps:
1. Visit https://vrf.chain.link
2. Connect wallet
3. Click "Create Subscription" → Note subscription ID
4. Add LINK tokens (Mainnet: 50+ LINK, Sepolia: 10+ LINK)
5. After contract deployment: Add contract as consumer
```

**2. IPFS Pinning Service**
```bash
# NFT.Storage (Recommended - Free):
1. Visit https://nft.storage
2. Sign up with GitHub/email
3. Generate API token
4. Save to .env: NFT_STORAGE_API_KEY=xxx

# Pinata (Backup):
1. Visit https://pinata.cloud
2. Create account
3. Generate API keys (JWT)
4. Save to .env: PINATA_API_KEY=xxx, PINATA_SECRET_KEY=xxx
```

**3. Environment Configuration**
```bash
# Create .env file in scripts/ directory:
ETHEREUM_RPC_URL=https://mainnet.infura.io/v3/YOUR_KEY
CHAIN_ID=1
RAFFLE_CONTRACT_ADDRESS=0x...
EMBLEM_VAULT_CONTRACT_ADDRESS=0x...
PRIVATE_KEY=0x...  # ⚠️ KEEP SECRET!
NFT_STORAGE_API_KEY=xxx
VRF_SUBSCRIPTION_ID=12345
```

### BI-WEEKLY ROUND WORKFLOW

**WEEK 0: Start Round**
```bash
# 1. Prepare 10 Emblem Vault NFTs
- Identify NFTs: 1 Fake Pack, 1 Kek Pack, 8 Pepe Packs
- Transfer to contract: emblemVault.safeTransferFrom(owner, raffleContract, tokenId)

# 2. Set puzzle proof hash (optional)
$ node scripts/cli/set-proof.js <roundId> <solution>
# Generates keccak256 hash, commits to contract

# 3. Configure and create round
$ node scripts/cli/manage-round.js create
# Interactive prompts for start/end times, verification

# 4. Open round for betting
$ node scripts/cli/manage-round.js open <roundId>
# Announces round, enables betting

# 5. Announce on social media
- Share round details, puzzle clues, end date
```

**WEEK 2: Close Round**
```bash
# 1. Snapshot participants (after 2-week period)
$ node scripts/cli/snapshot-round.js <roundId>
# Steps:
#   - Queries all participants
#   - Calculates effective weights
#   - Generates Participants File
#   - Builds Merkle tree
#   - Uploads to IPFS
#   - Commits root to contract
#   - Transitions to Snapshotted state
# Output: CID, Merkle root, transaction hash

# 2. Request VRF (if ≥10 tickets)
$ node scripts/cli/manage-round.js request-vrf <roundId>
# Calls Chainlink VRF, waits for fulfillment (5-30 min)

# 3. Monitor VRF fulfillment
$ node scripts/cli/manage-round.js status <roundId>
# Check state: VRFRequested → VRFFulfilled

# 4. Commit winners (after VRF fulfilled)
$ node scripts/cli/commit-winners.js <roundId>
# Steps:
#   - Fetches Participants File from IPFS
#   - Queries VRF seed
#   - Runs deterministic winner selection
#   - Generates Winners File
#   - Builds Merkle tree
#   - Uploads to IPFS
#   - Commits root to contract
#   - Transitions to WinnersCommitted state
# Output: Winners CID, Merkle root, transaction hash

# 5. Announce winners
- Share Winners File CID on social media
- Notify winners (optional)

# 6. Close round (after claims period)
$ node scripts/cli/manage-round.js close <roundId>
# Distributes fees, processes refunds, finalizes round
```

**REFUND PATH (if <10 tickets)**:
```bash
# 1. Snapshot participants
$ node scripts/cli/snapshot-round.js <roundId>

# 2. Close round immediately (skip VRF)
$ node scripts/cli/manage-round.js close <roundId>
# Automatically processes refunds for all participants

# 3. Announce refund availability
- Users can withdrawRefund() anytime
```

### MONITORING & MAINTENANCE

**Daily Checks**:
```bash
# Check VRF subscription balance
- Visit https://vrf.chain.link
- Alert if <20% remaining
- Top up with LINK tokens

# Monitor unclaimed prizes
$ node scripts/cli/manage-round.js unclaimed <roundId>
# Lists unclaimed prizes, reach out to winners if needed
```

**Weekly Checks**:
```bash
# Verify IPFS file availability
$ node scripts/cli/verify-ipfs.js <roundId>
# Tests all gateways, ensures files are pinned

# Check contract ETH balance
$ node scripts/cli/manage-round.js balance
# Ensure sufficient ETH for refunds and operations
```

---

## User Workflow

### BETTING PHASE

**1. Connect Wallet**
```
- Visit https://pepedawn.com
- Click "Connect Wallet"
- Approve connection in MetaMask/mobile wallet
- Ensure correct network (Ethereum Mainnet)
```

**2. Place Bet**
```
- Choose tickets: 1 (0.005 ETH), 5 (0.0225 ETH), or 10 (0.04 ETH)
- Review transaction details
- Confirm in wallet
- Wait for confirmation (~15 seconds)
- See wallet on leaderboard with % odds
```

**3. Submit Puzzle Proof (Optional)**
```
- Solve steganographic puzzle
- Enter solution
- Click "Submit Proof"
- Confirm transaction
- See weight increase by 40% on leaderboard
```

**4. Monitor Progress**
```
- View leaderboard position
- Track tickets toward 10-ticket minimum
- See countdown to round end
```

### CLAIMING PHASE

**5. Check Winner Status (after round closes)**
```
- View round in "Winners finalized" state
- Download Winners File from IPFS
- See "Claim" buttons for each prize slot won
- Review prize details (Fake/Kek/Pepe Pack, NFT ID)
```

**6. Claim Prize**
```
- Click "Claim" button for specific prize slot
- System generates Merkle proof automatically
- Review transaction (gas estimate)
- Confirm in wallet
- Receive Emblem Vault NFT in wallet
- See "Claimed ✓" status
```

**7. Withdraw Refund (if <10 tickets)**
```
- View round in "Closed" state with refund notice
- Click "Withdraw Refund"
- Confirm transaction
- Receive full wager amount back
- See "Refund withdrawn ✓" status
```

---

## Developer Workflow

### LOCAL DEVELOPMENT

**1. Clone & Install**
```bash
git clone https://github.com/your-org/pepedawn.git
cd pepedawn

# Install contract dependencies
cd contracts
forge install

# Install frontend dependencies
cd ../frontend
npm install

# Install scripts dependencies
cd ../scripts
npm install
```

**2. Environment Setup**
```bash
# Copy example env file
cp .env.example .env

# Configure for Sepolia testnet
ETHEREUM_RPC_URL=https://sepolia.infura.io/v3/YOUR_KEY
CHAIN_ID=11155111
RAFFLE_CONTRACT_ADDRESS=0x... # Deploy first
```

**3. Run Tests**
```bash
# Smart contract tests
cd contracts
forge test                    # All tests
forge test --match-test testClaim  # Specific test
forge test -vvv               # Verbose output

# Frontend tests
cd frontend
npm test

# Script tests
cd scripts
npm test
```

**4. Deploy to Testnet**
```bash
# Deploy contract
cd contracts
forge script scripts/Deploy.s.sol --rpc-url $ETHEREUM_RPC_URL --broadcast

# Note contract address, update .env

# Run frontend locally
cd ../frontend
npm run dev
# Visit http://localhost:5173
```

### TESTNET ROUND FLOW

**Quick Test Round** (1-hour duration for testing):
```bash
# 1. Create short test round
$ node scripts/cli/manage-round.js create --test-mode
# Creates 1-hour round instead of 2-week

# 2. Place test bets (use testnet wallets)
- Connect multiple wallets
- Place varying bet amounts
- Submit some proof attempts

# 3. Fast-forward to round end
# Wait 1 hour or use Hardhat time travel (if local)

# 4. Run full close workflow
$ node scripts/cli/snapshot-round.js <roundId>
$ node scripts/cli/manage-round.js request-vrf <roundId>
# Wait for VRF (~2-5 min on Sepolia)
$ node scripts/cli/commit-winners.js <roundId>

# 5. Test claims
- Connect winner wallet
- Verify Winners File loads
- Click "Claim" button
- Confirm NFT received in wallet
```

### DEBUGGING

**Contract Events**
```bash
# View all events for a round
$ node scripts/cli/events.js <roundId>

# Filter specific event types
$ node scripts/cli/events.js <roundId> --type BetPlaced
$ node scripts/cli/events.js <roundId> --type PrizeClaimed
```

**IPFS File Inspection**
```bash
# Download and validate file
$ node scripts/cli/inspect-ipfs.js <CID>
# Shows file contents, validates Merkle root

# Test all gateways
$ node scripts/cli/test-gateways.js <CID>
# Checks availability across Pinata, Infura, ipfs.io
```

**Merkle Proof Generation**
```bash
# Generate proof for specific wallet
$ node scripts/cli/generate-proof.js <roundId> <wallet>
# Shows proof array for manual testing
```

---

## Common Issues & Solutions

### Contract Issues

**"Insufficient LINK balance"**
```
Problem: VRF subscription needs more LINK
Solution: Add LINK tokens at https://vrf.chain.link
```

**"Round not in correct state"**
```
Problem: Trying to call function in wrong state
Solution: Check current state with manage-round.js status <roundId>
```

**"Contract doesn't own NFT"**
```
Problem: Prize NFT not transferred to contract
Solution: Transfer NFT before round opens:
  emblemVault.safeTransferFrom(owner, raffleContract, tokenId)
```

### IPFS Issues

**"IPFS fetch timeout"**
```
Problem: Gateway slow or down
Solution: 
  - Wait and retry (60s timeout)
  - Try alternative gateway
  - Copy CID manually: ipfs.io/ipfs/{CID}
```

**"Merkle root mismatch"**
```
Problem: File corrupted or wrong file
Solution:
  - Re-download from different gateway
  - Verify CID matches on-chain value
  - Regenerate file if owner (snapshot/commit-winners scripts)
```

### Frontend Issues

**"Wrong network" error**
```
Problem: Wallet connected to wrong chain
Solution: Switch to Ethereum Mainnet in wallet
```

**"Claim verification failed"**
```
Problem: Merkle proof generation issue
Solution:
  - Refresh page
  - Clear browser cache
  - Re-download Winners File
  - Check wallet address matches winner
```

---

## Architecture Overview

```
┌─────────────────────────────────────────────────────────────┐
│                      PEPEDAWN PLATFORM                       │
└─────────────────────────────────────────────────────────────┘

[Smart Contract]
   ├─ PepedawnRaffle.sol (main contract)
   ├─ State management (6 round states)
   ├─ Merkle root storage (participants, winners)
   └─ ERC721 custody (Emblem Vault NFTs)
          │
          ▼
[Chainlink VRF]
   ├─ Subscription managed by owner
   ├─ Provides verifiable randomness
   └─ Callback: fulfillRandomWords()
          │
          ▼
[Owner Scripts] (Node.js CLI)
   ├─ snapshot-round.js → Participants File → IPFS
   ├─ commit-winners.js → Winners File → IPFS
   ├─ manage-round.js → State transitions
   └─ verify-ipfs.js → File validation
          │
          ▼
[IPFS] (Off-chain storage)
   ├─ NFT.Storage / Pinata (free pinning)
   ├─ Participants File (JSON + Merkle tree)
   ├─ Winners File (JSON + Merkle tree)
   └─ Public gateways (Pinata, Infura, ipfs.io)
          │
          ▼
[Frontend] (Vite + Vanilla JS)
   ├─ Wallet connection (MetaMask, WalletConnect)
   ├─ Round state visualization (6 states)
   ├─ IPFS file fetching (60s timeout)
   ├─ Merkle proof generation (client-side)
   ├─ Claim buttons (pull-payment)
   └─ Mobile responsive (touch-friendly)
```

---

## Security Checklist

**Before Mainnet Deployment**:
- [ ] Contract audited or reviewed by security expert
- [ ] All tests passing (unit, fuzz, integration)
- [ ] VRF subscription funded with adequate LINK
- [ ] Owner private key secured (hardware wallet recommended)
- [ ] IPFS pinning services configured and tested
- [ ] Frontend deployed to production domain
- [ ] Emergency pause functionality tested
- [ ] Refund mechanism tested with <10 tickets scenario
- [ ] Claim mechanism tested with multiple winners
- [ ] Mobile wallet integration tested (iOS/Android)

**Ongoing Security**:
- [ ] Monitor VRF subscription balance weekly
- [ ] Review contract events for anomalies
- [ ] Keep IPFS files pinned and accessible
- [ ] Back up private keys securely
- [ ] Monitor unclaimed prizes and reach out to winners
- [ ] Test new wallets/browsers periodically

---

## Support & Resources

**Documentation**:
- Spec: `specs/002-merkle-uhoh/spec.md`
- Data Model: `specs/002-merkle-uhoh/data-model.md`
- Research: `specs/002-merkle-uhoh/research.md`
- Contract API: `specs/002-merkle-uhoh/contracts/contract-api.md`

**External Resources**:
- Chainlink VRF: https://docs.chain.link/vrf
- OpenZeppelin Contracts: https://docs.openzeppelin.com/contracts
- IPFS Gateways: https://ipfs.github.io/public-gateway-checker/
- MetaMask Docs: https://docs.metamask.io/

**Community**:
- Discord: [TO_BE_PROVIDED]
- Twitter: [TO_BE_PROVIDED]
- GitHub Issues: [TO_BE_PROVIDED]

---

**Status**: QUICKSTART COMPLETE
**Next**: Contract API Specifications
