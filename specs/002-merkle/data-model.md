# Data Model: User-Facing Behavior Updates (VRF Seed + Merkle + Claims)

**Feature**: 002-merkle  
**Date**: October 8, 2025  
**Status**: Complete

## Overview

This document defines the data entities, relationships, and state transitions for the Merkle proof-based claims system.

## On-Chain Entities (Smart Contract)

### 1. Round

**Description**: Represents a single raffle round with Merkle roots for participants and winners.

**Storage**:
```solidity
struct Round {
    uint256 roundId;
    RoundState state;
    uint256 startTime;
    uint256 endTime;
    bytes32 participantsRoot;  // NEW: Merkle root of participants
    bytes32 winnersRoot;       // NEW: Merkle root of winners
    uint256 vrfRequestId;
    uint256 vrfSeed;           // ENHANCED: Exposed for UI display
    uint256 totalPrizeSlots;   // Fixed at 10
}

enum RoundState {
    Open,
    Snapshotted,
    VRFRequested,
    VRFFulfilled,
    WinnersCommitted,
    Closed
}
```

**State Transitions**:
```
Open → Snapshotted (when betting closes)
  ↓
VRFRequested (when VRF requested)
  ↓
VRFFulfilled (when VRF fulfilled)
  ↓
WinnersCommitted (when winners Merkle root committed)
  ↓
Closed (when round finalized)
```

**Validation Rules**:
- `participantsRoot` MUST be set before VRF request
- `winnersRoot` MUST be set after VRF fulfillment
- `vrfSeed` MUST be immutable once set
- State transitions MUST be sequential (no skipping)

### 2. Claim Record

**Description**: Tracks claim status for each prize slot per round.

**Storage**:
```solidity
// Mapping: roundId => prizeIndex => claimer address
mapping(uint256 => mapping(uint8 => address)) public claims;

// Mapping: roundId => address => claimed count
mapping(uint256 => mapping(address => uint8)) public claimCounts;
```

**Validation Rules**:
- Each `prizeIndex` (0-9) can be claimed exactly once per round
- A wallet can claim multiple prizes up to its ticket count
- Claims require valid Merkle proof
- Claims only allowed in `WinnersCommitted` or `Closed` states

### 3. Refund Balance

**Description**: Tracks refund amounts per user (pull-payment pattern).

**Storage**:
```solidity
// Mapping: address => refund amount
mapping(address => uint256) public refunds;
```

**Validation Rules**:
- Refunds accumulate from failed rounds or overpayments
- Withdrawal requires balance > 0
- Withdrawal uses reentrancy guard
- Balance set to 0 after successful withdrawal

## Off-Chain Entities (IPFS Files)

### 4. Participants File

**Description**: JSON file containing all participants, weights, and Merkle tree data.

**Schema**:
```json
{
  "roundId": 12,
  "totalWeight": "123456",
  "participants": [
    {
      "address": "0xAbc...",
      "weight": "50",
      "tickets": 10
    }
  ],
  "merkle": {
    "root": "0xPARTICIPANTS_ROOT",
    "leafFormat": "keccak256(abi.encode(address, uint128 weight))",
    "leaves": [
      "0x..."
    ]
  }
}
```

**Validation Rules**:
- `merkle.root` MUST match on-chain `participantsRoot`
- `participants` array MUST be sorted by address (ascending)
- `weight` MUST be uint128 compatible
- `tickets` derived from weight and bet amount

**Relationships**:
- One file per round
- Referenced by `roundId`
- Stored on IPFS, CID emitted in `ParticipantsSnapshotted` event

### 5. Winners File

**Description**: JSON file containing all winners, prize assignments, and Merkle tree data.

**Schema**:
```json
{
  "roundId": 12,
  "vrfSeed": "0xSEED",
  "derivation": "Deterministic expansion from seed + participants",
  "winners": [
    {
      "address": "0xAbc...",
      "prizeTier": 3,
      "prizeIndex": 0
    }
  ],
  "merkle": {
    "root": "0xWINNERS_ROOT",
    "leafFormat": "keccak256(abi.encode(address, uint8 prizeTier, uint8 prizeIndex))",
    "leaves": [
      "0x..."
    ]
  }
}
```

