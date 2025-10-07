# PepedawnRaffle Interface Documentation

**Feature**: 001-build-a-simple  
**Date**: 2025-01-27  
**Contract**: PepedawnRaffle.sol  
**Framework**: Vite MPA + ethers.js v6

## Contract Overview

PepedawnRaffle is a skill-weighted decentralized raffle system that implements:
- 2-week betting rounds with ETH wagers
- Puzzle proof submissions for +40% weight multiplier
- Chainlink VRF v2.5 for verifiable randomness
- Dynamic gas estimation for VRF callbacks
- Emblem Vault integration for prize distribution
- Automatic fee distribution (80% creators, 20% next round)

## Smart Contract Interface

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
- Emits `RoundClosed(roundId)`

#### `snapshotRound(uint256 roundId) external onlyOwner`
**Purpose**: Snapshot participants before VRF request  
**Preconditions**: Round status must be `Closed`  
**Effects**:
- Sets status to `Snapshot`
- Emits `RoundSnapshot(roundId, totalTickets, totalWeight)`

#### `requestVRF(uint256 roundId) external onlyOwner`
**Purpose**: Request Chainlink VRF for winner selection with dynamic gas estimation  
**Preconditions**: Round status must be `Snapshot`  
**Effects**:
- Estimates callback gas based on round complexity
- Adds 30% safety buffer to gas estimate
- Calls Chainlink VRF coordinator with calculated gas limit
- Sets status to `VRFRequested`
- Stores VRF request ID
- Emits `VRFRequested(roundId, requestId)`

### User Actions

#### `placeBet(uint256 tickets) external payable`
**Purpose**: Place a wager in the current open round  
**Parameters**:
- `tickets`: Number of tickets (1, 5, or 10)
**Preconditions**:
- Current round must be `Open`
- `msg.value` must match exact pricing:
  - 1 ticket: 0.005 ETH
  - 5 tickets: 0.0225 ETH  
  - 10 tickets: 0.04 ETH
- Wallet total wagers cannot exceed 1.0 ETH per round
- Address not denylisted
- Contract not paused
**Effects**:
- Updates user wager totals
- Calculates effective weight (with puzzle bonus if applicable)
- Updates round totals
- Emits `WagerPlaced(roundId, wallet, amount, tickets, effectiveWeight)`

#### `submitProof(bytes32 proofHash) external`
**Purpose**: Submit puzzle proof for +40% weight multiplier  
**Parameters**:
- `proofHash`: Hash of the puzzle solution
**Preconditions**:
- Current round must be `Open`
- Wallet must have existing wager in round
- One proof per wallet per round
- `proofHash` cannot be zero or trivial patterns
- Address not denylisted
- Contract not paused
**Effects**:
- Stores proof with verification status
- Recalculates effective weight with 1.4x multiplier
- Updates round total weight
- Emits `ProofSubmitted(wallet, roundId, proofHash, newWeight)`

### VRF Integration

#### `fulfillRandomWords(uint256 requestId, uint256[] calldata randomWords) internal override`
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
**Returns**: Round struct with all fields including status, totals, VRF data

#### `getUserStats(uint256 roundId, address user) external view returns (uint256 wagered, uint256 tickets, uint256 weight, bool hasProof)`
**Purpose**: Get user's participation stats for a round  
**Returns**: Wager amount, ticket count, effective weight, proof status

#### `getRoundParticipants(uint256 roundId) external view returns (address[] memory)`
**Purpose**: Get all wallet addresses that participated in a round  
**Returns**: Array of participant addresses

#### `getRoundWinners(uint256 roundId) external view returns (WinnerAssignment[] memory)`
**Purpose**: Get winners and their prize tiers for a completed round  
**Returns**: Array of WinnerAssignment structs with winner data

#### `estimateVRFCallbackGas(uint256 roundId) external view returns (uint32)`
**Purpose**: Estimate gas required for VRF callback (for testing/monitoring)  
**Returns**: Estimated gas based on round complexity

### Security Management (Owner Only)

#### `setDenylistStatus(address wallet, bool isDenylisted) external onlyOwner`
**Purpose**: Toggle denylist status for an address  
**Effects**: Emits `AddressDenylisted(wallet, isDenylisted)`

#### `setEmergencyPause(bool paused) external onlyOwner`
**Purpose**: Emergency pause toggle (additional to Pausable contract)  
**Effects**: Emits `EmergencyPauseToggled(paused)`

#### `pause() external onlyOwner`
**Purpose**: Pause contract (Pausable functionality)

#### `unpause() external onlyOwner`
**Purpose**: Unpause contract (Pausable functionality)

