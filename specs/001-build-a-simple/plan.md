
# Implementation Plan: PEPEDAWN betting site with VRF draws and Emblem Vault prizes

**Branch**: `001-build-a-simple` | **Date**: 2025-10-06 | **Spec**: [spec.md](./spec.md)
**Input**: Feature specification from `Z:\Projects\pepedawn\specs\001-build-a-simple\spec.md`

## Execution Flow (/plan command scope)
```
1. Load feature spec from Input path
   → If not found: ERROR "No feature spec at {path}"
2. Fill Technical Context (scan for NEEDS CLARIFICATION)
   → Detect Project Type from file system structure or context (web=frontend+backend, mobile=app+api)
   → Set Structure Decision based on project type
3. Fill the Constitution Check section based on the content of the constitution document.
4. Evaluate Constitution Check section below
   → If violations exist: Document in Complexity Tracking
   → If no justification possible: ERROR "Simplify approach first"
   → Update Progress Tracking: Initial Constitution Check
5. Execute Phase 0 → research.md
   → If NEEDS CLARIFICATION remain: ERROR "Resolve unknowns"
6. Execute Phase 1 → contracts, data-model.md, quickstart.md, and the agent guidance file for the agent (e.g., `AGENT.md`).
7. Re-evaluate Constitution Check section
   → If new violations: Refactor design, return to Phase 1
   → Update Progress Tracking: Post-Design Constitution Check
8. Plan Phase 2 → Describe task generation approach (DO NOT create tasks.md)
9. STOP - Ready for /tasks command
```

**IMPORTANT**: The /plan command STOPS at step 7. Phases 2-4 are executed by other commands:
- Phase 2: /tasks command creates tasks.md
- Phase 3-4: Implementation execution (manual or via tools)

## Summary
Build a skill-weighted decentralized raffle system where users connect Ethereum wallets to place bets in 2-week rounds, optionally submit puzzle proofs for +40% weight multiplier, compete for Emblem Vault prizes (Fake/Kek/Pepe packs containing PEPEDAWN cards), with winners selected via Chainlink VRF and prizes automatically distributed. Technical approach: Vite MPA + vanilla JS (minimal JS), ethers for wallet connection and on-chain reads/writes, Solidity contracts to hold escrow, track weights, request VRF, and distribute prizes.

## Technical Context
**Language/Version**: JavaScript (ES2023) + Solidity 0.8.19  
**Primary Dependencies**: Vite (MPA), ethers v6, Chainlink VRF (v2/v2.5), viem (optional), Foundry (contracts tests)  
**Storage**: On-chain (Ethereum); no off-chain DB  
**Testing**: Foundry (unit/invariant), minimal browser tests (TBD), manual quickstart  
**Target Platform**: Ethereum mainnet/testnet for dev; static site hosting for frontend
**Project Type**: web (frontend) + contracts  
**Performance Goals**: Minimal JS, fast load (<= 100KB JS), snappy wallet connect  
**Constraints**: Ethereum-only, simplest VRF config, no BTC/XCP ops  
**Scale/Scope**: Single MPA site with 3 pages (title, main, rules) + one contracts package

## Constitution Check
*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

This plan satisfies the constitution based on the spec (FR-017..FR-024):

- VRF Fairness:
  - Provider: Chainlink VRF v2/v2.5 on Ethereum (FR-021).
  - Reproducibility: derive from request id, seed, block in events (FR-009/021).
  - No off-chain salts post-wager; tests use deterministic PRNG only.
  - Snapshot eligible tickets/weights before VRF request (FR-008).

- On-Chain Wager & Escrow:
  - Round lifecycle stored on-chain; 2-week duration (FR-004).
  - Min/discounts (FR-017); per-wallet cap 1.0 ETH per round (FR-023).
  - Fee schedule 80/20 creators/next round at settlement; events emitted (FR-024).
  - On-chain queries for balances, tickets, weights, and events (FR-011/012).

- Skill-Weighted Odds via Puzzle Proofs:
  - One proof per wallet per round; +40% weight; hard cap +40% (FR-019).
  - Submission on-chain or signed message verified; events emitted (FR-011/019).

