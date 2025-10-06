# Quickstart Guide: PEPEDAWN Development Setup

**Feature**: 001-build-a-simple  
**Date**: 2025-10-06  
**Target**: Developers setting up the project for the first time

## Prerequisites

### Required Software
- **Node.js**: v18+ (for frontend build tools)
- **Git**: For version control
- **Foundry**: For smart contract development and testing
- **MetaMask**: Browser extension for wallet testing

### Recommended Tools
- **VS Code**: With Solidity and JavaScript extensions
- **Ethereum wallet**: With testnet ETH for testing

## Quick Setup (5 minutes)

### 1. Clone and Install
```bash
# Clone the repository
git clone <repository-url>
cd pepedawn

# Install frontend dependencies
cd frontend
npm install

# Install Foundry (if not already installed)
curl -L https://foundry.paradigm.xyz | bash
foundryup

# Install contract dependencies
cd ../contracts
forge install
```

### 2. Environment Configuration
```bash
# Copy environment template
cp .env.example .env

# Edit .env with your settings:
# - RPC_URL: Your Ethereum RPC endpoint
# - PRIVATE_KEY: Your deployment private key (testnet only)
# - ETHERSCAN_API_KEY: For contract verification
```

### 3. Run Tests
```bash
# Test smart contracts locally (no deployment needed)
cd contracts
forge test

# Test frontend (basic)
cd ../frontend
npm run test
```

**⚠️ Expected Results**: 
- **✅ BasicDeploymentTest**: Should pass (local contract deployment)
- **❌ DeployedContractTest**: Will fail until you deploy to testnet
- **❌ Other tests**: May fail due to VRF/ownership issues (expected for now)

**To test deployed contract after deployment**:
```bash
# Load environment variables from .env
Get-Content .env | ForEach-Object { if($_ -match "^([^#][^=]+)=(.*)$") { [Environment]::SetEnvironmentVariable($matches[1], $matches[2], "Process") } }
# Test deployed contract specifically
forge test --match-path "test/DeployedContractTest.t.sol" --fork-url $env:SEPOLIA_RPC_URL
```

**⚠️ Important Note**: The test suite includes `DeployedContractTest` which requires a deployed contract on Sepolia. If you haven't deployed yet, you'll see failures like "call to non-contract address". To deploy:

```bash
# Deploy to Sepolia (requires environment setup)
forge script script/Deploy.s.sol --rpc-url $SEPOLIA_RPC_URL --broadcast --verify

# Or deploy manually using Remix IDE (recommended for beginners)
# See deployment section below for details
```

### 4. Start Development
```bash
# Start frontend development server
cd frontend
npm run dev

# In another terminal, start local blockchain (optional)
anvil
```

## Project Structure Overview

```
pepedawn/
├── frontend/                 # Vite MPA web application
│   ├── src/
│   │   ├── main.js          # Main betting page logic
│   │   ├── contract-config.js # Contract addresses/ABIs
│   │   └── ui.js            # Wallet connection & UI
│   ├── index.html           # Title page
│   ├── main.html            # Betting interface
│   └── rules.html           # Rules page
├── contracts/               # Foundry smart contracts
│   ├── src/
│   │   └── PepedawnRaffle.sol # Main contract
│   ├── test/                # Comprehensive test suite
│   └── script/              # Deployment scripts
└── deploy/
    └── artifacts/           # Deployment artifacts
```

## Development Workflow

### Smart Contract Development

#### 1. Write Tests First (TDD)
```bash
cd contracts

# Create failing test
forge create test/NewFeature.t.sol

# Write test that fails
forge test --match-test testNewFeature

# Implement feature until test passes
forge test --match-test testNewFeature
```

#### 2. Run Full Test Suite
```bash
# Unit tests
forge test

# Invariant/fuzz tests
forge test --fuzz-runs 1000

# Gas reporting
forge test --gas-report

# Coverage analysis
forge coverage
```

#### 3. Deploy to Testnet