#### `updateVRFConfig(address _coordinator, uint256 _subscriptionId, bytes32 _keyHash) external onlyOwner`
**Purpose**: Update VRF configuration  
**Preconditions**: Valid coordinator address, non-zero subscription ID and key hash

#### `resetVRFTiming() external onlyOwner`
**Purpose**: Reset VRF timing for testing purposes

## Frontend API Interface

### Wallet Integration

#### `connectWallet() -> Promise<{address: string, provider: object}>`
**Purpose**: Connect user's Ethereum wallet (MetaMask, WalletConnect, etc.)  
**Returns**: Wallet address and provider instance  
**Error Handling**: 
- No wallet installed → Show installation instructions
- User rejection → Show retry option
- Network mismatch → Prompt network switch

#### `disconnectWallet() -> void`
**Purpose**: Clear wallet connection state  
**Effects**: Reset UI to disconnected state

#### `getWalletAddress() -> string | null`
**Purpose**: Get currently connected wallet address  
**Returns**: Address string or null if not connected

### Network Management

#### `checkNetwork() -> Promise<boolean>`
**Purpose**: Verify connected to correct Ethereum network  
**Returns**: True if on correct network (mainnet/testnet)  
**Effects**: Show network switch prompt if incorrect

#### `switchNetwork(chainId: number) -> Promise<void>`
**Purpose**: Request wallet to switch to specified network  
**Parameters**: Target chain ID  
**Error Handling**: User rejection, unsupported network

### Contract Interaction

#### `getCurrentRound() -> Promise<RoundData>`
**Purpose**: Get current active round information  
**Returns**: 
```typescript
interface RoundData {
  id: number;
  startTime: number;
  endTime: number;
  status: string; // "Created" | "Open" | "Closed" | "Snapshot" | "VRFRequested" | "Distributed"
  totalTickets: number;
  totalWeight: number;
  totalWagered: string; // ETH amount as string
  participantCount: number;
  vrfRequestId: string;
  vrfRequestedAt: number;
  feesDistributed: boolean;
}
```

#### `getUserStats(roundId: number, address: string) -> Promise<UserStats>`
**Purpose**: Get user's participation data for a round  
**Returns**:
```typescript
interface UserStats {
  wagered: string; // ETH amount
  tickets: number;
  weight: number;
  hasProof: boolean;
}
```

#### `getRoundWinners(roundId: number) -> Promise<WinnerData[]>`
**Purpose**: Get winners for completed round  
**Returns**:
```typescript
interface WinnerData {
  roundId: number;
  wallet: string;
  prizeTier: number; // 1=Fake, 2=Kek, 3=Pepe
  vrfRequestId: string;
  blockNumber: number;
}
```

#### `estimateGasForRound(roundId: number) -> Promise<number>`
**Purpose**: Get estimated VRF callback gas for a round  
**Returns**: Estimated gas limit

### Write Operations

#### `placeBet(tickets: number) -> Promise<TransactionResult>`
**Purpose**: Place a wager in current round  
**Parameters**: Number of tickets (1, 5, or 10)  
**Preconditions**: 
- Wallet connected
- Current round is open
- Sufficient ETH balance
- Won't exceed 1.0 ETH cap
**Returns**:
```typescript
interface TransactionResult {
  hash: string;
  success: boolean;
  error?: string;
}
```

#### `submitProof(proofHash: string) -> Promise<TransactionResult>`
**Purpose**: Submit puzzle proof for weight bonus  
**Parameters**: Proof hash as hex string  
**Preconditions**:
- Wallet connected
- Has existing wager in current round
- No previous proof submitted
- Valid proof hash

### Event Handling

#### `subscribeToRoundEvents() -> void`
**Purpose**: Listen for round lifecycle events  
**Events Monitored**:
- `RoundCreated`: New round started
- `RoundOpened`: Betting opened
- `RoundClosed`: Betting closed
- `RoundSnapshot`: Snapshot taken
- `VRFRequested`: VRF requested
- `VRFFulfilled`: VRF completed
- `WagerPlaced`: New wager (update leaderboard)
- `ProofSubmitted`: Proof submitted (update weights)
- `WinnersAssigned`: Winners selected
- `PrizeDistributed`: Prize distributed
- `FeesDistributed`: Fees distributed

#### `subscribeToUserEvents(address: string) -> void`
**Purpose**: Listen for user-specific events  
**Events Monitored**:
- User's bet confirmations
- User's proof submissions
- Prize wins

## Events

### Round Lifecycle
```solidity
event RoundCreated(uint256 indexed roundId, uint64 startTime, uint64 endTime);
event RoundOpened(uint256 indexed roundId);
event RoundClosed(uint256 indexed roundId);
event RoundSnapshot(uint256 indexed roundId, uint256 totalTickets, uint256 totalWeight);
```