- Emblem Vault Distribution (No BTC/XCP ops):
  - Prize tiers: 1x Fake, 1x Kek, 8x Pepe packs; pre-committed (FR-002/020).
  - Transfer to winners or escrow with eligibility proof (FR-010).
  - Winner-to-vault mapping via events (FR-011).

- Spec-First, Test-First, Observability:
  - Spec: this document and spec.md with comprehensive FR/scenarios.
  - Tests: Foundry unit/invariant/scenario tests planned.
  - Events: structured with correlation/round ids (FR-011).
  - Endpoints: read-only for round status, tickets, weights (FR-012).

- Security Requirements:
  - Reentrancy protection: checks-effects-interactions pattern required.
  - Access control: secure ownership transfer mechanisms required.
  - Input validation: all external parameters validated.
  - Emergency controls: pause functionality for critical operations.
  - Winner selection: duplicate prevention and VRF manipulation protection.

## Project Structure

### Documentation (this feature)
```
specs/001-build-a-simple/
├── plan.md              # This file (/plan command output)
├── research.md          # Phase 0 output (/plan command)
├── data-model.md        # Phase 1 output (/plan command)
├── quickstart.md        # Phase 1 output (/plan command)
├── contracts/           # Phase 1 output (/plan command)
└── tasks.md             # Phase 2 output (/tasks command - NOT created by /plan)
```

### Source Code (repository root)
```
frontend/
├── src/
│   ├── main.js          # Main betting page logic
│   ├── contract-config.js # Contract addresses and ABIs
│   ├── ui.js            # UI components and wallet connection
│   ├── style.css        # Styling
│   └── styles.css       # Additional styles
├── index.html           # Title page with animation/music
├── main.html            # Main betting interface
├── rules.html           # Rules and about page
├── public/              # Static assets
└── dist/                # Built assets

contracts/
├── src/
│   ├── PepedawnRaffle.sol    # Main raffle contract
│   └── PepedawnRaffle-Remix.sol # Remix version
├── test/
│   ├── BasicDeployment.t.sol
│   ├── Round.t.sol
│   ├── Wager.t.sol
│   ├── PuzzleProof.t.sol
│   ├── VRFDraw.t.sol
│   ├── Distribution.t.sol
│   ├── InvariantWeights.t.sol
│   └── ScenarioFullRound.t.sol
├── script/
│   ├── Deploy.s.sol
│   └── TestEnv.s.sol
└── foundry.toml

deploy/
└── artifacts/
    ├── addresses.json
    ├── vrf-config.json
    └── abis/
```

**Structure Decision**: Web application with frontend (Vite MPA) + contracts (Foundry). Existing structure already matches this layout with frontend/ and contracts/ directories at repository root.

## Progress Tracking

- [x] Initial Constitution Check: Passed - all requirements addressed in spec
- [x] Phase 0: research.md - Technology decisions and security requirements documented
- [x] Phase 1: Design artifacts completed
  - [x] data-model.md - Entity definitions and relationships
  - [x] contracts/ - Smart contract and frontend API specifications
  - [x] quickstart.md - Development setup and testing guide
- [x] Post-Design Constitution Check: Passed - design aligns with constitutional requirements

## Phase 0: Outline & Research
1. **Extract unknowns from Technical Context** above:
   - For each NEEDS CLARIFICATION → research task
   - For each dependency → best practices task
   - For each integration → patterns task

2. **Generate and dispatch research agents**:
   ```
   For each unknown in Technical Context:
     Task: "Research {unknown} for {feature context}"
   For each technology choice:
     Task: "Find best practices for {tech} in {domain}"
   ```

3. **Consolidate findings** in `research.md` using format:
   - Decision: [what was chosen]
   - Rationale: [why chosen]
   - Alternatives considered: [what else evaluated]

**Output**: research.md with all NEEDS CLARIFICATION resolved

## Phase 1: Design & Contracts
*Prerequisites: research.md complete*

