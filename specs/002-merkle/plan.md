# Implementation Plan: User-Facing Behavior Updates (VRF Seed + Merkle + Claims)

**Branch**: `002-merkle` | **Date**: October 8, 2025 | **Spec**: [spec.md](./spec.md)
**Input**: Feature specification from `/specs/002-merkle/spec.md`

## Execution Flow (/plan command scope)
```
1. Load feature spec from Input path ✓
   → Spec found and loaded successfully
2. Fill Technical Context ✓
   → Project Type: Web3 application (Solidity contracts + JavaScript frontend)
   → Structure Decision: Contracts + Frontend (existing structure)
3. Fill the Constitution Check section ✓
4. Evaluate Constitution Check section ✓
   → No violations detected - feature enhances existing VRF/Merkle implementation
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

This feature enhances the PEPEDAWN raffle system with comprehensive user-facing improvements for VRF seed display, Merkle proof verification, and prize claiming functionality. The implementation focuses on:

1. **Enhanced Round State Visualization**: Six distinct UI states with clear labels and transitions
2. **IPFS File Integration**: Client-side verification of Participants and Winners files with Merkle root validation
3. **Claims System**: Individual prize slot claiming with client-side Merkle proof generation
4. **Pull-Payment Refunds**: User-initiated refund withdrawals with clear status feedback
5. **Mobile-Responsive UI**: Full feature parity across desktop and mobile devices
6. **Observability**: Comprehensive error and action logging for debugging

**Technical Approach**: Extend existing PepedawnRaffle.sol contract with Merkle tree storage and verification, add IPFS integration to frontend, implement client-side Merkle proof generation using ethers.js/viem, and enhance UI components for state management and mobile responsiveness.

## Technical Context

**Smart Contracts**:
- Language/Version: Solidity ^0.8.19
- Framework: Foundry (forge-std)
- Primary Dependencies: OpenZeppelin Contracts, Chainlink VRF v2.5
- Testing: Forge test suite (unit, fuzz)
- Target Platform: Ethereum Sepolia testnet, Ethereum mainnet

**Frontend**:
- Language/Version: JavaScript (ES2020+)
- Framework: Vite 5.x (vanilla JS)
- Primary Dependencies: ethers.js v6 or viem, merkletreejs, ipfs-http-client
- Testing: Vitest or Jest
- Target Platform: Modern browsers (Chrome 90+, Firefox 88+, Safari 14+, mobile browsers)

**Project Type**: Web3 application (Solidity contracts + JavaScript frontend)

**Performance Goals**:
- IPFS file fetch: <60 seconds with timeout handling
- Merkle proof generation: <500ms for trees up to 1000 participants
- UI state transitions: <100ms perceived latency
- Mobile tap targets: ≥44x44px

**Constraints**:
- Client-side verification required (no backend trust)
- Mobile-first responsive design
- Pull-payment pattern for claims and refunds
- 60-second IPFS timeout before "service unavailable"
- Top 20 leaderboard display with "View all" expansion

**Scale/Scope**:
- Support 500+ participants per round
- 10 prize slots per round
- Multiple claims per winner (up to ticket count)
- Historical round data retention

## Constitution Check
*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

### VRF Fairness ✓
- **VRF Provider**: Chainlink VRF v2.5 (existing implementation in PepedawnRaffle.sol)
- **Reproducibility**: VRF seed displayed in UI from `RandomnessReceived` event; deterministic winner selection algorithm documented
- **No Off-Chain Salts**: All randomness derived from on-chain VRF fulfillment
- **Snapshot Timing**: Participants snapshotted before VRF request; participantsRoot committed on-chain

### On-Chain Wager & Escrow ✓
- **Round Lifecycle**: Existing implementation with Open → Snapshotted → VRFRequested → VRFFulfilled → WinnersCommitted → Closed states
- **Parameters**: Bet amounts, caps, and fees already emitted via events
- **Queries**: Enhanced with Merkle root queries for participants and winners

### Skill-Weighted Odds via Puzzle Proofs ✓
- **Submission Method**: Existing on-chain puzzle proof submission
- **Formula**: Existing bounded multipliers and caps
- **Anti-Abuse**: Existing constraints maintained; Merkle tree ensures immutable snapshot

### Emblem Vault Distribution ✓
- **Prize Tiers**: 10 prize slots with deterministic tier assignment from VRF seed
- **Transfer Method**: Pull-payment pattern via `claim()` function with Merkle proof
- **Mapping**: Winners file maps addresses to prize slots; winnersRoot committed on-chain

### Spec-First, Test-First, Observability ✓
- **Spec**: Complete specification with 17 functional requirements and 5 clarifications
- **Tests**: Will generate failing tests for Merkle verification, claims, and UI states
- **Events**: New events for Merkle roots, claims, and refunds
- **Endpoints**: Contract read functions for roots, claim status, refund balances

### Security Requirements ✓
- **Reentrancy Protection**: Existing ReentrancyGuard on claim and refund functions
- **Access Control**: Existing Ownable pattern for privileged functions
- **Input Validation**: Merkle proof validation, address checks, prize slot bounds
- **Emergency Controls**: Existing pause functionality for critical operations
- **Winner Selection**: Merkle tree prevents duplicate claims; VRF seed immutable post-fulfillment

**Status**: PASS - Feature enhances existing constitutional compliance without introducing violations.

## Project Structure

### Documentation (this feature)
```
specs/002-merkle/
├── plan.md              # This file (/plan command output)
├── research.md          # Phase 0 output (/plan command)
├── data-model.md        # Phase 1 output (/plan command)
├── quickstart.md        # Phase 1 output (/plan command)
├── contracts/           # Phase 1 output (/plan command)
│   ├── merkle-api.md    # Contract interface specifications
│   └── frontend-api.md  # Frontend service contracts
└── tasks.md             # Phase 2 output (/tasks command - NOT created by /plan)
```

### Source Code (repository root)
```
contracts/
├── src/
│   ├── PepedawnRaffle.sol       # Main contract (extend with Merkle)
│   └── libraries/
│       └── MerkleVerifier.sol   # Merkle proof verification library
└── test/
    ├── MerkleProofs.t.sol       # Merkle proof tests
    ├── Claims.t.sol             # Prize claiming tests
    └── Refunds.t.sol            # Refund withdrawal tests

