# Quickstart (Phase 1)

## Prereqs
- Node 20+
- pnpm or npm
- Foundry installed (for contracts)

## Frontend
```
pnpm create vite@latest frontend -- --template vanilla
cd frontend && pnpm i ethers
pnpm dev
```

## Contracts
```
forge init contracts
cd contracts
# add Chainlink VRF deps if needed
forge test
```

## Validate Flow
- Connect wallet in `main.html`, place a bet (testnet).
- Submit a single puzzle proof; confirm +40% weight shown.
- Close round, request VRF, fulfill, observe winners and Emblem Vault distribution.
- Check read-only endpoints display round status, tickets, weights, expected prizes.
