# Smart Contract API: Merkle Proof Claims

**Feature**: 002-merkle  
**Date**: October 8, 2025  
**Contract**: PepedawnRaffle.sol (extended)

## Overview

This document specifies the smart contract interface extensions for Merkle proof-based claims and refunds.

## New State Variables

```solidity
/// @notice Merkle root of participants for each round
/// @dev Set when round is snapshotted, immutable after VRF request
mapping(uint256 => bytes32) public participantsRoots;

/// @notice Merkle root of winners for each round
/// @dev Set after VRF fulfillment, immutable once set
mapping(uint256 => bytes32) public winnersRoots;

/// @notice Tracks which prize slots have been claimed per round
/// @dev roundId => prizeIndex => claimer address
mapping(uint256 => mapping(uint8 => address)) public claims;

/// @notice Tracks claim count per user per round
/// @dev roundId => user => claim count (for validation)
mapping(uint256 => mapping(address => uint8)) public claimCounts;

/// @notice Refund balances per user (pull-payment pattern)
mapping(address => uint256) public refunds;
```

## New Events

```solidity
/// @notice Emitted when participants are snapshotted
/// @param roundId The round ID
/// @param participantsRoot The Merkle root of participants
/// @param participantsCID The IPFS CID of the participants file
/// @param totalParticipants The total number of participants
event ParticipantsSnapshotted(
    uint256 indexed roundId,
    bytes32 participantsRoot,
    string participantsCID,
    uint256 totalParticipants
);

/// @notice Emitted when winners are committed
/// @param roundId The round ID
/// @param winnersRoot The Merkle root of winners
/// @param winnersCID The IPFS CID of the winners file
/// @param vrfSeed The VRF seed used for winner selection
event WinnersCommitted(
    uint256 indexed roundId,
    bytes32 winnersRoot,
    string winnersCID,
    uint256 vrfSeed
);

/// @notice Emitted when a prize is claimed
/// @param roundId The round ID
/// @param prizeIndex The prize slot index (0-9)
/// @param prizeTier The prize tier (1-3)
/// @param winner The address of the winner
/// @param timestamp The claim timestamp
event PrizeClaimed(
    uint256 indexed roundId,
    uint8 prizeIndex,
    uint8 prizeTier,
    address indexed winner,
    uint256 timestamp
);

/// @notice Emitted when a refund is withdrawn
/// @param user The user address
/// @param amount The refund amount in wei
/// @param timestamp The withdrawal timestamp
event RefundWithdrawn(
    address indexed user,
    uint256 amount,
    uint256 timestamp
);
```

## New Functions

### 1. snapshotParticipants

```solidity
/// @notice Snapshot participants and commit Merkle root
/// @dev Only callable by owner when round is in Open state
/// @param roundId The round ID to snapshot
/// @param participantsRoot The Merkle root of participants
/// @param participantsCID The IPFS CID of the participants file
/// @param totalParticipants The total number of participants
function snapshotParticipants(
    uint256 roundId,
    bytes32 participantsRoot,
    string calldata participantsCID,
    uint256 totalParticipants
) external onlyOwner {
    require(rounds[roundId].state == RoundState.Open, "Round not open");
    require(participantsRoot != bytes32(0), "Invalid root");
    require(bytes(participantsCID).length > 0, "Invalid CID");
    
    participantsRoots[roundId] = participantsRoot;
    rounds[roundId].state = RoundState.Snapshotted;
    
    emit ParticipantsSnapshotted(
        roundId,
        participantsRoot,
        participantsCID,
        totalParticipants
    );
}
```

**Test Cases**:
- ✓ Owner can snapshot participants in Open state
- ✗ Non-owner cannot snapshot participants
- ✗ Cannot snapshot in non-Open state
- ✗ Cannot snapshot with zero root
- ✗ Cannot snapshot with empty CID
- ✓ Participants root is stored correctly
- ✓ Round state transitions to Snapshotted
- ✓ Event emitted with correct parameters

### 2. commitWinners

