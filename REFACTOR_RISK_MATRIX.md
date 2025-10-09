# PEPEDAWN Refactoring Risk Matrix
**Analysis Date**: October 9, 2025  
**Current Status**: Stable, tested, merkle-based hybrid approach  
**Scale**: Max 50-100 participants, 10 rounds monthly, likely ending before round 10

---

## Executive Summary

Given your constraints (max 100 participants, 10 rounds total, monthly cadence), the **current merkle approach is over-engineered** for your scale. However, refactoring carries risks to your stable codebase.

**TL;DR Recommendation**: **Option 3 (Hybrid Plus)** or **Option 4 (Minimal Automation)** - Best risk/reward ratio for your scale.

---

## Solution Options Matrix

| Solution | Automation Level | On-Chain Data | Gas Cost/Round | Code Stability Risk | Maintenance Burden | Implementation Effort |
|----------|-----------------|---------------|----------------|---------------------|-------------------|---------------------|
| **Option 1: Full On-Chain** | 100% | All | ~$50-100 | 🔴 HIGH | 🟢 LOWEST | 🔴 HIGH (4-6 weeks) |
| **Option 2: On-Chain Winners** | 90% | Winners only | ~$20-40 | 🟠 MEDIUM-HIGH | 🟡 LOW | 🟠 MEDIUM (2-3 weeks) |
| **Option 3: Hybrid Plus** | 80% | Keep Merkle | ~$5-15 | 🟡 LOW-MEDIUM | 🟡 LOW-MEDIUM | 🟢 LOW (1 week) |
| **Option 4: Minimal Automation** | 70% | Keep Merkle | ~$5-15 | 🟢 VERY LOW | 🟠 MEDIUM | 🟢 VERY LOW (2-3 days) |
| **Option 5: Status Quo** | 60% | Keep Merkle | ~$5-15 | 🟢 NO RISK | 🔴 HIGH | 🟢 NONE |

---

## Detailed Analysis

### Option 1: Full On-Chain Everything
**Description**: Remove all off-chain components. Winners computed in `fulfillRandomWords()`, no Merkle trees, no IPFS, no manual scripts.

#### Architecture Changes
```solidity
// In fulfillRandomWords - compute and store winners directly
function fulfillRandomWords(uint256 requestId, uint256[] calldata randomWords) internal override {
    uint256 roundId = vrfRequestToRound[requestId];
    
    // Select and store winners on-chain
    _assignWinnersAndDistribute(roundId, randomWords[0]);
    
    // Distribute prizes immediately (NFT transfers)
    for (uint256 i = 0; i < 10; i++) {
        address winner = roundWinners[roundId][i].wallet;
        uint256 tokenId = prizeNFTs[roundId][i];
        emblemVault.safeTransferFrom(address(this), winner, tokenId);
    }
    
    rounds[roundId].status = RoundStatus.Distributed;
}
```

**Pros**:
- ✅ Zero manual intervention
- ✅ Zero off-chain dependencies (no IPFS, no Merkle)
- ✅ Simplest architecture
- ✅ Most transparent (everything on-chain)
- ✅ No script maintenance

