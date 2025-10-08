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
active 2‑week round, optionally submit a valid puzzle proof to increase my odds
by 40%, see my wallet appear on the leaderboard with my current percentage
chance of winning, track progress toward the 10-ticket minimum required for
distribution, and—after the round closes—either receive my prize via Emblem
Vault transfer if I win and the round met the minimum, or receive a full refund
if the round had fewer than 10 tickets, with all outcomes verifiable through
on‑chain randomness and events.

### Acceptance Scenarios
1. **Given** an open round, **When** a user connects a wallet and places a bet,
   **Then** the bet is recorded on-chain, the wallet appears on the leaderboard
   with its percentage chance displayed, and the progress bar updates showing
   tickets toward the 10-ticket minimum.
2. **Given** the owner has set a valid proof hash for a round and a wallet has
   wagered, **When** the user submits a matching proof, **Then** the wallet's
   effective weight increases by 40%, the leaderboard updates, and success
   feedback is shown.
3. **Given** a wallet that has already wagered, **When** the user submits an
   INCORRECT proof hash, **Then** the proof is rejected, no weight bonus is
   applied, the attempt is consumed, and failure feedback is shown.
4. **Given** a round has closed with 10+ tickets, **When** VRF is requested and
   fulfilled, **Then** 10 winners are selected (1st place gets Fake pack, 2nd
   place gets Kek pack, 3rd-10th place each get Pepe pack), and winners are
   reproducible from on-chain data.
5. **Given** a round has closed with fewer than 10 tickets, **When** the round
   is processed, **Then** ALL participants are refunded their full wager
   amount, no fees are collected, and refund events are emitted.
6. **Given** a round with 10+ tickets and weighted distribution, **When**
   winners are selected, **Then** wallets with higher weight have
   proportionally higher odds, and the same wallet CAN appear as multiple
   winners.
7. **Given** winners are assigned, **When** prizes are distributed, **Then**
   the 1st place winner receives Fake pack, 2nd place receives Kek pack,
   3rd-10th place winners each receive one Pepe pack, and Emblem Vault
   assignment events are emitted.
8. **Given** the public read endpoints, **When** observers query round status,
   ticket counts, weights, and progress toward minimum, **Then** values match
   on-chain state.
9. **Given** a denylisted wallet, **When** it attempts to bet, **Then** the
   system blocks the action per eligibility rules and logs an event.
10. **Given** a wallet that already submitted a proof attempt (success or
    fail), **When** it tries again in the same round, **Then** the submission
    is rejected with a clear message.

### Edge Cases
- Bet submitted right as round closes → reject with reason; no partial accepts.
- Duplicate proof submissions → reject; event emitted; only one attempt allowed.
- Proof submission before first wager → reject.
- Incorrect proof submission → reject, consume attempt, show failure message.
- Very small "dust" wagers → enforce min stake; show validation error.
- Round closes with exactly 10 tickets → process normally with VRF draw.
- Round closes with 9 or fewer tickets → refund all participants, no VRF.
- Leaderboard shows 0% odds if under 10 tickets → warn users of potential refund.
- VRF request on round under 10 tickets → blocked; must refund first.
- Same wallet wins multiple prizes → allowed; emit separate events per prize.
- Wallet wins 1st place → receives Fake pack (highest tier, 3 cards).
- Refund processing when contract has insufficient ETH → should never happen
  (escrowed funds); emergency circuit breaker if detected.
- VRF request failure/timeout → retry policy and incident logging.
- Emblem Vault transfer failure → escrow and manual claim path with on-chain
  eligibility proof.
- Owner forgets to set valid proof before opening round → proofs cannot succeed.
- Wallet disconnects mid-bet → do not create on-chain transaction; show status.

## Requirements *(mandatory)*

### Functional Requirements
- **FR-001**: Users MUST be able to connect an Ethereum wallet to participate.
- **FR-002**: The site MUST clearly display prize tiers and distribution:
  - 1st place: 1x Fake Pack (3 PEPEDAWN cards bundled in one Emblem Vault)
  - 2nd place: 1x Kek Pack (2 PEPEDAWN cards bundled in one Emblem Vault)
  - 3rd-10th place: 1x Pepe Pack each (1 PEPEDAWN card per Emblem Vault)
  - Total: 10 winners per round, 10 prize packs distributed
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
  - The contract owner MUST set a valid proof hash per round before the round opens.
  - Users submit their proof attempt; it MUST match the valid proof hash exactly.
  - Only one puzzle solution attempt per wallet per round is allowed (success or fail).
  - An accepted proof increases effective weight by 40% (multiplier = 1.4).
  - A hard cap of +40% additional weight per wallet per round is enforced.
  - The UI MUST show immediate feedback on proof submission success or failure.

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
  - 80% of fees go to the creators' address(es).
  - Remaining 20% stays in the contract as a reward for the next round.
  - Fees are applied upon settlement at round close.
  - Fee parameters and transfers MUST be emitted via events.