```solidity
/// @notice Commit winners Merkle root after VRF fulfillment
/// @dev Only callable by owner when round is in VRFFulfilled state
/// @param roundId The round ID
/// @param winnersRoot The Merkle root of winners
/// @param winnersCID The IPFS CID of the winners file
function commitWinners(
    uint256 roundId,
    bytes32 winnersRoot,
    string calldata winnersCID
) external onlyOwner {
    require(rounds[roundId].state == RoundState.VRFFulfilled, "VRF not fulfilled");
    require(winnersRoot != bytes32(0), "Invalid root");
    require(bytes(winnersCID).length > 0, "Invalid CID");
    require(rounds[roundId].vrfSeed != 0, "VRF seed not set");
    
    winnersRoots[roundId] = winnersRoot;
    rounds[roundId].state = RoundState.WinnersCommitted;
    
    emit WinnersCommitted(
        roundId,
        winnersRoot,
        winnersCID,
        rounds[roundId].vrfSeed
    );
}
```

**Test Cases**:
- ✓ Owner can commit winners in VRFFulfilled state
- ✗ Non-owner cannot commit winners
- ✗ Cannot commit in non-VRFFulfilled state
- ✗ Cannot commit with zero root
- ✗ Cannot commit with empty CID
- ✗ Cannot commit without VRF seed
- ✓ Winners root is stored correctly
- ✓ Round state transitions to WinnersCommitted
- ✓ Event emitted with correct parameters

### 3. claim

```solidity
/// @notice Claim a prize with Merkle proof
/// @dev Verifies proof against winnersRoot and transfers prize
/// @param roundId The round ID
/// @param prizeIndex The prize slot index (0-9)
/// @param prizeTier The prize tier (1-3)
/// @param merkleProof The Merkle proof
function claim(
    uint256 roundId,
    uint8 prizeIndex,
    uint8 prizeTier,
    bytes32[] calldata merkleProof
) external nonReentrant {
    require(
        rounds[roundId].state == RoundState.WinnersCommitted ||
        rounds[roundId].state == RoundState.Closed,
        "Winners not committed"
    );
    require(prizeIndex < 10, "Invalid prize index");
    require(prizeTier >= 1 && prizeTier <= 3, "Invalid prize tier");
    require(claims[roundId][prizeIndex] == address(0), "Already claimed");
    
    // Verify Merkle proof
    bytes32 leaf = keccak256(abi.encode(msg.sender, prizeTier, prizeIndex));
    require(
        MerkleProof.verify(merkleProof, winnersRoots[roundId], leaf),
        "Invalid proof"
    );
    
    // Record claim
    claims[roundId][prizeIndex] = msg.sender;
    claimCounts[roundId][msg.sender]++;
    
    // Transfer prize (implementation depends on prize type)
    _transferPrize(msg.sender, prizeTier);
    
    emit PrizeClaimed(roundId, prizeIndex, prizeTier, msg.sender, block.timestamp);
}
```

**Test Cases**:
- ✓ Valid winner can claim with valid proof
- ✗ Cannot claim in non-WinnersCommitted/Closed state
- ✗ Cannot claim with invalid prize index (≥10)
- ✗ Cannot claim with invalid prize tier (<1 or >3)
- ✗ Cannot claim already claimed prize
- ✗ Cannot claim with invalid Merkle proof
- ✗ Cannot claim prize not assigned to caller
- ✓ Claim is recorded correctly
- ✓ Claim count is incremented
- ✓ Prize is transferred
- ✓ Event emitted with correct parameters
- ✓ Reentrancy protection works

### 4. withdrawRefund

```solidity
/// @notice Withdraw accumulated refund
/// @dev Pull-payment pattern for refunds
function withdrawRefund() external nonReentrant {
    uint256 amount = refunds[msg.sender];
    require(amount > 0, "No refund available");
    
    refunds[msg.sender] = 0;
    
    (bool success, ) = msg.sender.call{value: amount}("");
    require(success, "Transfer failed");
    
    emit RefundWithdrawn(msg.sender, amount, block.timestamp);
}
```

**Test Cases**:
- ✓ User can withdraw refund when balance > 0
- ✗ Cannot withdraw when balance = 0
- ✓ Refund balance set to 0 after withdrawal
- ✓ ETH transferred correctly
- ✗ Transfer failure reverts transaction
- ✓ Event emitted with correct parameters
- ✓ Reentrancy protection works

### 5. getClaimStatus

```solidity
/// @notice Get claim status for a prize slot
/// @param roundId The round ID
/// @param prizeIndex The prize slot index (0-9)
/// @return claimer The address that claimed the prize (address(0) if unclaimed)
/// @return claimed Whether the prize has been claimed
function getClaimStatus(
    uint256 roundId,
    uint8 prizeIndex
) external view returns (address claimer, bool claimed) {
    claimer = claims[roundId][prizeIndex];
    claimed = claimer != address(0);
}
```

