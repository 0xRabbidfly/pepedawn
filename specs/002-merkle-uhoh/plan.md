# Implementation Plan: PEPEDAWN Betting Site with VRF, Merkle Verification, and Claims System

**Branch**: `002-merkle-uhoh` | **Date**: October 8, 2025 | **Spec**: [spec.md](./spec.md)
**Input**: Feature specification from `/specs/002-merkle-uhoh/spec.md`

## Execution Flow (/plan command scope)
```
1. Load feature spec from Input path ✓
   → Spec found and loaded successfully
2. Fill Technical Context ✓
   → Project Type: Web3 application (Solidity contracts + JavaScript frontend + Owner tooling)
   → Structure Decision: Contracts + Frontend + Scripts (manual operations workflow)
3. Fill the Constitution Check section ✓
4. Evaluate Constitution Check section ✓
   → No violations detected - comprehensive constitutional compliance
   → Update Progress Tracking: Initial Constitution Check PASS
5. Execute Phase 0 → research.md ✓
6. Execute Phase 1 → contracts, data-model.md, quickstart.md, AGENT.md ✓
7. Re-evaluate Constitution Check section ✓
   → No new violations - design aligns with constitution
   → Update Progress Tracking: Post-Design Constitution Check PASS
8. Plan Phase 2 → Task generation approach described ✓
9. STOP - Ready for /tasks command ✓
```

**IMPORTANT**: The /plan command STOPS at step 9. Phases 2-4 are executed by other commands:
- Phase 2: /tasks command creates tasks.md
- Phase 3-4: Implementation execution (manual or via tools)

## Summary

This feature implements a complete PEPEDAWN betting platform with:

**Core Functionality** (47 Functional Requirements):
1. **Betting & Puzzle Proofs** (FR-001 to FR-027): Ethereum wallet integration, 2-week rounds, tiered pricing (1/5/10 tickets), puzzle proof weighting (+40%), denylist enforcement, per-wallet betting caps, minimum ticket thresholds, weighted lottery, refund mechanism
2. **Round Lifecycle** (FR-028): Fully manual owner-controlled state transitions (snapshot → requestVRF → commitWinners → close)
3. **IPFS Integration** (FR-029): Off-chain file generation with provided scripts, owner uploads to free IPFS services, CID commitment on-chain
4. **Storage Efficiency** (FR-030): Indefinite on-chain retention using Merkle roots, events for detailed data, support for 100+ rounds
5. **UI/UX** (FR-031 to FR-047): Six round states, Merkle verification with badges, claims system, refund withdrawals, mobile responsive, observability

**Operational Model**:
- **Manual Owner Workflow**: Owner runs scripts locally to manage round transitions and IPFS uploads
- **Contract-Held Prizes**: Contract owns Emblem Vault NFTs; winners claim via pull-payment with Merkle proofs
- **External VRF**: Owner manages Chainlink VRF subscription externally (funds with LINK)
- **Cost Optimization**: No hosting required, free IPFS pinning, minimal infrastructure

**Technical Approach**:
- **Smart Contract**: Extend PepedawnRaffle with Merkle root storage, NFT custody, claims mapping, efficient events
- **Frontend**: IPFS integration, client-side Merkle proof generation, real-time state visualization, mobile-first design
- **Owner Tools**: Scripts for snapshot generation, IPFS upload automation, round management, VRF coordination

## Technical Context

**Smart Contracts**:
- **Language/Version**: Solidity ^0.8.20
- **Framework**: Foundry (forge-std)
- **Primary Dependencies**: OpenZeppelin Contracts v5.x (ERC721Holder, MerkleProof, ReentrancyGuard, Ownable2Step), Chainlink VRF v2.5
- **Storage**: Ethereum blockchain (Sepolia testnet, mainnet)
- **Testing**: Forge test suite (unit tests, fuzz tests, integration tests)
- **Target Platform**: Ethereum mainnet + Sepolia testnet
- **Performance Goals**: Gas-optimized for 500+ participants, <200K gas per claim
- **Constraints**: No upgradeable contracts, owner-controlled operations, pull-payment pattern

**Frontend**:
- **Language/Version**: JavaScript (ES2020+)
- **Framework**: Vite 5.x (vanilla JS)
- **Primary Dependencies**: 
  - Web3 interaction: ethers.js v6 or viem
  - Merkle trees: merkletreejs
  - IPFS: ipfs-http-client or fetch with gateway fallbacks