- **FR-025**: Minimum ticket threshold and refund mechanism:
  - A round MUST have at least 10 total tickets purchased to be eligible for distribution.
  - If a round closes with fewer than 10 tickets, ALL participants MUST be refunded their full wager amount.
  - Refunds MUST be processed from the contract's ETH balance.
  - No fees are collected on refunded rounds.
  - Refund events MUST be emitted for each participant.

- **FR-026**: Winner selection (weighted lottery):
  - Winners are selected using weighted randomization based on total effective weight.
  - A wallet with more tickets/weight has proportionally higher odds of winning each prize.
  - The same wallet address CAN win multiple prizes in a single round.
  - Each prize is drawn independently; duplicate winners across different prizes are allowed.
  - Winner selection algorithm MUST be deterministic and reproducible from VRF seed.

- **FR-027**: Leaderboard and progress tracking:
  - The leaderboard MUST display all participating wallets with their current odds.
  - A progress indicator MUST show tickets purchased toward the 10-ticket minimum.
  - Progress bar format: "X / 10 tickets needed for round distribution"
  - If threshold not met by round end, participants MUST be notified of pending refund.

*Requirements needing clarification:*

### Key Entities *(include if feature involves data)*
- **Round**: Identifier, start/end timestamps, parameters (fees, caps, prize
  tiers), status (created/opened/closed/snapshotted/randomness_requested/
  randomness_fulfilled/winners_assigned/prizes_distributed/refunded), valid
  proof hash (set by owner), minimum ticket threshold (10), meets threshold
  boolean.
- **Wager**: Wallet address, round id, amount, timestamp, tickets/weight,
  escrow status, refund status.
- **Wallet**: Address, eligibility status, total effective weight, proof
  submission status (not_attempted/success/failed).
- **PuzzleProof**: Wallet address, round id, proof hash submitted, verification
  status (matched/not_matched), weight multiplier applied (0 or 1.4x), valid
  proof hash for round (set by owner).
- **PrizeTier**: 
  - 1st place: Fake Pack (3 cards bundled in one Emblem Vault)
  - 2nd place: Kek Pack (2 cards bundled in one Emblem Vault)
  - 3rd-10th place: Pepe Pack (1 card per Emblem Vault, 8 total packs)
  - Associated Emblem Vault token ids (pre-committed).
- **WinnerAssignment**: Round id, wallet address, prize tier, randomness
  request id/seed/block references; emitted via events. Each winner receives
  exactly one prize pack.
- **LeaderboardEntry**: Wallet address, total weight, win percentage, rank,
  proof status indicator.
- **ProgressIndicator**: Current total tickets, minimum required (10), progress
  percentage, warning if under threshold.
- **RefundRecord**: Round id, wallet address, amount refunded, timestamp;
  emitted only when round fails to meet minimum tickets.
- **DeployArtifacts (docs/ops)**: Contract addresses, ABIs, VRF config, event
  tx hashes for lifecycle, randomness, prize mapping, and refunds.

---

## Review & Acceptance Checklist
*GATE: Automated checks run during main() execution*

### Content Quality
- [x] No implementation details (languages, frameworks, APIs)
- [x] Focused on user value and business needs
- [x] Written for non-technical stakeholders
- [x] All mandatory sections completed

### Requirement Completeness
- [x] No [NEEDS CLARIFICATION] markers remain
- [x] Requirements are testable and unambiguous  
- [x] Success criteria are measurable
- [x] Scope is clearly bounded
- [x] Dependencies and assumptions identified

### Constitution Alignment (PEPEDAWN)
- [x] If randomness involved: Specifies VRF provider and reproducibility from on-chain data
- [x] If wagers/rounds involved: Defines on-chain storage, lifecycle, and events
- [x] If puzzle weights involved: Defines submission, formula, caps, and anti-abuse rules
- [x] If prize distribution involved: Uses Emblem Vault only, tiers pre-committed, event mappings
- [x] Spec-first and test-first approach explicit; observability requirements listed

---

## Execution Status
*Updated by main() during processing*

- [x] User description parsed
- [x] Key concepts extracted
- [x] Ambiguities marked
- [x] User scenarios defined
- [x] Requirements generated
- [x] Entities identified
- [x] Review checklist passed

---


---

## User-Facing Behavior Updates (VRF Seed + Merkle + Claims)

### Round States & UI Labels
| State            | On-chain status          | UI label                      | What users see/do |
|---|---|---|---|
| Open             | `Open`                   | **Live: betting open**        | Connect wallet, place bet, submit puzzle proof; live leaderboard shows current % odds. |
| Snapshotted      | `Snapshotted`            | **Snapshotted (inputs locked)** | Leaderboard frozen; show **Participants File (CID)** and **participantsRoot** with a **Verified ✓** badge once the client verifies the Merkle root. |
| VRF Requested    | `VRFRequested`           | **Waiting for randomness**    | Spinner/notice about confirmations. |
| VRF Fulfilled    | `VRFFulfilled`           | **Randomness received**       | Display **VRF seed** from on-chain event and reproducibility note. |
| Winners Committed| `WinnersCommitted`       | **Winners finalized**         | Populate **Winners page** from **Winners File (CID)**; winners see **Claim** buttons per prize slot. |
| Closed           | `Closed`                 | **Round closed**              | Historical view; unclaimed prizes/withdraws still available if applicable. |