**Option A: Deploy with Foundry (Advanced)**
```bash
# Set up environment variables (create .env file in contracts/ directory)
# Required variables:
# SEPOLIA_RPC_URL=https://sepolia.drpc.org  # or your Infura/Alchemy URL
# PRIVATE_KEY=0x...  # your wallet private key
# VRF_COORDINATOR=0x8103B0A8A00be2DDC778e6e7eaa21791Cd364625
# VRF_SUBSCRIPTION_ID=1
# VRF_KEY_HASH=0x474e34a077df58807dbe9c96d3c009b23b3c6d0cce433e59bbf5b34f823bc56c
# CREATORS_ADDRESS=0x...  # your address
# EMBLEM_VAULT_ADDRESS=0x...  # your address

# Test deployment first (simulation)
$env:SEPOLIA_RPC_URL = "https://sepolia.drpc.org"
forge script script/Deploy.s.sol --rpc-url $env:SEPOLIA_RPC_URL

# Deploy to Sepolia
forge script script/Deploy.s.sol --rpc-url $env:SEPOLIA_RPC_URL --broadcast

# Update contract addresses in frontend
cp deploy/artifacts/addresses.json frontend/public/deploy/

# Test deployed contract
forge test --match-path "test/DeployedContractTest.t.sol" --fork-url $env:SEPOLIA_RPC_URL
```

