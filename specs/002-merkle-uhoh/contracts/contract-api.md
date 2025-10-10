# Contract API Specification: PepedawnRaffle

**Feature**: 002-merkle-uhoh  
**Date**: October 8, 2025  
**Solidity Version**: ^0.8.19

## Overview

Complete API specification for the PepedawnRaffle smart contract, including all functions, events, modifiers, and integration points.

## Contract Interfaces

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {ReentrancyGuard} from "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import {Ownable2Step} from "@openzeppelin/contracts/access/Ownable2Step.sol";
import {Pausable} from "@openzeppelin/contracts/security/Pausable.sol";
import {ERC721Holder} from "@openzeppelin/contracts/token/ERC721/utils/ERC721Holder.sol";
import {IERC721} from "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import {MerkleProof} from "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";
import {VRFConsumerBaseV2Plus} from "@chainlink/contracts/src/v0.8/vrf/dev/VRFConsumerBaseV2Plus.sol";
import {IVRFCoordinatorV2Plus} from "@chainlink/contracts/src/v0.8/vrf/dev/interfaces/IVRFCoordinatorV2Plus.sol";
```

## Enums & Structs

```solidity
enum RoundState {
    Open,                  // 0: Betting active
    Snapshotted,          // 1: Betting closed, inputs locked
    VRFRequested,         // 2: Waiting for Chainlink VRF
    VRFFulfilled,         // 3: Randomness received
    WinnersCommitted,     // 4: Winners determined, claims available
    Closed                // 5: Round finalized
}

struct Round {
    uint128 roundId;
    uint128 startTime;
    uint128 endTime;
    RoundState state;
    uint256 totalWagered;
    uint256 totalTickets;
    uint128 totalWeight;
    uint16 participantCount;
    bytes32 participantsRoot;
    bytes32 winnersRoot;
    uint256 vrfRequestId;
    uint256 vrfSeed;
    uint64 vrfRequestTimestamp;
    bool meetsMinimumThreshold;
    uint256 refundPool;
}

struct Participant {
    uint256 totalWagered;
    uint128 tickets;
    uint128 baseWeight;
    uint128 proofBonus;
    uint128 effectiveWeight;
    bool hasProof;
}

struct VRFConfig {
    IVRFCoordinatorV2Plus coordinator;
    uint64 subscriptionId;
    bytes32 keyHash;
    uint32 callbackGasLimit;
    uint16 requestConfirmations;
}
```

## State Variables

```solidity
// Round management
mapping(uint256 => Round) public rounds;
mapping(uint256 => string) public participantsCIDs;
mapping(uint256 => string) public winnersCIDs;
uint256 public currentRoundId;

// Participant tracking
mapping(uint256 => mapping(address => Participant)) public participants;
mapping(uint256 => address[]) public participantList;

// Claims
mapping(uint256 => mapping(uint8 => address)) public claims;
mapping(uint256 => mapping(address => uint8)) public claimCounts;
mapping(uint256 => mapping(uint8 => uint256)) public prizeNFTs;

// Refunds
mapping(address => uint256) public refunds;

// Puzzle proofs
mapping(uint256 => bytes32) public validProofHashes;
mapping(uint256 => mapping(address => bool)) public proofAttempted;

// Configuration
VRFConfig public vrfConfig;
IERC721 public emblemVault;
address public creatorsAddress;
uint256 public singleTicketPrice;      // 0.005 ETH
uint256 public fiveTicketPrice;        // 0.0225 ETH
uint256 public tenTicketPrice;         // 0.04 ETH
uint256 public maxWagerPerWallet;      // 1.0 ETH
mapping(address => bool) public denylisted;
```

## User Functions

### buyTickets

**Description**: Purchase tickets in an open round.

**Function Signature**:
```solidity
function buyTickets(uint256 roundId, uint8 tickets) 
    external 
    payable 
    nonReentrant 
    whenNotPaused 
    whenNotEmergencyPaused
```

**Parameters**:
- `roundId`: The round to purchase tickets in
- `tickets`: Number of tickets (1, 5, or 10)

**Requirements**:
- Round state MUST be `Open`
- `tickets` MUST be 1, 5, or 10
- `msg.value` MUST match exact ticket price
- Caller MUST NOT be denylisted
- Cumulative wager MUST NOT exceed 1.0 ETH per wallet per round

**Effects**:
- Creates or updates `Participant` record
- Increments `totalWagered`, `totalTickets`, `totalWeight`, `participantCount`
- Emits `BetPlaced` event

**Events**:
```solidity
event BetPlaced(
    uint256 indexed roundId,
    address indexed participant,
    uint256 amount,
    uint8 tickets,
    uint256 totalWagered
);
```

**Example**:
```javascript
await contract.buyTickets(1, 10, { value: ethers.parseEther("0.04") });
```

---

### submitProof

**Description**: Submit puzzle proof to increase betting weight.

**Function Signature**:
```solidity
function submitProof(uint256 roundId, bytes32 proofHash) 
    external 
    nonReentrant 
    whenNotPaused