- **Testing**: Vitest with contract mocks (SKIP THIS FOR NOW)
- **Target Platform**: Modern browsers (Chrome 90+, Firefox 88+, Safari 14+) + mobile browsers (iOS Safari, Chrome Mobile)
- **Performance Goals**: 
  - IPFS fetch: <60s with timeout
  - Merkle proof generation: <500ms for 1000 participants
  - UI state updates: <100ms perceived latency
- **Constraints**: 
  - Client-side verification (no backend)
  - Touch-friendly UI (≥44x44px tap targets)
  - Top 20 leaderboard + expand for full list

**Owner Tools**:
- **Language/Version**: Node.js 18+ (JavaScript/TypeScript)
- **Framework**: CLI scripts (commander.js or yargs)
- **Primary Dependencies**: ethers.js, merkletreejs, IPFS pinning SDK (NFT.Storage, Web3.Storage, or Pinata)
- **Storage**: Local filesystem for temp files, IPFS for published files
- **Testing**: Manual validation + unit tests for critical logic
- **Target Platform**: Windows/Linux(WSL2) terminal
- **Performance Goals**: <30 seconds per round transition
- **Constraints**: Clear step-by-step instructions, error recovery guidance

**Project Type**: Web3 application (Solidity contracts + JavaScript frontend + Node.js scripts)

**Scale/Scope**:
- 10 rounds per counterparty asset (total of 100 cards)
- 10-500+ participants per round
- 10 prize slots per round
- 100+ historical rounds stored on-chain
- Unlimited IPFS file retention
- Multiple claims per winner (up to ticket count)

## Constitution Check
*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

### VRF Fairness ✅ PASS
- **VRF Provider**: Chainlink VRF v2.5 on Ethereum (FR-021)
- **Network Config**: Owner manages external subscription via Chainlink dashboard/CLI; subscription ID configured at deployment
- **Reproducibility**: VRF seed displayed in UI from `RandomnessFulfilled` event; deterministic winner derivation documented in Winners File
- **No Off-Chain Salts**: All randomness derived from on-chain VRF callback; seed immutable once fulfilled
- **Snapshot Timing**: Participants snapshotted (FR-008) before VRF request; participantsRoot committed on-chain; Participants File generated and uploaded to IPFS

### On-Chain Wager & Escrow ✅ PASS
- **Round Lifecycle**: Six states (Open → Snapshotted → VRFRequested → VRFFulfilled → WinnersCommitted → Closed) with manual owner transitions (FR-028)
- **Parameters**: Min stake 0.005 ETH, bundle discounts (5-ticket: 10%, 10-ticket: 20%), max 1.0 ETH per wallet per round (FR-017, FR-023)
- **Fee Schedule**: 80% to creators, 20% retained for next round (FR-024)
- **Minimum Threshold**: 10 tickets required for distribution; <10 tickets triggers full refund (FR-025)
- **Events**: Round lifecycle, wagers, proofs, randomness, winners, claims, refunds, fee distributions (FR-011)
- **Queries**: Round status, ticket counts, effective weights, Merkle roots, claim status, refund balances (FR-012)

### Skill-Weighted Odds via Puzzle Proofs ✅ PASS
- **Submission Method**: On-chain proof hash submission via `submitProof()` (FR-006, FR-019)
- **Formula**: +40% weight multiplier (1.4x) for valid proof; hard cap enforced (FR-019)
- **Validation**: Proof must match owner-set valid hash per round; only one attempt per wallet per round
- **Anti-Abuse**: One submission per wallet (success or fail); must wager before submitting proof; denylisted wallets blocked (FR-018)
- **Events**: ProofSubmitted (success/fail), weight adjustments factored into Participants File

### Emblem Vault Distribution ✅ PASS
- **Prize Tiers**: 1st place: Fake Pack (3 cards), 2nd place: Kek Pack (2 cards), 3rd-10th place: Pepe Pack (1 card each) (FR-002)
- **Pre-Commitment**: Owner transfers 10 Emblem Vault NFTs to contract before round opens; token IDs mapped to prize tiers (FR-020)
- **Transfer Method**: Pull-payment via `claim(roundId, prizeIndex, prizeTier, proof)` with Merkle proof verification (FR-010, FR-033, FR-034)
- **Contract Custody**: NFTs held in contract until claimed; unclaimed prizes remain claimable indefinitely (FR-020, FR-045)
- **Mapping**: Winners File maps addresses to prize slots; winnersRoot committed on-chain; each claim emits event with winner, tier, NFT ID (FR-010)

