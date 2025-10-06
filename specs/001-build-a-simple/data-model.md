# Data Model: PEPEDAWN betting site with VRF draws and Emblem Vault prizes

**Feature**: 001-build-a-simple  
**Date**: 2025-10-06  
**Source**: Extracted from spec.md Key Entities section

## Core Entities

### Round
**Purpose**: Represents a 2-week betting cycle with defined start/end times and lifecycle states.

**Fields**:
- `id` (uint256): Unique round identifier, auto-incrementing
- `startTime` (uint64): Unix timestamp when betting opens
- `endTime` (uint64): Unix timestamp when betting closes (startTime + 2 weeks)
- `status` (enum): Current lifecycle state
- `totalTickets` (uint256): Sum of all tickets purchased in this round
- `totalWeight` (uint256): Sum of all effective weights (including puzzle bonuses)
- `totalWagered` (uint256): Total ETH wagered in this round
- `vrfRequestId` (uint256): Chainlink VRF request identifier
- `feesDistributed` (bool): Whether 80/20 fee split has been processed

**Status Values**:
- `Created`: Round exists but betting not yet open
- `Open`: Accepting bets and puzzle proofs
- `Closed`: No more bets/proofs accepted
- `Snapshot`: Eligible participants snapshotted for VRF
- `VRFRequested`: Randomness requested from Chainlink
- `Distributed`: Winners selected and prizes distributed

**Validation Rules**:
- `startTime` and `endTime` immutable once set
- `endTime` must be exactly 2 weeks after `startTime`
- Status transitions must follow defined lifecycle
- Only one round can be in `Open` status at a time

### Wager
**Purpose**: Records individual betting transactions with ticket calculations.

**Fields**:
- `wallet` (address): Ethereum address of the bettor
- `roundId` (uint256): Reference to the Round
- `amount` (uint256): ETH amount wagered
- `tickets` (uint256): Number of tickets purchased (1, 5, or 10)
- `effectiveWeight` (uint256): Final weight including puzzle multipliers
- `createdAt` (uint64): Unix timestamp of wager placement

**Validation Rules**:
- `amount` must match exact pricing: 0.005 ETH (1 ticket), 0.0225 ETH (5 tickets), 0.04 ETH (10 tickets)
- Cumulative wagers per wallet per round cannot exceed 1.0 ETH
- Can only wager in rounds with `Open` status
- `effectiveWeight` initially equals `tickets`, modified by puzzle proofs

### Wallet
**Purpose**: Aggregates per-wallet state across rounds for eligibility and tracking.

**Fields**:
- `address` (address): Ethereum wallet address (primary key)
- `eligibilityStatus` (enum): Current participation eligibility
- `totalEffectiveWeight` (uint256): Current round weight including bonuses
- `proofStatus` (bool): Whether puzzle proof submitted in current round

**Eligibility Values**:
- `Allowed`: Can participate normally
- `Denylisted`: Blocked from participation

**Validation Rules**:
- Denylisted wallets cannot place wagers or submit proofs
- Proof status resets each round
- Weight calculations must account for puzzle multipliers

### PuzzleProof
**Purpose**: Records puzzle solution submissions and weight multiplier applications.

**Fields**:
- `wallet` (address): Submitting wallet address
- `roundId` (uint256): Reference to the Round
- `proofHash` (bytes32): Hash of the puzzle solution
- `verified` (bool): Whether proof passed validation
- `submittedAt` (uint64): Unix timestamp of submission
- `weightMultiplier` (uint256): Applied multiplier (1400 = 1.4x)

**Validation Rules**:
- One proof per wallet per round maximum
- Can only submit if wallet has already wagered in the round
- `proofHash` cannot be zero/empty
- `weightMultiplier` fixed at 1400 (40% increase)
- Proof submission only allowed in `Open` rounds

### PrizeTier
**Purpose**: Defines available prize categories and their Emblem Vault mappings.

