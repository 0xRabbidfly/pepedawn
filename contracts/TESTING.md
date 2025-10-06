# Testing Guide for PepedawnRaffle

This document explains the testing strategy and how to run different types of tests.

## 🎯 Test Categories

### **Unit Tests** (`test:unit`)
- **Purpose**: Test individual functions with mocked dependencies
- **Speed**: Fast (no network calls)
- **When to run**: Every commit, local development
- **Files**: `BasicDeployment`, `AccessControl`, `InputValidation`, `Wager`, `WinnerSelection`, `Distribution`, `EmergencyControls`, `Governance`

### **Integration Tests** (`test:integration`)
- **Purpose**: Test complete workflows with mocked VRF
- **Speed**: Medium
- **When to run**: Before deployment, staging
- **Files**: `Round`, `Security`, `ScenarioFullRound`

### **Deployed Contract Tests** (`test:deployed`)
- **Purpose**: Test live deployed contract on Sepolia
- **Speed**: Slow (network calls)
- **When to run**: Manual testing, after deployment
- **Requirements**: `SEPOLIA_RPC_URL` environment variable

### **VRF Tests** (`test:vrf`)
- **Purpose**: Test VRF integration with real Chainlink
- **Speed**: Slow (network calls, VRF fulfillment)
- **When to run**: Manual testing only
- **Requirements**: Funded VRF subscription, `SEPOLIA_RPC_URL`

### **Security Tests** (`test:security`)
- **Purpose**: Security-focused testing with extensive fuzzing
- **Speed**: Slow (high fuzz runs)
- **When to run**: Before mainnet deployment

## 🚀 Running Tests

### **Using Foundry Profiles**
```bash
# Unit tests (fast, mocked)
forge test --profile unit

# Integration tests (workflow with mocks)
forge test --profile integration

# Deployed contract tests (requires network)
forge test --profile deployed

# VRF tests (requires funded subscription)
forge test --profile vrf

# Security tests (extensive fuzzing)
forge test --profile security

# All tests (excluding VRF)
forge test --profile all

# CI tests (fast, reliable)
forge test --profile ci
```

### **Using Scripts**
```bash
# Bash (Linux/Mac)
./scripts/test.sh unit
./scripts/test.sh integration
./scripts/test.sh deployed
./scripts/test.sh vrf

# PowerShell (Windows)
.\scripts\test.ps1 unit
.\scripts\test.ps1 integration
.\scripts\test.ps1 deployed
.\scripts\test.ps1 vrf
```

### **Using npm Scripts**
```bash
npm run test:unit
npm run test:integration
npm run test:deployed
npm run test:vrf
npm run test:security
npm run test:all
```

## 🔧 Environment Setup

### **Required Environment Variables**
Create a `.env` file in the `contracts/` directory:

```env
# Sepolia Testnet Configuration
SEPOLIA_RPC_URL=https://sepolia.drpc.org
PRIVATE_KEY=your_private_key_here

# VRF Configuration (for VRF tests)
VRF_COORDINATOR=0x8103B0A8A00be2DDC778e6e7eaa21791Cd364625
VRF_SUBSCRIPTION_ID=your_subscription_id
VRF_KEY_HASH=0x474e34a077df58807dbe9c96d3c009b23b3c6d0cce433e59bbf5b34f823bc56c

# Address Configuration
CREATORS_ADDRESS=0x0000000000000000000000000000000000000000
EMBLEM_VAULT_ADDRESS=0x0000000000000000000000000000000000000000
```

## 🏗️ CI/CD Integration

### **GitHub Actions**
The project includes GitHub Actions workflows:

- **Automatic**: Unit, integration, and security tests on every push/PR
- **Manual**: Deployed contract and VRF tests (requires secrets)

### **Required Secrets**
Set these in your GitHub repository settings:

- `SEPOLIA_RPC_URL`: Your Sepolia RPC endpoint

## 📊 Test Results Interpretation

### **Expected Results**

#### **Unit Tests**: Should all pass ✅
- These test individual functions with mocks
- No external dependencies

#### **Integration Tests**: Should all pass ✅
- These test workflows with mocked VRF
- No network calls required

#### **Deployed Tests**: May have some failures ⚠️
- Depends on deployed contract state
- Some tests expect no active rounds

#### **VRF Tests**: May have some failures ⚠️
- Requires funded VRF subscription
- Some tests are designed to fail (security testing)

### **Common Issues**

1. **"call to non-contract address"**: Contract not deployed or wrong address
2. **"InvalidConsumer"**: Contract not added to VRF subscription
3. **"insufficient funds"**: VRF subscription needs more LINK
4. **"Round not in required status"**: Wrong round state for operation

## 🎯 Best Practices

1. **Run unit tests frequently** during development
2. **Run integration tests** before committing
3. **Run deployed tests** after deployment
4. **Run VRF tests** only when needed (expensive)
5. **Run security tests** before mainnet deployment

## 🔍 Debugging Tests

### **Verbose Output**
```bash
forge test --profile unit -vvv
```

### **Specific Test**
```bash
forge test --match-test testSpecificFunction --profile unit
```

### **Gas Reporting**
```bash
forge test --profile unit --gas-report
```

## 📝 Adding New Tests

1. Create test file in `test/` directory
2. Follow naming convention: `DescriptiveName.t.sol`
3. Add to appropriate profile in `foundry.toml`
4. Update this documentation
