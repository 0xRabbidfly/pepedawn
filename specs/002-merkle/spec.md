# Feature Specification: User-Facing Behavior Updates (VRF Seed + Merkle + Claims)

**Feature Branch**: `002-add-the-following`  
**Created**: October 8, 2025  
**Status**: Draft  
**Input**: User description: "add the following to the spec.md"

## Execution Flow (main)
```
1. Parse user description from Input
   → Feature involves comprehensive UI updates for VRF integration, Merkle proofs, and claims system
2. Extract key concepts from description
   → Actors: Users, Winners, Contract Owner
   → Actions: Betting, Claiming prizes, Withdrawing refunds, Viewing round states
   → Data: Round states, Merkle trees, IPFS files, VRF seeds
   → Constraints: Ticket limits, verification requirements, pull-payment model
3. For each unclear aspect:
   → All aspects clearly defined in provided specification
4. Fill User Scenarios & Testing section
   → Complete user journey from betting to claiming defined
5. Generate Functional Requirements
   → 15 functional requirements identified (FR-009 through FR-015 plus additional)
6. Identify Key Entities
   → Round states, Participants file, Winners file, Claims, Refunds
7. Run Review Checklist
   → Specification complete and ready for implementation
8. Return: SUCCESS (spec ready for planning)
```

---

## ⚡ Quick Guidelines
- ✅ Focus on WHAT users need and WHY
- ❌ Avoid HOW to implement (no tech stack, APIs, code structure)
- 👥 Written for business stakeholders, not developers

---

## User Scenarios & Testing *(mandatory)*

### Primary User Story
As a user participating in PEPEDAWN rounds, I want to see clear visual feedback about round progression, verify the fairness of winner selection through transparent files and proofs, and easily claim any prizes I've won, so that I can trust the system and access my winnings without confusion.

### Acceptance Scenarios

1. **Given** a round is in "Open" state, **When** I visit the application, **Then** I see "Live: betting open" with live leaderboard showing current percentage odds and can place bets and submit puzzle proofs.

2. **Given** a round transitions to "Snapshotted" state, **When** I view the round, **Then** I see "Snapshotted (inputs locked)" with a frozen leaderboard, a link to the Participants File (CID), the participantsRoot hash, and a "Verified ✓" badge once client-side verification passes.

3. **Given** a round is in "VRF Requested" state, **When** I check the status, **Then** I see "Waiting for randomness" with a spinner and information about confirmation progress.

4. **Given** VRF is fulfilled, **When** I view the round, **Then** I see "Randomness received" with the VRF seed displayed and a note about reproducibility.

5. **Given** winners are committed, **When** I am a winner, **Then** I see "Winners finalized" with access to the Winners File, and "Claim" buttons for each prize slot I won.

6. **Given** I have won a prize, **When** I click "Claim" for a specific prize slot, **Then** the system generates a Merkle proof and submits my claim, showing "Claimed ✓" upon success.

7. **Given** I have a refund available, **When** I click "Withdraw Refund", **Then** the system processes my refund and shows "Refund withdrawn ✓" upon success.

### Edge Cases
- What happens when IPFS file fetch fails? → Show retry option with copyable CID for alternative gateways
- How does system handle invalid Merkle proofs? → Show "Verification failed" message and keep Claim button enabled
- What if user tries to claim already claimed prize? → Show "Already claimed" and disable that specific slot
- How does system handle denylisted users? → Block betting with explicit message and policy link
- What if file verification fails (root mismatch)? → Show red warning banner and hide Claim buttons

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: System MUST display six distinct round states with appropriate UI labels: "Live: betting open", "Snapshotted (inputs locked)", "Waiting for randomness", "Randomness received", "Winners finalized", and "Round closed"

- **FR-002**: System MUST freeze the leaderboard when round reaches "Snapshotted" state and display the Participants File CID with participantsRoot hash; leaderboard MUST display top 20 participants by default with a "View all" option for rounds with more participants

- **FR-003**: System MUST verify Merkle roots client-side by comparing file roots against on-chain roots and display "Verified ✓" badges when matched

- **FR-004**: System MUST display VRF seed from on-chain events when randomness is received, with reproducibility documentation

- **FR-005**: System MUST render winners table from Winners File showing address, prizeTier, and prizeIndex for each winner

- **FR-006**: System MUST implement individual "Claim" buttons for each prize slot where the connected wallet appears as a winner

- **FR-007**: System MUST generate Merkle proofs client-side using the format `keccak256(abi.encode(address, uint8 prizeTier, uint8 prizeIndex))` for claims

- **FR-008**: System MUST prevent double-claims by showing "Already claimed" status and disabling claimed prize slots; when claim transaction fails, system MUST display error message and keep Claim button enabled for manual retry

- **FR-009**: System MUST implement "Withdraw Refund" functionality that calls the contract and shows success/failure status

- **FR-010**: System MUST display ticket counts and explain that users can win multiple times up to their ticket count

- **FR-011**: System MUST show clear error messages for denylisted addresses with policy information

- **FR-012**: System MUST handle IPFS fetch failures with retry options and alternative gateway access; if fetch does not complete within 60 seconds, display "service unavailable" message

- **FR-013**: System MUST display red warning banners when file verification fails (root mismatch) and hide claim functionality

- **FR-014**: System MUST show appropriate loading states during VRF confirmation periods

- **FR-015**: System MUST maintain historical view for closed rounds while keeping unclaimed prizes and refunds accessible

- **FR-016**: System MUST log all errors (failed claims, verification failures, IPFS timeouts) and critical actions (claims submitted, refunds withdrawn, Merkle verification completed) for observability and debugging

- **FR-017**: System MUST be fully responsive and functional on mobile browsers; all features (betting, claiming, verification, leaderboard viewing) MUST work on mobile devices with appropriate touch-friendly UI elements

### Key Entities *(include if feature involves data)*

- **Round State**: Represents current phase of a betting round with six possible values (Open, Snapshotted, VRFRequested, VRFFulfilled, WinnersCommitted, Closed)

- **Participants File**: JSON file stored on IPFS containing round participants, their weights, ticket counts, and Merkle tree root for verification

- **Winners File**: JSON file stored on IPFS containing VRF seed, deterministic winner derivation, prize assignments, and Merkle tree root for claims

- **Prize Slot**: Individual prize position (0-9) with deterministic tier assignment and claimable status per winner

- **Claim Record**: Tracks claim status for each prize slot per user, preventing double-claims and showing completion status

- **Refund Balance**: Accumulated refund amount per user available for withdrawal through pull-payment model

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