### Off-chain Files (Displayed & Verified in UI)
- **Participants File (JSON, IPFS CID)** — visible at **Snapshotted**:
  ```json
  {
    "roundId": 12,
    "totalWeight": "123456",
    "participants": [
      { "address": "0xAbc...", "weight": "50", "tickets": 10 },
      { "address": "0xDef...", "weight": "5",  "tickets": 1  }
    ],
    "merkle": {
      "root": "0xPARTICIPANTS_ROOT",
      "leafFormat": "keccak256(abi.encode(address, uint128 weight))"
    }
  }
  ```
- **Winners File (JSON, IPFS CID)** — visible at **Winners Committed**:
  ```json
  {
    "roundId": 12,
    "vrfSeed": "0xSEED",
    "derivation": "Deterministic expansion from seed + participants",
    "winners": [
      { "address": "0xAbc...", "prizeTier": 3, "prizeIndex": 0 },
      { "address": "0x123...", "prizeTier": 2, "prizeIndex": 1 }
    ],
    "merkle": {
      "root": "0xWINNERS_ROOT",
      "leafFormat": "keccak256(abi.encode(address, uint8 prizeTier, uint8 prizeIndex))"
    }
  }
  ```

**Client Verification:** The UI must verify that each file's `merkle.root` equals the corresponding on-chain root and display a **Verified ✓** badge when matched.

### Weights & Winners Semantics
- **Ticket-level without replacement**: a wallet can win **multiple times up to the number of tickets it holds** (e.g., 4 tickets ⇒ at most 4 wins).
- **Prize slots**: There are **10 prize slots** indexed `0..9`. Each slot has a **deterministic prize tier** derived from the seed; it is displayed and committed in the Winners File.

### Claims & Refunds (Pull-Payments)
- **Claims**: For each `prizeIndex` where the connected wallet appears in the Winners File, show a **Claim** button. The app generates a Merkle proof client-side and calls `claim(roundId, prizeIndex, prizeTier, proof)`. After success, show **Claimed ✓** and disable that slot.
- **Refunds**: If a refund is accrued for a wallet, show **Withdraw Refund**; clicking calls `withdrawRefund()` and, on success, shows **Refund withdrawn ✓**.

### Leaderboard Behavior
- While **Open**, show live odds (% chance) based on tickets and puzzle boosts.
- At **Snapshotted**, **freeze** the leaderboard and show the **Participants File (CID)** + **participantsRoot** with a verification badge.
- At **Winners Committed**, render the winners table from the Winners File: `address`, `prizeTier`, and `prizeIndex`; show **Claim** buttons for the connected winner.

### Governance (User-Visible)
- The owner may **denylist** addresses (policy transparent in UI). A denylisted wallet cannot place bets; the UI shows a clear error and a link to the policy.

### Verifiability & Transparency (NFR)
- Display CIDs and on-chain roots for both files; verify Merkle roots client-side.
- Display the **VRF seed** with a link to the on-chain fulfillment event.
- Document the deterministic derivation so users can reproduce the winners list off-chain.

### Functional Requirements (Additions)
- **FR-009**: Show **Snapshotted** state with a link to the **Participants File (CID)** and the **participantsRoot**; freeze leaderboard; display **Verified ✓** when the root matches.
- **FR-010**: Show **Randomness received** with the **VRF seed**.
- **FR-011**: Show **Winners finalized** with the **Winners File (CID)** and **winnersRoot**; render winners page.
- **FR-012**: Implement **Claim** per `prizeIndex` using a Merkle proof (`keccak256(abi.encode(address, uint8 prizeTier, uint8 prizeIndex))`); prevent double-claims.
- **FR-013**: Implement **Withdraw Refund** button calling `withdrawRefund()`; surface success/failure.
- **FR-014**: Show **Verified ✓** badges after client-side checks pass.
- **FR-015**: Clarify that a wallet may win **multiple times up to its ticket count**.

### Edge Cases / Failure Modes (UX)
- **Bad Merkle proof** → “Verification failed—check your wallet and try again.” Keep Claim enabled.
- **Already claimed** → show “Already claimed” and disable that slot.
- **Refund = 0** → disable Withdraw with tooltip “No refund available.”
- **Denylisted** → block betting with explicit message and policy link.
- **IPFS fetch failed** → retry option + copyable CID to use any public gateway.
- **Verification mismatch** (file root ≠ on-chain root) → red warning banner and hide Claim.

### UI Copy (Strings)
- “**Snapshotted (inputs locked)** — verified root: `0x…` — [View participants.json]”
- “**Randomness received** — VRF seed: `0x…`”
- “**Winners finalized** — verified root: `0x…` — [View winners.json]”
- “Claim prize #`{prizeIndex}` — Tier: `{prizeTier}`” / “**Claimed ✓**”
- “**Withdraw refund**” / “**Refund withdrawn ✓**”
- “You hold **{tickets}** tickets. You can win **up to {tickets} times** this round.”
