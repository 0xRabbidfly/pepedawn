# Feature Specification: PEPEDAWN betting site with VRF draws and Emblem Vault prizes

**Feature Branch**: `001-build-a-simple`  
**Created**: 2025-10-05  
**Status**: Draft  
**Input**: User description: "Build a simple web site that allows me to connect my ethereum wallet to bet and possibly win an emblem vault containing the counterparty fake rare asset called PEPEDAWN.\n\nThe web page should indicate the prizes as \n1x Fake Pack (3 PEPEDAWN cards)\n1x Kek Pack (2 PEPEDAWN cards)\n8x Pepe Pack (1 PEPEDAWN card)\n\nThe rules will clearly explain the timeline per round (2 weeks), the betting rules, the settlement via Emblem Vault transfer of asset to winners, and the provable and verifiable randomness.\n\nAs each bet rolls in, the leaderboard will post the wallet address and the percentage chance of winning the Fake Pack only. This list is updated with each incoming bet.\n\nThere should be a very beautiful title page with animation and music and an <enter> button, which takes the user to the main betting page. An additional rules pages will have all the details they require to understand the game. The main page with the betting interface will have the leaderboard immediately below it.\n\nThere is an additional <submit puzzle proof> button that allows wallets to also add a solution to a stenographic or cryptographic puzzle. This will add weight to their overall bet by a certain percentage. Only one submission can ever be made per wallet and only for wallets that have already wagered an amount. The weighting rules will be on the about page to help everyone understand how odds can be modified. The idea here is that those without capital can also engage in puzzle solving to enhance their odds of winning."

## Execution Flow (main)
```
1. Parse user description from Input
   → If empty: ERROR "No feature description provided"
2. Extract key concepts from description
   → Identify: actors, actions, data, constraints
3. For each unclear aspect:
   → Mark with [NEEDS CLARIFICATION: specific question]
4. Fill User Scenarios & Testing section
   → If no clear user flow: ERROR "Cannot determine user scenarios"
5. Generate Functional Requirements
   → Each requirement must be testable
   → Mark ambiguous requirements
6. Identify Key Entities (if data involved)
7. Run Review Checklist
   → If any [NEEDS CLARIFICATION]: WARN "Spec has uncertainties"
   → If implementation details found: ERROR "Remove tech details"
8. Return: SUCCESS (spec ready for planning)
```

---

## ⚡ Quick Guidelines
- ✅ Focus on WHAT users need and WHY
- ❌ Avoid HOW to implement (no tech stack, APIs, code structure)
- 👥 Written for business stakeholders, not developers

### Section Requirements
- **Mandatory sections**: Must be completed for every feature
- **Optional sections**: Include only when relevant to the feature
- When a section doesn't apply, remove it entirely (don't leave as "N/A")

### For AI Generation
When creating this spec from a user prompt:
1. **Mark all ambiguities**: Use [NEEDS CLARIFICATION: specific question] for any assumption you'd need to make
2. **Don't guess**: If the prompt doesn't specify something (e.g., "login system" without auth method), mark it
3. **Think like a tester**: Every vague requirement should fail the "testable and unambiguous" checklist item
4. **Common underspecified areas**:
   - User types and permissions
   - Data retention/deletion policies  
   - Performance targets and scale
   - Error handling behaviors
   - Integration requirements
   - Security/compliance needs

---

## User Scenarios & Testing *(mandatory)*

### Primary User Story
As a wallet holder, I want to connect my Ethereum wallet, place a wager in an
active 2‑week round, optionally submit a valid puzzle proof to increase my odds,
see my wallet appear on the leaderboard with my current percentage chance of
winning the Fake Pack, and—after the round closes—have winners selected via
verifiable on‑chain randomness and receive my prize via Emblem Vault transfer if
I win.

### Acceptance Scenarios
1. **Given** an open round, **When** a user connects a wallet and places a bet,
   **Then** the bet is recorded on-chain and the wallet appears on the
   leaderboard with its percentage chance of the Fake Pack displayed.
2. **Given** a wallet that has already wagered, **When** the user submits a
   valid puzzle proof, **Then** the wallet’s effective weight increases by the
   documented multiplier (capped), and the leaderboard percentage updates.