### Spec-First, Test-First, Observability ✅ PASS
- **Spec**: Complete specification with 47 functional requirements, 10 clarifications, comprehensive acceptance scenarios
- **Tests**: Unit tests for Merkle verification, claims, refunds, state transitions; fuzz tests for weighted selection; integration tests for full round lifecycle (SKIP FULL ROUND TESTS FOR NOW)
- **Events**: Structured events for all lifecycle transitions, user actions, errors (FR-011, FR-043, FR-046)
- **Endpoints**: Contract read functions for all state (rounds, weights, roots, claims, refunds); frontend displays all data (FR-012, FR-031-047)
- **Observability**: Frontend logs errors (failed claims, IPFS timeouts) and critical actions (claims submitted, refunds withdrawn, Merkle verification) (FR-046)

### Security Requirements ✅ PASS
- **Reentrancy Protection**: ReentrancyGuard on `placeBet()`, `submitProof()`, `claim()`, `withdrawRefund()`, fee distributions
- **Checks-Effects-Interactions**: State updated before external calls (NFT transfers, ETH transfers)
- **Access Control**: Ownable2Step for owner functions (snapshotRound, requestRandomness, commitWinners, closeRound, setDenylistStatus, setPause); onlyVRFCoordinator modifier for fulfillRandomWords
- **Input Validation**: Address validation (not zero, not contract), amount validation (positive, within caps), Merkle proof validation, prize slot bounds (0-9)
- **Emergency Controls**: Pausable for critical operations (betting, claiming); emergencyPause for circuit breaker; denylist for blocking addresses (FR-018, FR-038)
- **External Call Safety**: Pull-payment pattern for prizes and refunds; reentrancy guards on all external calls
- **Winner Selection**: Merkle tree prevents duplicate claims per prize slot; VRF seed immutable; wallet can win multiple prizes up to ticket count (FR-026)
- **Duplicate Prevention**: Claim mapping ensures each prize slot claimed once; claimCounts tracks per-user claims (FR-035, FR-037)

**Status**: PASS - Comprehensive constitutional compliance with appropriate security controls for small-scale site (133 assets, manual operations).

## Project Structure

### Documentation (this feature)
```
specs/002-merkle-uhoh/
├── plan.md              # This file (/plan command output)
├── research.md          # Phase 0 output (/plan command)
├── data-model.md        # Phase 1 output (/plan command)
├── quickstart.md        # Phase 1 output (/plan command)
├── contracts/           # Phase 1 output (/plan command)
│   ├── contract-api.md  # Smart contract interface specifications
│   ├── frontend-api.md  # Frontend integration specifications
│   └── scripts-api.md   # Owner scripts specifications
└── tasks.md             # Phase 2 output (/tasks command - NOT created by /plan)
```

### Source Code (repository root)
```
contracts/
├── src/
│   ├── PepedawnRaffle.sol           # Main contract (extend with Merkle + NFT custody)
│   └── interfaces/
│       └── IEmblemVault.sol          # ERC721 interface for Emblem Vault
└── test/
    ├── MerkleProofs.t.sol            # Merkle proof verification tests
    ├── Claims.t.sol                  # Prize claiming tests
    ├── Refunds.t.sol                 # Refund withdrawal tests
    ├── RoundLifecycle.t.sol          # Manual state transition tests
    └── Integration.t.sol             # Full round flow tests

frontend/
├── src/
│   ├── services/
│   │   ├── merkle.js                 # Merkle tree generation + proof creation
│   │   ├── ipfs.js                   # IPFS file fetching (gateway fallbacks, 60s timeout)
│   │   ├── contract.js               # Contract interaction (ethers.js/viem)
│   │   └── state.js                  # Round state management
│   ├── components/
│   │   ├── RoundStateDisplay.js     # Six-state visualization
│   │   ├── Leaderboard.js           # Live leaderboard (top 20 + expand)
│   │   ├── ClaimButton.js           # Individual claim buttons per prize slot
│   │   ├── RefundButton.js          # Refund withdrawal button
│   │   └── MerkleVerification.js    # Verification badges (✓)
│   ├── ui.js                         # Main UI controller
│   └── styles.css                    # Mobile-responsive styles (≥44px touch targets)
└── test/
    └── merkle.test.js                # Client-side Merkle tests

scripts/
├── cli/
│   ├── snapshot-round.js             # Generate Participants File, upload to IPFS, commit root
│   ├── commit-winners.js             # Generate Winners File, upload to IPFS, commit root
│   ├── manage-round.js               # Unified CLI for round management
│   └── verify-ipfs.js                # Verify IPFS files match on-chain roots
├── lib/
│   ├── merkle.js                     # Shared Merkle tree logic
│   ├── ipfs-upload.js                # IPFS pinning service integration
│   └── contract-utils.js             # Contract query helpers
└── README.md                          # Step-by-step owner instructions
```

