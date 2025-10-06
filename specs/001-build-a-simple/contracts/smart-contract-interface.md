# Smart Contract Interface: PepedawnRaffle

**Feature**: 001-build-a-simple  
**Date**: 2025-10-06  
**Contract**: PepedawnRaffle.sol

## Public Functions

### Round Management (Owner Only)

#### `createRound() external onlyOwner`
**Purpose**: Create a new 2-week betting round  
**Preconditions**: Previous round must be completed  
**Effects**: 
- Increments `currentRoundId`
- Sets start/end timestamps (2 weeks duration)
- Sets status to `Created`
- Emits `RoundCreated(roundId, startTime, endTime)`

#### `openRound(uint256 roundId) external onlyOwner`
**Purpose**: Open round for betting and proof submissions  
**Preconditions**: Round status must be `Created`  
**Effects**:
- Sets status to `Open`
- Emits `RoundOpened(roundId)`

#### `closeRound(uint256 roundId) external onlyOwner`
**Purpose**: Close round to new bets/proofs  
**Preconditions**: Round status must be `Open`  
**Effects**:
- Sets status to `Closed`
- Emits `RoundClosed(roundId, totalTickets, totalWeight, totalWagered)`

#### `snapshotRound(uint256 roundId) external onlyOwner`
**Purpose**: Snapshot participants before VRF request  
**Preconditions**: Round status must be `Closed`  
**Effects**:
- Sets status to `Snapshot`
- Emits `RoundSnapshot(roundId, totalTickets, totalWeight)`

### User Actions

#### `placeBet(uint256 tickets) external payable`
**Purpose**: Place a wager in the current open round  
**Parameters**:
- `tickets`: Number of tickets (1, 5, or 10)
**Preconditions**:
- Current round must be `Open`
- `msg.value` must match exact pricing
- Wallet total wagers cannot exceed 1.0 ETH per round
**Effects**:
- Updates user wager totals
- Calculates effective weight (with puzzle bonus if applicable)
- Updates round totals
- Emits `BetPlaced(roundId, wallet, amount, tickets, effectiveWeight)`

#### `submitProof(bytes32 proofHash) external`
**Purpose**: Submit puzzle proof for +40% weight multiplier  
**Parameters**:
- `proofHash`: Hash of the puzzle solution
**Preconditions**:
- Current round must be `Open`
- Wallet must have existing wager in round
- One proof per wallet per round
- `proofHash` cannot be zero
**Effects**:
- Stores proof with verification status
- Recalculates effective weight with 1.4x multiplier
- Updates round total weight
- Emits `ProofSubmitted(wallet, roundId, proofHash, newWeight)`

### VRF Integration

#### `requestVRF(uint256 roundId) external onlyOwner`
**Purpose**: Request Chainlink VRF for winner selection  
**Preconditions**: Round status must be `Snapshot`  
**Effects**:
- Calls Chainlink VRF coordinator
- Sets status to `VRFRequested`
- Stores VRF request ID
- Emits `VRFRequested(roundId, requestId)`

#### `fulfillRandomWords(uint256 requestId, uint256[] memory randomWords) internal override`
**Purpose**: VRF callback to process randomness and select winners  
**Parameters**:
- `requestId`: VRF request identifier
- `randomWords`: Array of random values from VRF
**Effects**:
- Selects winners using weighted random selection
- Assigns prize tiers (1 Fake, 1 Kek, 8 Pepe)
- Distributes prizes via Emblem Vault
- Distributes fees (80% creators, 20% next round)
- Sets status to `Distributed`
- Emits `VRFFulfilled(roundId, requestId, randomWords)`
- Emits `WinnersAssigned(roundId, winners[], prizeTiers[])`
- Emits `PrizeDistributed(roundId, winner, prizeTier, assetId)` for each winner
- Emits `FeesDistributed(roundId, creatorsAddress, creatorsAmount, nextRoundAmount)`

### View Functions

#### `getRound(uint256 roundId) external view returns (Round memory)`
**Purpose**: Get complete round information  
**Returns**: Round struct with all fields