**Validation Rules**:
- `merkle.root` MUST match on-chain `winnersRoot`
- `winners` array MUST have exactly 10 entries (one per prize slot)
- `prizeIndex` values MUST be 0-9 (unique)
- `prizeTier` values MUST be 1-3 (Gold/Silver/Bronze)
- `vrfSeed` MUST match on-chain `vrfSeed`

**Relationships**:
- One file per round
- Referenced by `roundId`
- Stored on IPFS, CID emitted in `WinnersCommitted` event

## Frontend Entities (Client State)

### 6. Round State (UI)

**Description**: Client-side representation of round data with verification status.

**Structure**:
```javascript
{
  roundId: 12,
  state: 'WinnersCommitted',
  
  participants: {
    cid: 'QmParticipants...',
    root: '0xPARTICIPANTS_ROOT',
    verified: true,
    file: { /* Participants File */ },
    verificationError: null
  },
  
  winners: {
    cid: 'QmWinners...',
    root: '0xWINNERS_ROOT',
    verified: true,
    file: { /* Winners File */ },
    verificationError: null
  },
  
  vrfSeed: '0xSEED',
  
  userAddress: '0xUser...',
  userTickets: 5,
  userWins: [
    { prizeIndex: 2, prizeTier: 3, claimed: false },
    { prizeIndex: 7, prizeTier: 2, claimed: true }
  ],
  userRefund: '1500000000000000000' // 1.5 ETH in wei
}
```

**Validation Rules**:
- `verified` set to `true` only after successful Merkle root verification
- `verificationError` populated on verification failure
- `userWins` derived from Winners File filtered by `userAddress`
- `claimed` status fetched from contract

### 7. Merkle Tree Cache

**Description**: Cached Merkle trees for proof generation.

**Structure**:
```javascript
{
  roundId: 12,
  type: 'winners', // or 'participants'
  tree: MerkleTree, // merkletreejs instance
  leaves: ['0x...'],
  root: '0xWINNERS_ROOT',
  timestamp: 1696723200000
}
```

**Storage**: IndexedDB for persistence across sessions

**Validation Rules**:
- Cache invalidated if on-chain root changes
- Maximum cache age: 24 hours
- Cache keyed by `roundId` and `type`

### 8. Transaction State

**Description**: Tracks pending transactions for claims and refunds.

**Structure**:
```javascript
{
  type: 'claim', // or 'refund'
  roundId: 12,
  prizeIndex: 2, // only for claims
  txHash: '0xTX...',
  status: 'pending', // pending | confirmed | failed
  error: null,
  timestamp: 1696723200000
}
```

**Validation Rules**:
- One pending transaction per claim/refund at a time
- Status updated from transaction receipt
- Error populated on transaction failure
- Cleared after confirmation or user dismissal

## Entity Relationships

```
Round (on-chain)
  ├── has one ParticipantsRoot (bytes32)
  │   └── references Participants File (IPFS)
  │       └── contains many Participant entries
  │
  ├── has one WinnersRoot (bytes32)
  │   └── references Winners File (IPFS)
  │       └── contains many Winner entries (exactly 10)
  │
  ├── has many Claim Records
  │   └── one per prizeIndex (0-9)
  │       └── claimed by one Address
  │
  └── has one VRF Seed
      └── used to generate Winners deterministically

User (address)
  ├── has many Claim Records (across rounds)
  ├── has one Refund Balance (cumulative)
  └── appears in many Participants Files
      └── may appear in many Winners Files
```

## State Transition Diagram

