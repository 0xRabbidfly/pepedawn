# PepedawnRaffle Mainnet Deployment Cost Estimate

## Contract Size
- **Initcode Size**: 24,234 bytes
- **Runtime Size**: 23,321 bytes

## Gas Cost Calculation

### Base Deployment Gas
```
Formula: (initcode_bytes × 200) + (runtime_bytes × 200) + 32,000 (base transaction)

Calculation:
- Initcode: 24,234 × 200 = 4,846,800 gas
- Runtime: 23,321 × 200 = 4,664,200 gas  
- Base TX: 32,000 gas
- Constructor logic overhead: ~200,000 gas (estimate for VRF setup, etc.)

TOTAL ESTIMATED: ~9,743,000 gas (~9.7M gas)
```

### Cost at Different Gas Prices

| Gas Price | ETH Cost | USD Cost (@$2,400/ETH) |
|-----------|----------|------------------------|
| 1 gwei    | 0.00974 ETH | $23.38 |
| 5 gwei    | 0.04872 ETH | $116.89 |
| 10 gwei   | 0.09743 ETH | $233.78 |
| 20 gwei   | 0.19486 ETH | $467.57 |
| 50 gwei   | 0.48715 ETH | $1,169.16 |

## How to Get Exact Gas Usage

### Option 1: Check Sepolia Deployment
Look at your existing Sepolia deployment to see actual gas used:
```bash
# Get deployment transaction
cast tx <DEPLOYMENT_TX_HASH> --rpc-url $SEPOLIA_RPC_URL

# Look for "gasUsed" field in the output
```

### Option 2: Deploy to Local Mainnet Fork (RECOMMENDED)
This is the most reliable method that gives exact gas costs:

**Step 1: Start Anvil Fork** (Terminal 1)
```bash
# Windows
cd contracts
simulate-mainnet-deploy.bat

# Linux/Mac
cd contracts
bash simulate-mainnet-deploy.sh
```

Or manually:
```bash
# Choose one of these free RPC endpoints:
# - https://ethereum.publicnode.com (reliable, no auth needed)
# - https://eth.llamarpc.com (reliable, no auth needed)
# - https://rpc.ankr.com/eth (reliable, no auth needed)

anvil --fork-url https://ethereum.publicnode.com
```

**Step 2: Deploy to Fork** (Terminal 2)
```bash
cd contracts

# Deploy using the default anvil test key
forge script scripts/forge/Deploy.s.sol \
  --rpc-url http://localhost:8545 \
  --broadcast \
  --private-key 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80

# Look for output like:
# "Gas Used: 9,732,045"
```

This gives you **exact gas costs** as it would be on mainnet!

### Option 3: Dry Run with Public RPC (Alternative)
```bash
# From contracts/ directory
# Note: Demo endpoints are rate-limited, use your own API key or public endpoints

forge script scripts/forge/Deploy.s.sol --rpc-url https://ethereum.publicnode.com -vvvv

# Look for "Gas used:" in the output
# Note: This won't broadcast, just estimates
```

**Why not use Alchemy demo?**
The demo endpoint (`https://eth-mainnet.g.alchemy.com/v2/demo`) is heavily rate-limited. You'll get HTTP 429 errors. Use your own API key or free public endpoints instead.

## Current Mainnet Gas Prices

Check current gas prices:
```bash
# Get current base fee
cast gas-price --rpc-url https://eth-mainnet.g.alchemy.com/v2/demo

# For gas price in gwei
cast gas-price --rpc-url https://eth-mainnet.g.alchemy.com/v2/demo | cast to-unit gwei
```

Or visit: https://etherscan.io/gastracker

## Recommendations

1. **Best Time to Deploy**: When base fee is <5 gwei (check etherscan.io/gastracker)
2. **Gas Limit**: Set to ~12,000,000 (with buffer)
3. **Priority Fee**: 1-2 gwei is usually sufficient for standard deployments
4. **Budget**: Expect $100-200 at normal gas prices (5-10 gwei)

## Optimization Notes

Current settings in `foundry.toml`:
```toml
optimizer = true
optimizer_runs = 200
via_ir = true
```

These are already optimized for deployment. The contract size is **well under the 24KB limit** with 918 bytes margin.

## Contract Size Breakdown
- You're using: 24,234 bytes initcode
- Ethereum limit: 49,152 bytes (EIP-170)
- **Margin: 24,918 bytes (50.7% remaining)** ✅

This is healthy - you have room for future upgrades if needed.