```

**Parameters**:
- `roundId`: The round to submit proof for
- `proofHash`: keccak256 hash of the solution

**Requirements**:
- Round state MUST be `Open`
- Caller MUST have wagered in this round
- Caller MUST NOT have previously attempted proof submission
- `validProofHashes[roundId]` MUST be set

**Effects**:
- Marks proof attempted
- If verified: Increases `effectiveWeight` by 40%
- Emits `ProofSubmitted` event (success or fail)

**Events**:
```solidity
event ProofSubmitted(
    uint256 indexed roundId,
    address indexed participant,
    bool verified,
    uint128 newWeight
);
```

**Example**:
```javascript
const solution = "ANSWER";
const hash = ethers.keccak256(ethers.toUtf8Bytes(solution));
await contract.submitProof(1, hash);
```

---

### claim

**Description**: Claim a won prize using Merkle proof.

**Function Signature**:
```solidity
function claim(
    uint256 roundId,
    uint8 prizeIndex,
    uint8 prizeTier,
    bytes32[] calldata proof
) external nonReentrant
```

**Parameters**:
- `roundId`: The round to claim from
- `prizeIndex`: Prize slot (0-9)
- `prizeTier`: Expected tier (1-3)
- `proof`: Merkle proof

**Requirements**:
- Round state MUST be `WinnersCommitted` or `Closed`
- Prize MUST NOT already be claimed
- Merkle proof MUST be valid
- Caller's claim count MUST be < tickets

**Effects**:
- Marks prize as claimed
- Transfers Emblem Vault NFT to caller
- Increments caller's claim count
- Emits `PrizeClaimed` event

**Events**:
```solidity
event PrizeClaimed(
    uint256 indexed roundId,
    address indexed winner,
    uint8 prizeIndex,
    uint8 prizeTier,
    uint256 emblemVaultTokenId
);
```

**Example**:
```javascript
// Frontend generates proof from Winners File
const leaf = ethers.keccak256(
    ethers.AbiCoder.defaultAbiCoder().encode(
        ['address', 'uint8', 'uint8'],
        [userAddress, prizeTier, prizeIndex]
    )
);
const proof = winnersTree.getHexProof(leaf);
await contract.claim(1, 0, 3, proof);
```

---

### withdrawRefund

**Description**: Withdraw accumulated refunds (pull-payment).

**Function Signature**:
```solidity
function withdrawRefund() external nonReentrant
```

**Requirements**:
- `refunds[msg.sender]` MUST be > 0

**Effects**:
- Sets `refunds[msg.sender]` to 0
- Transfers ETH to caller
- Emits `RefundWithdrawn` event

**Events**:
```solidity
event RefundWithdrawn(address indexed user, uint256 amount);
```

**Example**:
```javascript
await contract.withdrawRefund();
```

---

## Owner Functions

### createRound

**Description**: Create a new round.

**Function Signature**:
```solidity
function createRound(uint256 startTime, uint256 endTime) 
    external 
    onlyOwner 
    returns (uint256 roundId)
```

**Parameters**:
- `startTime`: Round start timestamp
- `endTime`: Round end timestamp (2 weeks later)

**Requirements**:
- `endTime` > `startTime`
- Previous round (if exists) MUST be `Closed`

**Effects**:
- Creates new `Round` with state `Open`
- Increments `currentRoundId`
- Emits `RoundCreated` event

**Events**:
```solidity
event RoundCreated(
    uint256 indexed roundId,
    uint256 startTime,
    uint256 endTime
);
```

---

### snapshotRound

**Description**: Snapshot round and transition to `Snapshotted` state.

**Function Signature**:
```solidity
function snapshotRound(uint256 roundId) external onlyOwner
```

**Requirements**:
- Round state MUST be `Open`
- Current time MUST be >= `endTime`

**Effects**:
- Transitions state to `Snapshotted`
- Sets `meetsMinimumThreshold` based on ticket count
- Emits `RoundSnapshotted` event

**Events**:
```solidity
event RoundSnapshotted(
    uint256 indexed roundId,
    uint256 totalTickets,
    bool meetsThreshold
);
```

---

### commitParticipantsRoot

**Description**: Commit Merkle root and IPFS CID for participants.

**Function Signature**:
```solidity
function commitParticipantsRoot(
    uint256 roundId,
    bytes32 root,
    string calldata cid
) external onlyOwner
```

**Requirements**:
- Round state MUST be `Snapshotted`
- `root` MUST NOT be zero

**Effects**:
- Sets `participantsRoot`
- Sets `participantsCIDs[roundId]`
- Emits `ParticipantsRootCommitted` event

**Events**:
```solidity
event ParticipantsRootCommitted(
    uint256 indexed roundId,
    bytes32 root,
    string cid
);
```

---

### requestRandomness

**Description**: Request VRF randomness from Chainlink.

**Function Signature**:
```solidity
function requestRandomness(uint256 roundId) 
    external 
    onlyOwner 
    returns (uint256 requestId)