#### `getUserStats(uint256 roundId, address user) external view returns (uint256 wagered, uint256 tickets, uint256 weight, bool hasProof)`
**Purpose**: Get user's participation stats for a round  
**Returns**: Wager amount, ticket count, effective weight, proof status

#### `getRoundParticipants(uint256 roundId) external view returns (address[] memory)`
**Purpose**: Get all wallet addresses that participated in a round  
**Returns**: Array of participant addresses

#### `getRoundWinners(uint256 roundId) external view returns (address[] memory, uint8[] memory)`
**Purpose**: Get winners and their prize tiers for a completed round  
**Returns**: Arrays of winner addresses and corresponding prize tiers

#### `getLeaderboard(uint256 roundId) external view returns (address[] memory, uint256[] memory)`
**Purpose**: Get current leaderboard with Fake Pack odds  
**Returns**: Arrays of wallet addresses and their percentage odds (basis points)

#### `currentRoundId() external view returns (uint256)`
**Purpose**: Get the current active round ID  
**Returns**: Current round identifier

#### `nextRoundFunds() external view returns (uint256)`
**Purpose**: Get accumulated funds for next round (20% fee portion)  
**Returns**: ETH amount available for next round

## Events

### Round Lifecycle
```solidity
event RoundCreated(uint256 indexed roundId, uint64 startTime, uint64 endTime);
event RoundOpened(uint256 indexed roundId);
event RoundClosed(uint256 indexed roundId, uint256 totalTickets, uint256 totalWeight, uint256 totalWagered);
event RoundSnapshot(uint256 indexed roundId, uint256 totalTickets, uint256 totalWeight);
```

### User Actions
```solidity
event BetPlaced(uint256 indexed roundId, address indexed wallet, uint256 amount, uint256 tickets, uint256 effectiveWeight);
event ProofSubmitted(address indexed wallet, uint256 indexed roundId, bytes32 proofHash, uint256 newWeight);
```

### VRF and Winners
```solidity
event VRFRequested(uint256 indexed roundId, uint256 requestId);
event VRFFulfilled(uint256 indexed roundId, uint256 requestId, uint256[] randomWords);
event WinnersAssigned(uint256 indexed roundId, address[] winners, uint8[] prizeTiers);
```

### Prize Distribution
```solidity
event PrizeDistributed(uint256 indexed roundId, address indexed winner, uint8 prizeTier, uint256 assetId);
event FeesDistributed(uint256 indexed roundId, address creatorsAddress, uint256 creatorsAmount, uint256 nextRoundAmount);
```

## Error Conditions

### Access Control
- `"Only owner"`: Non-owner attempting owner-only function
- `"Only VRF coordinator"`: Invalid VRF callback caller

### Round State
- `"Round does not exist"`: Invalid round ID
- `"Round not in required status"`: Operation not allowed in current round state
- `"No active round"`: Attempting user action when no round is open

### Betting Validation
- `"Invalid ticket count (must be 1, 5, or 10)"`: Unsupported ticket quantity
- `"Incorrect payment amount"`: ETH sent doesn't match ticket pricing
- `"Exceeds wallet cap of 1.0 ETH"`: Would exceed per-wallet per-round limit

### Proof Validation
- `"Must place wager before submitting proof"`: Proof submitted without existing wager
- `"Proof already submitted for this round"`: Duplicate proof attempt
- `"Invalid proof hash"`: Empty or zero proof hash

### Transfer Failures
- `"Creator fee transfer failed"`: ETH transfer to creators address failed

## Security Considerations

### Reentrancy Protection
- All external calls use checks-effects-interactions pattern
- Reentrancy guards on functions making external calls
- State updates before external interactions

### Access Control
- Owner-only functions for round management
- VRF coordinator validation for randomness callback
- Input validation on all external parameters

### Emergency Controls
- Pause functionality for critical operations
- Emergency withdrawal mechanisms
- Circuit breakers for unusual conditions

### VRF Security
- Request ID validation in fulfillment
- Protection against VRF manipulation
- Duplicate winner prevention in selection algorithm

## Gas Optimization

- Batch operations where possible
- Efficient storage patterns
- Event-based off-chain indexing
- Minimal on-chain computations for leaderboard
