# MAINNET DEPLOYMENT PLAN

**Project**: PEPEDAWN - Skill-Weighted Decentralized Raffle  
**Target**: Ethereum Mainnet Launch  
**Status**: Pre-Deployment Preparation  
**Last Updated**: 2025-10-09

> ⚠️ **CRITICAL**: This is a one-shot deployment. All items must be completed and verified before mainnet launch.

---

## TABLE OF CONTENTS

1. [Executive Summary](#executive-summary)
2. [Contract Code Review](#contract-code-review)
3. [Configuration Changes](#configuration-changes)
4. [Gas Cost Analysis](#gas-cost-analysis)
5. [Mainnet vs Sepolia Differences](#mainnet-vs-sepolia-differences)
6. [Deployment Preparation](#deployment-preparation)
7. [Website Deployment](#website-deployment)
8. [Security Checklist](#security-checklist)
9. [Testing & Validation](#testing--validation)
10. [Deployment Procedure](#deployment-procedure)
11. [Post-Deployment](#post-deployment)
12. [Emergency Procedures](#emergency-procedures)

---

## EXECUTIVE SUMMARY

### Critical Path Items
- [ ] **Security audit** of PepedawnRaffle.sol
- [ ] **Gas optimization** review and testing
- [ ] **Mainnet wallet** setup with multi-sig
- [ ] **Emblem Vault** mainnet contract integration
- [ ] **Chainlink VRF** mainnet subscription setup
- [ ] **Website** deployment to pepedawn.art (Namecheap)
- [ ] **Emergency procedures** documentation
- [ ] **Monitoring systems** setup

### Estimated Timeline
- **Preparation**: 2-3 weeks
- **Audit**: 1-2 weeks
- **Deployment Day**: 1 day
- **Monitoring**: Continuous

### Budget Estimates
- **Gas Costs**: 0.5-1.5 ETH (deployment + initial setup)
- **Chainlink LINK**: 10-20 LINK (VRF subscription)
- **Audit**: $5K-15K (if external audit used)
- **Contingency**: 2 ETH

---

## CONTRACT CODE REVIEW

### 1. REMOVE TEST/DEBUG FUNCTIONS

#### ❌ MUST REMOVE: `resetVrfTiming()`
**Location**: `contracts/src/PepedawnRaffle.sol:409-411`

```solidity
/**
 * @notice Reset VRF timing for testing purposes
 * @dev Only available for testing - should be removed in production
 */
function resetVrfTiming() external onlyOwner {
    lastVrfRequestTime = 0;
}
```

**Action**: Delete this function entirely before mainnet deployment.  
**Reason**: Test function that bypasses security timing checks.  
**Impact**: Security vulnerability if left in production.

---

### 2. REVIEW CIRCUIT BREAKER LIMITS

**Current Settings**:
```solidity
uint256 public constant MAX_PARTICIPANTS_PER_ROUND = 10000; // Line 41
uint256 public constant MAX_TOTAL_WAGER_PER_ROUND = 1000 ether; // Line 42
```

**Questions to Answer**:
- [ ] Is 1000 ETH per round reasonable for mainnet? (Worth $3-4M at current prices)
- [ ] Should we start with lower limits (e.g., 100 ETH) for first few rounds?
- [ ] Do we need dynamic adjustment based on ETH price?

**Recommendation**: 
- Start with **100 ETH limit** for Round 1-3
- Increase to **500 ETH** for Rounds 4-10  
- Use full **1000 ETH** after proven stable

---

### 3. GAS OPTIMIZATION REVIEW

#### VRF Gas Estimation Constants
```solidity
uint32 public constant VRF_MIN_CALLBACK_GAS = 400000; // Line 46
uint32 public constant VRF_MAX_CALLBACK_GAS = 2500000; // Line 49
```

**Mainnet Considerations**:
- Base fee on mainnet is typically **10-50 gwei** (vs 1-5 gwei Sepolia)
- Priority fees add **1-5 gwei** during normal times
- During congestion: **100-500 gwei** possible

**Action Items**:
- [ ] Test callback gas usage with 100+ participants
- [ ] Test with 1000+ participants (max scenario)
- [ ] Verify gas estimation logic works at mainnet gas prices
- [ ] Consider adding max gas price safety check

---

### 4. EMBLEM VAULT INTEGRATION

**Current Implementation** (Lines 131-132, 341-342, 642, 697):
```solidity
address public emblemVaultAddress;
IERC721 public emblemVault; // Standard ERC721 interface
```

**Our contract uses**: Standard ERC721 interface (simple, clean ✓)  
**Emblem Vault SDK provides**: Advanced vault creation/management tools (not needed for basic custody)

---

#### 🎯 MAINNET MIGRATION PLAN

**Contract Addresses**:
Based on Emblem SDK docs, Emblem Vault uses different addresses per network:
- **Sepolia**: Test/mock address (current)
- **Mainnet**: Must identify the specific Emblem Vault collection contract

**📋 ACTION ITEMS** (in order):

#### Phase 1: Discovery (Week 1)
- [ ] **Identify which Emblem Vault collection** you're using for prizes
  - Are these curated vaults? Custom collection? Existing NFTs?
  - Get the mainnet contract address for that specific collection
- [ ] **Verify contract is ERC721 compliant** on mainnet:
  ```bash
  cast call $EMBLEM_VAULT_MAINNET "supportsInterface(bytes4)" "0x80ac58cd" --rpc-url $MAINNET_RPC_URL
  # Should return: 0x0000000000000000000000000000000000000000000000000000000000000001 (true)
  ```
- [ ] **Confirm NFT inventory**:
  - How many NFTs available? (contract assumes 133 total)
  - Which token IDs? (contract maps: 1-10 Fake, 11-50 Kek, 51-133 Pepe)
  - Who currently owns them?

#### Phase 2: Testing (Week 2)
- [ ] **Fork test NFT operations**:
  ```bash
  # Fork mainnet
  anvil --fork-url https://eth-mainnet.g.alchemy.com/v2/YOUR_KEY
  
  # Test ownership check
  cast call $EMBLEM_VAULT_MAINNET "ownerOf(uint256)" $TOKEN_ID --rpc-url http://localhost:8545
  
  # Test transfer to contract (simulate)
  cast send $EMBLEM_VAULT_MAINNET "safeTransferFrom(address,address,uint256)" \
    $CURRENT_OWNER $CONTRACT_ADDRESS $TOKEN_ID --rpc-url http://localhost:8545
  ```
- [ ] **Test contract's prize claiming flow** on fork with real Emblem Vault contract
- [ ] **Verify gas costs** for `safeTransferFrom` with Emblem Vault NFTs

#### Phase 3: Pre-Deployment Prep (Week 3)
- [ ] **Gather prize NFTs**:
  - Minimum 10 NFTs for Round 1 (contract validates this in `setPrizesForRound`)
  - Ensure you control the wallet that owns them
  - Document token IDs: `[id1, id2, id3, ..., id10]`
- [ ] **Calculate gas budget** for NFT transfers:
  - 10 NFTs × ~65,000 gas × current gas price = transfer cost
  - At 30 gwei: ~0.02 ETH total

#### Phase 4: Deployment Day
- [ ] **Deploy contract** with mainnet Emblem Vault address:
  ```bash
  # In Deploy.s.sol constructor:
  EMBLEM_VAULT_MAINNET = 0x...; # The actual mainnet address
  ```
- [ ] **Transfer NFTs to contract** (before opening round):
  ```bash
  # For each prize NFT (use owner wallet):
  cast send $EMBLEM_VAULT_MAINNET \
    "safeTransferFrom(address,address,uint256)" \
    $YOUR_ADDRESS \
    $CONTRACT_ADDRESS \
    $TOKEN_ID \
    --private-key $OWNER_KEY \
    --rpc-url $MAINNET_RPC_URL
  ```
- [ ] **Verify contract ownership**:
  ```bash
  # Check contract owns all 10 NFTs
  for id in 1 2 3 4 5 6 7 8 9 10; do
    cast call $EMBLEM_VAULT_MAINNET "ownerOf(uint256)" $id --rpc-url $MAINNET_RPC_URL
  done
  ```
- [ ] **Set prizes for Round 1**:
  ```bash
  cast send $CONTRACT_ADDRESS \
    "setPrizesForRound(uint256,uint256[])" \
    1 "[1,2,3,4,5,6,7,8,9,10]" \
    --private-key $OWNER_KEY \
    --rpc-url $MAINNET_RPC_URL
  ```

---

#### 🔍 KEY QUESTIONS TO ANSWER NOW

1. **Which Emblem Vault contract are you using?**
   - Emblem Vault V2? V3? A specific curated collection?
   - Contract address on mainnet?

2. **Do you have the NFTs?**
   - 133 NFTs as coded? Or starting with fewer?
   - Are they already minted on mainnet?
   - What wallet currently owns them?

3. **Prize allocation strategy**:
   - Using the hardcoded mapping (1-10, 11-50, 51-133)?
   - Or dynamic selection per round?

4. **NFT replenishment plan**:
   - After distributing 10 NFTs/round, how to get more?
   - Buy on secondary market? Mint new? Partner with Emblem?

---

#### ⚠️ CRITICAL RISKS

1. **Wrong Contract Address**: If you deploy with wrong Emblem Vault address, prizes won't transfer
   - **Mitigation**: Test on fork first, verify `ownerOf()` and `safeTransferFrom()` work
   
2. **NFT Not Owned**: If contract doesn't own the NFT, claim will fail
   - **Mitigation**: Pre-transfer all NFTs before opening round, validate in `setPrizesForRound()`
   
3. **Token ID Mismatch**: If hardcoded IDs don't exist, claims fail
   - **Mitigation**: Document exact token IDs, update `_getPrizeAssetId()` if needed


## Emergency Recovery
If NFT stuck: Use `emergencyWithdrawNFT()` (owner only)
```

### 5. CONSTANTS VALIDATION

#### Wager Amounts (Realistic for Mainnet?)
```solidity
uint256 public constant MIN_WAGER = 0.005 ether; // ~$12-18 at current prices
uint256 public constant BUNDLE_5_PRICE = 0.0225 ether; // ~$60-80
uint256 public constant BUNDLE_10_PRICE = 0.04 ether; // ~$100-150
```

**Consider**:
- Is $12 minimum too high/low for participation?
- Gas costs on mainnet: $5-50+ per transaction during congestion
- Users need to factor in: bet cost + gas + proof submission gas + claim gas

**Recommendation**: Monitor first round closely and be ready to adjust in v2.

#### Round Duration
```solidity
uint256 public constant ROUND_DURATION = 2 weeks;
```

**Considerations**:
- Marketing time: Is 2 weeks enough to build hype?
- Too short: Not enough participation
- Too long: Users lose interest
- Consider 3-4 weeks for first rounds on mainnet

---

### 6. SECURITY ENHANCEMENTS

#### Add Version Tracking
```solidity
// Add to contract
string public constant VERSION = "1.0.0-mainnet";
uint256 public immutable DEPLOYMENT_TIMESTAMP;

constructor(...) {
    DEPLOYMENT_TIMESTAMP = block.timestamp;
    // ... rest of constructor
}
```

#### Add Contract Pause Reason
```solidity
string public pauseReason; // Add state variable

function pause(string calldata reason) external onlyOwner {
    pauseReason = reason;
    _pause();
    emit ContractPaused(reason, block.timestamp);
}
```

#### Improve Emergency Withdrawal
```solidity
// Current: 24-hour wait (Line 1388-1392)
require(
    block.timestamp >= lastVrfRequestTime + 24 hours, 
    "Must wait 24 hours after last activity"
);
```

**Consider**: Should mainnet have **7-day timelock** for emergency withdrawals?

---

## CONFIGURATION CHANGES

### 1. NETWORK CONFIGURATION

#### Current (Sepolia)
```javascript
// frontend/src/contract-config.js
export const CONTRACT_CONFIG = {
  address: "0x7Be07bE03603a44c64A81bcEFDe2Bedc38b1f5d0",
  network: 'sepolia',
  chainId: 11155111,
}
```

#### Required (Mainnet)
```javascript
export const CONTRACT_CONFIG = {
  address: "0x__DEPLOY_TO_MAINNET__", // Will be filled on deployment
  network: 'mainnet',
  chainId: 1,
}
```

**Files to Update**:
- [ ] `frontend/src/contract-config.js`
- [ ] `deploy/artifacts/addresses.json`
- [ ] `frontend/public/deploy/artifacts/addresses.json`
- [ ] `contracts/.env` (add MAINNET_RPC_URL)
- [ ] All README/documentation

---

### 2. CHAINLINK VRF CONFIGURATION

#### Current VRF Settings (Sepolia)
```json
{
  "coordinator": "0x8103B0A8A00be2DDC778e6e7eaa21791Cd364625",
  "subscriptionId": 1,
  "keyHash": "0x474e34a077df58807dbe9c96d3c009b23b3c6d0cce433e59bbf5b34f823bc56c"
}
```

#### Mainnet VRF Requirements

**VRF Coordinator Address**: `0x271682DEB8C4E0901D1a1550aD2e64D568E69909` (VRF v2.5)  
**Key Hash (500 gwei)**: `0x8af398995b04c28e9951adb9721ef74c74f93e6a478f39e7e0777be13527e7ef`  
**Key Hash (200 gwei)**: `0xff8dedfbfa60af186cf3c830acbc32c05aae823045ae5ea7da1e45fbfaba4f92`  
**Key Hash (100 gwei)**: `0x9fe0eebf5e446e3c998ec9bb19951541aee00bb90ea201ae456421a2ded86805`

**Action Items**:
- [ ] Create new VRF subscription on mainnet via https://vrf.chain.link
- [ ] Fund subscription with **20-50 LINK** minimum
- [ ] Add deployed contract as consumer
- [ ] Choose appropriate key hash based on gas requirements
- [ ] Update `deploy/artifacts/vrf-config.json`
- [ ] Test VRF on mainnet with small transaction first

**Cost Estimation**:
```
VRF Cost = 0.25 LINK + gas * LINK/ETH exchange rate
Gas for 500k callback ~= 0.02-0.1 ETH worth of LINK
Total per round: ~0.35-0.5 LINK
20 LINK = ~40-60 rounds of operation
```

---

### 3. WALLET SETUP

#### Owner Wallet (Critical)

**Current Setup**: Single EOA (Externally Owned Account)  
**Mainnet Requirement**: **MULTI-SIG WALLET**

**Recommended**: Gnosis Safe with 2-of-3 or 3-of-5 configuration

**Action Items**:
- [ ] Deploy Gnosis Safe on mainnet
- [ ] Add 2-5 signers (trusted team members)
- [ ] Set threshold (e.g., 2-of-3 required for transactions)
- [ ] Test Safe operation on Sepolia first
- [ ] Document all signer addresses
- [ ] Store recovery phrases in separate secure locations

**Alternative**: If staying with EOA:
- [ ] Use hardware wallet (Ledger/Trezor)
- [ ] Never expose private key
- [ ] Have backup hardware wallet
- [ ] Use separate "hot wallet" for small operations

#### Creators Address
```solidity
address public creatorsAddress; // Receives 80% of wagers
```

**Current**: Likely same as owner  
**Mainnet Consideration**: 
- Should this be a payment splitter contract?
- Multi-sig for fund management?
- Consider tax/legal implications

---

### 4. IPFS CONFIGURATION

**Current Setup** (contracts/scripts/cli/upload-to-ipfs.js):
- Uses Pinata or similar service
- API keys in environment variables

**Mainnet Requirements**:
- [ ] Production Pinata account (or Infura IPFS)
- [ ] Separate API keys for mainnet
- [ ] Backup IPFS provider
- [ ] Monitor pin status
- [ ] Have fallback hosting (S3/CDN) for critical files

**Files that need IPFS**:
- Participants JSON (each round)
- Winners JSON (each round)
- Prize metadata
- Round documentation

---

### 5. ENVIRONMENT VARIABLES

#### New `.env` Structure

```bash
# Mainnet Configuration
MAINNET_RPC_URL=https://eth-mainnet.g.alchemy.com/v2/YOUR_KEY
MAINNET_PRIVATE_KEY=0x... # USE HARDWARE WALLET OR ENCRYPTED
CONTRACT_ADDRESS_MAINNET=0x... # Filled after deployment

# Chainlink VRF Mainnet
VRF_COORDINATOR_MAINNET=0x271682DEB8C4E0901D1a1550aD2e64D568E69909
VRF_SUBSCRIPTION_ID_MAINNET=TBD
VRF_KEY_HASH_MAINNET=0x8af398995b04c28e9951adb9721ef74c74f93e6a478f39e7e0777be13527e7ef

# Addresses
CREATORS_ADDRESS=0x... # Multi-sig or payment splitter
EMBLEM_VAULT_ADDRESS_MAINNET=0x... # Real Emblem Vault contract

# IPFS (Production)
PINATA_API_KEY_PROD=...
PINATA_SECRET_KEY_PROD=...

# Security
PAUSE_ENABLED=false # Only enable if needed
EMERGENCY_CONTACT=email@domain.com
```

**Security Notes**:
- Never commit mainnet private keys to git
- Use encrypted environment variable storage
- Consider using secret management service (AWS Secrets Manager, HashiCorp Vault)

---

## GAS COST ANALYSIS

### Deployment Costs

#### Contract Deployment
```
Contract Size: ~24kb (below 24.576kb limit ✓)
Deployment Gas: ~4,000,000 - 5,000,000 gas

At different gas prices:
- 30 gwei: ~0.12-0.15 ETH ($350-500)
- 50 gwei: ~0.20-0.25 ETH ($600-850)
- 100 gwei: ~0.40-0.50 ETH ($1,200-1,700)
```

**Optimization Opportunities**:
- Current: Uses `via_ir = true` (IR-based compilation)
- Consider: Deploy with `optimizer_runs = 999999` for gas-efficient runtime

**Action**: Deploy during low-gas period (weekends, 2-6 AM EST)

#### Initial Setup (Post-Deployment)
```solidity
1. Add VRF consumer: ~46,000 gas
2. Create first round: ~150,000 gas  
3. Set prizes: ~500,000 gas (10 NFTs)
4. Open round: ~50,000 gas

Total Setup: ~750,000 gas
At 30 gwei: ~0.0225 ETH ($70-80)
At 50 gwei: ~0.0375 ETH ($110-130)
```

**Total Deployment Budget**: 0.5 - 1.5 ETH depending on gas prices

---

### Per-Round Operation Costs

#### Owner Operations
```
1. createRound(): ~150,000 gas
2. setValidProof(): ~43,000 gas
3. openRound(): ~50,000 gas
4. closeRound(): ~100,000 gas (+ refund gas if <10 tickets)
5. snapshotRound(): ~30,000 gas
6. commitParticipantsRoot(): ~70,000 gas
7. requestVrf(): ~200,000 gas (+ Chainlink fee)
8. submitWinnersRoot(): ~100,000 gas (+ fee distribution)

Total per round: ~750,000 gas
At 30 gwei: ~0.0225 ETH ($70)
At 50 gwei: ~0.0375 ETH ($110)
```

**Plus Chainlink VRF**: 0.35-0.5 LINK (~$5-10)

---

### User Operation Costs

#### Place Bet
```
First bet (new participant): ~180,000 gas
Subsequent bets: ~100,000 gas

At 30 gwei: 0.003-0.0054 ETH ($9-16)
At 50 gwei: 0.005-0.009 ETH ($15-27)
At 100 gwei: 0.01-0.018 ETH ($30-54)
```

**Problem**: During high gas, users pay more in gas than minimum bet (0.005 ETH)!

**Solutions**:
1. Recommend betting during low-gas periods
2. UI shows estimated gas costs before bet
3. Consider Layer 2 deployment in future (Arbitrum/Optimism)

#### Submit Proof
```
Gas: ~120,000 gas
At 30 gwei: ~0.0036 ETH ($11)
At 50 gwei: ~0.006 ETH ($18)
```

#### Claim Prize
```
Gas: ~150,000 gas (NFT transfer + verification)
At 30 gwei: ~0.0045 ETH ($13)
At 50 gwei: ~0.0075 ETH ($22)
```

---

### Gas Optimization Recommendations

#### 1. Batch Operations for Users (Future v2)
```solidity
// Allow betting multiple times in one transaction
function placeBets(uint256[] calldata ticketCounts) external payable {
    for (uint i = 0; i < ticketCounts.length; i++) {
        _placeBet(ticketCounts[i]);
    }
}
```

#### 2. Optimize Storage Patterns
- Pack structs to fit in single slots
- Use smaller uint types where possible
- Consider using mappings instead of arrays where appropriate

#### 3. Event Optimization
- Current: Emits many events
- Consider: Remove non-critical events for mainnet

#### 4. Consider EIP-4844 (Future)
- Store participants/winners data in blobs instead of IPFS
- Significantly cheaper data availability
- Wait for tooling maturity

---

## MAINNET VS SEPOLIA DIFFERENCES

### 1. Network Parameters

| Aspect | Sepolia | Mainnet | Impact |
|--------|---------|---------|--------|
| **Gas Price** | 1-5 gwei | 10-500 gwei | **50-500x higher costs** |
| **Block Time** | ~12s | ~12s | Same |
| **Finality** | ~15 min | ~15 min | Same |
| **LINK Price** | Free (faucet) | ~$12-20 | Need to buy LINK |
| **ETH Value** | $0 (testnet) | $3,000-4,000 | **Real money at risk** |
| **VRF Coordinator** | Test coordinator | Prod coordinator | Different addresses |
| **Etherscan** | sepolia.etherscan.io | etherscan.io | Different block explorers |

---

### 2. Chainlink VRF Differences

| Feature | Sepolia | Mainnet |
|---------|---------|---------|
| **Coordinator** | 0x8103B0A8... | 0x271682DE... |
| **LINK Funding** | Faucet | Purchase required |
| **Fulfillment Time** | 30s - 5min | 30s - 5min |
| **Cost per Request** | Free/negligible | 0.35-0.5 LINK + gas |
| **Request Limits** | Relaxed | Production limits apply |

**Key Difference**: On mainnet, if subscription runs out of LINK, VRF requests **will fail**!

**Mitigation**:
- [ ] Set up LINK balance monitoring
- [ ] Alert when balance < 5 LINK
- [ ] Auto-top-up system (consider Chainlink Automation)
- [ ] Have emergency LINK reserve ready

---

### 3. Smart Contract Behavior

#### Sepolia: More Forgiving
- Can redeploy easily if bugs found
- Test network, less scrutiny
- Failed transactions = wasted test ETH (no real cost)

#### Mainnet: Unforgiving
- **Contract is immutable** after deployment
- All bugs are public and permanent
- Failed transactions = lost real ETH
- MEV bots may exploit any vulnerabilities
- Front-running is common

---

### 4. User Experience Differences

| Aspect | Sepolia Testing | Mainnet Reality |
|--------|----------------|-----------------|
| **User Errors** | Easy to fix | Costly to fix |
| **Transaction Speed** | Users tolerant | Users expect speed |
| **Gas Costs** | Ignored | Primary concern |
| **Support Burden** | Minimal | High (real money) |
| **Scam Risk** | Low | High (phishing, fake sites) |

---

### 5. Emblem Vault Integration

**Sepolia**:
- Using mock/test Emblem Vault or no NFTs
- NFT transfers not tested with real vault

**Mainnet**:
- Must use real Emblem Vault contract
- Real NFTs with real value
- NFT custody is critical security concern

**CRITICAL ACTION ITEMS**:
- [ ] Verify Emblem Vault mainnet contract address
- [ ] Test NFT custody and transfer flow
- [ ] Document NFT token ID allocation strategy
- [ ] Have emergency NFT recovery procedure
- [ ] Ensure contract can receive and hold ERC721s

---

### 6. Frontend Differences

#### RPC Provider
```javascript
// Sepolia
rpcUrl: 'https://sepolia.infura.io/v3/YOUR_KEY'

// Mainnet (Need production-tier)
rpcUrl: 'https://mainnet.infura.io/v3/YOUR_PROD_KEY'
// OR
rpcUrl: 'https://eth-mainnet.g.alchemy.com/v2/YOUR_KEY'
```

**Considerations**:
- Production RPC providers have rate limits
- Need paid tier for higher request volumes
- Consider load balancing between providers
- Have fallback RPC endpoints

**Costs**:
- Infura: Free tier = 100k requests/day
- Alchemy: Free tier = 300M compute units/month
- Estimate: 1000 users/day = need paid tier (~$50-200/month)

---

### 7. MetaMask/Wallet Differences

**Network Detection**:
```javascript
// Must handle mainnet chain ID
if (chainId !== 1) {
  alert("Please switch to Ethereum Mainnet");
  // Offer to switch automatically
}
```

**User Balance Checks**:
- Must verify user has enough ETH for gas + bet
- Show clear error messages
- Estimate total cost before transaction

---

### 8. Block Explorer Integration

**Links to Update**:
```javascript
// Current
blockExplorer: 'https://sepolia.etherscan.io'

// Mainnet
blockExplorer: 'https://etherscan.io'
```

**Everywhere links appear**:
- Transaction receipts
- Winner announcements  
- Contract address displays
- Round history

---

## DEPLOYMENT PREPARATION

### PHASE 1: SECURITY AUDIT (2-3 weeks)

#### Option A: Professional Audit (Recommended)
**Firms to Consider**:
- OpenZeppelin ($10K-30K)
- Consensys Diligence ($15K-50K)
- Trail of Bits ($20K-60K)
- Cyfrin (Competitive pricing)

**Deliverables**:
- Comprehensive security report
- Severity-rated findings
- Recommendations for fixes
- Re-audit after fixes

#### Option B: Community Audit (Budget-Friendly)
**Platforms**:
- Code4rena (competitive audits)
- Sherlock (audit contests)
- Immunefi (bug bounties)

**Cost**: $2K-10K in bug bounties

#### Option C: Self-Audit (Minimum Viable)
- [ ] Run Slither static analysis
- [ ] Run Mythril symbolic execution
- [ ] Run Echidna fuzzing (extended)
- [ ] Manual review by 2+ experienced Solidity devs
- [ ] Document all potential risks

**Command**:
```bash
cd contracts

# Slither
slither src/PepedawnRaffle.sol --solc-remaps "@chainlink=lib/chainlink-brownie-contracts" "@openzeppelin=lib/openzeppelin-contracts"

# Mythril (requires Docker)
myth analyze src/PepedawnRaffle.sol

# Echidna (requires Echidna installed)
echidna-test . --contract PepedawnRaffle --config echidna.config.yml
```

---

### PHASE 2: GAS OPTIMIZATION (1 week)

#### Action Items
- [ ] Profile gas usage with realistic scenarios
  - 100 participants
  - 1000 participants  
  - 5000 participants
- [ ] Test VRF callback gas with max participants
- [ ] Optimize hot paths (placeBet, submitProof)
- [ ] Run gas reporter: `forge test --gas-report`
- [ ] Compare optimized vs current version

#### Target Metrics
- Deployment: < 5M gas
- placeBet (first): < 150k gas
- placeBet (repeat): < 80k gas
- VRF callback: < 2M gas (with 1000 participants)

---

### PHASE 3: MAINNET TESTING (1 week)

#### Fork Testing
```bash
# Mainnet fork testing
anvil --fork-url https://eth-mainnet.g.alchemy.com/v2/YOUR_KEY

# Deploy to fork
forge script scripts/forge/Deploy.s.sol --fork-url http://localhost:8545
```

**Test Scenarios**:
- [ ] Full round lifecycle with fork
- [ ] VRF request/fulfillment on mainnet fork
- [ ] Emblem Vault NFT custody
- [ ] Emergency pause/unpause
- [ ] Fee distribution
- [ ] Refund scenarios

#### Shadow Testing
- [ ] Deploy to mainnet (without announcing)
- [ ] Run 1-2 private test rounds with team
- [ ] Verify all operations work as expected
- [ ] Test gas costs in production
- [ ] Validate monitoring/alerts

**Cost**: ~0.5 ETH for shadow testing

---

### PHASE 4: INFRASTRUCTURE SETUP (1 week)

#### Monitoring Systems

**Required Tools**:
1. **Tenderly**: Transaction monitoring and debugging
   - [ ] Create account and add contract
   - [ ] Set up alerts for failed transactions
   - [ ] Monitor contract state changes

2. **OpenZeppelin Defender**: Contract operations and security
   - [ ] Set up Relayer for owner operations
   - [ ] Configure automated tasks (monitoring)
   - [ ] Set up security notifications

3. **Chainlink VRF Monitoring**:
   - [ ] Subscribe to VRF alerts
   - [ ] Monitor subscription balance
   - [ ] Track fulfillment times

4. **Custom Monitoring** (scripts/monitoring/):
   ```bash
   # Create monitoring scripts
   - check-contract-health.js   # Every 5 min
   - check-vrf-balance.js       # Every hour  
   - check-round-status.js      # Every hour
   - alert-on-errors.js         # Continuous
   ```

#### Alert Configuration
- [ ] Email alerts for: contract paused, VRF failure, low LINK balance
- [ ] Telegram bot for: new rounds, winners, issues
- [ ] Dashboard for: participants, wagered amounts, gas costs

---

### PHASE 5: LEGAL & COMPLIANCE (Ongoing)

#### Regulatory Considerations

**Gambling Laws**:
- Online gambling is heavily regulated in most jurisdictions
- "Skill-based" vs "chance-based" distinction matters
- Some jurisdictions may classify this as illegal gambling

**Securities Laws**:
- Could ETH prizes be considered securities?
- Are you running an unregistered lottery?

**Tax Implications**:
- Winnings may be taxable income
- Creator fees may be taxable revenue
- International tax considerations

**Data Privacy**:
- GDPR compliance (if EU users)
- Privacy policy
- Terms of service

**Action Items**:
- [ ] Consult with crypto-focused lawyer
- [ ] Create Terms of Service
- [ ] Create Privacy Policy
- [ ] Add disclaimers to website
- [ ] Consider geo-blocking restricted jurisdictions
- [ ] Document "skill-based" aspects prominently

**Budget**: $5K-20K for legal review

---

### PHASE 6: OPERATIONS DOCUMENTATION

#### Runbooks to Create

**1. Normal Operations Runbook**
```markdown
# Round Management
- How to create new round
- How to set puzzle proof
- How to open/close rounds
- How to handle VRF requests
- How to commit winners
- Expected timeline for each step
```

**2. Emergency Response Runbook**
```markdown
# Emergency Scenarios
- Contract must be paused
- VRF request timeout
- Winner selection dispute
- NFT custody issue
- Security breach detected
- Key compromise
```

**3. Support Runbook**
```markdown
# User Support
- Common error messages
- How to help users claim prizes
- How to verify winner status
- Refund procedures
```

**4. Financial Operations**
```markdown
# Treasury Management
- Creator fee withdrawal schedule
- LINK balance management
- Gas cost tracking
- Revenue/expense reporting
```

---

## WEBSITE DEPLOYMENT

### 1. NAMECHEAP HOSTING SETUP

#### Current Setup
- **Domain**: pepedawn.art (presumably registered)
- **Hosting**: Namecheap shared/VPS hosting
- **Current Deployment**: GitHub Actions via FTP

#### Production Requirements

**Server Requirements**:
```
- Static file hosting (HTML/CSS/JS)
- HTTPS/SSL (free with Let's Encrypt)
- CDN for global distribution
- DDoS protection
- Uptime monitoring
```

**Namecheap Options**:
1. **Stellar** (shared hosting): $2.99/mo - Suitable if low traffic
2. **Stellar Plus**: $4.49/mo - Better for moderate traffic
3. **VPS**: $6.88+/mo - Best for high traffic and control

**Recommendation**: Start with Stellar Plus, upgrade to VPS if >10k visits/day

---

### 2. DEPLOYMENT PIPELINE

#### Current Pipeline (GitHub Actions)
```yaml
# .github/workflows/deploy.yml (needs to be created)
name: Deploy to Pepedawn.art

on:
  push:
    branches: [ main ]
    paths:
      - 'frontend/**'

jobs:
  deploy:
    runs-on: ubuntu-latest
    
    steps:
    - uses: actions/checkout@v3
    
    - name: Setup Node
      uses: actions/setup-node@v3
      with:
        node-version: '20'
    
    - name: Install dependencies
      working-directory: ./frontend
      run: npm ci
    
    - name: Build
      working-directory: ./frontend
      run: npm run build
    
    - name: Deploy via FTP
      uses: SamKirkland/FTP-Deploy-Action@4.3.0
      with:
        server: ${{ secrets.FTP_SERVER }}
        username: ${{ secrets.FTP_USERNAME }}
        password: ${{ secrets.FTP_PASSWORD }}
        local-dir: ./frontend/dist/
        server-dir: ./public_html/
```

**Required Secrets** (add to GitHub repository):
- `FTP_SERVER`: ftp.pepedawn.art (or Namecheap provided)
- `FTP_USERNAME`: Your FTP username
- `FTP_PASSWORD`: Your FTP password (use strong password)

---

### 3. FRONTEND CONFIGURATION FOR MAINNET

#### Update All Mainnet References

**File: frontend/src/contract-config.js**
```javascript
export const CONTRACT_CONFIG = {
  address: "0x_MAINNET_CONTRACT_ADDRESS_", // Update on deployment
  network: 'mainnet',
  chainId: 1,
  
  // ⚠️ CRITICAL: Set to false for production!
  DEV_MODE: false, // Hides debug UI elements (network indicator, etc.)
  
  abi: [/* ABI array */]
};

export const VRF_CONFIG = {
  coordinator: "0x271682DEB8C4E0901D1a1550aD2e64D568E69909",
  subscriptionId: YOUR_MAINNET_SUB_ID, // Update after creating subscription
  keyHash: "0x8af398995b04c28e9951adb9721ef74c74f93e6a478f39e7e0777be13527e7ef",
};

export const NETWORKS = {
  mainnet: {
    name: 'Ethereum Mainnet',
    chainId: 1,
    rpcUrl: 'https://eth-mainnet.g.alchemy.com/v2/',
    blockExplorer: 'https://etherscan.io'
  }
};
```

**File: frontend/public/deploy/artifacts/addresses.json**
```json
{
  "1": {
    "PepedawnRaffle": "0x_MAINNET_ADDRESS_",
    "deployedAt": "2025-XX-XX",
    "deployedBy": "deployment-script",
    "deploymentTx": "0x...",
    "verified": true
  }
}
```

---

### 4. FRONTEND SECURITY ENHANCEMENTS

#### Add Phishing Protection
```javascript
// src/security.js
export function validateContract(provider) {
  const expectedAddress = CONTRACT_CONFIG.address.toLowerCase();
  const currentAddress = getCurrentContract().toLowerCase();
  
  if (expectedAddress !== currentAddress) {
    throw new Error('⚠️ CONTRACT MISMATCH - Possible phishing attempt!');
  }
}

// Verify on every page load
window.addEventListener('load', () => {
  if (window.ethereum) {
    validateContract(window.ethereum);
  }
});
```

#### Add Domain Verification
```javascript
// Prevent iframe embedding on untrusted sites
if (window.self !== window.top) {
  document.body.innerHTML = 'This application cannot be embedded.';
}

// Check we're on the right domain
if (window.location.hostname !== 'pepedawn.art' && 
    window.location.hostname !== 'www.pepedawn.art') {
  alert('⚠️ You are not on the official website! Beware of phishing.');
}
```

#### Add Content Security Policy
```html
<!-- index.html, main.html, rules.html -->
<meta http-equiv="Content-Security-Policy" 
      content="default-src 'self'; 
               script-src 'self' 'unsafe-inline' https://cdn.ethers.io; 
               style-src 'self' 'unsafe-inline';
               connect-src 'self' https://mainnet.infura.io https://eth-mainnet.g.alchemy.com https://etherscan.io https://gateway.pinata.cloud;
               img-src 'self' data: https:;">
```

---

### 5. PERFORMANCE OPTIMIZATION

#### Enable Caching
```
# .htaccess (add to Namecheap public_html/)
<IfModule mod_expires.c>
  ExpiresActive On
  
  # Images
  ExpiresByType image/jpeg "access plus 1 year"
  ExpiresByType image/png "access plus 1 year"
  ExpiresByType image/webp "access plus 1 year"
  
  # CSS and JavaScript
  ExpiresByType text/css "access plus 1 month"
  ExpiresByType application/javascript "access plus 1 month"
  
  # HTML
  ExpiresByType text/html "access plus 0 seconds"
</IfModule>

# Enable compression
<IfModule mod_deflate.c>
  AddOutputFilterByType DEFLATE text/html text/css application/javascript
</IfModule>
```

#### Optimize Asset Loading
- [ ] Minify all JS/CSS (Vite does this automatically)
- [ ] Compress images (use WebP format)
- [ ] Use lazy loading for images
- [ ] Preload critical resources

#### CDN Setup (Optional but Recommended)
- [ ] Use Cloudflare free tier for:
  - Global CDN
  - DDoS protection
  - SSL certificate
  - Caching
  - Analytics

**Setup**:
1. Add pepedawn.art to Cloudflare
2. Update nameservers at Namecheap
3. Enable "Always Use HTTPS"
4. Set cache level to "Standard"

---

### 6. WEBSITE MONITORING

#### Uptime Monitoring
**Free Tools**:
- UptimeRobot (50 monitors free)
- Pingdom (1 monitor free)
- StatusCake (10 monitors free)

**Setup**:
- [ ] Monitor https://pepedawn.art (main page)
- [ ] Monitor https://pepedawn.art/main.html (app page)
- [ ] Alert email + SMS on downtime
- [ ] Check every 5 minutes

#### Analytics Setup
```html
<!-- Add to all pages -->
<!-- Google Analytics or Plausible (privacy-friendly) -->
<script defer data-domain="pepedawn.art" src="https://plausible.io/js/script.js"></script>
```

**Track**:
- Page views
- Wallet connections
- Bet placements (via events)
- Proof submissions
- Prize claims
- Error rates

---

### 7. DEPLOYMENT CHECKLIST

#### Pre-Deployment
- [ ] **Set `DEV_MODE: false`** in `frontend/src/contract-config.js` (removes debug UI)
- [ ] Test build locally: `npm run build && npm run preview`
- [ ] Verify network indicator is HIDDEN (should not show chain ID)
- [ ] Test on mobile devices (iOS Safari, Android Chrome)
- [ ] Test with MetaMask, WalletConnect, Coinbase Wallet
- [ ] Verify all links work
- [ ] Check HTTPS is enforced
- [ ] Verify contract address is correct
- [ ] Test network switching
- [ ] Verify terms of service and privacy policy links

#### Deployment
- [ ] Build production version
- [ ] Upload to Namecheap via FTP/GitHub Actions
- [ ] Verify files uploaded correctly
- [ ] Clear browser cache and test
- [ ] Test from multiple locations (US, EU, Asia)
- [ ] Verify SSL certificate is valid
- [ ] Check mobile responsiveness

#### Post-Deployment
- [ ] Set up uptime monitoring
- [ ] Configure analytics
- [ ] Test all user flows end-to-end
- [ ] Monitor error logs
- [ ] Have rollback plan ready (previous version backup)

---

## SECURITY CHECKLIST

### CONTRACT SECURITY

#### Pre-Deployment Audit
- [ ] Remove all test/debug functions (`resetVrfTiming`)
- [ ] Run Slither with no high/medium findings
- [ ] Run Mythril with no critical issues
- [ ] Fuzz test with Echidna (1M+ iterations)
- [ ] Professional audit completed (if budget allows)
- [ ] All audit findings addressed
- [ ] Re-audit after fixes

#### Access Control Review
- [ ] Owner functions are protected with `onlyOwner`
- [ ] No public functions that should be restricted
- [ ] Consider using multi-sig for owner
- [ ] Emergency pause mechanism tested
- [ ] Owner transfer uses two-step process

#### Reentrancy Review
- [ ] All external calls use checks-effects-interactions
- [ ] ReentrancyGuard applied to sensitive functions
- [ ] No hidden reentrancy vectors

#### Integer Overflow/Underflow
- [ ] Using Solidity 0.8.20 (built-in overflow checks ✓)
- [ ] No unsafe math operations
- [ ] Verify calculations don't overflow in edge cases

#### External Call Safety
- [ ] Emblem Vault NFT transfers are safe
- [ ] VRF coordinator calls are validated
- [ ] ETH transfers use `call` with return value check
- [ ] No delegatecall to untrusted contracts

---

### OPERATIONAL SECURITY

#### Key Management
- [ ] Owner key stored in hardware wallet
- [ ] No private keys in code or configs
- [ ] Environment variables secured
- [ ] Backup keys stored separately
- [ ] Key access documented and limited

#### Infrastructure Security
- [ ] RPC endpoints use API keys
- [ ] API keys rotated regularly
- [ ] GitHub secrets secured
- [ ] FTP password is strong and unique
- [ ] 2FA enabled on all accounts

#### Monitoring & Alerts
- [ ] Tenderly alerts configured
- [ ] Email alerts for critical events
- [ ] Telegram bot for real-time updates
- [ ] VRF balance monitoring
- [ ] Contract pause detection

---

### FRONTEND SECURITY

#### Web3 Security
- [ ] Contract address hardcoded (not user-provided)
- [ ] Network validation before transactions
- [ ] User balance checks before operations
- [ ] Gas estimation with safety margins
- [ ] Transaction signing is explicit (user confirms)

#### Input Validation
- [ ] All user inputs sanitized
- [ ] Proof hashes validated
- [ ] Amounts checked for reasonableness
- [ ] Rate limiting implemented

#### Content Security
- [ ] Content Security Policy set
- [ ] No XSS vulnerabilities
- [ ] No iframe embedding allowed
- [ ] Domain validation on load
- [ ] HTTPS enforced

---

### SOCIAL SECURITY

#### Communication Channels
- [ ] Official website: pepedawn.art (only)
- [ ] Official Twitter/X account verified
- [ ] Official Discord/Telegram secured
- [ ] Clear "Beware of scams" messaging

#### Phishing Prevention
- [ ] Publish contract address on all channels
- [ ] Educate users about official domains
- [ ] Never ask for private keys/seed phrases
- [ ] Report fake accounts immediately

---

## TESTING & VALIDATION

### PRE-DEPLOYMENT TESTING

#### Unit Tests (Already Complete)
```bash
cd contracts
forge test --profile unit
```

**Current Status**: 151 tests, 100% FR coverage ✓

#### Integration Tests
```bash
forge test --profile integration
```

**Verify**:
- [ ] Full round lifecycle works
- [ ] VRF request/fulfillment flow
- [ ] Merkle tree generation and verification
- [ ] Prize claiming with proofs
- [ ] Refund scenarios

#### Fork Tests (Critical for Mainnet)
```bash
# Fork mainnet and test
anvil --fork-url https://eth-mainnet.g.alchemy.com/v2/YOUR_KEY --fork-block-number <recent_block>

# In another terminal
forge script scripts/forge/Deploy.s.sol --fork-url http://localhost:8545 --broadcast

# Run integration tests against fork
forge test --fork-url http://localhost:8545
```

**Test Scenarios**:
1. Deploy contract to fork
2. Create and open round
3. Multiple users place bets
4. Submit proofs
5. Close round and snapshot
6. Request VRF (mock fulfillment)
7. Generate and commit winners
8. Claim prizes
9. Test refund scenario
10. Test emergency pause

---

### MAINNET SHADOW TESTING

#### Phase 1: Private Testing (1-2 days)
1. Deploy to mainnet (do NOT announce)
2. Team members test with real ETH
3. Run 1-2 full rounds privately
4. Cost: ~0.5-1 ETH

**Test Checklist**:
- [ ] Create round successfully
- [ ] Place bets from multiple wallets
- [ ] Submit puzzle proofs (correct and incorrect)
- [ ] Close round
- [ ] Request VRF and verify fulfillment
- [ ] Generate participants and winners files
- [ ] Commit to IPFS
- [ ] Verify Merkle proofs work
- [ ] Claim prizes
- [ ] Withdraw refunds (if applicable)
- [ ] Monitor gas costs at each step

#### Phase 2: Beta Testing (1 week)
1. Invite trusted community members
2. Run 1-2 public-ish rounds
3. Monitor for issues
4. Collect feedback

**Beta Test Goals**:
- Verify user experience is smooth
- Gas costs are reasonable
- No unexpected errors
- Frontend works on all devices/wallets

---

### LOAD TESTING

#### Simulate High Participation
```javascript
// scripts/load-test.js
// Create script to simulate many users

async function loadTest() {
  // Generate 100 wallets
  // Each places 1-10 bets
  // Some submit proofs
  // Measure gas costs
  // Check for contract failures
}
```

**Scenarios to Test**:
- [ ] 100 participants in round
- [ ] 500 participants in round
- [ ] 1000 participants in round
- [ ] 5000 participants (max expected)
- [ ] VRF callback gas with max participants

---

### GAS PROFILING

```bash
cd contracts

# Generate detailed gas report
forge test --gas-report > gas-report.txt

# Profile specific operations
forge test --match-test testPlaceBet --gas-report
forge test --match-test testRequestVrf --gas-report
forge test --match-test testClaimPrize --gas-report
```

**Analyze**:
- Average gas per operation
- Gas at 10th, 50th, 90th percentile
- Worst-case gas usage
- Compare to budget estimates

---

### SECURITY TESTING

#### Automated Scans
```bash
# Slither
slither src/PepedawnRaffle.sol --checklist

# Mythril
myth analyze src/PepedawnRaffle.sol --execution-timeout 900

# Manticore (symbolic execution)
manticore src/PepedawnRaffle.sol
```

#### Manual Security Review
- [ ] Review all `external`/`public` functions
- [ ] Check all math operations
- [ ] Verify access controls
- [ ] Test emergency scenarios
- [ ] Review external calls
- [ ] Check for front-running vectors

#### Chaos Testing
- [ ] Call functions in unexpected order
- [ ] Send ETH directly to contract
- [ ] Try to break circuit breakers
- [ ] Test with malicious inputs
- [ ] Attempt reentrancy attacks

---

## DEPLOYMENT PROCEDURE

### D-DAY CHECKLIST

#### T-minus 7 days
- [ ] All audits complete
- [ ] All tests passing
- [ ] Mainnet wallets ready (owner, creators, etc.)
- [ ] VRF subscription created and funded
- [ ] Emblem Vault NFTs ready
- [ ] Website deployment tested
- [ ] Monitoring systems ready
- [ ] Emergency procedures documented
- [ ] Support team briefed

#### T-minus 24 hours
- [ ] Final code review
- [ ] Gas price monitoring (aim for <30 gwei)
- [ ] Check mainnet RPC endpoints working
- [ ] Verify all accounts funded
- [ ] Backup all data
- [ ] Alert team deployment is happening

#### T-minus 1 hour
- [ ] Double-check deployment script
- [ ] Verify environment variables
- [ ] Clear confirmation on all addresses
- [ ] Team on standby

---

### DEPLOYMENT SEQUENCE

#### Step 1: Deploy Contract (Owner)

```bash
cd contracts

# Ensure environment is set
source .env # or set variables manually

# Verify all variables are set
echo $MAINNET_RPC_URL
echo $VRF_COORDINATOR_MAINNET
echo $CREATORS_ADDRESS
echo $EMBLEM_VAULT_ADDRESS_MAINNET

# Deploy
forge script scripts/forge/Deploy.s.sol \
  --rpc-url $MAINNET_RPC_URL \
  --broadcast \
  --verify \
  --etherscan-api-key $ETHERSCAN_API_KEY \
  --slow # Use slow mode for better gas price

# Save deployment address
export CONTRACT_ADDRESS=<deployed_address>
```

**Expected Output**:
```
✅ Contract deployed at: 0x...
✅ Transaction: 0x...
✅ Gas used: ~4.5M
✅ Cost: ~0.15 ETH (at 30 gwei)
```

**Immediately After**:
1. Save contract address securely
2. Verify on Etherscan it deployed correctly
3. Update all config files

---

#### Step 2: Verify Contract (If auto-verify failed)

```bash
forge verify-contract \
  $CONTRACT_ADDRESS \
  PepedawnRaffle \
  --chain mainnet \
  --etherscan-api-key $ETHERSCAN_API_KEY \
  --watch
```

**Verify Success**:
- [ ] Green checkmark on Etherscan
- [ ] Source code matches deployed bytecode
- [ ] All imports resolved correctly

---

#### Step 3: Add VRF Consumer

```bash
# Via Cast
cast send $VRF_COORDINATOR_MAINNET \
  "addConsumer(uint256,address)" \
  $VRF_SUBSCRIPTION_ID \
  $CONTRACT_ADDRESS \
  --private-key $PRIVATE_KEY \
  --rpc-url $MAINNET_RPC_URL

# OR via Chainlink UI: https://vrf.chain.link
# 1. Go to your subscription
# 2. Click "Add Consumer"
# 3. Enter CONTRACT_ADDRESS
# 4. Confirm transaction
```

**Verify**:
```bash
# Check contract is added
cast call $VRF_COORDINATOR_MAINNET \
  "getSubscription(uint256)" \
  $VRF_SUBSCRIPTION_ID \
  --rpc-url $MAINNET_RPC_URL
```

---

#### Step 4: Update All Configurations

**Files to Update**:

1. **deploy/artifacts/addresses.json**
```json
{
  "1": {
    "PepedawnRaffle": "0x<DEPLOYED_ADDRESS>",
    "deployedAt": "2025-XX-XXTXX:XX:XXZ",
    "deployedBy": "mainnet-deployment",
    "deploymentTx": "0x<TX_HASH>",
    "verified": true
  }
}
```

2. **frontend/src/contract-config.js**
```javascript
export const CONTRACT_CONFIG = {
  address: "0x<DEPLOYED_ADDRESS>",
  network: 'mainnet',
  chainId: 1,
  // ... rest
};
```

3. **frontend/public/deploy/artifacts/addresses.json**
```json
// Same as deploy/artifacts/addresses.json
```

4. **deploy/artifacts/vrf-config.json**
```json
{
  "coordinator": "0x271682DEB8C4E0901D1a1550aD2e64D568E69909",
  "subscriptionId": YOUR_ACTUAL_SUB_ID,
  "keyHash": "0x8af398995b04c28e9951adb9721ef74c74f93e6a478f39e7e0777be13527e7ef",
  "callbackGasLimit": 500000,
  "requestConfirmations": 5,
  "lastUpdated": "2025-XX-XXTXX:XX:XXZ",
  "notes": "Mainnet production configuration"
}
```

5. **README.md**
```markdown
**Contract Address**: `0x<DEPLOYED_ADDRESS>`
**Network**: Ethereum Mainnet (Chain ID: 1)
```

---

#### Step 5: Deploy Frontend

```bash
cd frontend

# Build production version
npm run build

# Test build locally
npm run preview
# Open in browser and test thoroughly

# Deploy via GitHub Actions (push to main)
git add dist/ src/contract-config.js public/deploy/
git commit -m "Deploy mainnet configuration"
git push origin main

# OR deploy manually via FTP
# Use FileZilla or similar to upload dist/* to public_html/
```

**Verify Deployment**:
- [ ] Visit https://pepedawn.art
- [ ] Check contract address is correct
- [ ] Test wallet connection
- [ ] Verify network detection works
- [ ] Check all pages load (index, main, rules)

---

#### Step 6: Transfer Prize NFTs (Critical)

**Before first round opens**:

```bash
# Transfer 10 Emblem Vault NFTs to contract
# For each NFT (token IDs 1-10 or whichever you're using):

cast send $EMBLEM_VAULT_ADDRESS_MAINNET \
  "safeTransferFrom(address,address,uint256)" \
  $YOUR_ADDRESS \
  $CONTRACT_ADDRESS \
  <TOKEN_ID> \
  --private-key $PRIVATE_KEY \
  --rpc-url $MAINNET_RPC_URL

# Verify contract owns them
cast call $EMBLEM_VAULT_ADDRESS_MAINNET \
  "ownerOf(uint256)" \
  <TOKEN_ID> \
  --rpc-url $MAINNET_RPC_URL
```

**Expected**: Contract address is returned

---

#### Step 7: Create First Round

```bash
# Create round
cast send $CONTRACT_ADDRESS \
  "createRound()" \
  --private-key $PRIVATE_KEY \
  --rpc-url $MAINNET_RPC_URL

# Wait for confirmation
sleep 30

# Set prizes for round 1
cast send $CONTRACT_ADDRESS \
  "setPrizesForRound(uint256,uint256[])" \
  1 \
  "[1,2,3,4,5,6,7,8,9,10]" \
  --private-key $PRIVATE_KEY \
  --rpc-url $MAINNET_RPC_URL

# Set valid proof for round
PROOF_HASH=$(cast keccak "pepedawn2025") # Or whatever puzzle solution
cast send $CONTRACT_ADDRESS \
  "setValidProof(uint256,bytes32)" \
  1 \
  $PROOF_HASH \
  --private-key $PRIVATE_KEY \
  --rpc-url $MAINNET_RPC_URL
```

---

#### Step 8: Open Round (When Ready)

**DO NOT do this immediately!**

Wait until:
- [ ] Website is live and tested
- [ ] Community is notified
- [ ] Marketing materials are ready
- [ ] Support team is standing by

```bash
# Open round 1
cast send $CONTRACT_ADDRESS \
  "openRound(uint256)" \
  1 \
  --private-key $PRIVATE_KEY \
  --rpc-url $MAINNET_RPC_URL
```

---

#### Step 9: Announce Launch

**Communication Channels**:
1. Twitter/X announcement
2. Discord announcement
3. Email newsletter (if applicable)
4. Website banner
5. Reddit post (if applicable)

**Announcement Template**:
```
🎉 PEPEDAWN is LIVE on Ethereum Mainnet! 

Round 1 is now open for betting!

📍 Contract: 0x... (verified on Etherscan)
🌐 Website: https://pepedawn.art
💰 Min bet: 0.005 ETH
🧩 Puzzle proofs: +40% odds
🎁 Prizes: 10 Emblem Vault NFTs

Round closes in 2 weeks. Good luck! 🐸

⚠️ Always verify you're on the official site!
```

---

### DEPLOYMENT CONTINGENCIES

#### If Deployment Fails
1. **Don't panic**
2. Check error message
3. Common issues:
   - Wrong network
   - Insufficient gas
   - Invalid constructor parameters
4. Fix and redeploy (use different nonce)

#### If Contract Has Bug After Deployment
1. **Pause contract immediately**: `pause()`
2. Assess severity
3. If critical:
   - Announce issue
   - Begin refund process
   - Deploy fixed version
4. If minor:
   - Document workaround
   - Plan v2 deployment
   - Consider upgradeability in v2

#### If VRF Fails
1. Check subscription balance
2. Check consumer is added
3. Verify key hash is correct
4. Wait for fulfillment (can take 5-10 min)
5. If timeout (>1 hour):
   - Contact Chainlink support
   - May need to re-request

---

## POST-DEPLOYMENT

### IMMEDIATE (First 24 Hours)

#### Monitoring
- [ ] Watch contract for all events
- [ ] Monitor first 5-10 bets
- [ ] Check gas costs are reasonable
- [ ] Verify proof submissions work
- [ ] Monitor VRF LINK balance
- [ ] Check for any reverted transactions

#### Support
- [ ] Team on standby for questions
- [ ] Monitor Discord/Twitter for issues
- [ ] Respond to any bugs/problems immediately
- [ ] Document any issues for future

#### Metrics to Track
- Unique participants
- Total wagered
- Average bet size
- Proof submission rate
- Error rate
- Gas costs (actual vs estimated)

---

### FIRST WEEK

#### Operations
- [ ] Monitor round progress
- [ ] Top up VRF subscription if needed
- [ ] Address any user issues
- [ ] Collect feedback
- [ ] Monitor for any security issues

#### Marketing
- [ ] Share milestones (100 ETH wagered, etc.)
- [ ] Highlight interesting statistics
- [ ] Showcase winner claims
- [ ] Build community engagement

---

### ONGOING

#### Weekly Tasks
- [ ] Check VRF LINK balance
- [ ] Review gas costs vs budget
- [ ] Analyze participation metrics
- [ ] Review security logs
- [ ] Update community on round status

#### Per-Round Tasks
- [ ] Close round on time
- [ ] Snapshot participants
- [ ] Generate and upload participants file
- [ ] Request VRF
- [ ] Generate and upload winners file
- [ ] Commit winners on-chain
- [ ] Announce winners
- [ ] Monitor prize claims
- [ ] Prepare next round

#### Monthly Reviews
- [ ] Financial review (revenue, expenses)
- [ ] Security audit
- [ ] User feedback analysis
- [ ] Platform improvements planning
- [ ] Gas optimization opportunities

---

### MAINTENANCE PLAN

#### Contract Upgrades (v2 Planning)
- Collect user feedback
- Identify pain points
- Plan improvements:
  - Lower gas costs
  - Additional features
  - Better UX
  - Layer 2 migration?

#### Website Updates
- [ ] Fix bugs as reported
- [ ] Add requested features
- [ ] Performance improvements
- [ ] Mobile optimization
- [ ] Accessibility improvements

#### Operations Improvements
- [ ] Automate round management (Chainlink Automation)
- [ ] Improve monitoring
- [ ] Better documentation
- [ ] Community tools (stats dashboards, etc.)

---

## EMERGENCY PROCEDURES

### EMERGENCY CONTACTS

**Team Members**:
```
Owner 1: [Name] - [Phone] - [Email] - [Telegram]
Owner 2: [Name] - [Phone] - [Email] - [Telegram]
Developer: [Name] - [Phone] - [Email] - [Telegram]
```

**External**:
```
Chainlink Support: https://docs.chain.link/resources/support
Etherscan Support: support@etherscan.io
Audit Firm: [If ongoing relationship]
Legal Counsel: [Contact info]
```

---

### EMERGENCY SCENARIOS

#### Scenario 1: Critical Bug Discovered

**Indicators**:
- Funds at risk
- Incorrect winner selection
- Reentrancy vulnerability
- Front-running issue

**Response** (execute in order):
1. **Pause contract immediately**:
   ```bash
   cast send $CONTRACT_ADDRESS "pause()" \
     --private-key $PRIVATE_KEY \
     --rpc-url $MAINNET_RPC_URL
   ```

2. **Announce on all channels**:
   ```
   🚨 URGENT: Contract has been paused due to a critical issue.
   
   Your funds are safe. We are investigating and will provide updates.
   
   DO NOT interact with the contract until further notice.
   ```

3. **Assess damage**:
   - How much ETH is at risk?
   - Have any funds been stolen?
   - How many users affected?

4. **Determine fix**:
   - Can issue be resolved operationally?
   - Need new contract deployment?
   - Can we refund users?

5. **Execute fix**:
   - Deploy new contract if needed
   - Migrate state if possible
   - Process refunds if necessary

6. **Communication**:
   - Transparent about what happened
   - Explain fix
   - Timeline for resolution
   - Compensation plan (if applicable)

---

#### Scenario 2: VRF Request Timeout

**Indicators**:
- VRF request made >1 hour ago
- No fulfillment event
- Round stuck in VRFRequested state

**Response**:
1. **Check VRF subscription**:
   ```bash
   # Visit https://vrf.chain.link
   # Check subscription balance
   # Check consumer is added
   ```

2. **Contact Chainlink**:
   - Create support ticket
   - Provide request ID
   - Wait for response (usually < 1 hour)

3. **If Chainlink confirms issue**:
   - May need to re-request VRF
   - Chainlink may refund LINK

4. **Communication**:
   ```
   ⏳ VRF fulfillment is taking longer than expected.
   
   This is a Chainlink infrastructure issue, not with our contract.
   
   We are in contact with Chainlink support. Round will continue once resolved.
   ```

---

#### Scenario 3: Owner Key Compromise

**Indicators**:
- Unexpected transactions from owner address
- Key has been exposed
- Suspicious activity

**Response** (IMMEDIATE):
1. **If you still have access**:
   ```bash
   # Transfer ownership to new safe address
   cast send $CONTRACT_ADDRESS \
     "transferOwnership(address)" \
     $NEW_SAFE_ADDRESS \
     --private-key $CURRENT_KEY \
     --rpc-url $MAINNET_RPC_URL
   
   # Pause contract from new address
   cast send $CONTRACT_ADDRESS "pause()" \
     --private-key $NEW_KEY \
     --rpc-url $MAINNET_RPC_URL
   ```

2. **If you don't have access**:
   - Announce publicly
   - Contract may need to be abandoned
   - Work with community on refund plan
   - Consider using `emergencyWithdrawETH` if available

3. **Communication**:
   ```
   🚨 SECURITY ALERT: Owner key may be compromised.
   
   Contract is paused. DO NOT send any funds.
   
   We are working on a solution. Updates to follow.
   ```

---

#### Scenario 4: Website Compromise/Phishing

**Indicators**:
- Fake pepedawn.art site appears
- DNS hijacked
- Man-in-the-middle attack

**Response**:
1. **Verify official website**:
   - Check DNS records
   - Verify SSL certificate
   - Check website files on server

2. **If DNS hijacked**:
   - Contact Namecheap immediately
   - Change account password
   - Enable 2FA
   - Restore correct DNS records

3. **If phishing site**:
   - Report to Google Safe Browsing
   - Report to hosting provider
   - Report to domain registrar
   - Contact MetaMask to block site

4. **Communication**:
   ```
   ⚠️ PHISHING ALERT: Fake pepedawn sites detected
   
   Official website: https://pepedawn.art (verify SSL certificate)
   Contract address: 0x... (verify on our Twitter bio)
   
   Never enter your private key or seed phrase anywhere!
   ```

---

#### Scenario 5: Low LINK Balance

**Indicators**:
- VRF subscription balance < 5 LINK
- Alert notification

**Response**:
1. **Add LINK immediately**:
   - Purchase LINK on exchange
   - Transfer to VRF subscription
   - Verify balance updated

2. **Set up auto-top-up** (if not already):
   - Consider using Chainlink Automation
   - Or manual monitoring script

3. **Prevention**:
   - Keep 20-30 LINK reserve
   - Set alerts at 10 LINK, 5 LINK, 2 LINK

---

#### Scenario 6: High Gas Prices

**Indicators**:
- Base fee > 200 gwei
- Users complaining about costs
- Participation drops

**Response**:
1. **Short-term**:
   - Announce high gas situation
   - Recommend waiting for lower gas
   - Extend round duration if needed

2. **Medium-term**:
   - Analyze if pattern continues
   - Consider adjusting round timing
   - Look into Layer 2 options

3. **Communication**:
   ```
   ⚠️ High gas prices on Ethereum right now (>200 gwei)
   
   You can still participate, but transaction costs are higher than normal.
   
   Consider waiting for gas to drop (usually overnight US time).
   
   Check gas prices: https://etherscan.io/gastracker
   ```

---

#### Scenario 7: Emblem Vault NFT Issue

**Indicators**:
- NFT custody problem
- Transfer fails
- Wrong NFT distributed

**Response**:
1. **Assess situation**:
   - Check NFT ownership
   - Verify token IDs
   - Check Emblem Vault contract status

2. **If NFT stuck**:
   - Use `emergencyWithdrawNFT` if available
   - Transfer manually from contract

3. **If wrong NFT given**:
   - Contact winner
   - Offer correct NFT if available
   - Consider compensation

4. **Communication**:
   - Transparency about issue
   - Explanation of resolution
   - Timeline to fix

---

### REFUND PROCEDURE

#### When Refunds Are Needed
- Critical bug requires shutting down
- Round cancelled
- Users affected by contract issue

#### Refund Process
1. **Identify affected users**:
   ```bash
   # Get all participants for round
   cast call $CONTRACT_ADDRESS \
     "getRoundParticipants(uint256)" \
     $ROUND_ID \
     --rpc-url $MAINNET_RPC_URL
   ```

2. **Calculate refund amounts**:
   ```bash
   # For each participant
   cast call $CONTRACT_ADDRESS \
     "userWageredInRound(uint256,address)" \
     $ROUND_ID \
     $USER_ADDRESS \
     --rpc-url $MAINNET_RPC_URL
   ```

3. **Execute refunds**:
   - If automatic refund system works: users call `withdrawRefund()`
   - If manual needed: batch ETH transfers from owner

4. **Communication**:
   ```
   💰 REFUND PROCESS
   
   Round X has been cancelled due to [reason].
   
   How to claim your refund:
   1. Go to pepedawn.art
   2. Connect wallet
   3. Click "Withdraw Refund"
   
   Or call withdrawRefund() directly on contract.
   
   Refunds available for 90 days.
   ```

---

### ROLLBACK PROCEDURES

#### Contract Rollback
**Reality**: Smart contracts are immutable, no true rollback possible.

**Options**:
1. Deploy new version and migrate
2. Use emergency pause
3. Process manual refunds

#### Website Rollback
```bash
# Keep previous version backed up
cd frontend
git checkout <previous_commit>
npm run build
# Deploy via FTP/GitHub Actions

# OR if using Cloudflare/CDN with versioning:
# Revert to previous deployment in dashboard
```

#### DNS Rollback
- Namecheap DNS changes take 1-48 hours
- Keep old IP addresses documented
- Consider having backup domain (pepedawn.io?)

---

## ADDITIONAL CONSIDERATIONS

### LEGAL & COMPLIANCE

#### Terms of Service (Must Have)
```
PEPEDAWN Terms of Service

1. Acceptance of Terms
2. Service Description (lottery/raffle mechanics)
3. Eligibility (age, jurisdiction restrictions)
4. Prohibited Conduct
5. Intellectual Property
6. Disclaimers and Limitations of Liability
7. Governing Law
8. Dispute Resolution
```

**Action**: Hire lawyer to draft or use template and customize.

#### Privacy Policy (Required)
- What data is collected (wallet addresses, IPFS CIDs)
- How it's used
- Who has access
- User rights (GDPR compliance)

#### Risk Disclaimers
```
⚠️ IMPORTANT RISKS:
- Smart contracts are experimental technology
- Funds may be lost due to bugs
- Transactions are irreversible
- No guarantee of prizes
- Regulatory status uncertain
- Gas costs may be high
```

Place on website, in docs, in terms of service.

---

### INSURANCE & RISK MANAGEMENT

#### Smart Contract Insurance
**Providers**:
- Nexus Mutual (decentralized)
- InsurAce (multi-chain)
- Unslashed Finance

**Coverage**:
- Smart contract bugs
- Oracle failures
- Economic exploits

**Cost**: 2-5% of covered amount annually

**Decision**: Consider for first 6-12 months, especially if holding >50 ETH.

---

### MARKETING & LAUNCH STRATEGY

#### Pre-Launch (2-4 weeks before)
- [ ] Teaser announcements
- [ ] Build waitlist
- [ ] Create content (explainer videos, guides)
- [ ] Partner outreach (Emblem Vault, Chainlink community)
- [ ] Press releases (crypto news sites)

#### Launch Day
- [ ] Coordinated announcements
- [ ] AMA session
- [ ] Monitor all channels
- [ ] Support team ready

#### Post-Launch
- [ ] Daily updates
- [ ] Share milestones
- [ ] Highlight winners
- [ ] Community engagement
- [ ] Continuous marketing

---

### FINANCIAL PROJECTIONS

#### Revenue Model
```
Per Round:
- Wagers: 10-100 ETH (estimate range)
- Creators receive: 80% = 8-80 ETH
- Next round fund: 20% = 2-20 ETH

Monthly (2 rounds):
- Revenue: 16-160 ETH ($50K-500K at current prices)
```

#### Expense Model
```
Fixed per month:
- RPC endpoints: $50-200
- IPFS hosting: $20-50
- Monitoring tools: $30-100
- Website hosting: $5-50

Variable per round:
- Gas for operations: 0.02-0.1 ETH
- VRF costs: 0.5 LINK
- NFT costs: Variable (if purchasing)

Annual:
- Legal/compliance: $5K-20K
- Audit (if needed): $10K-50K
```

#### Break-Even Analysis
```
Need ~5-10 ETH wagered per round to break even
With 10+ participants at 0.5 ETH average: profitable
```

---

### LONG-TERM ROADMAP

#### v2 Features (6-12 months)
- [ ] Layer 2 deployment (lower gas)
- [ ] Multi-chain support
- [ ] DAO governance
- [ ] Upgradeability via proxy
- [ ] More prize types
- [ ] Referral system
- [ ] Batch betting
- [ ] Mobile app

#### v3 Features (12-24 months)
- [ ] Fully decentralized (IPFS-hosted frontend)
- [ ] Custom ERC20 token
- [ ] Staking mechanisms
- [ ] Automated round management
- [ ] AI-generated puzzles
- [ ] Social features

---

## FINAL CHECKLIST

### PRE-DEPLOYMENT (All must be ✅)

#### Code
- [ ] All test/debug functions removed
- [ ] All tests passing (151/151)
- [ ] Slither: no high/medium issues
- [ ] Mythril: no critical issues
- [ ] Professional audit complete (if budget allows)
- [ ] All audit findings addressed
- [ ] Gas profiling complete
- [ ] Fork testing complete

#### Configuration
- [ ] All mainnet addresses updated
- [ ] **`DEV_MODE: false`** set in contract-config.js
- [ ] VRF subscription created and funded (20+ LINK)
- [ ] Emblem Vault mainnet contract verified
- [ ] Environment variables set correctly
- [ ] All secrets secured (no keys in git)
- [ ] Multi-sig wallet setup (or hardware wallet)
- [ ] IPFS production account ready

#### Website
- [ ] Frontend built for production
- [ ] All contract addresses correct
- [ ] Network detection works
- [ ] Mobile responsive
- [ ] SSL/HTTPS enforced
- [ ] CDN setup (Cloudflare)
- [ ] Uptime monitoring configured
- [ ] Analytics setup

#### Operations
- [ ] Monitoring systems ready (Tenderly, etc.)
- [ ] Alert systems configured
- [ ] Emergency procedures documented
- [ ] Support team briefed
- [ ] Runbooks created
- [ ] Backup/disaster recovery plan

#### Legal
- [ ] Terms of Service created
- [ ] Privacy Policy created
- [ ] Risk disclaimers added
- [ ] Legal review complete (or waived consciously)
- [ ] Jurisdiction restrictions decided

#### Marketing
- [ ] Announcement materials ready
- [ ] Social media accounts secured
- [ ] Community channels moderated
- [ ] Marketing calendar planned
- [ ] Partnerships confirmed

---

### DEPLOYMENT DAY

- [ ] Gas prices acceptable (<50 gwei)
- [ ] All team members available
- [ ] Deploy contract
- [ ] Verify on Etherscan
- [ ] Add VRF consumer
- [ ] Transfer prize NFTs
- [ ] Update all configs
- [ ] Deploy frontend
- [ ] Test end-to-end
- [ ] Create first round
- [ ] Set prizes and proof
- [ ] Open round
- [ ] Make announcements
- [ ] Monitor closely

---

### POST-DEPLOYMENT (First Week)

- [ ] 24/7 monitoring first 48 hours
- [ ] Respond to all issues immediately
- [ ] Track all metrics
- [ ] Daily team standups
- [ ] Community engagement
- [ ] Document lessons learned
- [ ] Adjust as needed

---

## CONCLUSION

This deployment plan covers:

✅ **Contract Code**: Review, changes needed, security hardening  
✅ **Configuration**: All network configs, wallet setup, environment variables  
✅ **Gas Costs**: Detailed analysis and optimization  
✅ **Mainnet Differences**: Comprehensive comparison with Sepolia  
✅ **Deployment**: Step-by-step procedure with commands  
✅ **Website**: Namecheap deployment, CDN, monitoring  
✅ **Security**: Audits, monitoring, emergency procedures  
✅ **Operations**: Runbooks, support, ongoing maintenance  
✅ **Legal**: Compliance, terms of service, risk management  
✅ **Marketing**: Launch strategy, community building  

**Most Critical Items**:
1. ❌ Remove `resetVrfTiming()` function (SECURITY)
2. ✅ Professional security audit (HIGHLY RECOMMENDED)
3. ✅ Multi-sig wallet for owner (CRITICAL)
4. ✅ Emblem Vault mainnet integration testing
5. ✅ VRF subscription setup and funding
6. ✅ Comprehensive monitoring and alerts
7. ✅ Emergency procedures documentation
8. ✅ Legal review (terms, privacy, disclaimers)

**You have one shot at this. Take your time, follow this plan, and you'll be ready for a successful mainnet launch. 🚀**

---

**Next Steps**:
1. Read through this entire document
2. Create project board with all checklist items
3. Assign responsibilities to team members
4. Set timeline for each phase
5. Begin Phase 1 (Security Audit)

**Estimated Total Timeline**: 4-6 weeks from start to launch  
**Estimated Total Budget**: $10K-50K (audit, legal, infrastructure, contingency)

Good luck with your mainnet deployment! 🐸