## Phase 0: Research (In-Scope)

### Research Areas

1. **Merkle Tree Implementation**
   - Solidity: OpenZeppelin MerkleProof library (battle-tested, gas-efficient)
   - JavaScript: merkletreejs (2.5k+ stars, keccak256 support, browser-compatible)
   - Leaf formats: `keccak256(abi.encode(address, uint128 weight))` for participants; `keccak256(abi.encode(address, uint8 prizeTier, uint8 prizeIndex))` for winners
   - Sorted pairs for deterministic root generation

2. **IPFS Integration**
   - **Pinning Services**: NFT.Storage (free, 100GB), Web3.Storage (free, 1TB), Pinata (free tier: 1GB)
   - **Gateway Strategy**: Primary (Pinata) → Fallback 1 (Infura) → Fallback 2 (Public ipfs.io) → User-provided CID
   - **Timeout Handling**: 60-second fetch limit (FR-039), retry with exponential backoff, "service unavailable" message
   - **Verification**: Client-side Merkle root comparison against on-chain roots (FR-030, FR-032)

3. **ERC721 Integration (Emblem Vault)**
   - **Interface**: IERC721 (OpenZeppelin standard)
   - **Contract Custody**: Contract implements ERC721Holder to receive NFTs (FR-020)
   - **Transfer Method**: `safeTransferFrom(address(this), winner, tokenId)` in claim function (FR-010)
   - **Safety**: ReentrancyGuard on claim; check contract ownership before transfer

4. **Chainlink VRF Subscription Management**
   - **Setup**: Owner creates subscription at vrf.chain.link (FR-021)
   - **Funding**: Owner deposits LINK tokens to subscription
   - **Configuration**: Add contract as consumer; configure keyHash, callbackGasLimit (200K-500K), confirmations (3+)
   - **Monitoring**: Owner monitors LINK balance; low balance alerts recommended

5. **Gas Optimization for Historical Data**
   - **Storage Costs**: ~20K gas per 32-byte slot (Merkle root)
   - **Events**: ~375 gas per log topic + data (cheaper than storage)
   - **Strategy**: Store roots + minimal metadata on-chain; emit detailed data in events; reconstruct from IPFS files
   - **Projection**: 100 rounds × (64 bytes roots + events) ≈ <2M gas total storage cost

6. **Mobile Responsive Design**
   - **Framework**: CSS Grid + Flexbox for adaptive layouts
   - **Touch Targets**: ≥44x44px buttons (FR-047)
   - **Viewport**: Meta viewport tag, responsive breakpoints (320px, 768px, 1024px)
   - **Testing**: Chrome DevTools device emulation, real device testing (iOS Safari, Chrome Mobile)

### Research Artifacts (research.md)
- Merkle library comparison table
- IPFS pinning service comparison
- VRF subscription setup guide (external docs links)
- Gas cost projections for 100+ rounds
- Mobile design patterns reference

## Phase 1: Design (In-Scope)

### 1. Data Model (data-model.md)

**On-Chain Entities**:
- **Round**: Add `participantsRoot`, `winnersRoot`, `participantsCID`, `winnersCID` fields
- **Claim Record**: `mapping(uint256 roundId => mapping(uint8 prizeIndex => address claimer))`
- **Claim Counts**: `mapping(uint256 roundId => mapping(address => uint8 claimCount))`
- **Refund Balance**: `mapping(address => uint256 refundBalance)`
- **Prize Mapping**: `mapping(uint256 roundId => mapping(uint8 prizeIndex => uint256 emblemVaultTokenId))`

