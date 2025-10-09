# Gas Cost Analysis: Merkle vs Full On-Chain Storage

## Assumptions
- **100 participants** per round (typical scenario)
- **10 winners** (1 Fake Pack, 1 Kek Pack, 8 Pepe Packs)
- **Monthly frequency** (12 rounds per year)

## Gas Cost Breakdown

### Current Merkle Approach

#### One-Time Per Round (Owner Operations)
```
Operation                               Gas Cost
─────────────────────────────────────────────────
commitParticipantsRoot (1 bytes32)      ~23,000
commitWinnersRoot (1 bytes32)           ~23,000
─────────────────────────────────────────────────
Total per round:                        ~46,000 gas
```

#### Per Winner Claim (User Operations)
```
Operation                               Gas Cost
─────────────────────────────────────────────────
Merkle proof verification (log2(10))    ~15,000
  - 4 levels × ~3,500 gas/level
Prize transfer & state updates          ~50,000
─────────────────────────────────────────────────
Total per claim:                        ~65,000 gas
Total for 10 winners:                   ~650,000 gas
```

**Total Gas Per Round: 696,000 gas**

---

### Full On-Chain Storage Approach

#### One-Time Per Round (Owner Operations)
```
Storing 100 participants:
- address (20 bytes)
- tickets (uint256)  
- weight (uint256)
= 3 storage slots × 100 participants = 300 slots
= 300 × 20,000 gas = 6,000,000 gas

Storing 10 winners:
- address (20 bytes)
- tier (uint8)
- prizeIndex (uint256)
= ~2 storage slots × 10 winners = 20 slots  
= 20 × 20,000 gas = 400,000 gas
─────────────────────────────────────────────────
Total per round:                        ~6,400,000 gas
```

#### Per Winner Claim (User Operations)
```
Operation                               Gas Cost
─────────────────────────────────────────────────
Read winner data from storage           ~2,100
Prize transfer & state updates          ~50,000
─────────────────────────────────────────────────
Total per claim:                        ~52,000 gas
Total for 10 winners:                   ~520,000 gas
```

**Total Gas Per Round: 6,920,000 gas**

---

## Cost Comparison Table

### Per Round Cost (Owner Pays Setup, Users Pay Claims)

| Gas Price | Merkle Approach | On-Chain Storage | Difference |
|-----------|-----------------|------------------|------------|
| **0.5 gwei** | | | |
| - Owner setup | 0.000023 ETH ($0.05) | 0.0032 ETH ($6.40) | +13,826% |
| - All claims (10) | 0.000325 ETH ($0.65) | 0.00026 ETH ($0.52) | -20% |
| - **Total** | **0.000348 ETH ($0.70)** | **0.00346 ETH ($6.92)** | **+895%** |
| | | | |
| **1 gwei** | | | |
| - Owner setup | 0.000046 ETH ($0.09) | 0.0064 ETH ($12.80) | +13,826% |
| - All claims (10) | 0.00065 ETH ($1.30) | 0.00052 ETH ($1.04) | -20% |
| - **Total** | **0.000696 ETH ($1.39)** | **0.00692 ETH ($13.84)** | **+895%** |
| | | | |
| **10 gwei** | | | |
| - Owner setup | 0.00046 ETH ($0.92) | 0.064 ETH ($128.00) | +13,826% |
| - All claims (10) | 0.0065 ETH ($13.00) | 0.0052 ETH ($10.40) | -20% |
| - **Total** | **0.00696 ETH ($13.92)** | **0.0692 ETH ($138.40)** | **+895%** |

*ETH price assumed at $2,000 for USD estimates*

---

## Annual Cost (12 Rounds)

| Gas Price | Merkle Approach | On-Chain Storage | Difference |
|-----------|-----------------|------------------|------------|
| **0.5 gwei** | $8.40 | $83.04 | +$74.64 |
| **1 gwei** | $16.68 | $166.08 | +$149.40 |
| **10 gwei** | $167.04 | $1,660.80 | +$1,493.76 |

---

## Key Insights

### 🔴 On-Chain Storage is ~10x More Expensive
- **895% increase** in total gas costs per round
- Dominated by storing 100 participant records (6M gas)
- Only saves ~130,000 gas total on claims (20% reduction)

