# Data Model: PEPEDAWN Betting Site with VRF, Merkle Verification, and Claims System

**Feature**: 002-merkle-uhoh  
**Date**: October 8, 2025  
**Status**: Complete

## Overview

This document defines the complete data model for the PEPEDAWN betting platform, including on-chain entities (smart contract storage), off-chain entities (IPFS files), state transitions, and validation rules.

## 1. On-Chain Entities (Smart Contract Storage)

###

 1.1 Round

**Description**: Core entity representing a single 2-week raffle round with full lifecycle management.

**Storage Structure**:
```solidity
struct Round {
    // Identity & timing (packed)
    uint128 roundId;                  // Unique round identifier
    uint128 startTime;                // Round start timestamp
    uint128 endTime;                  // Round end timestamp (immutable once set)
    RoundState state;                 // Current lifecycle state (uint8)
    
    // Participation tracking
    uint256 totalWagered;             // Total ETH wagered this round
    uint256 totalTickets;             // Total tickets purchased
    uint128 totalWeight;              // Total effective weight (with bonuses)
    uint16 participantCount;          // Number of unique participants
    
    // Merkle roots & IPFS references
    bytes32 participantsRoot;         // Merkle root of participants tree
    bytes32 winnersRoot;              // Merkle root of winners tree
    
    // VRF integration
    uint256 vrfRequestId;             // Chainlink VRF request ID
    uint256 vrfSeed;                  // Random seed from VRF (immutable once set)
    uint64 vrfRequestTimestamp;       // When VRF was requested
    
    // Refund tracking
    bool meetsMinimumThreshold;       // True if ≥10 tickets
    uint256 refundPool;               // Total amount to refund if threshold not met
}

enum RoundState {
    Open,                  // 0: Betting active
    Snapshotted,          // 1: Betting closed, inputs locked
    VRFRequested,         // 2: Waiting for Chainlink VRF
    VRFFulfilled,         // 3: Randomness received
    WinnersCommitted,     // 4: Winners determined, claims available
    Closed                // 5: Round finalized
}

// Storage mappings
mapping(uint256 => Round) public rounds;
mapping(uint256 => string) public participantsCIDs;  // roundId => IPFS CID
mapping(uint256 => string) public winnersCIDs;       // roundId => IPFS CID
```

**State Transitions**:
```
Open (0)
  ↓ [Owner: snapshotRound() - freezes betting, generates Participants File]
Snapshotted (1)
  ↓ [Owner: requestRandomness() - triggers Chainlink VRF]
VRFRequested (2)
  ↓ [VRF Coordinator: fulfillRandomWords() - provides random seed]
VRFFulfilled (3)
  ↓ [Owner: commitWinners() - uploads Winners File, commits root]
WinnersCommitted (4)
  ↓ [Owner: closeRound() - finalizes round]
Closed (5)
```

**Validation Rules**:
- State transitions MUST be sequential (cannot skip states)
- `startTime` < `endTime` (immutable once set)
- `participantsRoot` MUST be set before transitioning to VRFRequested
- `winnersRoot` MUST be set before transitioning to WinnersCommitted
- `vrfSeed` is immutable once set (cannot be changed)
- `meetsMinimumThreshold` = true if totalTickets ≥ 10
- Round cannot transition to VRFRequested if `!meetsMinimumThreshold`

**Invariants**:
- `totalWeight` ≥ `totalTickets` (weights can increase with proofs, not decrease)
- `participantCount` ≤ totalTickets (one wallet can buy multiple tickets)
- `refundPool` = `totalWagered` if `!meetsMinimumThreshold` at close
- `vrfRequestTimestamp` > 0 only if state ≥ VRFRequested

### 1.2 Participant (Per-Round)

**Description**: Tracks individual participant data within a specific round.

