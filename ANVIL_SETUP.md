# Anvil Fork Testing Setup

## Quick Start

### Step 1: Create `.env.mainnet` Template

Create `contracts/.env.mainnet` with this content:

```bash
# ============================================================================
# MAINNET CONFIGURATION (for Anvil testing & real deployment)
# ============================================================================

# WALLET (Anvil test key - safe for testing)
PRIVATE_KEY=ac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80
CREATORS_ADDRESS=0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266

# ⚠️ FOR REAL MAINNET: Replace above with your secure keys

# NETWORK
MAINNET_RPC_URL=https://ethereum.publicnode.com

# CHAINLINK VRF (Mainnet v2.5)
VRF_COORDINATOR=0x271682DEB8C4E0901D1a1550aD2e64D568E69909
VRF_SUBSCRIPTION_ID=0
VRF_KEY_HASH=0x9fe0eebf5e446e3c998ec9bb19951541aee00bb90ea201ae456421a2ded86805

# EMBLEM VAULT (Mainnet ERC1155) ✅ VERIFIED
EMBLEM_VAULT_ADDRESS=0x4C03BCAD293fb0562D26FAa7D90A0cb3Ea74c919

# CONTRACT (filled after deployment)
CONTRACT_ADDRESS=
```

### Step 2: Test on Anvil Fork

**Terminal 1 - Start Anvil:**
```bash
anvil --fork-url https://ethereum.publicnode.com
```

**Terminal 2 - Deploy:**
```bash
# Use mainnet config
cp contracts/.env.mainnet contracts/.env

# Deploy to Anvil
cd contracts
forge script scripts/forge/Deploy.s.sol --rpc-url http://localhost:8545 --broadcast

# Verify correct Emblem Vault address
cast call $CONTRACT_ADDRESS "emblemVaultAddress()" --rpc-url http://localhost:8545
# Should return: 0x4C03BCAD293fb0562D26FAa7D90A0cb3Ea74c919

# Test ERC1155 balanceOf on real Emblem Vault
cast call 0x4C03BCAD293fb0562D26FAa7D90A0cb3Ea74c919 \
  "balanceOf(address,uint256)" \
  $SOME_ADDRESS \
  1 \
  --rpc-url http://localhost:8545

# Restore Sepolia config when done
git checkout contracts/.env
```

### Step 3: Validation Checklist

After deploying to Anvil, verify:

- [ ] Contract deployed successfully
- [ ] `emblemVaultAddress()` returns `0x4C03BCAD293fb0562D26FAa7D90A0cb3Ea74c919`
- [ ] Can query `balanceOf()` on Emblem Vault contract
- [ ] VRF coordinator address is mainnet address
- [ ] No errors in deployment

### For Real Mainnet Deployment

Before deploying to real mainnet:

1. **Update `.env.mainnet`:**
   - Replace `PRIVATE_KEY` with hardware wallet key
   - Replace `CREATORS_ADDRESS` with production address
   - Create VRF subscription and update `VRF_SUBSCRIPTION_ID`
   - Add `ETHERSCAN_API_KEY` and `PINATA_JWT`

2. **Deploy:**
   ```bash
   cp contracts/.env.mainnet contracts/.env
   cd contracts
   forge script scripts/forge/Deploy.s.sol \
     --rpc-url $MAINNET_RPC_URL \
     --broadcast \
     --verify
   ```

## Key Differences: Sepolia vs Mainnet

| Config | Sepolia (.env) | Mainnet (.env.mainnet) |
|--------|----------------|------------------------|
| **VRF Coordinator** | 0x9Ddfa... (Sepolia) | 0x2716... (Mainnet) |
| **Emblem Vault** | Test ERC1155 contract | 0x4C03...c919 (Real) |
| **Key Hash** | Sepolia hash | Mainnet 100 gwei hash |
| **Network** | Testnet | Mainnet (or localhost for Anvil) |

## Troubleshooting

**"Out of gas" on Anvil:**
- Anvil accounts have 10000 ETH, this shouldn't happen
- Check your deployment script isn't trying to use Sepolia addresses

**"Contract not found" for Emblem Vault:**
- Make sure Anvil is forking mainnet: `--fork-url https://ethereum.publicnode.com`
- Verify you can query the address: `cast code 0x4C03BCAD293fb0562D26FAa7D90A0cb3Ea74c919 --rpc-url http://localhost:8545`

**VRF subscription errors:**
- For Anvil testing, VRF won't actually fulfill (no oracles running locally)
- This is OK - you're testing deployment and NFT integration, not VRF
- VRF testing happens on Sepolia testnet