**Test Cases**:
- ✓ Returns correct claimer address for claimed prize
- ✓ Returns address(0) for unclaimed prize
- ✓ Returns correct claimed status

### 6. getUserClaimCount

```solidity
/// @notice Get number of prizes claimed by user in a round
/// @param roundId The round ID
/// @param user The user address
/// @return count The number of prizes claimed
function getUserClaimCount(
    uint256 roundId,
    address user
) external view returns (uint8 count) {
    return claimCounts[roundId][user];
}
```

**Test Cases**:
- ✓ Returns 0 for user with no claims
- ✓ Returns correct count after claims
- ✓ Count increments with each claim

### 7. getRefundBalance

```solidity
/// @notice Get refund balance for user
/// @param user The user address
/// @return balance The refund balance in wei
function getRefundBalance(address user) external view returns (uint256 balance) {
    return refunds[user];
}
```

**Test Cases**:
- ✓ Returns 0 for user with no refund
- ✓ Returns correct balance after refund accrual
- ✓ Returns 0 after withdrawal

## Modified Functions

### requestRandomness (enhanced)

```solidity
/// @notice Request VRF randomness for winner selection
/// @dev Now requires participants to be snapshotted first
function requestRandomness(uint256 roundId) external onlyOwner {
    require(rounds[roundId].state == RoundState.Snapshotted, "Not snapshotted");
    require(participantsRoots[roundId] != bytes32(0), "Participants not snapshotted");
    
    // Existing VRF request logic...
    rounds[roundId].state = RoundState.VRFRequested;
}
```

**New Test Cases**:
- ✗ Cannot request VRF without participants snapshot
- ✓ Can request VRF after participants snapshot

## Gas Estimates

| Function | Estimated Gas | Notes |
|----------|---------------|-------|
| `snapshotParticipants` | ~50,000 | Storage write + event |
| `commitWinners` | ~50,000 | Storage write + event |
| `claim` (10-element proof) | ~120,000 | Proof verification + storage + transfer |
| `withdrawRefund` | ~40,000 | Storage update + ETH transfer |
| `getClaimStatus` | ~2,000 | View function |
| `getUserClaimCount` | ~2,000 | View function |
| `getRefundBalance` | ~2,000 | View function |

## Security Considerations

### Access Control
- `snapshotParticipants`: Owner only
- `commitWinners`: Owner only
- `claim`: Any user with valid proof
- `withdrawRefund`: Any user with balance

### Reentrancy Protection
- `claim`: Protected with `nonReentrant` modifier
- `withdrawRefund`: Protected with `nonReentrant` modifier

### Input Validation
- All Merkle roots validated (non-zero)
- All CIDs validated (non-empty)
- Prize index validated (0-9)
- Prize tier validated (1-3)
- Merkle proofs validated against stored roots

### State Validation
- Functions check round state before execution
- Participants root immutable after VRF request
- Winners root immutable once set
- Claims immutable once recorded

## Integration with Existing Contract

### Existing Functions to Modify
1. `requestRandomness`: Add participants snapshot check
2. `fulfillRandomWords`: Maintain VRF seed storage
3. `closeRound`: Allow state transition to Closed

### Existing Events to Maintain
- `RoundCreated`
- `BetPlaced`
- `RandomnessRequested`
- `RandomnessFulfilled`

### Backward Compatibility
- Existing rounds without Merkle roots continue to work
- New rounds require Merkle roots for claims
- Migration strategy: Deploy new contract version, migrate state if needed

## Summary

The smart contract API introduces 4 new functions for Merkle-based claims (`snapshotParticipants`, `commitWinners`, `claim`, `withdrawRefund`) and 3 view functions for querying state. The design uses pull-payment patterns, Merkle proof verification, and comprehensive access control to ensure secure and gas-efficient prize distribution.

**Key Design Decisions**:
1. **Merkle roots on-chain**: Only 32 bytes per root
2. **Pull-payment claims**: Users initiate claims with proofs
3. **Reentrancy protection**: All state-changing functions protected
4. **View functions**: Gas-free claim status queries
5. **Event-driven**: All state changes emit events for frontend

**Next**: Frontend API specifications