**Storage Structure**:
```solidity
struct Participant {
    address wallet;               // Participant's Ethereum address
    uint256 totalWagered;         // Total ETH wagered by this wallet this round
    uint128 tickets;              // Number of tickets purchased
    uint128 baseWeight;           // Base weight from tickets
    uint128 proofBonus;           // Additional weight from puzzle proof
    uint128 effectiveWeight;      // Total weight (baseWeight + proofBonus)
    bool hasProof;                // True if valid proof submitted
    bool denylisted;              // True if wallet is denylisted
}

// Storage mappings
mapping(uint256 => mapping(address => Participant)) public participants;  // roundId => wallet => data
mapping(uint256 => address[]) public participantList;                     // roundId => list of addresses
```

**Weight Calculation**:
```
baseWeight = tickets (1 ticket = 1 base weight)
proofBonus = hasProof ? (baseWeight * 0.4) : 0
effectiveWeight = baseWeight + proofBonus
```

**Example**:
- User buys 10 tickets: baseWeight = 10
- User submits valid proof: proofBonus = 10 × 0.4 = 4
- effectiveWeight = 10 + 4 = 14 (40% increase)

**Validation Rules**:
- `totalWagered` ≤ 1.0 ETH per wallet per round (FR-023)
- `tickets` ∈ {1, 5, 10} per transaction (tiered pricing)
- `hasProof` can only transition false → true (one attempt only)
- `denylisted` wallets cannot wager or submit proofs
- `effectiveWeight` = baseWeight + proofBonus (always)

### 1.3 Claim Record

**Description**: Tracks which prizes have been claimed and by whom.

**Storage Structure**:
```solidity
// Mapping: roundId => prizeIndex => claimer address
mapping(uint256 => mapping(uint8 => address)) public claims;

// Mapping: roundId => address => claim count (how many prizes claimed)
mapping(uint256 => mapping(address => uint8)) public claimCounts;

// Prize NFT mapping: roundId => prizeIndex => Emblem Vault token ID
mapping(uint256 => mapping(uint8 => uint256)) public prizeNFTs;
```

**Claim Lifecycle**:
```
Initial State:
  claims[roundId][prizeIndex] = address(0)  (unclaimed)

User Claims:
  claims[roundId][prizeIndex] = msg.sender
  claimCounts[roundId][msg.sender]++
  Transfer NFT: prizeNFTs[roundId][prizeIndex] → msg.sender

Verification:
  isClaimed = (claims[roundId][prizeIndex] != address(0))
  canClaim = (!isClaimed && merkleProof.verify(...))
```

**Validation Rules**:
- Each `prizeIndex` (0-9) can be claimed exactly once per round
- A wallet can claim multiple prizes up to its ticket count
- Claims require valid Merkle proof against `winnersRoot`
- Claims only allowed in `WinnersCommitted` or `Closed` states
- `prizeNFTs[roundId][prizeIndex]` MUST be owned by contract before claim
- `claimCounts[roundId][wallet]` ≤ `participants[roundId][wallet].tickets`

### 1.4 Refund Balance

**Description**: Tracks accumulated refunds per wallet (pull-payment pattern).

**Storage Structure**:
```solidity
// Mapping: address => refund balance
mapping(address => uint256) public refunds;
```

**Refund Accrual**:
```solidity
// When round closes with <10 tickets:
for each participant in round:
    refunds[participant.wallet] += participant.totalWagered
```

**Withdrawal**:
```solidity
function withdrawRefund() external nonReentrant {
    uint256 amount = refunds[msg.sender];
    require(amount > 0, "No refund available");
    
    refunds[msg.sender] = 0; // Zero before transfer (checks-effects-interactions)
    
    (bool success, ) = msg.sender.call{value: amount}("");
    require(success, "Transfer failed");
    
    emit RefundWithdrawn(msg.sender, amount);
}
```

**Validation Rules**:
- Withdrawal requires `refunds[wallet] > 0`
- Balance set to 0 before ETH transfer (reentrancy protection)
- ReentrancyGuard applied to withdrawal function
- Refunds never expire (claimable indefinitely)

### 1.5 Puzzle Proof

**Description**: Tracks puzzle proof submissions per round.

