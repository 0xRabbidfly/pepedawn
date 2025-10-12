# Feature Specification: PEPEDAWN Betting Site with VRF Draws, Emblem Vault Prizes, Merkle Verification, and Claims System

**Feature Branch**: `002-merkle-uhoh`  
**Created**: 2025-10-05 (Updated: 2025-10-08)  
**Status**: Complete  
**Input**: Comprehensive PEPEDAWN betting platform with user-facing round state management, Merkle-based verification, and pull-payment claims system.

## Execution Flow (main)
```
1. Parse user description from Input
   → Feature encompasses full betting platform with transparent verification
2. Extract key concepts from description
   → Actors: Users, Winners, Contract Owner, Observers
   → Actions: Betting, Puzzle solving, Claiming prizes, Withdrawing refunds, Verifying fairness
   → Data: Rounds, Wagers, Proofs, Merkle trees, IPFS files, VRF seeds, Claims
   → Constraints: Ticket limits, time windows, verification requirements, eligibility rules
3. For each unclear aspect:
   → All aspects clearly defined through iterative clarification
4. Fill User Scenarios & Testing section
   → Complete user journey from title page through betting to claiming prizes
5. Generate Functional Requirements
   → 47 functional requirements covering full system lifecycle
6. Identify Key Entities
   → Comprehensive data model for rounds, participants, winners, claims, and verification
7. Run Review Checklist
   → Specification complete, testable, and ready for implementation
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
As a wallet holder, I want to connect my Ethereum wallet, place a wager in an active 2‑week round, optionally submit a valid puzzle proof to increase my odds by 40%, see my wallet appear on the leaderboard with my current percentage chance of winning, track progress toward the 10-ticket minimum required for distribution, observe transparent round state transitions with verifiable Merkle proofs and VRF randomness, and—after the round closes—either claim my prize through a pull-payment system if I win (with the round meeting the minimum), or withdraw my full refund if the round had fewer than 10 tickets, with all outcomes verifiable through on‑chain data, IPFS files, and client-side verification.

### Acceptance Scenarios

#### Betting Phase
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

#### Round State Progression
4. **Given** a round is in "Open" state, **When** I visit the application, **Then** I see "Live: betting open" with live leaderboard showing current percentage odds and can place bets and submit puzzle proofs.
5. **Given** a round transitions to "Snapshotted" state, **When** I view the round, **Then** I see "Snapshotted (inputs locked)" with a frozen leaderboard, a link to the Participants File (CID), the participantsRoot hash, and a "Verified ✓" badge once client-side verification passes.
6. **Given** a round is in "VRF Requested" state, **When** I check the status, **Then** I see "Waiting for randomness" with a spinner and information about confirmation progress.
7. **Given** VRF is fulfilled, **When** I view the round, **Then** I see "Randomness received" with the VRF seed displayed and a note about reproducibility.

#### Winner Selection & Claims (RAFFLE MODEL)
8. **Given** a round has closed with 10+ tickets, **When** VRF is requested and
   fulfilled, **Then** 10 winners are selected using raffle mechanics (1st place 
   gets Fake pack, 2nd place gets Kek pack, 3rd-10th place each get Pepe pack), 
   where each ticket is an entry that gets "consumed" when drawn, and winners are
   reproducible from on-chain data.
9. **Given** winners are committed, **When** I am a winner, **Then** I see "Winners finalized" with access to the Winners File, and "Claim" buttons for each prize slot I won.
10. **Given** I have won a prize, **When** I click "Claim" for a specific prize slot, **Then** the system generates a Merkle proof and submits my claim, showing "Claimed ✓" upon success.
11. **Given** a round with 10+ tickets and weighted raffle distribution, **When**
    winners are selected, **Then** wallets with more tickets have proportionally 
    higher odds, each ticket acts as a raffle entry that is consumed on win, and 
    the same wallet CAN win multiple prizes (up to their ticket count).

#### Refunds
12. **Given** a round has closed with fewer than 10 tickets, **When** the round
    is processed, **Then** ALL participants are refunded their full wager
    amount, no fees are collected, and refund events are emitted.
13. **Given** I have a refund available, **When** I click "Withdraw Refund", **Then** the system processes my refund and shows "Refund withdrawn ✓" upon success.

#### Verification & Transparency
14. **Given** the public read endpoints, **When** observers query round status,
    ticket counts, weights, and progress toward minimum, **Then** values match
    on-chain state.
15. **Given** Participants File and Winners File are available, **When** I download and verify them, **Then** their Merkle roots match the on-chain committed roots and display "Verified ✓" badges.

#### Governance
16. **Given** a denylisted wallet, **When** it attempts to bet, **Then** the
    system blocks the action per eligibility rules and logs an event with explicit error message and policy link.
17. **Given** a wallet that already submitted a proof attempt (success or
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
- Same wallet wins multiple prizes → allowed; emit separate events per prize; show multiple Claim buttons.
- Wallet wins 1st place → receives Fake pack (highest tier, 3 cards).
- Refund processing when contract has insufficient ETH → should never happen
  (escrowed funds); emergency circuit breaker if detected.
- VRF request failure/timeout → retry policy and incident logging.
- VRF subscription underfunded → request fails; owner must add LINK to subscription; retry randomness request.
- Contract doesn't hold required Emblem Vault NFT when claim() called → transaction reverts; owner must transfer missing NFT to contract; winner can retry claim.
- Owner forgets to set valid proof before opening round → proofs cannot succeed.
- Wallet disconnects mid-bet → do not create on-chain transaction; show status.
- IPFS file fetch fails → Show retry option with copyable CID for alternative gateways; show "service unavailable" after 60 seconds.
- Invalid Merkle proofs → Show "Verification failed" message and keep Claim button enabled for manual retry.
- User tries to claim already claimed prize → Show "Already claimed" and disable that specific slot.
- Denylisted users → Block betting with explicit message and policy link.
- File verification fails (root mismatch) → Show red warning banner and hide Claim buttons.
- Claim transaction fails (gas, network error) → Show error message with reason; keep Claim button enabled; no automatic retry.
- Large participant count (500+ wallets) → Show top 20 participants with "View all" option.
- Mobile device usage → All features work with touch-friendly UI; addresses truncated with copy functionality.

## Requirements *(mandatory)*

### Functional Requirements

#### Core System (FR-001 to FR-027)
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
- **FR-010**: Prizes MUST be distributed via Emblem Vault NFT transfers:
  - The contract MUST hold the Emblem Vault NFTs before the round opens
  - Winners claim prizes by calling claim() with valid Merkle proof
  - Contract automatically transfers the corresponding Emblem Vault NFT to winner's address
  - Each claim MUST emit an event with winner address, prize tier, and NFT token ID
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
- **FR-020**: Emblem Vault prizes MUST be transferred to the contract before the round opens:
  - Owner transfers all 10 Emblem Vault NFTs to the contract address
  - Contract stores mapping of prize tier to NFT token ID
  - NFTs remain in contract custody until claimed by winners
  - Unclaimed prizes remain claimable indefinitely (no expiration)
- **FR-021**: Network and VRF configuration:
  - Ethereum only. No non-EVM or L2 networks in scope for this feature.
  - Use the simplest viable Chainlink VRF (v2 or v2.5) on Ethereum.
  - Owner creates and manages VRF subscription externally via Chainlink dashboard or CLI
  - Owner funds subscription with LINK tokens and adds contract as consumer
  - Contract is configured with subscription ID at deployment
  - Owner is responsible for monitoring and maintaining sufficient LINK balance in subscription
  - Document subId, keyHash, callbackGasLimit, and confirmations in deploy artifacts.
  - Emit events on randomness requested/fulfilled with request id and block data.
- **FR-022**: Title page audio assets will be provided by the project creator.
  - Audio title: [TO_BE_PROVIDED]
  - Source URL/hosting: [TO_BE_PROVIDED]
  - License/rights: [TO_BE_PROVIDED]
  - The title page MUST function without audio until placeholders are replaced.
- **FR-023**: Per-round maximum bet cap:
  - A single wallet's cumulative wagers per round MUST NOT exceed 1.0 ETH.
  - Attempts to exceed this cap MUST be rejected and an event MUST be emitted.
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
- **FR-026**: Winner selection (weighted raffle):
  - Winners are selected using RAFFLE MECHANICS: each ticket is an entry that gets consumed when drawn.
  - Each ticket has a weight (1 base, or 1.4 with proof bonus) that determines selection probability.
  - When a ticket wins, it is REMOVED from the pool, reducing both ticket count and total weight.
  - A wallet with more tickets/weight has proportionally higher odds AND can win multiple prizes (up to ticket count).
  - The same wallet address CAN win multiple prizes in a single round (maximum = number of tickets purchased).
  - Each prize draw uses the remaining pool of tickets, with dynamically updated odds.
  - Winner selection algorithm MUST be deterministic and reproducible from VRF seed.
  - Example: If wallet buys 5 tickets and wins 1st prize, they have 4 tickets remaining for subsequent draws.
- **FR-027**: Leaderboard and progress tracking:
  - The leaderboard MUST display all participating wallets with their current odds.
  - A progress indicator MUST show tickets purchased toward the 10-ticket minimum.
  - Progress bar format: "X / 10 tickets needed for round distribution"
  - If threshold not met by round end, participants MUST be notified of pending refund.
- **FR-028**: Round state transitions MUST be manually controlled by the contract owner:
  - Owner calls snapshotRound() to transition from Open → Snapshotted
  - Owner calls requestRandomness() to transition from Snapshotted → VRF Requested
  - VRF callback automatically transitions VRF Requested → VRF Fulfilled
  - Owner calls commitWinners() to transition from VRF Fulfilled → Winners Committed
  - Owner calls closeRound() to transition from Winners Committed → Closed
  - Each transition MUST emit appropriate events for observability
- **FR-029**: IPFS file generation and publication MUST be performed off-chain by the contract owner:
  - Owner uses provided scripts to query contract state and generate Participants File (after snapshot) and Winners File (after VRF fulfillment)
  - Owner uploads files to IPFS using free pinning services (e.g., NFT.Storage, Web3.Storage, Pinata)
  - Owner commits the resulting CIDs on-chain via contract function calls
  - Scripts MUST include clear step-by-step instructions for the manual workflow
  - Contract events MUST emit all data necessary to reconstruct files for verification
- **FR-030**: Storage efficiency MUST be optimized for indefinite on-chain retention:
  - Round data stored using efficient patterns (Merkle roots for participants/winners instead of full mappings)
  - Detailed participant/winner data emitted in events (lower gas cost than storage)
  - Core round metadata (timestamps, status, roots, VRF seed) stored on-chain
  - IPFS CIDs (32 bytes each) stored on-chain for verifiable off-chain data retrieval
  - Design target: Support 100+ rounds on-chain without prohibitive gas costs

#### UI/UX & Round State Visualization (FR-031 to FR-047)
- **FR-031**: System MUST display six distinct round states with appropriate UI labels: "Live: betting open", "Snapshotted (inputs locked)", "Waiting for randomness", "Randomness received", "Winners finalized", and "Round closed"
- **FR-032**: System MUST freeze the leaderboard when round reaches "Snapshotted" state and display the Participants File CID with participantsRoot hash; leaderboard MUST display top 20 participants by default with a "View all" option for rounds with more participants
- **FR-033**: System MUST verify Merkle roots client-side by comparing file roots against on-chain roots and display "Verified ✓" badges when matched
- **FR-034**: System MUST display VRF seed from on-chain events when randomness is received, with reproducibility documentation
- **FR-035**: System MUST render winners table from Winners File showing address, prizeTier, and prizeIndex for each winner
- **FR-036**: System MUST implement individual "Claim" buttons for each prize slot where the connected wallet appears as a winner
- **FR-037**: System MUST generate Merkle proofs client-side using the format `keccak256(abi.encodePacked(address, uint8 prizeTier, uint8 prizeIndex))` for claims
- **FR-038**: System MUST prevent double-claims by showing "Already claimed" status and disabling claimed prize slots; when claim transaction fails, system MUST display error message and keep Claim button enabled for manual retry
- **FR-039**: System MUST implement "Withdraw Refund" functionality that calls the contract and shows success/failure status
- **FR-040**: System MUST display ticket counts and explain that users can win multiple times up to their ticket count
- **FR-041**: System MUST show clear error messages for denylisted addresses with policy information
- **FR-042**: System MUST handle IPFS fetch failures with retry options and alternative gateway access; if fetch does not complete within 60 seconds, display "service unavailable" message
- **FR-043**: System MUST display red warning banners when file verification fails (root mismatch) and hide claim functionality
- **FR-044**: System MUST show appropriate loading states during VRF confirmation periods
- **FR-045**: System MUST maintain historical view for closed rounds while keeping unclaimed prizes and refunds accessible:
  - All round data MUST remain on-chain indefinitely using efficient storage (Merkle roots, events)
  - UI MUST display all historical rounds with ability to view details, participants, and winners
  - Detailed participant/winner lists reconstructed from IPFS files (using CIDs stored on-chain)
  - UI MAY implement pagination for rounds list if count exceeds 50 rounds
  - Unclaimed prizes and refunds remain claimable forever (no expiration)
- **FR-046**: System MUST log all errors (failed claims, verification failures, IPFS timeouts) and critical actions (claims submitted, refunds withdrawn, Merkle verification completed) for observability and debugging
- **FR-047**: System MUST be fully responsive and functional on mobile browsers; all features (betting, claiming, verification, leaderboard viewing) MUST work on mobile devices with appropriate touch-friendly UI elements

### Key Entities *(include if feature involves data)*

#### Core Entities
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
  - Associated Emblem Vault NFT token IDs (stored in contract mapping)
  - Contract custody: NFTs transferred to contract before round opens, held until claimed
- **WinnerAssignment**: Round id, wallet address, prize tier, randomness
  request id/seed/block references; emitted via events. Each winner receives
  exactly one prize pack.
- **LeaderboardEntry**: Wallet address, total weight, win percentage, rank,
  proof status indicator.
- **ProgressIndicator**: Current total tickets, minimum required (10), progress
  percentage, warning if under threshold.
- **RefundRecord**: Round id, wallet address, amount refunded, timestamp;
  emitted only when round fails to meet minimum tickets.
- **DeployArtifacts (docs/ops)**: Contract addresses, ABIs, VRF config (subscription ID, key hash, coordinator address, callback gas limit), event tx hashes for lifecycle, randomness, prize mapping, and refunds, instructions for funding VRF subscription.

#### UI/Verification Entities
- **Round State**: Represents current phase of a betting round with six possible values (Open, Snapshotted, VRFRequested, VRFFulfilled, WinnersCommitted, Closed)
- **Participants File**: JSON file stored on IPFS containing round participants, their weights, ticket counts, and Merkle tree root for verification; format:
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
      "leafFormat": "keccak256(abi.encodePacked(address, uint128 weight))"
    }
  }
  ```
