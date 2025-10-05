# Research (Phase 0)

## Decisions
- Build frontend with Vite MPA + vanilla JS to minimize bundle size and maximize DX.
- Use ethers v6 for wallet connection and contract interactions.
- Ethereum-only network support for this feature; simplest Chainlink VRF (v2/v2.5).
- Contracts in Solidity 0.8.x; testing with Foundry (unit + invariant).

## Rationale
- MPA + vanilla avoids framework overhead and keeps JS minimal for fast loads.
- ethers has mature wallet/provider support and a small surface needed here.
- Constitution requires verifiable randomness and Ethereum on-chain accounting.
- Foundry offers fast Solidity-native testing and fuzz/invariant capabilities.

## Alternatives Considered
- viem + wagmi: nice DX but more dependencies; ethers suffices.
- React/Next: heavier runtime and complexity vs. MPA for simple flows.
- Hardhat/Truffle: slower tests and less powerful fuzzing vs. Foundry.