**Storage Structure**:
```solidity
struct ProofSubmission {
    bytes32 submittedHash;        // Hash submitted by user
    bool attempted;               // True if submission made (success or fail)
    bool verified;                // True if hash matched validProofHash
    uint256 timestamp;            // When proof was submitted
}

// Storage mappings
mapping(uint256 => bytes32) public validProofHashes;  // roundId => valid proof hash (set by owner)
mapping(uint256 => mapping(address => ProofSubmission)) public proofSubmissions;  // roundId => wallet => submission
```

**Proof Lifecycle**:
```
Owner Setup:
  validProofHashes[roundId] = keccak256(abi.encode(solution))

User Submission:
  proofSubmissions[roundId][msg.sender] = {
      submittedHash: userHash,
      attempted: true,
      verified: (userHash == validProofHashes[roundId]),
      timestamp: block.timestamp
  }

If verified:
  participants[roundId][msg.sender].hasProof = true
  participants[roundId][msg.sender].proofBonus = baseWeight * 0.4
  participants[roundId][msg.sender].effectiveWeight = baseWeight + proofBonus
```

**Validation Rules**:
- Only one submission attempt per wallet per round (success or fail)
- User must have wagered before submitting proof
- Proof submission only allowed while round is `Open`
- `validProofHashes[roundId]` must be set before round opens
- Weight bonus (40%) only applied if `verified == true`

### 1.6 Configuration

**Description**: Global contract configuration and governance.

**Storage Structure**:
```solidity
struct VRFConfig {
    IVRFCoordinatorV2Plus coordinator;  // Chainlink VRF coordinator
    uint64 subscriptionId;              // Subscription ID (owner-managed)
    bytes32 keyHash;                    // VRF key hash (gas lane)
    uint32 callbackGasLimit;            // Gas limit for VRF callback
    uint16 requestConfirmations;        // Block confirmations required
}

struct FeeConfig {
    address creatorsAddress;            // Address to receive 80% of fees
    uint16 creatorsBasisPoints;         // 8000 = 80%
    uint16 poolBasisPoints;             // 2000 = 20% stays in contract
}

struct PricingConfig {
    uint256 singleTicketPrice;          // 0.005 ETH
    uint256 fiveTicketPrice;            // 0.0225 ETH (10% discount)
    uint256 tenTicketPrice;             // 0.04 ETH (20% discount)
    uint256 maxWagerPerWallet;          // 1.0 ETH per round
}

// Storage
VRFConfig public vrfConfig;
FeeConfig public feeConfig;
PricingConfig public pricingConfig;
IERC721 public emblemVault;             // Emblem Vault NFT contract
mapping(address => bool) public denylisted;  // Denylisted wallets
bool public paused;                          // Emergency pause
bool public emergencyPaused;                 // Circuit breaker
```

**Configuration Management**:
- VRF config set at deployment, updatable by owner
- Fee config updatable by owner with event emission
- Pricing config updatable by owner with event emission
- Denylist managed by owner (add/remove addresses)
- Pause controls: `paused` (standard), `emergencyPaused` (circuit breaker)

## 2. Off-Chain Entities (IPFS Files)

### 2.1 Participants File

**Description**: JSON file containing complete participant snapshot at round close.

**File Format** (`participants.json`):
```json
{
  "version": "1.0",
  "roundId": 12,
  "snapshotBlock": 18234567,
  "snapshotTimestamp": 1696800000,
  "totalWeight": "123456",
  "totalTickets": 247,
  "participantCount": 89,
  "participants": [
    {
      "address": "0x1234567890123456789012345678901234567890",
      "weight": "14000",
      "tickets": 10,
      "hasProof": true,
      "baseWeight": "10000",
      "proofBonus": "4000",
      "totalWagered": "0.04"
    },
    {
      "address": "0xabcdefabcdefabcdefabcdefabcdefabcdefabcd",
      "weight": "500",
      "tickets": 1,
      "hasProof": false,
      "baseWeight": "500",
      "proofBonus": "0",
      "totalWagered": "0.005"
    }
  ],
  "merkle": {
    "root": "0x1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef",
    "leafFormat": "keccak256(abi.encode(address, uint128 weight))",
    "treeDepth": 7,
    "leafCount": 89
  }
}
```