**Option B: Deploy with Remix IDE (Recommended for beginners)**
1. Open [Remix IDE](https://remix.ethereum.org/)
2. Create new file: `PepedawnRaffle.sol`
3. Copy your contract code
4. Compile with Solidity 0.8.20
5. In "Deploy & Run Transactions":
   - Environment: "Injected Web3" (MetaMask)
   - Network: Sepolia Testnet
   - Contract: PepedawnRaffle
   - Constructor parameters:
     - VRF Coordinator: `0x8103B0A8A00be2DDC778e6e7eaa21791Cd364625`
     - Subscription ID: `1`
     - Key Hash: `0x474e34a077df58807dbe9c96d3c009b23b3c6d0cce433e59bbf5b34f823bc56c`
     - Creators Address: Your address
     - Emblem Vault Address: Your address
6. Deploy and copy the contract address

**⚠️ Important Notes**:
- **DeployedContractTest**: The test suite includes tests that connect to a deployed contract. Without deployment, you'll see "call to non-contract address" errors.
- **Environment Variables**: Foundry requires environment variables to be set in the shell session (not just in .env file)
- **RPC URLs**: Some Infura projects may not have Sepolia access. Use `https://sepolia.drpc.org` as a fallback.
- **Testing Deployed Contracts**: Use `--fork-url` when testing deployed contracts to connect to the actual network.

### Frontend Development

#### 1. Start Development Server
```bash
cd frontend
npm run dev
# Opens http://localhost:5173
```

#### 2. Test Wallet Integration
- Install MetaMask browser extension
- Switch to Sepolia testnet
- Get testnet ETH from faucet
- Connect wallet to application
- Test betting flow

#### 3. Build for Production
```bash
npm run build
# Outputs to dist/ directory
```

## Testing Guide

### Contract Testing Strategy

#### Unit Tests
- Test individual functions in isolation
- Mock external dependencies (VRF, Emblem Vault)
- Cover all edge cases and error conditions

#### Invariant Tests
- Test system-wide properties that should always hold
- Example: Total weight equals sum of individual weights
- Run with fuzzing for comprehensive coverage

#### Scenario Tests
- Test complete user journeys end-to-end
- Example: Full round lifecycle from creation to prize distribution
- Include multiple participants and edge cases

### Frontend Testing

#### Manual Testing Checklist
- [ ] Wallet connection/disconnection
- [ ] Network switching
- [ ] Bet placement (1, 5, 10 tickets)
- [ ] Puzzle proof submission
- [ ] Leaderboard updates
- [ ] Error handling
- [ ] Mobile responsiveness

#### Automated Testing (Minimal)
```bash
# Run basic frontend tests
npm run test

# Visual regression testing (optional)
npm run test:visual
```

## Common Development Tasks

### Add New Contract Function

1. **Write Test First**:
```solidity
// test/NewFunction.t.sol
function testNewFunction() public {
    // Arrange
    // Act
    // Assert
}
```

2. **Implement Function**:
```solidity
// src/PepedawnRaffle.sol
function newFunction() external {
    // Implementation
}
```

3. **Update Frontend Interface**:
```javascript
// src/contract-config.js
// Add function to ABI and create wrapper
```

### Update Frontend UI

1. **Modify HTML**:
```html
<!-- main.html -->
<div id="new-feature">
  <!-- New UI elements -->
</div>
```

2. **Add JavaScript Logic**:
```javascript
// src/main.js
function handleNewFeature() {
  // Implementation
}
```

3. **Update Styles**:
```css
/* src/style.css */
#new-feature {
  /* Styling */
}
```

### Deploy to New Network

1. **Update Configuration**:
```bash
# Add network to foundry.toml
[rpc_endpoints]
new_network = "https://rpc.new-network.com"
```

2. **Deploy Contracts**:
```bash
forge script script/Deploy.s.sol --rpc-url $NEW_NETWORK_RPC --broadcast
```

3. **Update Frontend Config**:
```javascript
// src/contract-config.js
const NETWORKS = {
  // Add new network configuration
};
```

## Troubleshooting

### Common Issues

#### "Foundry not found"
```bash
# Install Foundry
curl -L https://foundry.paradigm.xyz | bash
foundryup
```

#### "Contract compilation failed"
```bash
# Clean and rebuild
forge clean
forge build
```

#### "call to non-contract address" or DeployedContractTest failures
This happens when `forge test` tries to connect to a deployed contract that doesn't exist or has the wrong address.

**Solutions:**
1. **Deploy the contract first** (see deployment section above)
2. **Update the contract address** in `test/DeployedContractTest.t.sol`:
   ```solidity
   address constant DEPLOYED_CONTRACT = 0xYOUR_NEW_CONTRACT_ADDRESS;
   ```
3. **Run only local tests** (skip deployed contract tests):
   ```bash
   forge test --match-path "test/BasicDeployment.t.sol"
   forge test --match-path "test/AccessControl.t.sol"
   # etc. (skip DeployedContractTest.t.sol)
   ```

#### "Frontend won't connect to wallet"
- Check MetaMask is installed and unlocked
- Verify correct network selected
- Check browser console for errors
- Ensure contract addresses are correct

#### "Tests failing after changes"
```bash
# Run specific test with verbose output
forge test --match-test testSpecificFunction -vvv

# Check gas usage
forge test --gas-report
```

### Getting Help

1. **Check existing tests** for usage examples
2. **Review contract events** in Etherscan/block explorer
3. **Use Foundry debugger** for transaction analysis:
   ```bash
   forge test --debug testFailingFunction
   ```
4. **Check browser console** for frontend errors

## Performance Tips

### Contract Optimization
- Use `uint256` for gas efficiency
- Batch operations where possible
- Emit events for off-chain indexing
- Minimize storage operations

### Frontend Optimization
- Cache contract call results
- Use event subscriptions for real-time updates
- Minimize bundle size (currently 99.26KB)
- Optimize images and assets

## Security Checklist

### Before Deployment
- [ ] All tests passing
- [ ] Security audit completed
- [ ] Access controls verified
- [ ] Input validation implemented
- [ ] Reentrancy protection added
- [ ] Emergency controls tested

### Before Mainnet
- [ ] Extensive testnet testing
- [ ] Multi-signature setup for owner functions
- [ ] VRF subscription funded
- [ ] Emblem Vault integration verified
- [ ] Frontend security review completed

## Next Steps

After completing quickstart:
1. Review [data-model.md](./data-model.md) for entity relationships
2. Study [contracts/](./contracts/) for API specifications
3. Run through complete testing scenarios
4. Deploy to testnet and verify functionality
5. Proceed to implementation tasks via `/tasks` command