### User Actions
```solidity
event WagerPlaced(address indexed wallet, uint256 indexed roundId, uint256 amount, uint256 tickets, uint256 effectiveWeight);
event ProofSubmitted(address indexed wallet, uint256 indexed roundId, bytes32 proofHash, uint256 newWeight);
```

### VRF and Winners
```solidity
event VRFRequested(uint256 indexed roundId, uint256 indexed requestId);
event VRFFulfilled(uint256 indexed roundId, uint256 indexed requestId, uint256[] randomWords);
event WinnersAssigned(uint256 indexed roundId, address[] winners, uint8[] prizeTiers);
```

### Prize Distribution
```solidity
event PrizeDistributed(uint256 indexed roundId, address indexed winner, uint8 prizeTier, uint256 assetId);
event FeesDistributed(uint256 indexed roundId, address indexed creators, uint256 creatorsAmount, uint256 nextRoundAmount);
event EmblemVaultPrizeAssigned(uint256 indexed roundId, address indexed winner, uint256 indexed assetId, uint256 timestamp);
event RoundPrizesDistributed(uint256 indexed roundId, uint256 winnerCount, uint256 timestamp);
```

### Security Events
```solidity
event AddressDenylisted(address indexed wallet, bool denylisted);
event EmergencyPauseToggled(bool paused);
event VRFTimeoutDetected(uint256 indexed roundId, uint256 requestId);
event CircuitBreakerTriggered(uint256 indexed roundId, string reason);
event SecurityValidationFailed(address indexed user, string reason);
```

## Constants

### Pricing
- `MIN_WAGER`: 0.005 ETH (1 ticket)
- `BUNDLE_5_PRICE`: 0.0225 ETH (5 tickets)
- `BUNDLE_10_PRICE`: 0.04 ETH (10 tickets)
- `WALLET_CAP`: 1.0 ETH (max per wallet per round)

### Multipliers
- `PROOF_MULTIPLIER`: 1400 (1.4x = +40% weight bonus)

### Fees
- `CREATORS_FEE_PCT`: 80% (to creators)
- `NEXT_ROUND_FEE_PCT`: 20% (for next round)

### Prize Tiers
- `FAKE_PACK_TIER`: 1 (premium prize)
- `KEK_PACK_TIER`: 2 (mid-tier prize)
- `PEPE_PACK_TIER`: 3 (common prize)

### Security Limits
- `MAX_PARTICIPANTS_PER_ROUND`: 10000 (circuit breaker)
- `MAX_TOTAL_WAGER_PER_ROUND`: 1000 ETH (circuit breaker)
- `VRF_REQUEST_TIMEOUT`: 1 hour (timeout protection)
- `ROUND_DURATION`: 2 weeks

## Error Conditions

### Access Control
- `"Only callable by owner"`: Non-owner attempting owner-only function
- `"Only VRF coordinator"`: Invalid VRF callback caller
- `"Must be proposed owner"`: Invalid ownership transfer

### Round State
- `"Round does not exist"`: Invalid round ID
- `"Round not in required status"`: Operation not allowed in current round state
- `"No active round"`: Attempting user action when no round is open
- `"Previous round not completed"`: Cannot create new round

### Betting Validation
- `"Invalid ticket count (must be 1, 5, or 10)"`: Unsupported ticket quantity
- `"Incorrect payment amount"`: ETH sent doesn't match ticket pricing
- `"Exceeds wallet cap of 1.0 ETH"`: Would exceed per-wallet per-round limit
- `"Max participants reached for this round"`: Circuit breaker triggered
- `"Max total wager reached for this round"`: Circuit breaker triggered

### Proof Validation
- `"Must place wager before submitting proof"`: Proof submitted without existing wager
- `"Proof already submitted for this round"`: Duplicate proof attempt
- `"Invalid proof hash"`: Empty, zero, or trivial proof hash
- `"Round not open for proofs"`: Proof submission not allowed

### VRF Validation
- `"No participants in round"`: Cannot request VRF for empty round
- `"VRF request too frequent"`: Rate limiting protection
- `"Invalid VRF coordinator"`: Coordinator address validation failed
- `"VRF request timeout exceeded"`: Request took too long
- `"Invalid VRF request"`: Request ID validation failed
- `"Invalid random word: zero"`: VRF returned invalid randomness

### Transfer Failures
- `"Creator fee transfer failed"`: ETH transfer to creators address failed