**Merkle Tree Construction**:
```javascript
const leaves = participants.map(p => 
    ethers.keccak256(ethers.AbiCoder.defaultAbiCoder().encode(
        ['address', 'uint128'],
        [p.address, BigInt(p.weight)]
    ))
);
const tree = new MerkleTree(leaves, ethers.keccak256, { sortPairs: true });
const root = tree.getHexRoot();
```

**Validation**:
- `version` MUST be "1.0"
- `roundId` MUST match on-chain round
- `snapshotBlock` MUST be valid block number
- `totalWeight` MUST equal sum of all participants' weights
- `totalTickets` MUST equal sum of all participants' tickets
- `participantCount` MUST equal length of `participants` array
- `merkle.root` MUST match on-chain `participantsRoot`
- All addresses MUST be valid checksummed Ethereum addresses

### 2.2 Winners File

**Description**: JSON file containing deterministic winner selection results.

**File Format** (`winners.json`):
```json
{
  "version": "1.0",
  "roundId": 12,
  "vrfSeed": "0xabcdef1234567890abcdef1234567890abcdef1234567890abcdef1234567890",
  "vrfRequestId": "0x9876543210fedcba9876543210fedcba9876543210fedcba9876543210fedcba",
  "vrfBlock": 18235000,
  "vrfTimestamp": 1696801000,
  "derivationMethod": "Deterministic expansion: keccak256(vrfSeed, prizeIndex) % totalWeight → cumulative weight selection",
  "totalWeight": "123456",
  "prizeSlots": 10,
  "winners": [
    {
      "prizeIndex": 0,
      "prizeTier": 3,
      "prizeName": "Fake Pack (3 PEPEDAWN cards)",
      "emblemVaultTokenId": "42001",
      "address": "0x1234567890123456789012345678901234567890",
      "tickets": 10,
      "weight": "14000",
      "selectionRandom": "0xdef123abc456...",
      "selectedWeight": "78543",
      "cumulativeRange": "0-14000"
    },
    {
      "prizeIndex": 1,
      "prizeTier": 2,
      "prizeName": "Kek Pack (2 PEPEDAWN cards)",
      "emblemVaultTokenId": "42002",
      "address": "0xabcdefabcdefabcdefabcdefabcdefabcdefabcd",
      "tickets": 1,
      "weight": "500",
      "selectionRandom": "0x456abc789def...",
      "selectedWeight": "14250",
      "cumulativeRange": "14000-14500"
    }
  ],
  "merkle": {
    "root": "0xfedcba0987654321fedcba0987654321fedcba0987654321fedcba0987654321",
    "leafFormat": "keccak256(abi.encode(address, uint8 prizeTier, uint8 prizeIndex))",
    "treeDepth": 4,
    "leafCount": 10
  }
}
```

**Winner Selection Algorithm** (Deterministic):
```javascript
// For each prize slot 0-9:
function selectWinner(prizeIndex, vrfSeed, participants, totalWeight) {
    // Generate random number for this prize slot
    const random = ethers.keccak256(
        ethers.AbiCoder.defaultAbiCoder().encode(
            ['uint256', 'uint8'],
            [vrfSeed, prizeIndex]
        )
    );
    
    // Select weight in range [0, totalWeight)
    const selectedWeight = BigInt(random) % BigInt(totalWeight);
    
    // Find participant owning this weight in cumulative distribution
    let cumulativeWeight = 0n;
    for (const participant of participants) {
        cumulativeWeight += BigInt(participant.weight);
        if (selectedWeight < cumulativeWeight) {
            return {
                address: participant.address,
                prizeTier: getPrizeTier(prizeIndex),  // 3 for index 0, 2 for index 1, 1 for 2-9
                prizeIndex: prizeIndex,
                selectionRandom: random,
                selectedWeight: selectedWeight.toString(),
                cumulativeRange: `${cumulativeWeight - BigInt(participant.weight)}-${cumulativeWeight}`
            };
        }
    }
}
```

