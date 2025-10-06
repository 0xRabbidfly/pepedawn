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
# Test smart contracts
cd contracts
forge test

# Test frontend (basic)
cd ../frontend
npm run test
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
```bash
# Deploy to Sepolia
forge script script/Deploy.s.sol --rpc-url $SEPOLIA_RPC_URL --broadcast --verify

# Update contract addresses in frontend
cp deploy/artifacts/addresses.json frontend/public/deploy/
```

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