```

**Requirements**:
- Round state MUST be `Snapshotted`
- `meetsMinimumThreshold` MUST be true
- `participantsRoot` MUST be set

**Effects**:
- Calls Chainlink VRF coordinator
- Transitions state to `VRFRequested`
- Sets `vrfRequestId` and `vrfRequestTimestamp`
- Emits `RandomnessRequested` event

**Events**:
```solidity
event RandomnessRequested(
    uint256 indexed roundId,
    uint256 requestId
);
```

---

### commitWinners

**Description**: Commit Merkle root and IPFS CID for winners.

**Function Signature**:
```solidity
function commitWinners(
    uint256 roundId,
    bytes32 root,
    string calldata cid
) external onlyOwner
```

**Requirements**:
- Round state MUST be `VRFFulfilled`
- `vrfSeed` MUST be set
- `root` MUST NOT be zero

**Effects**:
- Sets `winnersRoot`
- Sets `winnersCIDs[roundId]`
- Transitions state to `WinnersCommitted`
- Emits `WinnersCommitted` event

**Events**:
```solidity
event WinnersCommitted(
    uint256 indexed roundId,
    bytes32 root,
    string cid
);
```

---

### closeRound

**Description**: Close round, distribute fees, process refunds.

**Function Signature**:
```solidity
function closeRound(uint256 roundId) external onlyOwner
```

**Requirements**:
- Round state MUST be `WinnersCommitted` OR (`Snapshotted` AND `!meetsMinimumThreshold`)

**Effects**:
- IF `meetsMinimumThreshold`: Distributes fees (80% creators, 20% pool)
- IF `!meetsMinimumThreshold`: Adds all wagers to refund pool
- Transitions state to `Closed`
- Emits `RoundClosed` event

**Events**:
```solidity
event RoundClosed(
    uint256 indexed roundId,
    uint256 feesDistributed,
    uint256 refundsIssued
);
```

---

### setPrizesForRound

**Description**: Set Emblem Vault NFT token IDs for round prizes.

**Function Signature**:
```solidity
function setPrizesForRound(
    uint256 roundId,
    uint256[10] calldata tokenIds
) external onlyOwner
```

**Parameters**:
- `roundId`: Round to configure
- `tokenIds`: Array of 10 Emblem Vault token IDs

**Requirements**:
- Contract MUST own all specified NFTs
- Round MUST NOT have started betting yet

**Effects**:
- Sets `prizeNFTs[roundId][0..9]`
- Emits `PrizesSet` event

**Events**:
```solidity
event PrizesSet(uint256 indexed roundId, uint256[10] tokenIds);
```

---

### setValidProofHash

**Description**: Set valid proof hash for puzzle solution.

**Function Signature**:
```solidity
function setValidProofHash(uint256 roundId, bytes32 hash) 
    external 
    onlyOwner
```

**Requirements**:
- Round MUST NOT have started or be in `Open` state

**Effects**:
- Sets `validProofHashes[roundId]`
- Emits `ProofHashSet` event

**Events**:
```solidity
event ProofHashSet(uint256 indexed roundId, bytes32 hash);
```

---

### setDenylistStatus

**Description**: Add/remove address from denylist.

**Function Signature**:
```solidity
function setDenylistStatus(address wallet, bool status) 
    external 
    onlyOwner
```

**Effects**:
- Sets `denylisted[wallet]`
- Emits `DenylistUpdated` event

**Events**:
```solidity
event DenylistUpdated(address indexed wallet, bool denylisted);
```

---

## VRF Integration

### fulfillRandomWords

**Description**: Chainlink VRF callback (internal, called by coordinator).

**Function Signature**:
```solidity
function fulfillRandomWords(
    uint256 requestId,
    uint256[] memory randomWords
) internal override
```

**Requirements**:
- Caller MUST be VRF coordinator
- `requestId` MUST match pending VRF request

**Effects**:
- Sets `vrfSeed` to `randomWords[0]`
- Transitions state to `VRFFulfilled`
- Emits `RandomnessFulfilled` event

**Events**:
```solidity
event RandomnessFulfilled(
    uint256 indexed roundId,
    uint256 seed,
    uint256 requestId
);
```

---

## View Functions

### getRound

```solidity
function getRound(uint256 roundId) 
    external 
    view 
    returns (Round memory)