### Security
- `"Address is denylisted"`: Blocked address attempted action
- `"Emergency pause is active"`: Contract is emergency paused
- `"Invalid address: zero address"`: Zero address validation
- `"Invalid address: contract address"`: Self-reference validation

## Security Considerations

### Reentrancy Protection
- All external calls use checks-effects-interactions pattern
- Reentrancy guards on functions making external calls
- State updates before external interactions

### Access Control
- Owner-only functions for round management
- VRF coordinator validation for randomness callback
- Input validation on all external parameters
- Denylist functionality for blocked addresses

### Emergency Controls
- Pause functionality for critical operations
- Emergency pause state separate from regular pause
- Circuit breakers for unusual conditions
- VRF timeout protection

### VRF Security
- Request ID validation in fulfillment
- Protection against VRF manipulation
- Duplicate winner prevention in selection algorithm
- Dynamic gas estimation prevents callback failures

### Gas Optimization
- Dynamic gas estimation based on round complexity
- Batch operations where possible
- Efficient storage patterns
- Event-based off-chain indexing
- Minimal on-chain computations for leaderboard

## Performance Optimization

### Caching Strategy
- Cache round data to reduce contract calls
- TTL: 30 seconds for active rounds, permanent for completed
- Cache leaderboard data with 10-second TTL

### Batch Operations
- Batch multiple read operations
- Reduce RPC calls, improve performance

#
### Dynamic Gas Estimation

The contract now uses dynamic gas estimation for VRF callbacks following Chainlink best practices:

#### `estimateVRFCallbackGas(uint256 roundId) external view returns (uint32)`
**Purpose**: Estimate gas required for VRF callback based on round complexity  
**Returns**: Estimated gas limit with safety buffer  
**Calculation**: Base gas + winner selection + prize distribution + storage operations + complexity multipliers

#### Gas Estimation Formula
- **Base Gas**: 50,000 (function overhead, events, basic checks)
- **Winner Selection**: 20,000 (selection algorithm)
- **Prize Distribution**: 15,000 per winner (max 10 winners)
- **Fee Distribution**: 25,000 (fee calculation and transfer)
- **Storage Operations**: 5,000 per participant
- **Event Emissions**: 10,000 (multiple events)
- **Complexity Multipliers**: +20% for >100 participants, +10% for >1000 total weight
- **Safety Buffer**: 30% added to final estimate

#### Benefits
- Prevents VRF callback failures due to insufficient gas
- Scales automatically with round complexity
- Follows Chainlink recommended practices
- Reduces manual gas configuration overhead
#### `estimateVRFCallbackGas(uint256 roundId) external view returns (uint32)`
**Purpose**: Estimate gas required for VRF callback based on round complexity  
**Returns**: Estimated gas limit with safety buffer  
**Calculation**: Base gas + winner selection + prize distribution + storage operations + complexity multipliers

#### Gas Estimation Formula
- **Base Gas**: 50,000 (function overhead, events, basic checks)
- **Winner Selection**: 20,000 (selection algorithm)
- **Prize Distribution**: 15,000 per winner (max 10 winners)
- **Fee Distribution**: 25,000 (fee calculation and transfer)
- **Storage Operations**: 5,000 per participant
- **Event Emissions**: 10,000 (multiple events)
- **Complexity Multipliers**: +20% for >100 participants, +10% for >1000 total weight
- **Safety Buffer**: 30% added to final estimate

#### Benefits
- Prevents VRF callback failures due to insufficient gas
- Scales automatically with round complexity
- Follows Chainlink recommended practices
- Reduces manual gas configuration overhead
#### `estimateVRFCallbackGas(uint256 roundId) external view returns (uint32)`
**Purpose**: Estimate gas required for VRF callback based on round complexity  
**Returns**: Estimated gas limit with safety buffer  
**Calculation**: Base gas + winner selection + prize distribution + storage operations + complexity multipliers

#### Gas Estimation Formula
- **Base Gas**: 50,000 (function overhead, events, basic checks)
- **Winner Selection**: 20,000 (selection algorithm)
- **Prize Distribution**: 15,000 per winner (max 10 winners)
- **Fee Distribution**: 25,000 (fee calculation and transfer)
- **Storage Operations**: 5,000 per participant
- **Event Emissions**: 10,000 (multiple events)
- **Complexity Multipliers**: +20% for >100 participants, +10% for >1000 total weight
- **Safety Buffer**: 30% added to final estimate

#### Benefits
- Prevents VRF callback failures due to insufficient gas
- Scales automatically with round complexity
- Follows Chainlink recommended practices
- Reduces manual gas configuration overhead


## Dynamic Gas Management
- Estimate callback gas based on round complexity
- Add 30% safety buffer to prevent failures
- Scale gas with participant count and round weight