**Off-Chain Entities** (IPFS Files):
- **Participants File**: JSON with `{ roundId, totalWeight, participants: [{ address, weight, tickets }], merkle: { root, leafFormat } }`
- **Winners File**: JSON with `{ roundId, vrfSeed, derivation, winners: [{ address, prizeTier, prizeIndex }], merkle: { root, leafFormat } }`

**State Transitions**:
```
Open (betting) 
  → [Owner: snapshotRound() + generate Participants File + upload IPFS + commit root]
Snapshotted (inputs locked)
  → [Owner: requestRandomness()]
VRFRequested (waiting for VRF)
  → [VRF Coordinator: fulfillRandomWords()]
VRFFulfilled (randomness received)
  → [Owner: generate Winners File + upload IPFS + commit root via commitWinners()]
WinnersCommitted (winners finalized)
  → [Users: claim() with Merkle proofs] → [Owner: closeRound()]
Closed (round finalized, historical view)
```

### 2. Contract Interfaces (contracts/contract-api.md)

**New/Modified Functions**:
```solidity
// Owner functions
function snapshotRound(uint256 roundId) external onlyOwner;
function commitParticipantsRoot(uint256 roundId, bytes32 root, string calldata cid) external onlyOwner;
function requestRandomness(uint256 roundId) external onlyOwner;
function commitWinnersRoot(uint256 roundId, bytes32 root, string calldata cid) external onlyOwner;
function commitWinners(uint256 roundId, bytes32 winnersRoot, string calldata cid) external onlyOwner;
function closeRound(uint256 roundId) external onlyOwner;
function setPrizesForRound(uint256 roundId, uint256[] calldata tokenIds) external onlyOwner;

// User functions
function claim(uint256 roundId, uint8 prizeIndex, uint8 prizeTier, bytes32[] calldata proof) external nonReentrant;
function withdrawRefund() external nonReentrant;

// Query functions
function getParticipantsRoot(uint256 roundId) external view returns (bytes32);
function getWinnersRoot(uint256 roundId) external view returns (bytes32);
function getParticipantsCID(uint256 roundId) external view returns (string memory);
function getWinnersCID(uint256 roundId) external view returns (string memory);
function getClaimStatus(uint256 roundId, uint8 prizeIndex) external view returns (address claimer, bool claimed);
function getRefundBalance(address user) external view returns (uint256);
function getRoundState(uint256 roundId) external view returns (RoundState);
```

**Events**:
```solidity
event RoundSnapshotted(uint256 indexed roundId, bytes32 participantsRoot, string participantsCID);
event ParticipantsRootCommitted(uint256 indexed roundId, bytes32 root, string cid);
event RandomnessRequested(uint256 indexed roundId, uint256 requestId);
event RandomnessFulfilled(uint256 indexed roundId, uint256 seed);
event WinnersRootCommitted(uint256 indexed roundId, bytes32 root, string cid);
event WinnersCommitted(uint256 indexed roundId, bytes32 winnersRoot, string winnersCID);
event PrizeClaimed(uint256 indexed roundId, address indexed winner, uint8 prizeIndex, uint8 prizeTier, uint256 emblemVaultTokenId);
event RefundWithdrawn(address indexed user, uint256 amount);
event RoundClosed(uint256 indexed roundId);
```

### 3. Frontend Services (contracts/frontend-api.md)

**Merkle Service** (`services/merkle.js`):
```javascript
class MerkleService {
  generateParticipantsTree(participants) // Returns MerkleTree
  generateWinnersTree(winners) // Returns MerkleTree
  generateProof(tree, leaf) // Returns bytes32[] proof
  verifyProof(proof, root, leaf) // Returns boolean
  reconstructParticipantsFile(roundId) // Queries contract, builds file
  reconstructWinnersFile(roundId) // Queries contract + VRF event, builds file
}
```

**IPFS Service** (`services/ipfs.js`):
```javascript
class IPFSService {
  async fetchFile(cid, timeout = 60000) // Try gateways with timeout
  async fetchWithRetry(cid, maxRetries = 3) // Exponential backoff
  verifyFileRoot(file, onChainRoot) // Client-side verification
}
```