**Prize Tier Assignment**:
```javascript
function getPrizeTier(prizeIndex) {
    if (prizeIndex === 0) return 3; // Fake Pack
    if (prizeIndex === 1) return 2; // Kek Pack
    return 1; // Pepe Pack (indices 2-9)
}
```

**Merkle Tree Construction**:
```javascript
const leaves = winners.map(w => 
    ethers.keccak256(ethers.AbiCoder.defaultAbiCoder().encode(
        ['address', 'uint8', 'uint8'],
        [w.address, w.prizeTier, w.prizeIndex]
    ))
);
const tree = new MerkleTree(leaves, ethers.keccak256, { sortPairs: true });
const root = tree.getHexRoot();
```

**Validation**:
- `version` MUST be "1.0"
- `roundId` MUST match on-chain round
- `vrfSeed` MUST match on-chain `vrfSeed`
- `prizeSlots` MUST be 10
- `winners` array MUST have exactly 10 entries
- Prize indices 0-9 MUST each appear exactly once
- `merkle.root` MUST match on-chain `winnersRoot`
- Winner selection MUST be reproducible from `vrfSeed` and Participants File

## 3. State Machine

### 3.1 Round Lifecycle

**Complete State Diagram**:
```
┌──────────────────────────────────────────────────────────────────┐
│ ROUND LIFECYCLE (Manual Owner Operations)                       │
└──────────────────────────────────────────────────────────────────┘

[1] Open
     • Users bet (placeBet)
     • Users submit proofs (submitProof)
     • Owner can pause/unpause
     │
     ▼ Owner: snapshotRound(roundId)
     │  ├─ Transition state to Snapshotted
     │  ├─ Generate Participants File off-chain
     │  ├─ Upload to IPFS
     │  └─ Call commitParticipantsRoot(roundId, root, cid)
     │
[2] Snapshotted
     • Betting closed (no more wagers or proofs)
     • Participants data frozen
     • Participants File available on IPFS
     │
     ▼ Owner: requestRandomness(roundId)
     │  ├─ Require totalTickets ≥ 10
     │  └─ Call Chainlink VRF coordinator
     │
[3] VRFRequested
     • Waiting for Chainlink VRF callback
     • Timeout: 1 hour (can retry after)
     │
     ▼ VRF Coordinator: fulfillRandomWords(requestId, randomWords)
     │  ├─ Automatic callback from Chainlink
     │  ├─ Set vrfSeed
     │  └─ Transition state to VRFFulfilled
     │
[4] VRFFulfilled
     • Random seed available
     • Deterministic winner selection can be performed off-chain
     │
     ▼ Owner: commitWinners(roundId, winnersRoot, cid)
     │  ├─ Generate Winners File off-chain (using vrfSeed)
     │  ├─ Upload to IPFS
     │  ├─ Commit winnersRoot on-chain
     │  └─ Transition state to WinnersCommitted
     │
[5] WinnersCommitted
     • Winners finalized
     • Claims available (users call claim with Merkle proofs)
     • Winners File available on IPFS
     │
     ▼ Owner: closeRound(roundId)
     │  ├─ Distribute fees (80% creators, 20% pool)
     │  ├─ Process refunds if totalTickets < 10
     │  └─ Transition state to Closed
     │
[6] Closed
     • Round finalized
     • Historical data available
     • Unclaimed prizes remain claimable
     • Refunds remain withdrawable

────────────────────────────────────────────────────────────────────

REFUND PATH (if totalTickets < 10):
[1] Open → [2] Snapshotted → Skip VRF → Owner: closeRound(roundId)
    • All participants added to refundPool
    • Users can withdrawRefund() anytime
    • No VRF request, no winners, no claims
```

### 3.2 Participant Lifecycle (Per Round)