**Cons**:
- ❌ **HIGHEST RISK**: Major code changes to stable contract
- ❌ Gas: ~$50-100/round (100 participants @ 50 gwei)
- ❌ NFT custody: Contract must hold all prizes upfront
- ❌ Winner disputes: Harder to re-distribute if issues
- ❌ No historical flexibility (can't regenerate claims)
- ❌ 4-6 weeks implementation + full test suite rewrite

**Gas Breakdown** (100 participants, Sepolia):
```
VRF fulfillment base:        75,000 gas
Winner selection (10):      300,000 gas (binary search)
Storage writes (10 winners): 200,000 gas (storage slots)
NFT transfers (10):          500,000 gas (external calls)
Fee distribution:             50,000 gas
TOTAL:                     ~1,125,000 gas @ 50 gwei = ~$3.50
         @ mainnet (2000 gwei) = ~$50-100 with congestion
```

**Recommended?** ❌ **NO** - Risks outweigh benefits for 10-round lifespan

---

### Option 2: On-Chain Winners, Merkle Claims
**Description**: Compute winners in `fulfillRandomWords()`, but keep Merkle tree for claims. Remove IPFS for winners file. Participants stay in Merkle.

#### Architecture Changes
```solidity
// Store winners on-chain, but keep Merkle for claims
function fulfillRandomWords(uint256 requestId, uint256[] calldata randomWords) internal override {
    uint256 roundId = vrfRequestToRound[requestId];
    
    // Select winners on-chain
    _assignWinnersAndDistribute(roundId, randomWords[0]);
    
    // Generate Merkle root from stored winners
    bytes32 winnersRoot = _generateWinnersRoot(roundId);
    rounds[roundId].winnersRoot = winnersRoot;
    rounds[roundId].status = RoundStatus.Distributed;
}

// New: Generate Merkle root from on-chain winners array
function _generateWinnersRoot(uint256 roundId) internal view returns (bytes32) {
    WinnerAssignment[] memory winners = roundWinners[roundId];
    bytes32[] memory leaves = new bytes32[](winners.length);
    
    for (uint256 i = 0; i < winners.length; i++) {
        leaves[i] = keccak256(abi.encodePacked(
            winners[i].wallet,
            winners[i].prizeTier,
            uint8(i)
        ));
    }
    
    return _buildMerkleRoot(leaves);
}

// Add on-chain Merkle tree builder (small for 10 winners)
function _buildMerkleRoot(bytes32[] memory leaves) internal pure returns (bytes32) {
    // Simple binary Merkle tree builder (10 leaves = 4 levels)
    // ... implementation
}
```

**Pros**:
- ✅ No manual winner computation
- ✅ No IPFS for winners
- ✅ Keep pull-payment claim system (good for disputes)
- ✅ Moderate risk (only changes VRF fulfillment)
- ✅ Gas reasonable for your scale (~$20-40/round)

**Cons**:
- ⚠️ Still requires Merkle tree generation (but on-chain)
- ⚠️ Still requires participant snapshot script
- ⚠️ Medium risk: Changes to critical VRF callback
- ⚠️ 2-3 weeks implementation + testing
- ⚠️ On-chain Merkle builder adds complexity

**Gas Breakdown**:
```
VRF fulfillment + winner selection: 375,000 gas
Merkle root generation (10 winners): 100,000 gas (on-chain computation)
Storage:                              200,000 gas
TOTAL:                              ~675,000 gas @ 50 gwei = ~$2
            @ mainnet (2000 gwei) = ~$20-40
```

**Recommended?** ⚠️ **MAYBE** - Better than Option 1, but still carries risk for modest benefit

---

### Option 3: Hybrid Plus (Smart Automation)
**Description**: **Keep current Merkle architecture**, but add **smart automation** via Chainlink Automation (formerly Keepers) or simple bot. No contract changes.

#### Architecture (No Contract Changes!)
```javascript
// New: automation-bot.js (replaces manual scripts)
// Watches contract events, triggers actions automatically

class RoundAutomationBot {
  async monitorRound(roundId) {
    // Watch for round events
    contract.on('RoundOpened', (rid) => {
      console.log(`Round ${rid} opened - ready for bets`);
    });
    
    contract.on('RoundClosed', async (rid) => {
      // Auto-snapshot
      await contract.snapshotRound(rid);
      
      // Auto-generate participants
      const participants = await this.fetchParticipants(rid);
      const merkle = this.buildMerkleTree(participants);
      
      // Upload to IPFS
      const cid = await this.uploadToIPFS(participants, merkle);
      
      // Commit root
      await contract.commitParticipantsRoot(rid, merkle.root, cid);
      
      // Request VRF
      await contract.requestVrf(rid);
    });
    
    contract.on('VRFFulfilled', async (rid, requestId, randomWords) => {
      // Auto-generate winners
      const winners = this.selectWinners(rid, randomWords[0]);
      const merkle = this.buildMerkleTree(winners);
      
      // Upload to IPFS
      const cid = await this.uploadToIPFS(winners, merkle);
      
      // Submit winners root
      await contract.submitWinnersRoot(rid, merkle.root, cid);
      
      console.log(`Round ${rid} complete - ready for claims!`);
    });
  }
}

// Deploy bot to Railway.app, Render, or run locally
```

**Chainlink Automation Alternative**:
```solidity
// Add to contract (minimal change)
function checkUpkeep(bytes calldata) external view returns (bool upkeepNeeded, bytes memory performData) {
    // Check if round needs snapshot
    if (rounds[currentRoundId].status == RoundStatus.Closed) {
        return (true, abi.encode(currentRoundId, "snapshot"));
    }
    // Add other checks...
}

function performUpkeep(bytes calldata performData) external {
    (uint256 roundId, string memory action) = abi.decode(performData, (uint256, string));
    
    if (keccak256(bytes(action)) == keccak256("snapshot")) {
        snapshotRound(roundId);
    }
    // Note: Still need bot for Merkle generation (off-chain computation)
}
```

**Pros**:
- ✅ **ZERO CONTRACT CHANGES** - no risk to stable code
- ✅ Full automation achieved via external bot
- ✅ Keep all security benefits of Merkle/IPFS
- ✅ Can pause/debug bot without contract changes
- ✅ Easy to iterate and improve automation
- ✅ Gas costs stay same (~$5-15/round)
- ✅ Implementation: 1 week (mostly bot logic)

**Cons**:
- ⚠️ Requires bot hosting (Railway.app = $5/mo or run locally)
- ⚠️ Bot single point of failure (but easy to restart)
- ⚠️ Still has off-chain dependencies (IPFS, bot)
- ⚠️ Monitoring needed (though bot can self-monitor)

**Recommended?** ✅ **YES** - Best risk/reward for your use case

---

### Option 4: Minimal Automation (Script Consolidation)
**Description**: Keep everything as-is, but consolidate all manual steps into **one command**. Minimal changes.

#### Implementation
```javascript
// Enhanced automate-round.js (already exists, just improve it)

// Current: 3 separate commands
// node scripts/automate-round.js OPEN
// node scripts/automate-round.js VRF  
// node scripts/automate-round.js FULL

// New: Add watch mode
// node scripts/automate-round.js WATCH

class RoundWatcher {
  async watchAndAutomate() {
    console.log('🤖 Watching for round events...');
    
    // Poll contract every 30 seconds
    setInterval(async () => {
      const round = await contract.getRound(currentRoundId);
      
      if (round.status === RoundStatus.Closed && !this.snapshotted) {
        console.log('📸 Auto-snapshotting...');
        await this.snapshot(currentRoundId);
        this.snapshotted = true;
      }
      
      if (round.status === RoundStatus.WinnersReady && !this.winnersSubmitted) {
        console.log('🎲 Auto-generating winners...');
        await this.generateAndSubmitWinners(currentRoundId);
        this.winnersSubmitted = true;
      }
      
    }, 30000);
  }
}

// Usage: Start once, leave running
// node scripts/automate-round.js WATCH
```

**Also add cron jobs**:
```bash
# crontab -e
# Check every 5 minutes if round needs attention
*/5 * * * * cd /path/to/pepedawn && node scripts/automate-round.js CHECK

# Or use pm2 to keep watcher alive
pm2 start scripts/automate-round.js -- WATCH
pm2 save
```

**Pros**:
- ✅ **MINIMAL RISK**: No contract changes at all
- ✅ Quick implementation (2-3 days)
- ✅ Uses existing stable scripts
- ✅ Easy to debug and pause
- ✅ No new dependencies
- ✅ Can run locally (no hosting costs)

**Cons**:
- ⚠️ Still requires a machine running (local or server)
- ⚠️ Not as elegant as Option 3
- ⚠️ Manual intervention if script crashes

**Recommended?** ✅ **YES** - Lowest risk, quick win

---

### Option 5: Status Quo (Do Nothing)
**Description**: Keep current manual process. Accept the operational burden for 10 rounds.

**Pros**:
- ✅ Zero risk to stable code
- ✅ Zero implementation time
- ✅ You understand it completely

**Cons**:
- ❌ Manual work every round (10 rounds = 10x manual work)
- ❌ Error-prone (human mistakes in multi-step process)
- ❌ Time-consuming per round (~30-60 min manual work)
- ❌ Requires being available at specific times

**Recommended?** ⚠️ **ONLY IF** you have very limited time and can't spare 2-3 days for Option 4

---

## Risk Analysis by Category

### 1. **Contract Security Risk**

| Option | Risk Level | Why |
|--------|-----------|-----|
| Option 1 | 🔴 HIGH | Major changes to VRF callback, winner selection, NFT transfers |
| Option 2 | 🟠 MEDIUM-HIGH | Moderate changes to VRF callback, on-chain Merkle builder |
| Option 3 | 🟢 VERY LOW | Zero contract changes |
| Option 4 | 🟢 VERY LOW | Zero contract changes |
| Option 5 | 🟢 NONE | No changes |

### 2. **Gas Cost Impact** (Mainnet equivalent, per round)

| Option | 50 Participants | 100 Participants | Notes |
|--------|----------------|------------------|-------|
| Option 1 | $40-80 | $80-150 | NFT transfers dominate |
| Option 2 | $15-30 | $25-50 | On-chain Merkle computation |
| Option 3 | $5-10 | $8-15 | Current costs maintained |
| Option 4 | $5-10 | $8-15 | Current costs maintained |
| Option 5 | $5-10 | $8-15 | Current costs maintained |

**Note**: At 50 participants (your likely max), all options are affordable. Gas is NOT the differentiator.

### 3. **Implementation Time**

| Option | Time | Complexity | Testing Burden |
|--------|------|-----------|---------------|
| Option 1 | 4-6 weeks | 🔴 HIGH | Full test suite rewrite |
| Option 2 | 2-3 weeks | 🟠 MEDIUM | VRF tests + integration |
| Option 3 | 1 week | 🟡 LOW | Bot unit tests only |
| Option 4 | 2-3 days | 🟢 VERY LOW | Script tests (simple) |
| Option 5 | 0 days | 🟢 NONE | None |

### 4. **Maintenance Burden** (Over 10 Rounds)

| Option | Ongoing Work | What Could Break |
|--------|-------------|-----------------|
| Option 1 | Very Low | Contract bugs (high impact) |
| Option 2 | Low | Contract bugs (medium impact) |
| Option 3 | Low-Medium | Bot hosting, IPFS gateway |
| Option 4 | Medium | Script crashes, need monitoring |
| Option 5 | High | Human errors, manual timing |

### 5. **Flexibility & Debuggability**

| Option | Can Pause Mid-Round? | Can Fix Issues? | Transparency |
|--------|---------------------|----------------|--------------|
| Option 1 | ❌ No | ❌ Hard (contract upgrade needed) | ✅ Highest |
| Option 2 | ❌ No | ⚠️ Medium (view functions help) | ✅ High |
| Option 3 | ✅ Yes | ✅ Easy (bot restart) | ✅ High (IPFS backup) |
| Option 4 | ✅ Yes | ✅ Easy (script retry) | ✅ High (IPFS backup) |
| Option 5 | ✅ Yes | ✅ Easy (manual intervention) | ✅ High |

---

## Recommendation Matrix by Priority

### If Your Priority Is...

1. **Minimize Risk to Stable Code** → **Option 4** or **Option 3**
   - Zero contract changes, work with what you have

2. **Maximum Automation** → **Option 3**
   - Event-driven bot handles everything automatically

3. **Lowest Implementation Time** → **Option 4**
   - 2-3 days, uses existing scripts, minimal new code

4. **Lowest Ongoing Maintenance** → **Option 1** (if you trust the rewrite) or **Option 3**
   - Option 1: Set-and-forget (but risky upfront)
   - Option 3: Bot needs minimal monitoring

5. **Best Long-Term Architecture** → **Option 2**
   - Hybrid of on-chain transparency + off-chain flexibility
   - But given 10-round lifespan, not worth the risk

6. **Keep Working Now** → **Option 5**
   - Accept 30-60 min manual work per round for 10 rounds = 5-10 hours total

---

## Final Recommendation

**Choose Option 3 (Hybrid Plus) or Option 4 (Minimal Automation)**

### Why Option 3 (Hybrid Plus)?
- ✅ Zero risk to your stable, tested contract
- ✅ Full automation achieved
- ✅ 1 week implementation (vs 4-6 weeks for rewrites)
- ✅ Can iterate and improve bot without contract changes
- ✅ Easy to pause/debug if issues arise
- ✅ Gas costs stay optimal
- ✅ Keep all Merkle/IPFS benefits (historical data, disputes)

### Why Option 4 (Minimal Automation)?
- ✅ Lowest risk AND lowest implementation time
- ✅ 80% of the automation benefit for 10% of the effort
- ✅ Uses scripts you already have and trust
- ✅ Can run locally (no hosting costs)
- ✅ Perfect for 10-round lifespan

### Don't Choose Option 1 or 2 Because:
- ❌ High risk to stable code for marginal benefit
- ❌ Given 10-round lifespan, not worth major refactor
- ❌ Gas savings minimal at your scale (50 participants)
- ❌ Loss of historical flexibility (Merkle/IPFS is good for disputes)

---

## Implementation Paths

### Path A: Option 3 (1 week, recommended)
```bash
Week 1:
- Day 1-2: Build event listener bot
- Day 3-4: Add Merkle generation + IPFS upload
- Day 5: Add error handling + monitoring
- Day 6: Test on Sepolia
- Day 7: Deploy to Railway.app, monitor round 1

# Deploy bot
railway up
railway logs --tail
```

### Path B: Option 4 (2-3 days, lowest risk)
```bash
Day 1: Enhance automate-round.js with WATCH mode
Day 2: Add cron job / pm2 setup
Day 3: Test on Sepolia round

# Run locally
pm2 start scripts/automate-round.js -- WATCH
pm2 save
pm2 startup # configure to restart on reboot
```

---

## Questions to Decide

1. **How much time can you invest now?**
   - < 3 days → Option 4
   - 1 week → Option 3
   - > 2 weeks → Not worth it for 10 rounds

2. **Do you want to run a bot/server?**
   - Yes → Option 3 (Railway.app $5/mo or free tier)
   - No / Local only → Option 4 (pm2 on your machine)

3. **How confident are you in the current contract?**
   - Very confident → Stick with Option 3/4 (don't touch it)
   - Want to improve → Consider Option 2 (but risky)

4. **What's your gas budget per round?**
   - At 50 participants: $5-15/round for all options (not a differentiator)

---

## My Recommendation

**Go with Option 4 this weekend (2-3 days), then consider Option 3 if you want more automation.**

You have stable code. Don't break it for marginal gains. Your scale (50-100 participants, 10 rounds) doesn't justify major refactoring.

Save the big refactor for a v2 if this becomes a massive success beyond round 10.

🐸 **TLDR: Option 4 (minimal automation) = 2 days of work, zero risk, 80% automation for 10-round lifespan.**

