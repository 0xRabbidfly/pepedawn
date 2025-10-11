---
description: Update frontend contract configuration with latest deployment artifacts (address, ABI, network settings)
---

You are tasked with updating the frontend contract configuration to match the latest deployment artifacts. This ensures the frontend can properly interact with the deployed smart contract.

## Task Overview

Synchronize `frontend/src/contract-config.js` with the latest deployment artifacts from:
- `deploy/artifacts/addresses.json` (contract addresses)
- `deploy/artifacts/abis/PepedawnRaffle.json` (contract ABI)
- `deploy/artifacts/vrf-config.json` (VRF configuration)

## Steps to Execute

### 1. Read Current Configuration
- Read `frontend/src/contract-config.js` to understand current setup
- Note the current contract address, network, and ABI format

### 2. Load Latest Deployment Artifacts
- Read `deploy/artifacts/addresses.json` for the latest contract address
- Read `deploy/artifacts/abis/PepedawnRaffle.json` for the latest ABI
- Read `deploy/artifacts/vrf-config.json` for VRF settings (if needed)

### 3. Update Contract Address
- Replace the contract address in `CONTRACT_CONFIG.address`
- Ensure it matches the deployed contract on the target network
- Add a comment with deployment timestamp if available

### 4. Update ABI
- Replace the entire ABI array with the latest version
- Ensure proper JavaScript object format (not escaped JSON strings)
- Maintain readable formatting with proper indentation
- Verify all function signatures are included

### 5. Update Network Configuration
- Verify network settings match the deployment target:
  - `network`: 'sepolia', 'mainnet', etc.
  - `chainId`: 11155111 (Sepolia), 1 (Mainnet), etc.
- Update RPC URLs if needed

### 6. Add VRF Configuration (if applicable)
- Include VRF coordinator address
- Add subscription ID and key hash
- Document gas limits and confirmations

## Expected Output Format

```javascript
// Contract configuration for PepedawnRaffle deployment
// Last updated: [TIMESTAMP]
// Deployed on: [NETWORK_NAME]

export const CONTRACT_CONFIG = {
  // Contract address from latest deployment
  address: "0x...", // Deployed on [DATE] - Block [BLOCK_NUMBER]
  
  // Network configuration
  network: 'sepolia',
  chainId: 11155111,
  
  // Latest ABI from compilation
  abi: [
    // ... complete ABI array
  ]
};

// VRF Configuration (if needed)
export const VRF_CONFIG = {
  coordinator: "0x...",
  subscriptionId: 123,
  keyHash: "0x...",
  callbackGasLimit: 500000,
  requestConfirmations: 5
};

// Network-specific settings
export const NETWORKS = {
  sepolia: {
    name: 'Sepolia Testnet',
    chainId: 11155111,
    rpcUrl: 'https://sepolia.infura.io/v3/...',
    blockExplorer: 'https://sepolia.etherscan.io'
  }
  // ... other networks
};
```

## Validation Steps

1. **Syntax Check**: Ensure valid JavaScript syntax
2. **Address Validation**: Verify contract address is a valid Ethereum address
3. **ABI Validation**: Confirm ABI contains expected functions (placeBet, submitProof, etc.)
4. **Network Consistency**: Ensure network settings match deployment target
5. **Export Verification**: Confirm all exports work correctly

## Error Handling

If artifacts are missing or invalid:
- Report which files are missing
- Suggest running deployment scripts first
- Provide fallback to current configuration
- Log specific error messages for debugging

## Notes

- **Preserve custom configurations** that aren't in artifacts
- **Add helpful comments** with deployment details
- **Maintain backward compatibility** where possible
- **Use consistent formatting** throughout the file
- **Include error handling** for missing artifacts

This prompt ensures the frontend stays synchronized with the latest smart contract deployment.