3. **Given** a round has closed, **When** any wallet attempts to bet, **Then**
   the bet is rejected and an explanation is shown.
4. **Given** a snapshot has been taken, **When** the system requests VRF and
   receives fulfillment, **Then** winners are deterministically reproducible
   from on-chain data and are emitted via events.
5. **Given** winners are assigned, **When** prizes are distributed, **Then** the
   Emblem Vault tokens are transferred to winners’ ETH addresses (or escrowed)
   and the mapping is emitted via events.
6. **Given** the public read endpoints, **When** observers query round status,
   ticket counts, weights, and expected prize counts, **Then** values match
   on-chain state.
7. **Given** a denylisted wallet, **When** it attempts to bet, **Then** the
   system blocks the action per eligibility rules and logs an event.
8. **Given** a wallet that already submitted a proof, **When** it tries again,
   **Then** the submission is rejected with a clear message.

### Edge Cases
- Bet submitted right as round closes → reject with reason; no partial accepts.
- Duplicate proof submissions → reject; event emitted.
- Proof submission before first wager → reject.
- Very small “dust” wagers → enforce min stake; show validation error.
- Leaderboard ties and rounding → deterministic ordering and rounding policy.
- VRF request failure/timeout → retry policy and incident logging.
- Emblem Vault transfer failure → escrow and manual claim path with on-chain
  eligibility proof.
- Prize reserves not pre-committed → round cannot open; operator alerted.
- Wallet disconnects mid-bet → do not create on-chain transaction; show status.

## Requirements *(mandatory)*

### Functional Requirements
- **FR-001**: Users MUST be able to connect an Ethereum wallet to participate.
- **FR-002**: The site MUST clearly display prize tiers:
  - 1x Fake Pack (3 PEPEDAWN cards)
  - 1x Kek Pack (2 PEPEDAWN cards)
  - 8x Pepe Packs (1 PEPEDAWN card)
- **FR-003**: Users MUST be able to place a wager in an open round; wagers are
  recorded on-chain and escrowed until settlement.
- **FR-004**: Each round MUST follow a 2‑week timeline; bets only accepted when
  the round is open; start/end timestamps are immutable once started.
- **FR-005**: The leaderboard MUST show wallet addresses and the percentage
  chance of winning the Fake Pack only; it MUST update with each incoming bet.
- **FR-006**: Users who have wagered MUST be able to submit exactly one puzzle
  proof per wallet per round to increase weight.
- **FR-007**: Weight multipliers from puzzle proofs MUST be deterministic,
  formulaic, and bounded by a hard cap; rules MUST be published.
- **FR-008**: The system MUST snapshot eligible tickets/weights prior to
  requesting randomness; draw inputs MUST be reproducible from on-chain data.
- **FR-009**: Winners MUST be selected using on-chain verifiable randomness
  (e.g., Chainlink VRF v2/v2.5) and be reproducible from request id/seed/block.
- **FR-010**: Prizes MUST be distributed via Emblem Vault transfers to winning
  ETH addresses or escrow with on-chain eligibility proof.
- **FR-011**: The system MUST emit structured events for round lifecycle,
  wagers, proofs, randomness, winners, and prize distributions.
- **FR-012**: Public read-only endpoints MUST expose round status, ticket
  counts, weights, and expected prize counts consistent with on-chain state.
- **FR-013**: The site MUST include a title page (animation + music) with an
  <enter> button leading to the main betting page.
- **FR-014**: The main page MUST include the betting interface with the
  leaderboard immediately below it.
- **FR-015**: A rules/about page MUST explain: round timeline, betting rules,
  settlement via Emblem Vault, provable randomness, and weighting rules.
- **FR-016**: The app MUST present disclaimers and age/jurisdiction gating per
  compliance policy.

- **FR-017**: Pricing and discounts:
  - Minimum stake is 0.005 ETH per ticket.
  - 5-ticket bundle: 10% discount → total 0.0225 ETH.
  - 10-ticket bundle: 20% discount → total 0.04 ETH.