```
┌─────────────────────────────────────────────────────────────┐
│ PARTICIPANT LIFECYCLE (Single Wallet, Single Round)         │
└─────────────────────────────────────────────────────────────┘

[1] Non-Participant
     │
     ▼ User: placeBet(tickets) [Round: Open]
     │  ├─ Validate: not denylisted
     │  ├─ Validate: totalWagered + msg.value ≤ 1.0 ETH
     │  ├─ Validate: payment matches ticket price
     │  ├─ Create/update Participant record
     │  ├─ Calculate baseWeight = tickets
     │  └─ Emit event: BetPlaced
     │
[2] Active Participant (No Proof)
     │
     ▼ User: submitProof(proofHash) [Round: Open] (Optional)
     │  ├─ Validate: has wagered
     │  ├─ Validate: not already attempted
     │  ├─ Compare: proofHash == validProofHashes[roundId]
     │  ├─ If match:
     │  │   ├─ Set hasProof = true
     │  │   ├─ Calculate proofBonus = baseWeight * 0.4
     │  │   ├─ Update effectiveWeight = baseWeight + proofBonus
     │  │   └─ Emit event: ProofVerified
     │  └─ If no match:
     │      ├─ Mark attempted
     │      └─ Emit event: ProofFailed
     │
[3] Active Participant (With Proof)
     │
     ▼ Owner: snapshotRound() [Round: Open → Snapshotted]
     │  ├─ Participant data frozen
     │  ├─ Included in Participants File
     │  └─ Added to Merkle tree
     │
[4] Snapshotted Participant
     │
     ▼ IF totalTickets ≥ 10:
     │  │
     │  ▼ VRF → Winners Selection [Round: VRFFulfilled]
     │  │  ├─ Weighted random selection
     │  │  └─ Participant may be selected 0+ times (up to ticket count)
     │  │
     │  ▼ IF Selected as Winner:
     │     │
     │     ▼ Owner: commitWinners() [Round: WinnersCommitted]
     │     │  ├─ Wallet added to Winners File
     │     │  └─ Eligible to claim prize(s)
     │     │
     │     ▼ User: claim(roundId, prizeIndex, prizeTier, proof)
     │        ├─ Validate: Merkle proof against winnersRoot
     │        ├─ Validate: not already claimed (this prizeIndex)
     │        ├─ Validate: claimCount < tickets
     │        ├─ Transfer NFT: prizeNFTs[roundId][prizeIndex] → user
     │        └─ Emit event: PrizeClaimed
     │
     ▼ IF totalTickets < 10:
        │
        ▼ Owner: closeRound() [Round: Closed]
           ├─ Participant added to refundPool
           │
           ▼ User: withdrawRefund()
              ├─ Withdraw full wager amount
              └─ Emit event: RefundWithdrawn
```

### 3.3 Claim Lifecycle (Per Prize Slot)

```
┌─────────────────────────────────────────────────────────────┐
│ PRIZE CLAIM LIFECYCLE (Single Prize Slot, Single Round)     │
└─────────────────────────────────────────────────────────────┘

[1] Unclaimed (Initial State)
     • claims[roundId][prizeIndex] = address(0)
     • NFT held by contract
     │
     ▼ Winner: claim(roundId, prizeIndex, prizeTier, proof)
     │  ├─ VALIDATE Round State:
     │  │   └─ Require: state == WinnersCommitted || state == Closed
     │  ├─ VALIDATE Claim Status:
     │  │   └─ Require: claims[roundId][prizeIndex] == address(0)
     │  ├─ VALIDATE Merkle Proof:
     │  │   ├─ Generate leaf: keccak256(abi.encode(msg.sender, prizeTier, prizeIndex))
     │  │   └─ Verify: MerkleProof.verify(proof, winnersRoot, leaf)
     │  ├─ VALIDATE Claim Count:
     │  │   └─ Require: claimCounts[roundId][msg.sender] < tickets
     │  ├─ VALIDATE NFT Ownership:
     │  │   └─ Require: emblemVault.ownerOf(tokenId) == address(this)
     │  ├─ UPDATE State:
     │  │   ├─ claims[roundId][prizeIndex] = msg.sender
     │  │   └─ claimCounts[roundId][msg.sender]++
     │  ├─ TRANSFER NFT:
     │  │   └─ emblemVault.safeTransferFrom(address(this), msg.sender, tokenId)
     │  └─ EMIT Event:
     │      └─ PrizeClaimed(roundId, msg.sender, prizeIndex, prizeTier, tokenId)
     │
[2] Claimed (Final State)
     • claims[roundId][prizeIndex] = winner address (non-zero)
     • NFT transferred to winner
     • Cannot be claimed again
     • Permanent on-chain record
```