1. **Extract entities from feature spec** → `data-model.md`:
   - Entity name, fields, relationships
   - Validation rules from requirements
   - State transitions if applicable

2. **Generate API contracts** from functional requirements:
   - For each user action → endpoint
   - Use standard REST/GraphQL patterns
   - Output OpenAPI/GraphQL schema to `/contracts/`

3. **Generate contract tests** from contracts:
   - One test file per endpoint
   - Assert request/response schemas
   - Tests must fail (no implementation yet)

4. **Extract test scenarios** from user stories:
   - Each story → integration test scenario
   - Quickstart test = story validation steps

5. **Update agent file incrementally** (O(1) operation):
   - Run `.specify/scripts/powershell/update-agent-context.ps1 -AgentType <agent>`
     **IMPORTANT**: Execute it exactly as specified above. Do not add or remove any arguments.
   - If exists: Add only NEW tech from current plan
   - Preserve manual additions between markers
   - Update recent changes (keep last 3)
   - Keep under 150 lines for token efficiency
   - Output to repository root

**Output**: data-model.md, /contracts/*, failing tests, quickstart.md, agent-specific file

## Phase 2: Task Planning Approach
*This section describes what the /tasks command will do - DO NOT execute during /plan*

**Task Generation Strategy**:
- Load `.specify/templates/tasks-template.md` as base
- Generate tasks from Phase 1 design docs (contracts, data model, quickstart)
- Each contract → contract test task [P]
- Each entity → model creation task [P] 
- Each user story → integration test task
- Implementation tasks to make tests pass

**Ordering Strategy**:
- TDD order: Tests before implementation 
- Dependency order: Models before services before UI
- Mark [P] for parallel execution (independent files)

**Estimated Output**: 25-30 numbered, ordered tasks in tasks.md

**IMPORTANT**: This phase is executed by the /tasks command, NOT by /plan

## Phase 3+: Future Implementation
*These phases are beyond the scope of the /plan command*

**Phase 3**: Task execution (/tasks command creates tasks.md)  
**Phase 4**: Implementation (execute tasks.md following constitutional principles)  
**Phase 5**: Validation (run tests, execute quickstart.md, performance validation)

## Complexity Tracking
*Fill ONLY if Constitution Check has violations that must be justified*

| Violation | Why Needed | Simpler Alternative Rejected Because |
|-----------|------------|-------------------------------------|
| [e.g., 4th project] | [current need] | [why 3 projects insufficient] |
| [e.g., Repository pattern] | [specific problem] | [why direct DB access insufficient] |


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
- [x] All NEEDS CLARIFICATION resolved
- [x] Complexity deviations documented (none required)

## Post-Design Constitution Check
*Re-evaluation after Phase 1 design completion*

**Status**: ✅ PASSED - Design artifacts fully comply with constitutional requirements

**Security Requirements Compliance** (Constitution v1.1.0):
- ✅ Reentrancy protection: Documented in smart-contract-interface.md security section
- ✅ Access control: Owner-only functions with secure transfer mechanisms planned
- ✅ Input validation: All external parameters validated per interface specifications
- ✅ Emergency controls: Pause functionality included in security considerations
- ✅ Winner selection: Duplicate prevention and VRF manipulation protection specified

**Constitutional Principle Alignment**:
- ✅ VRF Fairness: Chainlink VRF v2/v2.5 with reproducible randomness from request ID/seed/block
- ✅ On-Chain Escrow: Complete round lifecycle with structured event emissions
- ✅ Skill-Weighted Odds: Puzzle proof system with deterministic 40% multiplier and hard cap
- ✅ Emblem Vault Distribution: Prize tiers pre-committed with winner-to-vault mapping via events
- ✅ Spec-First Development: Comprehensive specifications and test-first approach documented
- ✅ Observability: Structured events with correlation IDs and read-only endpoints specified

**Security Integration**: All constitutional v1.1.0 security requirements integrated into design artifacts and will be implemented throughout development phases, not as afterthought.

---
*Based on Constitution v1.1.0 - See `.specify/memory/constitution.md`*