**Contract Service** (`services/contract.js`):
```javascript
class ContractService {
  async getRoundState(roundId)
  async getParticipantsData(roundId) // Returns {root, cid}
  async getWinnersData(roundId) // Returns {root, cid}
  async claim(roundId, prizeIndex, prizeTier, proof)
  async withdrawRefund()
  async getClaimStatus(roundId, prizeIndex)
  async getRefundBalance(address)
}
```

### 4. Owner Scripts (contracts/scripts-api.md)

**Snapshot Script** (`scripts/cli/snapshot-round.js`):
```
USAGE: node snapshot-round.js <roundId>

STEPS:
1. Query contract for all participants in round
2. Calculate effective weights (base + puzzle bonus)
3. Generate Participants File JSON
4. Build Merkle tree and calculate root
5. Upload file to IPFS (prompt for service selection)
6. Display CID and root
7. Call contract.commitParticipantsRoot(roundId, root, cid)
8. Verify on-chain commitment
9. Call contract.snapshotRound(roundId) to transition state

OUTPUT: Participants File CID, Merkle root, transaction hashes
```

**Winners Script** (`scripts/cli/commit-winners.js`):
```
USAGE: node commit-winners.js <roundId>

STEPS:
1. Query contract for VRF seed
2. Query contract for participants root/file
3. Fetch Participants File from IPFS
4. Run deterministic winner selection (reproduce on-chain algorithm)
5. Generate Winners File JSON
6. Build Merkle tree and calculate root
7. Upload file to IPFS
8. Display CID and root
9. Call contract.commitWinners(roundId, winnersRoot, cid)
10. Verify on-chain commitment

OUTPUT: Winners File CID, Merkle root, transaction hash
```

**Management Script** (`scripts/cli/manage-round.js`):
```
USAGE: node manage-round.js <command> <roundId>

COMMANDS:
- snapshot: Run snapshot workflow (calls snapshot-round.js)
- request-vrf: Call contract.requestRandomness()
- commit-winners: Run winners workflow (calls commit-winners.js)
- close: Call contract.closeRound()
- status: Display round state and progress

INTERACTIVE MODE: Guides owner through full round lifecycle step-by-step
```

### 5. Quickstart Guide (quickstart.md)

**Owner Workflow**:
```
1. SETUP (one-time):
   - Create Chainlink VRF subscription at vrf.chain.link
   - Fund subscription with LINK tokens
   - Add contract as consumer
   - Transfer 10 Emblem Vault NFTs to contract
   - Configure IPFS pinning service API keys

2. OPEN ROUND (bi-weekly):
   - Call contract.createRound(startTime, endTime)
   - Call contract.openRound(roundId)
   - Announce round on social media

3. CLOSE ROUND (after 2 weeks):
   - Run: node scripts/cli/snapshot-round.js <roundId>
   - Verify Participants File uploaded and root committed
   - Run: node scripts/cli/manage-round.js request-vrf <roundId>
   - Wait for VRF fulfillment (5-30 minutes)
   - Run: node scripts/cli/commit-winners.js <roundId>
   - Verify Winners File uploaded and root committed
   - Announce winners
   - Run: node scripts/cli/manage-round.js close <roundId>

4. MONITOR:
   - Check VRF subscription LINK balance weekly
   - Monitor IPFS file availability via gateways
   - Track unclaimed prizes and refunds
```

**User Workflow**:
```
1. BETTING:
   - Connect Ethereum wallet
   - Choose tickets (1, 5, or 10)
   - Confirm transaction
   - (Optional) Submit puzzle proof

2. CLAIMING:
   - View round in "Winners finalized" state
   - See "Claim" buttons for won prize slots
   - Click "Claim" button
   - Confirm transaction with Merkle proof
   - Receive Emblem Vault NFT in wallet

3. REFUNDS:
   - View round with <10 tickets in "Closed" state
   - Click "Withdraw Refund"
   - Confirm transaction
   - Receive ETH refund
```

### 6. Agent Guidance (AGENT.md)

**Testing Strategy**:
- Unit tests for Merkle verification (valid/invalid proofs)
- Unit tests for claim function (success, duplicate, invalid proof)
- Unit tests for refund withdrawal (balance, zero balance, reentrancy)
- Fuzz tests for winner selection (distribution fairness, no duplicates per slot)
- Integration tests for full round lifecycle (open → snapshot → VRF → winners → claims → close)