- **FR-018**: Eligibility policy:
  - No allowlist is used.
  - A configurable denylist is allowed and MUST be enforced.
  - Bets from denylisted wallets MUST be blocked and an event MUST be emitted.

- **FR-019**: Puzzle proof weighting:
  - Only one puzzle solution per wallet per round is allowed.
  - An accepted proof increases effective weight by 40% (multiplier = 1.4).
  - A hard cap of +40% additional weight per wallet per round is enforced.

- **FR-020**: Emblem Vault prizes MUST be preloaded into the contract before the
  round opens and automatically distributed at round close once VRF randomness
  is fulfilled.

- **FR-022**: Title page audio assets will be provided by the project creator.
  - Audio title: [TO_BE_PROVIDED]
  - Source URL/hosting: [TO_BE_PROVIDED]
  - License/rights: [TO_BE_PROVIDED]
  - The title page MUST function without audio until placeholders are replaced.

- **FR-023**: Per-round maximum bet cap:
  - A single wallet’s cumulative wagers per round MUST NOT exceed 1.0 ETH.
  - Attempts to exceed this cap MUST be rejected and an event MUST be emitted.

- **FR-021**: Network and VRF configuration:
  - Ethereum only. No non-EVM or L2 networks in scope for this feature.
  - Use the simplest viable Chainlink VRF (v2 or v2.5) on Ethereum.
  - Maintain a single subscription and key hash for the target network.
  - Document subId, keyHash, callbackGasLimit, and confirmations in deploy artifacts.
  - Emit events on randomness requested/fulfilled with request id and block data.

- **FR-024**: Fee schedule:
  - 80% of fees go to the creators’ address(es).
  - Remaining 20% stays in the contract as a reward for the next round.
  - Fees are applied upon settlement at round close.
  - Fee parameters and transfers MUST be emitted via events.

*Requirements needing clarification:*

### Key Entities *(include if feature involves data)*
- **Round**: Identifier, start/end timestamps, parameters (fees, caps, prize
  tiers), status (created/opened/closed/snapshotted/randomness_requested/
  randomness_fulfilled/winners_assigned/prizes_distributed).
- **Wager**: Wallet address, round id, amount, timestamp, tickets/weight,
  escrow status.
- **Wallet**: Address, eligibility status, total effective weight, proof status.
- **PuzzleProof**: Wallet address, round id, proof reference/data, verification
  status, weight multiplier applied.
- **PrizeTier**: Name (Fake/Kek/Pepe), count, description, associated Emblem
  Vault token ids (pre-committed) or minting plan.
- **WinnerAssignment**: Round id, wallet address, prize tier, randomness request
  id/seed/block references; emitted via events.
- **LeaderboardEntry**: Wallet address, Fake Pack odds percentage, rank.
- **DeployArtifacts (docs/ops)**: Contract addresses, ABIs, VRF config, event
  tx hashes for lifecycle, randomness, and prize mapping.

---

## Review & Acceptance Checklist
*GATE: Automated checks run during main() execution*

### Content Quality
- [ ] No implementation details (languages, frameworks, APIs)
- [ ] Focused on user value and business needs
- [ ] Written for non-technical stakeholders
- [ ] All mandatory sections completed

### Requirement Completeness
- [ ] No [NEEDS CLARIFICATION] markers remain
- [ ] Requirements are testable and unambiguous  
- [ ] Success criteria are measurable
- [ ] Scope is clearly bounded
- [ ] Dependencies and assumptions identified

### Constitution Alignment (PEPEDAWN)
- [ ] If randomness involved: Specifies VRF provider and reproducibility from on-chain data
- [ ] If wagers/rounds involved: Defines on-chain storage, lifecycle, and events
- [ ] If puzzle weights involved: Defines submission, formula, caps, and anti-abuse rules
- [ ] If prize distribution involved: Uses Emblem Vault only, tiers pre-committed, event mappings
- [ ] Spec-first and test-first approach explicit; observability requirements listed

---

## Execution Status
*Updated by main() during processing*

- [ ] User description parsed
- [ ] Key concepts extracted
- [ ] Ambiguities marked
- [ ] User scenarios defined
- [ ] Requirements generated
- [ ] Entities identified
- [ ] Review checklist passed

---