## 4. Access Control Matrix

| Function | User | Owner | VRF Coordinator | Round State | Notes |
|----------|------|-------|-----------------|-------------|-------|
| **placeBet** | ✓ | ✓ | ✗ | Open | User must not be denylisted |
| **submitProof** | ✓ | ✓ | ✗ | Open | User must have wagered |
| **claim** | ✓ | ✓ | ✗ | WinnersCommitted, Closed | Requires valid Merkle proof |
| **withdrawRefund** | ✓ | ✓ | ✗ | Any | Requires refunds[msg.sender] > 0 |
| **createRound** | ✗ | ✓ | ✗ | N/A | Owner only |
| **snapshotRound** | ✗ | ✓ | ✗ | Open | Owner only |
| **commitParticipantsRoot** | ✗ | ✓ | ✗ | Snapshotted | Owner only |
| **requestRandomness** | ✗ | ✓ | ✗ | Snapshotted | Owner only, requires ≥10 tickets |
| **fulfillRandomWords** | ✗ | ✗ | ✓ | VRFRequested | VRF Coordinator only |
| **commitWinners** | ✗ | ✓ | ✗ | VRFFulfilled | Owner only |
| **closeRound** | ✗ | ✓ | ✗ | WinnersCommitted | Owner only |
| **setPrizesForRound** | ✗ | ✓ | ✗ | Any | Owner only, before round opens |
| **setValidProofHash** | ✗ | ✓ | ✗ | Any | Owner only, before round opens |
| **setDenylistStatus** | ✗ | ✓ | ✗ | Any | Owner only |
| **pause/unpause** | ✗ | ✓ | ✗ | Any | Owner only |
| **setEmergencyPause** | ✗ | ✓ | ✗ | Any | Owner only |

## 5. Data Integrity Constraints

### 5.1 Merkle Verification

**Participants Verification** (Client-Side):
```javascript
async function verifyParticipantsFile(file, onChainRoot) {
    // 1. Reconstruct Merkle tree from file
    const leaves = file.participants.map(p => 
        ethers.keccak256(ethers.AbiCoder.defaultAbiCoder().encode(
            ['address', 'uint128'],
            [p.address, BigInt(p.weight)]
        ))
    );
    const tree = new MerkleTree(leaves, ethers.keccak256, { sortPairs: true });
    const computedRoot = tree.getHexRoot();
    
    // 2. Compare with on-chain root
    if (computedRoot !== onChainRoot) {
        throw new Error('Participants File verification failed: root mismatch');
    }
    
    // 3. Validate file metadata
    if (BigInt(file.totalWeight) !== leaves.reduce((sum, _, i) => sum + BigInt(file.participants[i].weight), 0n)) {
        throw new Error('Participants File verification failed: totalWeight mismatch');
    }
    
    return true;  // Verified ✓
}
```

