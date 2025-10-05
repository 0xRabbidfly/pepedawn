
# Implementation Plan: PEPEDAWN betting site (wallet bets, VRF draws, Emblem Vault prizes)

**Branch**: `001-build-a-simple` | **Date**: 2025-10-05 | **Spec**: Z:\Projects\pepedawn\specs\001-build-a-simple\spec.md
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
Build a minimal, fast web experience to place on-chain wagers for a 2-week
round, show a live leaderboard, accept one puzzle proof per wallet to increase
odds, draw winners using Chainlink VRF on Ethereum, and distribute Emblem Vault
prizes automatically. Technical approach: Vite MPA + vanilla JS (minimal JS),
ethers for wallet connection and on-chain reads/writes, Solidity contracts to
hold escrow, track weights, request VRF, and distribute prizes.

## Technical Context
**Language/Version**: JavaScript (ES2023) + Solidity 0.8.x  
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
  - Prize tiers per spec; assets preloaded; auto-distribution post-VRF (FR-020).
  - Winners→vault mapping events (FR-011/020).

- Spec-First, Test-First, Observability:
  - Contracts tests: unit, invariant; scenario tests for rounds/draws/payouts.
  - Structured events with round id/correlation id; read-only endpoints (FR-012).

## Project Structure

### Documentation (this feature)
```
specs/[###-feature]/
├── plan.md              # This file (/plan command output)
├── research.md          # Phase 0 output (/plan command)
├── data-model.md        # Phase 1 output (/plan command)
├── quickstart.md        # Phase 1 output (/plan command)
├── contracts/           # Phase 1 output (/plan command)
└── tasks.md             # Phase 2 output (/tasks command - NOT created by /plan)
```

### Source Code (repository root)
<!--
  ACTION REQUIRED: Replace the placeholder tree below with the concrete layout
  for this feature. Delete unused options and expand the chosen structure with
  real paths (e.g., apps/admin, packages/something). The delivered plan must
  not include Option labels.
-->
```
# [REMOVE IF UNUSED] Option 1: Single project (DEFAULT)
src/
├── models/
├── services/
├── cli/
└── lib/

tests/
├── contract/
├── integration/
└── unit/

# [REMOVE IF UNUSED] Option 2: Web application (when "frontend" + "backend" detected)
backend/
├── src/
│   ├── models/
│   ├── services/
│   └── api/
└── tests/

frontend/
├── src/
│   ├── components/
│   ├── pages/
│   └── services/
└── tests/

# [REMOVE IF UNUSED] Option 3: Mobile + API (when "iOS/Android" detected)
api/
└── [same as backend above]

ios/ or android/
└── [platform-specific structure: feature modules, UI flows, platform tests]
```

**Structure Decision**: Web + contracts
```
frontend/ (Vite MPA + vanilla)
├── index.html            # title page (animation, music, enter button)
├── rules.html            # rules/about page
├── main.html             # betting UI + leaderboard
├── src/
│   ├── main.js          # minimal JS to wire wallet connect (ethers)
│   ├── ui.js            # DOM helpers; no framework
│   └── styles.css       # minimal styles
└── assets/              # images/audio (audio placeholders until FR-022 filled)

contracts/
├── src/
│   └── PepedawnRaffle.sol
└── test/                # Foundry tests: unit + invariant

deploy/
└── artifacts/           # addresses, ABIs, VRF config, event refs
```

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
- [ ] Complexity deviations documented

---
*Based on Constitution v1.0.0 - See `.specify/memory/constitution.md`*