**Fields**:
- `name` (string): Prize tier name ("Fake Pack", "Kek Pack", "Pepe Pack")
- `count` (uint8): Number of prizes available (1, 1, 8 respectively)
- `description` (string): Prize contents description
- `emblemVaultTokenIds` (uint256[]): Pre-committed vault token IDs
- `cardCount` (uint8): Number of PEPEDAWN cards in pack (3, 2, 1)

**Validation Rules**:
- Prize counts must match spec: 1 Fake, 1 Kek, 8 Pepe
- Emblem Vault tokens must be pre-committed before round opens
- Token IDs must be valid and owned by contract

### WinnerAssignment
**Purpose**: Records VRF-based winner selection results with full auditability.

**Fields**:
- `roundId` (uint256): Reference to the Round
- `wallet` (address): Winning wallet address
- `prizeTier` (uint8): Assigned prize tier (1=Fake, 2=Kek, 3=Pepe)
- `vrfRequestId` (uint256): Chainlink VRF request that determined winner
- `blockNumber` (uint256): Block number when VRF fulfilled
- `randomSeed` (uint256): VRF-provided random value used for selection

**Validation Rules**:
- Winners must have participated in the round (have wagers)
- Prize tier assignments must respect available counts
- VRF data must be verifiable on-chain
- No duplicate winners for same prize tier

### LeaderboardEntry
**Purpose**: Real-time display of wallet odds for Fake Pack prize only.

**Fields**:
- `wallet` (address): Participant wallet address
- `fakePackOdds` (uint256): Percentage chance of winning Fake Pack (basis points)
- `rank` (uint256): Current leaderboard position
- `effectiveWeight` (uint256): Total weight including puzzle bonuses

**Validation Rules**:
- Odds calculated as: (wallet_weight / total_round_weight) * 10000
- Updates triggered by new wagers and puzzle proof submissions
- Only shows participants with active wagers in current round

### DeployArtifacts
**Purpose**: Operational data for contract deployment and monitoring.

**Fields**:
- `contractAddresses` (mapping): Contract name to deployed address
- `abis` (mapping): Contract name to ABI JSON
- `vrfConfig` (struct): VRF coordinator, subscription ID, key hash, gas limits
- `eventTxHashes` (mapping): Lifecycle event to transaction hash
- `networkId` (uint256): Ethereum network identifier

**Validation Rules**:
- Must be populated before any rounds can be created
- VRF configuration must be valid for target network
- Contract addresses must be verified as valid contracts

## Entity Relationships

```
Round (1) ←→ (N) Wager
Round (1) ←→ (N) PuzzleProof  
Round (1) ←→ (N) WinnerAssignment
Wallet (1) ←→ (N) Wager
Wallet (1) ←→ (N) PuzzleProof
PrizeTier (1) ←→ (N) WinnerAssignment
Round (1) ←→ (N) LeaderboardEntry
```

## State Transitions

### Round Lifecycle
```
Created → Open → Closed → Snapshot → VRFRequested → Distributed
```

### Wallet Eligibility
```
Allowed ←→ Denylisted (admin action)
```

## Data Storage Strategy

**On-Chain Storage** (Ethereum smart contract):
- All core entities except LeaderboardEntry and DeployArtifacts
- Immutable records for auditability
- Event emissions for off-chain indexing

**Off-Chain Derived** (computed from events):
- LeaderboardEntry: Real-time calculation from wager events
- DeployArtifacts: Configuration and operational metadata

**Event-Driven Updates**:
- Wager placement → Update round totals, recalculate leaderboard
- Proof submission → Update effective weights, recalculate leaderboard  
- VRF fulfillment → Create winner assignments
- Prize distribution → Update distribution status

## Performance Considerations

- Leaderboard calculations optimized for gas efficiency
- Batch operations where possible (e.g., multiple winner selection)
- Event indexing for fast off-chain queries
- Minimal on-chain storage for cost optimization