```

### getParticipant

```solidity
function getParticipant(uint256 roundId, address wallet) 
    external 
    view 
    returns (Participant memory)
```

### getParticipantList

```solidity
function getParticipantList(uint256 roundId) 
    external 
    view 
    returns (address[] memory)
```

### getClaimStatus

```solidity
function getClaimStatus(uint256 roundId, uint8 prizeIndex) 
    external 
    view 
    returns (address claimer, bool claimed)
```

### getRefundBalance

```solidity
function getRefundBalance(address wallet) 
    external 
    view 
    returns (uint256)
```

### isWinner

```solidity
function isWinner(
    uint256 roundId,
    address wallet,
    uint8 prizeIndex,
    uint8 prizeTier,
    bytes32[] calldata proof
) external view returns (bool)
```

Returns true if Merkle proof is valid for the given parameters.

---

## Modifiers

```solidity
modifier whenNotEmergencyPaused() {
    require(!emergencyPaused, "Emergency pause active");
    _;
}

modifier validAddress(address addr) {
    require(addr != address(0), "Invalid: zero address");
    require(addr != address(this), "Invalid: contract address");
    _;
}

modifier notDenylisted(address wallet) {
    require(!denylisted[wallet], "Address denylisted");
    _;
}
```

---

## Events Summary

### User Events
- `BetPlaced(uint256 indexed roundId, address indexed participant, uint256 amount, uint8 tickets, uint256 totalWagered)`
- `ProofSubmitted(uint256 indexed roundId, address indexed participant, bool verified, uint128 newWeight)`
- `PrizeClaimed(uint256 indexed roundId, address indexed winner, uint8 prizeIndex, uint8 prizeTier, uint256 emblemVaultTokenId)`
- `RefundWithdrawn(address indexed user, uint256 amount)`

### Owner Events
- `RoundCreated(uint256 indexed roundId, uint256 startTime, uint256 endTime)`
- `RoundSnapshotted(uint256 indexed roundId, uint256 totalTickets, bool meetsThreshold)`
- `ParticipantsRootCommitted(uint256 indexed roundId, bytes32 root, string cid)`
- `RandomnessRequested(uint256 indexed roundId, uint256 requestId)`
- `WinnersCommitted(uint256 indexed roundId, bytes32 root, string cid)`
- `RoundClosed(uint256 indexed roundId, uint256 feesDistributed, uint256 refundsIssued)`
- `PrizesSet(uint256 indexed roundId, uint256[10] tokenIds)`
- `ProofHashSet(uint256 indexed roundId, bytes32 hash)`
- `DenylistUpdated(address indexed wallet, bool denylisted)`

### VRF Events
- `RandomnessFulfilled(uint256 indexed roundId, uint256 seed, uint256 requestId)`

### Governance Events
- `Paused(address account)`
- `Unpaused(address account)`
- `EmergencyPauseSet(bool status)`
- `OwnershipTransferStarted(address indexed previousOwner, address indexed newOwner)`

---

## Error Codes

```solidity
error InvalidRoundState(RoundState current, RoundState required);
error InvalidTicketCount(uint8 provided);
error InvalidPayment(uint256 provided, uint256 required);
error MaxWagerExceeded(uint256 current, uint256 max);
error AlreadyClaimed(uint256 roundId, uint8 prizeIndex);
error InvalidMerkleProof();
error ClaimLimitExceeded(uint8 current, uint8 max);
error MinimumThresholdNotMet(uint256 tickets, uint256 required);
error ProofAlreadyAttempted();
error NoRefundAvailable();
error VRFRequestFailed();
```

---

## Gas Estimates

| Function | Estimated Gas |
|----------|--------------|
| buyTickets (new participant) | ~120,000 |
| buyTickets (existing participant) | ~80,000 |
| submitProof (success) | ~60,000 |
| submitProof (fail) | ~50,000 |
| claim | ~180,000 |
| withdrawRefund | ~35,000 |
| snapshotRound | ~100,000 |
| requestRandomness | ~150,000 |
| commitWinners | ~120,000 |
| closeRound (with fees) | ~200,000 |
| closeRound (refunds) | ~150,000 |

---

**Status**: CONTRACT API COMPLETE
**Next**: Implementation Phase