**Winners Verification** (Client-Side):
```javascript
async function verifyWinnersFile(file, onChainRoot, onChainSeed, participantsFile) {
    // 1. Reconstruct Merkle tree from file
    const leaves = file.winners.map(w => 
        ethers.keccak256(ethers.AbiCoder.defaultAbiCoder().encode(
            ['address', 'uint8', 'uint8'],
            [w.address, w.prizeTier, w.prizeIndex]
        ))
    );
    const tree = new MerkleTree(leaves, ethers.keccak256, { sortPairs: true });
    const computedRoot = tree.getHexRoot();
    
    // 2. Compare with on-chain root
    if (computedRoot !== onChainRoot) {
        throw new Error('Winners File verification failed: root mismatch');
    }
    
    // 3. Verify VRF seed matches
    if (file.vrfSeed !== onChainSeed) {
        throw new Error('Winners File verification failed: VRF seed mismatch');
    }
    
    // 4. Reproduce winner selection (deterministic check)
    for (const winner of file.winners) {
        const reproduced = selectWinner(winner.prizeIndex, file.vrfSeed, participantsFile.participants, participantsFile.totalWeight);
        if (reproduced.address !== winner.address) {
            throw new Error(`Winners File verification failed: winner mismatch at prizeIndex ${winner.prizeIndex}`);
        }
    }
    
    return true;  // Verified ✓
}
```

### 5.2 Invariants

**Round Invariants** (MUST hold at all times):
```solidity
// Weight consistency
assert(round.totalWeight >= round.totalTickets);

// Participant count
assert(round.participantCount <= round.totalTickets);

// State progression
assert(uint8(round.state) <= uint8(RoundState.Closed));

// VRF immutability
if (round.vrfSeed != 0) {
    assert(round.vrfSeed == immutableValue);  // Cannot change once set
}

// Minimum threshold logic
if (round.totalTickets < 10) {
    assert(!round.meetsMinimumThreshold);
    assert(round.state != RoundState.VRFRequested);  // Cannot request VRF
}
```

**Claim Invariants**:
```solidity
// Prize uniqueness
for each roundId, prizeIndex:
    assert(claims[roundId][prizeIndex] != address(0) => claimed exactly once);

// Claim count bounds
for each roundId, wallet:
    assert(claimCounts[roundId][wallet] <= participants[roundId][wallet].tickets);

// NFT ownership
if (claims[roundId][prizeIndex] == address(0)):
    assert(emblemVault.ownerOf(prizeNFTs[roundId][prizeIndex]) == address(this));
else:
    assert(emblemVault.ownerOf(prizeNFTs[roundId][prizeIndex]) == claims[roundId][prizeIndex]);
```

**Refund Invariants**:
```solidity
// Refund pool accuracy
if (!round.meetsMinimumThreshold) {
    assert(round.refundPool == round.totalWagered);
}

// Refund distribution
sum(refunds[all wallets]) <= round.refundPool;
```

## 6. Data Migration & Versioning

### 6.1 IPFS File Versioning

**Current Version**: 1.0

**Version Field**: All IPFS files include `"version": "1.0"` for future compatibility

**Forward Compatibility**:
- Client MUST check `version` field before parsing
- Client MUST reject unknown versions
- New versions require client update to support

**Backward Compatibility**:
- Version 1.0 is baseline (no previous versions)
- Future versions MAY add fields (additive changes)
- Future versions MUST NOT remove fields (breaking changes require major version bump)

### 6.2 Contract Storage

**Immutable Data**:
- Round ID, start/end times (once set)
- VRF seed (once fulfilled)
- Merkle roots (once committed)
- Claim records (once claimed)

**Mutable Data**:
- Round state (sequential progression only)
- Configuration (owner-controlled)
- Denylist (owner-controlled)
- Pause states (owner-controlled)

**No Upgrades**:
- Contract is NOT upgradeable (no proxy pattern)
- Data is permanent on-chain
- Historical data preserved indefinitely

## Summary

This data model defines:
- **6 Round States** with clear transitions
- **10 Prize Slots** per round with deterministic tier assignment
- **2 Merkle Trees** (participants, winners) for efficient verification
- **Pull-Payment Pattern** for claims and refunds (security best practice)
- **Manual Owner Operations** for all state transitions
- **Indefinite Data Retention** with efficient on-chain storage
- **Client-Side Verification** of all IPFS files against on-chain roots

All entities, relationships, and state transitions are fully specified for implementation.

---

**Status**: DATA MODEL COMPLETE
**Next Phase**: Quickstart Guide
