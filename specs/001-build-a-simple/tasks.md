# Tasks: PEPEDAWN betting site (wallet bets, VRF draws, Emblem Vault prizes)

**Input**: Design documents from `Z:\Projects\pepedawn\specs\001-build-a-simple\`
**Prerequisites**: plan.md (required), research.md, data-model.md, contracts/

## Execution Flow (main)
```
1. Load plan.md from feature directory
   → If not found: ERROR "No implementation plan found"
   → Extract: tech stack, libraries, structure
2. Load optional design documents:
   → data-model.md: Extract entities → model tasks
   → contracts/: Each file → contract test task
   → research.md: Extract decisions → setup tasks
   → quickstart.md: Extract scenarios → integration tests
3. Generate tasks by category:
   → Setup: project init, dependencies, linting
   → Tests: contract tests, integration tests
   → Core: models, services, CLI commands
   → Integration: event logging, read views
   → Polish: unit tests, performance, docs
4. Apply task rules:
   → Different files = mark [P] for parallel
   → Same file = sequential (no [P])
   → Tests before implementation (TDD)
5. Number tasks sequentially (T001, T002...)
6. Generate dependency graph
7. Create parallel execution examples
8. Validate task completeness
```

## Path Conventions
- Frontend: `frontend/` (Vite MPA + vanilla)
- Contracts: `contracts/` (Foundry)
- Deploy artifacts: `deploy/artifacts/`

## Phase 3.1: Setup
- [X] T001 Initialize Vite MPA in `frontend/` with vanilla template
- [X] T002 Install ethers v6 in `frontend/` and set up minimal bundling
- [X] T003 Create `frontend/index.html`, `frontend/main.html`, `frontend/rules.html`
- [X] T004 [P] Add `frontend/src/main.js`, `frontend/src/ui.js`, `frontend/src/styles.css`
- [X] T005 Initialize Foundry project in `contracts/`
- [X] T006 [P] Create `deploy/artifacts/README.md` and structure for addresses/ABIs/VRF config

## Phase 3.2: Tests First (TDD) ⚠️ MUST COMPLETE BEFORE 3.3
- [X] T007 Create Foundry unit test stubs in `contracts/test/Round.t.sol` (round lifecycle)
- [X] T008 [P] Create `contracts/test/Wager.t.sol` (wagers, caps, min pricing bundles)
- [X] T009 [P] Create `contracts/test/PuzzleProof.t.sol` (one-proof rule, +40% cap)
- [X] T010 [P] Create `contracts/test/VRFDraw.t.sol` (snapshot, request, fulfill randomness)
- [X] T011 [P] Create `contracts/test/Distribution.t.sol` (prize mapping and Emblem Vault transfers)
- [X] T012 [P] Create invariant tests in `contracts/test/InvariantWeights.t.sol` (weights monotonic caps)
- [X] T013 Create scenario tests in `contracts/test/ScenarioFullRound.t.sol` (open→bet→proof→snapshot→VRF→assign→distribute)

## Phase 3.3: Core Implementation (ONLY after tests are failing)
- [X] T014 Implement `contracts/src/PepedawnRaffle.sol` skeleton (events, structs, storage)
- [X] T015 Add round lifecycle functions: createRound, openRound, closeRound, snapshot (checks-effects-interactions)
- [X] T016 Add wager intake: validate min 0.005 ETH, bundles (5=0.0225, 10=0.04), per-wallet cap 1.0 ETH
- [X] T017 Emit events for wagers (wallet, amount, tickets, effective weight)
- [X] T018 Implement proof submission: one per wallet/round, +40% multiplier, hard cap enforcement
- [X] T019 Add read views: round status, ticket counts, weights, expected prize counts
- [X] T020 Integrate VRF config (subId, keyHash, callbackGasLimit, confirmations) and request/fulfill handlers
- [X] T021 Snapshot draw parameters pre‑VRF (eligible set, weights) and store references
- [X] T022 Assign winners from VRF output, emit mapping events wallet→prize tier
- [X] T023 Preload Emblem Vault assets; add auto-distribution at round close post‑VRF
- [X] T024 Apply fee schedule at settlement: 80% creators, 20% retained; emit fee events

## Phase 3.4: Frontend Integration
- [X] T025 Wire wallet connect with ethers in `frontend/src/main.js`
- [X] T026 Render prize tiers and round status on `frontend/main.html`
- [X] T027 Implement wager form (ticket count: 1, 5, 10 bundles), call contract, show tx status
- [X] T028 Render live leaderboard under betting UI (pull from views/events)
- [X] T029 Implement `Submit Puzzle Proof` flow; enforce one submission post-wager
- [X] T030 Build rules/about page content from spec (timeline, randomness, EV distribution, weights)

## Phase 3.5: Observability & Governance
- [X] T031 [P] Ensure all events structured with round id and correlation id (where applicable)
- [X] T032 [P] Document and record deploy artifacts (addresses, ABIs, VRF config) in `deploy/artifacts/`
- [X] T033 [P] Add a simple `status` panel in `frontend/main.html` calling read views for round status, tickets, weights, expected prizes

## Phase 3.6: Validation & Polish
- [X] T034 [P] Expand unit tests for pricing math and rounding
- [X] T035 [P] Expand invariant tests on caps and single-proof rule
- [X] T036 [P] Performance: ensure <= 100KB JS and fast wallet connect
- [X] T037 [P] Docs: update `README.md` with quickstart steps and links to artifacts

## Dependencies
- T007–T013 (tests) MUST fail before implementing T014–T024
- T014 blocks T015–T024
- T016 blocks frontend wager submission (T027)
- T018 blocks frontend proof submission (T029)
- T019 blocks status panel (T033) and leaderboard (T028)
- T020–T022 block distribution (T023)

## Parallel Execution Example
```
# After creating test stubs, run these in parallel:
Task: "Create contracts/test/Wager.t.sol"
Task: "Create contracts/test/PuzzleProof.t.sol"
Task: "Create contracts/test/VRFDraw.t.sol"
Task: "Create contracts/test/Distribution.t.sol"
Task: "Create contracts/test/InvariantWeights.t.sol"
```

## Validation Checklist
- [ ] All contract files have corresponding tests
- [ ] All entities have coverage in tests or read views
- [ ] Tests precede implementation (TDD)
- [ ] Parallel tasks touch different files
- [ ] Each task references exact file paths