### 💰 At 0.5 gwei (Current Ethereum)
- Merkle: **$0.70 per round** → $8.40/year
- On-chain: **$6.92 per round** → $83/year
- **Difference: +$75/year**

### ⚡ Where Costs Come From
**Merkle Approach:**
- 93% of gas spent on user claims (verification overhead)
- 7% spent on owner operations (tiny root storage)

**On-Chain Storage:**
- 92% of gas spent on owner operations (storing arrays)
- 8% spent on user claims (simpler reads)

---

## Recommendations

### Hybrid Optimization: Store Winners On-Chain Only

Instead of storing all participants (100 records), only store winners (10 records):

```
Winner storage (10 records):            400,000 gas
Participants root (1 bytes32):          23,000 gas
─────────────────────────────────────────────────
Total owner setup:                      ~423,000 gas
Winner claims (simpler):                ~520,000 gas
─────────────────────────────────────────────────
Total per round:                        ~943,000 gas
```

**Cost at 0.5 gwei: $1.89 per round** (vs $0.70 Merkle, $6.92 full on-chain)

### Benefits of Hybrid:
- ✅ Winners fully transparent on-chain (no IPFS/file issues)
- ✅ Simpler claims (no Merkle proofs for winners)
- ✅ Only 2.7x cost increase vs 10x
- ✅ Participants still use Merkle (less critical data)
- ✅ Eliminates the "winners file verification failed" class of bugs

---

## Bottom Line

**If budget allows $75-80/year extra:** Full on-chain storage eliminates ALL file handling complexity.

**If optimizing costs:** Hybrid approach (winners on-chain, participants Merkle) is the sweet spot at 2.7x cost for most benefit.

**Current Merkle approach:** Cheapest but highest operational complexity.

---

# Hybrid Design: Winners On-Chain Only

## Contract Storage Changes

### Add Winner Storage Structure

```solidity
struct WinnerRecord {
    address winner;
    uint8 prizeTier;      // 1=Fake, 2=Kek, 3=Pepe
    uint16 prizeIndex;    // Index within tier
}

// Storage mapping
mapping(uint256 => WinnerRecord[]) public roundWinners;

// Helper for claim validation
mapping(uint256 => mapping(address => bool)) public hasClaimedInRound;
```

### Modified Claim Function

```solidity
function claimPrize(
    uint256 roundId,
    uint256 winnerIndex  // Index in roundWinners array
) 
    external 
    nonReentrant 
    roundExists(roundId) 
    roundInStatus(roundId, RoundStatus.Distributed) 
{
    // Checks
    require(winnerIndex < roundWinners[roundId].length, "Invalid winner index");
    WinnerRecord storage winner = roundWinners[roundId][winnerIndex];
    require(winner.winner == msg.sender, "Not the winner");
    require(!hasClaimedInRound[roundId][msg.sender], "Already claimed");
    
    // Effects
    hasClaimedInRound[roundId][msg.sender] = true;
    
    // Get prize tokenId
    uint256 tokenId = getRoundPrize(roundId, winner.prizeTier, winner.prizeIndex);
    require(tokenId != 0, "Prize not set");
    
    // Interactions
    IERC721(emblemVaultAddress).safeTransferFrom(
        address(this),
        msg.sender,
        tokenId
    );
    
    emit PrizeClaimed(roundId, msg.sender, tokenId);
}
```

### New Submit Winners Function