```
┌─────────────────────────────────────────────────────────────┐
│                        Round Lifecycle                       │
└─────────────────────────────────────────────────────────────┘

    Open
     │
     │ [Betting closes]
     │ → Snapshot participants
     │ → Commit participantsRoot
     ↓
  Snapshotted
     │
     │ [Request VRF]
     ↓
  VRFRequested
     │
     │ [VRF fulfilled]
     │ → Store vrfSeed
     ↓
  VRFFulfilled
     │
     │ [Generate winners]
     │ → Commit winnersRoot
     ↓
  WinnersCommitted ────┐
     │                 │ [Users claim prizes]
     │                 │ [Users withdraw refunds]
     │                 │
     │ [All prizes     │
     │  claimed or     │
     │  expired]       │
     ↓                 │
   Closed ←───────────┘
```

## Data Flow: Claim Process

```
1. User views Winners File
   ↓
2. Frontend filters winners by user address
   ↓
3. For each unclaimed prize:
   a. Generate Merkle proof from cached tree
   b. Display "Claim" button
   ↓
4. User clicks "Claim"
   ↓
5. Frontend calls contract.claim(roundId, prizeIndex, prizeTier, proof)
   ↓
6. Contract verifies proof against winnersRoot
   ↓
7. Contract checks prizeIndex not already claimed
   ↓
8. Contract records claim and transfers prize
   ↓
9. Frontend updates UI: "Claimed ✓"
```

## Data Flow: Verification Process

```
1. Contract emits event with IPFS CID and Merkle root
   ↓
2. Frontend fetches file from IPFS (60s timeout)
   ↓
3. Frontend reconstructs Merkle tree from file data
   ↓
4. Frontend compares computed root with on-chain root
   ↓
5a. Match → Display "Verified ✓" badge
5b. Mismatch → Display red warning, hide claims
```

## Data Integrity Constraints

### On-Chain Constraints
1. `participantsRoot` cannot change after VRF request
2. `winnersRoot` cannot change after commitment
3. `vrfSeed` cannot change after fulfillment
4. Each `prizeIndex` claimed exactly once per round
5. Refund balance cannot go negative

### Off-Chain Constraints
1. Participants File `merkle.root` must match on-chain `participantsRoot`
2. Winners File `merkle.root` must match on-chain `winnersRoot`
3. Winners File `vrfSeed` must match on-chain `vrfSeed`
4. Exactly 10 winners per Winners File
5. All addresses in files must be valid Ethereum addresses

### Client-Side Constraints
1. Merkle proofs generated only from verified files
2. Claims submitted only for verified winners
3. Transaction state cleared after confirmation
4. Cache invalidated on root mismatch

## Performance Considerations

### Storage Costs (On-Chain)
- `participantsRoot`: 32 bytes (1 storage slot)
- `winnersRoot`: 32 bytes (1 storage slot)
- `vrfSeed`: 32 bytes (1 storage slot)
- Claim record: 20 bytes per claim (address)
- **Total per round**: ~96 bytes + 200 bytes for 10 claims = ~300 bytes

### Computation Costs (Client-Side)
- Merkle tree construction: O(n log n) for n participants
- Proof generation: O(log n) per proof
- Root verification: O(1) comparison
- **Expected**: <500ms for 1000 participants

### Network Costs (IPFS)
- Participants File: ~10-100 KB (depends on participant count)
- Winners File: ~2-5 KB (fixed 10 winners)
- **Fetch time**: <60 seconds with timeout

## Summary

The data model introduces two new Merkle roots on-chain (`participantsRoot`, `winnersRoot`) and two IPFS files (Participants File, Winners File) for off-chain verification. The claim system uses Merkle proofs to verify eligibility without storing all winner data on-chain, reducing gas costs while maintaining verifiability. Client-side state management tracks verification status, user claims, and transaction states for optimal UX.

**Key Design Decisions**:
1. **On-chain storage**: Only Merkle roots (32 bytes each)
2. **Off-chain storage**: Full participant/winner lists on IPFS
3. **Verification**: Client-side Merkle proof generation and verification
4. **Claims**: Pull-payment pattern with Merkle proof validation
5. **Caching**: IndexedDB for Merkle tree persistence

**Next Phase**: Contract and frontend API specifications