frontend/
├── src/
│   ├── services/
│   │   ├── merkle.js            # Merkle tree generation and proof creation
│   │   ├── ipfs.js              # IPFS file fetching with timeout
│   │   └── claims.js            # Claims and refunds logic
│   ├── components/
│   │   ├── RoundStateDisplay.js # Round state UI component
│   │   ├── LeaderboardView.js   # Leaderboard with pagination
│   │   ├── ClaimButton.js       # Individual claim button
│   │   └── VerificationBadge.js # Merkle verification badge
│   └── utils/
│       ├── logger.js            # Observability logging
│       └── mobile.js            # Mobile-specific utilities
└── tests/
    ├── merkle.test.js           # Merkle service tests
    ├── ipfs.test.js             # IPFS service tests
    └── claims.test.js           # Claims service tests

deploy/
└── artifacts/
    └── merkle/                  # Merkle tree artifacts per round
        ├── participants-{roundId}.json
        └── winners-{roundId}.json
```

**Structure Decision**: Web3 application with Solidity contracts (Foundry) and JavaScript frontend (Vite). Extends existing contract and frontend structure with Merkle proof functionality, IPFS integration, and enhanced UI components.

## Phase 0: Outline & Research

**Research Tasks Identified**:
1. Merkle tree libraries for Solidity (OpenZeppelin MerkleProof vs custom)
2. JavaScript Merkle tree libraries (merkletreejs vs @openzeppelin/merkle-tree)
3. IPFS client libraries and gateway strategies
4. Mobile wallet integration patterns (MetaMask mobile, WalletConnect)
5. Client-side proof generation performance optimization

**Output**: See [research.md](./research.md) for detailed findings and decisions.

## Phase 1: Design & Contracts

**Data Model**: See [data-model.md](./data-model.md) for entity definitions and relationships.

**Contract Interfaces**: See [contracts/merkle-api.md](./contracts/merkle-api.md) for smart contract API specifications.

**Frontend Services**: See [contracts/frontend-api.md](./contracts/frontend-api.md) for JavaScript service contracts.

**Quickstart Guide**: See [quickstart.md](./quickstart.md) for development setup and testing procedures.

**Agent Context**: See [AGENT.md](../../AGENT.md) for AI assistant guidance (updated incrementally).

## Phase 2: Task Planning Approach
*This section describes what the /tasks command will do - DO NOT execute during /plan*

**Task Generation Strategy**:
1. Load `.specify/templates/tasks-template.md` as base
2. Generate tasks from Phase 1 design docs:
   - **Contract Tasks**: Merkle storage, verification functions, claim/refund logic
   - **Frontend Tasks**: IPFS integration, Merkle proof generation, UI components
   - **Test Tasks**: Contract tests (unit, fuzz), frontend tests

**Ordering Strategy**:
- **TDD Order**: Tests before implementation
- **Dependency Order**:
  1. Contract Merkle storage and events
  2. Contract claim/refund functions
  3. Frontend Merkle service (proof generation)
  4. Frontend IPFS service (file fetching)
  5. Frontend UI components (state display, claims)
  6. mobile testing
- **Parallel Execution**: Mark [P] for independent tasks (e.g., separate contract functions, independent UI components)

**Estimated Output**: 30-35 numbered, ordered tasks in tasks.md

**Task Categories**:
- Smart Contract: 8-10 tasks (storage, functions, events, tests)
- Frontend Services: 6-8 tasks (Merkle, IPFS, claims, logging)
- UI Components: 8-10 tasks (state display, leaderboard, claim buttons, mobile)
- Testing: 6-8 tasks (contract tests, frontend tests, mobile)
- Documentation: 2-3 tasks (deployment guide, user guide)

**IMPORTANT**: This phase is executed by the /tasks command, NOT by /plan

## Phase 3+: Future Implementation
*These phases are beyond the scope of the /plan command*

**Phase 3**: Task execution (/tasks command creates tasks.md)  
**Phase 4**: Implementation (execute tasks.md following constitutional principles)  
**Phase 5**: Validation (run tests, execute quickstart.md, performance validation)

## Complexity Tracking
*Fill ONLY if Constitution Check has violations that must be justified*

No violations detected. Feature enhances existing implementation without introducing constitutional deviations.

## Progress Tracking
*This checklist is updated during execution flow*

**Phase Status**:
- [x] Phase 0: Research complete (/plan command)
- [x] Phase 1: Design complete (/plan command)
- [x] Phase 2: Task planning complete (/plan command - describe approach only)
- [ ] Phase 3: Tasks generated (/tasks command)
- [ ] Phase 4: Implementation complete
- [ ] Phase 5: Validation passed

**Gate Status**:
- [x] Initial Constitution Check: PASS
- [x] Post-Design Constitution Check: PASS
- [x] All NEEDS CLARIFICATION resolved (5 clarifications documented)
- [x] Complexity deviations documented (none)

---
*Based on Constitution v1.1.0 - See `.specify/memory/constitution.md`*