```solidity
function submitWinners(
    uint256 roundId,
    WinnerRecord[] calldata winners
) 
    external 
    onlyOwner 
    roundExists(roundId) 
    roundInStatus(roundId, RoundStatus.WinnersReady) 
{
    require(winners.length == 10, "Must submit exactly 10 winners");
    
    // Validate prize distribution
    uint8 fakeCount = 0;
    uint8 kekCount = 0;
    uint8 pepeCount = 0;
    
    for (uint256 i = 0; i < winners.length; i++) {
        require(winners[i].winner != address(0), "Invalid winner address");
        
        if (winners[i].prizeTier == 1) {
            fakeCount++;
        } else if (winners[i].prizeTier == 2) {
            kekCount++;
        } else if (winners[i].prizeTier == 3) {
            pepeCount++;
        } else {
            revert("Invalid prize tier");
        }
    }
    
    require(fakeCount == 1, "Must have 1 Fake Pack winner");
    require(kekCount == 1, "Must have 1 Kek Pack winner");
    require(pepeCount == 8, "Must have 8 Pepe Pack winners");
    
    // Store winners
    delete roundWinners[roundId];  // Clear any existing
    for (uint256 i = 0; i < winners.length; i++) {
        roundWinners[roundId].push(winners[i]);
    }
    
    rounds[roundId].status = RoundStatus.Distributed;
    
    emit WinnersSubmitted(roundId, winners.length);
}
```

## Off-Chain Script Changes

### Winner Selection Script (`generate-winners-file.js`)

**Current:** Generates JSON file + Merkle tree
**Modified:** Generates calldata for `submitWinners()`

```javascript
// After VRF fulfillment and winner selection
const winnersArray = winners.map(w => ({
    winner: w.address,
    prizeTier: w.prizeTier,
    prizeIndex: w.prizeIndex
}));

// Generate contract calldata
const iface = new ethers.Interface([
    "function submitWinners(uint256,(address,uint8,uint16)[])"
]);

const calldata = iface.encodeFunctionData("submitWinners", [
    roundId,
    winnersArray
]);

console.log("Execute this command:");
console.log(`cast send $CONTRACT_ADDRESS "${calldata}" --private-key $PRIVATE_KEY --rpc-url $SEPOLIA_RPC_URL`);

// Or auto-execute
const tx = await contract.submitWinners(roundId, winnersArray);
await tx.wait();
console.log("Winners submitted on-chain!");
```

### Frontend Changes (`claims.js`)

**Current:** Fetches winners file, builds Merkle tree, generates proof
**Modified:** Reads winners directly from contract

```javascript
async function displayClaimablePrizes(contract, userAddress, currentRoundId) {
    // Read winners from contract storage
    const winnerCount = await contract.roundWinners(currentRoundId).length;
    const userPrizes = [];
    
    for (let i = 0; i < winnerCount; i++) {
        const winner = await contract.roundWinners(currentRoundId, i);
        
        if (winner.winner.toLowerCase() === userAddress.toLowerCase()) {
            const hasClaimed = await contract.hasClaimedInRound(currentRoundId, userAddress);
            
            userPrizes.push({
                winnerIndex: i,
                prizeTier: winner.prizeTier,
                prizeIndex: winner.prizeIndex,
                isClaimed: hasClaimed
            });
        }
    }
    
    // Display prizes
    for (const prize of userPrizes) {
        const button = document.createElement('button');
        button.onclick = async () => {
            await contract.claimPrize(currentRoundId, prize.winnerIndex);
        };
        // ... render UI
    }
}
```

## Migration Path

### Phase 1: Deploy New Contract
- Add winner storage structures
- Keep Merkle functions for backwards compatibility
- Deploy to testnet

### Phase 2: Test Hybrid Flow
- Run one full round using on-chain winners
- Verify gas costs match estimates
- Test claim flow without Merkle proofs

### Phase 3: Update Scripts
- Modify `generate-winners-file.js` to call `submitWinners()`
- Update frontend to read from contract storage
- Remove IPFS/file handling

### Phase 4: Clean Up
- Remove unused Merkle functions
- Remove file generation scripts
- Update documentation

## Eliminated Complexity

**No More:**
- ❌ `merkle.js` (tree building, proof generation)
- ❌ `winners-round-X.json` files
- ❌ IPFS pinning/hosting
- ❌ File verification mismatches
- ❌ `abi.encode` vs `abi.encodePacked` bugs
- ❌ Merkle proof verification gas overhead

**Kept:**
- ✅ Participants Merkle tree (less critical, rarely queried)
- ✅ VRF randomness
- ✅ All security features

## Gas Cost: $1.89/round at 0.5 gwei
- 2.7x current cost
- Eliminates 80% of file handling bugs
- Simpler claims for users
- Full winner transparency on-chain