**Implementation Order**:
1. Contract: Add Merkle storage and verification
2. Contract: Add claim and refund functions
3. Contract: Add ERC721Holder for NFT custody
4. Contract: Update state transition functions
5. Scripts: Implement snapshot-round.js
6. Scripts: Implement commit-winners.js
7. Frontend: Add IPFS service
8. Frontend: Add Merkle service
9. Frontend: Update UI for six states
10. Frontend: Add claim buttons
11. Frontend: Add refund button
12. Integration: Test full workflow on testnet

**Gas Optimization Targets**:
- `claim()`: <200K gas per claim
- `withdrawRefund()`: <50K gas
- Merkle verification: ~3K gas per proof element
- Root storage: 20K gas per root

**Mobile Testing Checklist**:
- [ ] Touch targets ≥44x44px
- [ ] Leaderboard scrollable on narrow screens
- [ ] Claim buttons accessible on mobile
- [ ] MetaMask mobile wallet integration works
- [ ] IPFS fetch completes on mobile networks
- [ ] All text readable without zoom

## Phase 2: Task Planning (Out of Scope - /tasks command)

### Approach

When `/tasks` is executed, generate a task breakdown file (`tasks.md`) that organizes implementation into:

**Task Categories**:
1. **Smart Contract Development** (15-20 tasks)
   - Add Merkle storage to Round struct
   - Implement claim function with proof verification
   - Implement withdrawRefund function
   - Add ERC721Holder interface
   - Add state transition functions
   - Write unit tests for each function
   - Write fuzz tests for winner selection
   - Write integration tests for full flow

2. **Owner Scripts Development** (10-15 tasks)
   - Implement snapshot-round.js
   - Implement commit-winners.js
   - Implement manage-round.js
   - Implement IPFS upload integration
   - Write README with step-by-step instructions
   - Test scripts on testnet

3. **Frontend Development** (20-25 tasks)
   - Implement IPFS service with timeout handling
   - Implement Merkle service with proof generation
   - Update round state display for six states
   - Add claim buttons component
   - Add refund button component
   - Add Merkle verification badges
   - Update leaderboard for top 20 + expand
   - Mobile responsive styling
   - Write frontend tests

4. **Integration & Testing** (10-15 tasks)
   - Deploy contract to testnet
   - Create VRF subscription
   - Transfer test NFTs to contract
   - Run full round workflow on testnet
   - Test IPFS file uploads and retrieval
   - Test frontend claim flow
   - Test mobile responsiveness
   - Document findings and issues

**Task Structure**:
- Each task has clear acceptance criteria
- Tasks ordered by dependencies
- Estimated complexity (S/M/L)
- Assigned to contract/scripts/frontend domains

**Dependencies**:
- Contract tasks must complete before scripts can integrate
- Scripts tasks should complete before frontend integration
- All core functionality before UI polish
- Testnet deployment before integration testing

## Progress Tracking

### Execution Checklist
- [x] Load feature spec
- [x] Fill Technical Context
- [x] Fill Constitution Check
- [x] Evaluate Constitution Check (Initial) → PASS
- [x] Phase 0: Research areas identified
- [x] Phase 1: Design artifacts specified
- [x] Re-evaluate Constitution Check (Post-Design) → PASS
- [x] Phase 2: Task generation approach planned
- [x] STOP: Ready for /tasks command

### Artifacts Generated
- [x] plan.md (this file)
- [x] research.md (Phase 0 - COMPLETE)
- [x] data-model.md (Phase 1 - COMPLETE)
- [x] quickstart.md (Phase 1 - COMPLETE)
- [x] contracts/contract-api.md (Phase 1 - COMPLETE)
- [ ] tasks.md (Phase 2 - /tasks command)

### Next Steps
1. ~~Execute Phase 0: Create research.md~~ ✓ COMPLETE
2. ~~Execute Phase 1: Create data-model.md, quickstart.md, contracts/*.md~~ ✓ COMPLETE
3. Run `/tasks` command to generate tasks.md
4. Begin implementation (Phase 3)

---

**Status**: PLANNING & DESIGN COMPLETE (Phases 0-1) ✅
**Next Command**: `/tasks` to generate implementation task breakdown