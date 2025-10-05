# PEPEDAWN

Runtime guidance aligned with the project constitution (`.specify/memory/constitution.md`).

## VRF Configuration
- Provider: Chainlink VRF v2/v2.5 (network-dependent)
- Required parameters (per deployment):
  - Subscription ID (`subId`)
  - Key Hash (`keyHash`)
  - Callback gas limit (`callbackGasLimit`)
  - Request confirmations and num words
- Record these values in deploy artifacts and announce via on-chain events.

## Round Parameters
- Each round MUST define immutable `start` and `end` timestamps once opened.
- Parameters announced via events before wagers open: fees, caps, tier counts.
- Snapshot eligible tickets and weights before VRF request.

## Deployment Artifacts
- For every deploy, record in-repo under `deploy/` (structure is flexible):
  - Contract addresses
  - ABIs
  - VRF configuration (per network)
  - Emitted event tx hashes for: round lifecycle, randomness, prize assignment

## Observability
- Emit structured events for all public functions (round id, correlation id).
- Expose read-only endpoints for round status, ticket counts, weights, expected prize counts.

## Emblem Vault Distribution
- Prize tiers (Gold/Silver/Bronze) pre-committed per round (vault IDs or minting plan).
- Distribute prizes to winning ETH addresses or escrow with on-chain eligibility proof.
- Emit event mapping winners → prize vaults.


