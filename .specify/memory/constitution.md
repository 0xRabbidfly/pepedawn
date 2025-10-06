<!--
Sync Impact Report
- Version: 1.0.0 → 1.1.0 (security principles expansion)
- Modified principles: Domain Constraints, Security, and Compliance (expanded security requirements)
- Added sections: Enhanced security requirements for access control, input validation, emergency controls
- Removed sections: None
- Templates requiring updates:
  - ✅ .specify/templates/plan-template.md
  - ✅ .specify/templates/spec-template.md
  - ✅ .specify/templates/tasks-template.md
  - ⚠ .specify/templates/commands/*.md (not present)
- Follow-ups: Security audit findings integrated into constitutional requirements
-->

# PEPEDAWN Constitution

## Core Principles

### I. Verifiable Fairness (VRF-backed random draws)
- Rationale: Users must be able to independently verify that winners are selected fairly.
- Rules:
  - Random winner selection MUST use an on-chain verifiable randomness provider (e.g., Chainlink VRF v2/v2.5).
  - All draws MUST be reproducible from on-chain data (request id, seed, block number).
  - No off-chain secret salt may influence outcomes post-wager.
  - Development environments MAY use deterministic PRNG only for tests; never in production.
  - Draw parameters (round id, eligible ticket set, weights) MUST be snapshotted on-chain or provably derivable from on-chain events prior to randomness request.

### II. On-Chain Wager Accounting and Escrow
- Rationale: Bets and weights must be transparent and immutable.
- Rules:
  - All wagers MUST be recorded in an Ethereum smart contract with clear state transitions.
  - Each round has a defined start/end timestamp (multi-week cadence) stored on-chain.
  - ETH wagers are held in the contract until settlement; no off-chain custody.
  - Bet caps, min/max stake, and fee schedule MUST be configurable per round and emitted via events.
  - User balances, ticket counts, and effective weights MUST be queryable on-chain and emitted via events.

### III. Skill-Weighted Odds via Puzzle Proofs
- Rationale: Solving steganographic puzzles increases odds while remaining auditable.
- Rules:
  - Puzzle solutions MUST be submitted on-chain or proven via a signed message verified by the contract.
  - Each unique puzzle per round can increase a wallet’s weight by a bounded multiplier (e.g., +x%) subject to a hard cap.
  - Weight gains MUST be deterministic, formulaic, and publicly documented; no manual overrides.
  - Anti-abuse constraints: one solution per wallet per puzzle; identical solutions across wallets are permitted unless disallowed by spec; total weight cap per wallet MUST be enforced.
  - All accepted solutions/weight adjustments MUST be emitted via events and factored into the pre-randomness snapshot.

### IV. Emblem Vault Distribution; No Direct Bitcoin Chain Touch
- Rationale: We distribute Counterparty fakes (PEPEDAWN) without interacting with Bitcoin directly.
- Rules:
  - Prizes MUST be distributed as Emblem Vault-wrapped assets/NFTs on Ethereum; no direct BTC/XCP chain ops.
  - Prize tiers (Gold/Silver/Bronze packs) and their vault token IDs or minting process MUST be pre-committed per round.
  - Distribution MUST transfer prizes directly to winning ETH addresses or escrow for manual claim with on-chain eligibility proof.
  - Mapping from winners to prize vaults MUST be emitted via events for auditability.

### V. Spec-First, Test-First, and Observability
- Rationale: Predictable delivery and safety depend on specs, tests, and telemetry.
- Rules:
  - Spec-driven development is MANDATORY; feature work begins with specs and tests (Red-Green-Refactor).
  - Contracts MUST include unit tests, invariant/property tests, and scenario tests for rounds, weights, draws, and payouts.
  - Public functions MUST emit structured events; services MUST log structured JSON with correlation ids and round ids.
  - CLI/HTTP interfaces MUST provide read-only endpoints for round status, ticket counts, weights, and expected prize counts.

## Domain Constraints, Security, and Compliance

- Rounds:
  - Duration: multi-week; exact timestamps set per round and immutable once started.
  - Parameters (fees, caps, tier counts) MUST be announced via on-chain events before wagers open.
- Security:
  - Contracts MUST undergo automated static analysis and differential fuzzing in CI; severity HIGH blockers MUST be resolved before deploy.
  - Upgradability (if any) MUST be restricted via timelock + multisig; upgrade intent MUST be announced via events.
  - Payout and randomness code paths MUST have explicit re-entrancy protection, checks-effects-interactions ordering, and pull-pattern withdrawals where applicable.
  - Access Control: All privileged functions MUST implement secure ownership transfer mechanisms; single points of failure in access control are prohibited.
  - Input Validation: All external function parameters MUST be validated; contract addresses MUST be verified as valid contracts where applicable.
  - Emergency Controls: Contracts MUST implement emergency pause functionality for critical operations (betting, prize distribution) with clear governance procedures.
  - External Call Safety: All external calls MUST use the checks-effects-interactions pattern; reentrancy guards MUST be applied to functions making external calls.
  - Winner Selection: Random selection algorithms MUST prevent duplicate winner selection and manipulation; VRF fulfillment MUST be protected against coordinator compromise.
- Compliance and Eligibility:
  - Eligibility rules MUST be configurable; default denylist/allowlist strategy documented.
  - The app MUST present clear disclaimers and age/jurisdiction gating (enforced off-chain in the web tier; on-chain lists where legally required).
- Economics:
  - Fee recipients and percentages MUST be configurable per round and emitted via events.
  - Prize reserves MUST be verifiably funded before wagers open (e.g., vaults pre-minted and escrowed or attestations published).

## Development Workflow, Quality Gates, and Release Policy

- Workflow:
  - All changes require a spec and tests prior to implementation.
  - CI MUST run lint, unit, fuzz/invariant tests, gas snapshots, and contract size checks.
  - Minimum coverage thresholds: contracts ≥ 90% line/branch; critical paths 100% branch on access control and payout.
- Releases:
  - Versioning adheres to SemVer across contracts and services.
  - Deploy artifacts (addresses, ABIs, VRF config) MUST be recorded in repo and announced via events on deployment.
- Runtime Observability:
  - Emit round lifecycle events: created, opened, closed, snapshot_taken, randomness_requested, randomness_fulfilled, winners_assigned, prizes_distributed.
  - Public read endpoints MUST reflect on-chain state; discrepancies are operational incidents.

## Governance

- Authority:
  - This constitution supersedes other practices for randomness, escrow, and prize distribution.
- Amendments:
  - Proposals require rationale, impact, migration plan, and risk assessment.
  - MINOR: add/expand principles/sections; PATCH: clarifications; MAJOR: incompatible governance/principle removals/redefinitions.
  - Amendments require approval by project maintainers (multisig vote or documented consent) and MUST bump version and LAST_AMENDED_DATE.
- Compliance:
  - All PRs MUST reference applicable principles and demonstrate compliance in description/checklist.
  - Merges blocked if CI, security gates, or coverage thresholds fail.
- Records:
  - Maintain a CHANGELOG entry for each constitution update with version, date, and summary of changes.

**Version**: 1.1.0 | **Ratified**: 2025-10-05 | **Last Amended**: 2025-10-06