- **Winners File**: JSON file stored on IPFS containing VRF seed, deterministic winner derivation, prize assignments, and Merkle tree root for claims; format:
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
      "leafFormat": "keccak256(abi.encodePacked(address, uint8 prizeTier, uint8 prizeIndex))"
    }
  }
  ```
- **Prize Slot**: Individual prize position (0-9) with deterministic tier assignment and claimable status per winner
- **Claim Record**: Tracks claim status for each prize slot per user, preventing double-claims and showing completion status
- **Refund Balance**: Accumulated refund amount per user available for withdrawal through pull-payment model

---

## Detailed User Interface Specifications

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
**Client Verification:** The UI must verify that each file's `merkle.root` equals the corresponding on-chain root and display a **Verified ✓** badge when matched.

### Weights & Winners Semantics
- **Ticket-level without replacement**: a wallet can win **multiple times up to the number of tickets it holds** (e.g., 4 tickets ⇒ at most 4 wins).
- **Prize slots**: There are **10 prize slots** indexed `0..9`. Each slot has a **deterministic prize tier** derived from the seed; it is displayed and committed in the Winners File.

### Claims & Refunds (Pull-Payments)
- **Claims**: For each `prizeIndex` where the connected wallet appears in the Winners File, show a **Claim** button. The app generates a Merkle proof client-side and calls `claim(roundId, prizeIndex, prizeTier, proof)`. After success, show **Claimed ✓** and disable that slot.
- **Refunds**: If a refund is accrued for a wallet, show **Withdraw Refund**; clicking calls `withdrawRefund()` and, on success, shows **Refund withdrawn ✓**.

### Leaderboard Behavior
- While **Open**, show live odds (% chance) based on tickets and puzzle boosts; display top 20 participants by default with "View all" option for larger participant lists.
- At **Snapshotted**, **freeze** the leaderboard and show the **Participants File (CID)** + **participantsRoot** with a verification badge; maintain top 20 display with "View all" option.
- At **Winners Committed**, render the winners table from the Winners File: `address`, `prizeTier`, and `prizeIndex`; show **Claim** buttons for the connected winner.

### Governance (User-Visible)
- The owner may **denylist** addresses (policy transparent in UI). A denylisted wallet cannot place bets; the UI shows a clear error and a link to the policy.

### Verifiability & Transparency (NFR)
- Display CIDs and on-chain roots for both files; verify Merkle roots client-side.
- Display the **VRF seed** with a link to the on-chain fulfillment event.
- Document the deterministic derivation so users can reproduce the winners list off-chain.

### Observability (NFR)
- Log all errors: failed claims, verification failures, IPFS timeouts, transaction rejections.
- Log critical actions: claims submitted (with roundId, prizeIndex), refunds withdrawn (with amount), Merkle verification completed (with success/failure status), wallet connections, round state transitions viewed.

### Mobile Support (NFR)
- Application MUST be fully responsive across all screen sizes (mobile, tablet, desktop).
- All features MUST function on mobile browsers with mobile wallet support (MetaMask mobile, WalletConnect, etc.).
- UI elements MUST be touch-friendly with appropriate tap targets (minimum 44x44px).
- Tables and lists MUST adapt to narrow screens (stacked layouts, horizontal scrolling where appropriate).
- Long addresses and hashes MUST be truncated with copy-to-clipboard functionality on mobile.

### Edge Cases / Failure Modes (UX)
- **Bad Merkle proof** → "Verification failed—check your wallet and try again." Keep Claim enabled.
- **Already claimed** → show "Already claimed" and disable that slot.
- **Claim transaction failed** → display error message with reason (insufficient gas, network error, user rejection); keep Claim button enabled for manual retry; no automatic retry.
- **Refund transaction failed** → display error message; keep Withdraw Refund button enabled for manual retry.
- **Refund = 0** → disable Withdraw with tooltip "No refund available."
- **Denylisted** → block betting with explicit message and policy link.
- **IPFS fetch failed** → retry option + copyable CID to use any public gateway; show "service unavailable" after 60 seconds.
- **Verification mismatch** (file root ≠ on-chain root) → red warning banner and hide Claim.

### UI Copy (Strings)
- "**Snapshotted (inputs locked)** — verified root: `0x…` — [View participants.json]"
- "**Randomness received** — VRF seed: `0x…`"
- "**Winners finalized** — verified root: `0x…` — [View winners.json]"
- "Claim prize #`{prizeIndex}` — Tier: `{prizeTier}`" / "**Claimed ✓**"
- "**Withdraw refund**" / "**Refund withdrawn ✓**"
- "You hold **{tickets}** tickets. You can win **up to {tickets} times** this round."

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

## Clarifications

### Session 2025-10-08
- Q: When IPFS file fetches fail and users retry, what is the acceptable maximum wait time before the system should show a "service unavailable" message? → A: 60 seconds - maximize chance of success
- Q: For the leaderboard with live odds, what should happen when there are a large number of participants (e.g., 500+ wallets)? → A: Show top 20 participants with "View all" option
- Q: What user actions or events should be logged for observability and debugging purposes? → A: Errors + critical actions (claims submitted, refunds withdrawn, verification completed)
- Q: Should the application support mobile devices, and if so, what is the minimum acceptable experience? → A: Mobile responsive - all features must work on mobile browsers
- Q: When a user attempts to claim a prize but the transaction fails (e.g., insufficient gas, network error), what should happen? → A: Show error only - user must manually retry
- Q: Round lifecycle automation: How are round state transitions triggered? → A: Fully manual - Owner manually calls functions to transition each state (snapshot, request VRF, commit winners, close)
- Q: IPFS file publication: Who creates and publishes the Participants File and Winners File to IPFS? → A: Contract owner off-chain - Owner generates files locally using provided scripts, uploads to IPFS, then commits CIDs on-chain via contract calls
- Q: Emblem Vault prize distribution: How are the actual Emblem Vault NFTs transferred to winners? → A: Contract holds vaults - Contract owns the Emblem Vault NFTs; winners call claim() to trigger automatic transfer
- Q: Chainlink VRF subscription management: Who funds and manages the VRF subscription? → A: Contract owner external - Owner creates/funds subscription externally via Chainlink dashboard/CLI; contract uses the subscription ID
- Q: Data retention and historical access: How long must past round data remain accessible on-chain and via the UI? → A: Indefinite on-chain - All round data stored on-chain forever using efficient patterns (Merkle roots); UI shows all historical rounds with full details

---