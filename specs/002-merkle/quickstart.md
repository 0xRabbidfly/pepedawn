# Quickstart Guide: Merkle Proof Claims Implementation

**Feature**: 002-merkle  
**Date**: October 8, 2025  
**Estimated Time**: 2-3 hours for complete setup and first test

## Overview

This guide walks through setting up the development environment, running tests, and verifying the Merkle proof claims implementation.

## Prerequisites

- Node.js 18+ and npm
- Foundry (forge, anvil)
- Git
- MetaMask or similar Web3 wallet (for frontend testing)

## Step 1: Environment Setup (10 minutes)

### 1.1 Install Dependencies

```bash
# Navigate to project root
cd Z:\Projects\pepedawn

# Install contract dependencies (if not already installed)
cd contracts
forge install

# Install frontend dependencies
cd ../frontend
npm install

# Install new dependencies for Merkle functionality
npm install merkletreejs
npm install --save-dev vitest @vitest/ui
```

### 1.2 Verify Installation

```bash
# Test Foundry
forge --version

# Test Node
node --version

# Test npm packages
npm list merkletreejs
```

**Expected Output**: All commands should return version numbers without errors.

## Step 2: Smart Contract Development (30 minutes)

### 2.1 Review Existing Contract

```bash
cd Z:\Projects\pepedawn\contracts\src
```

Open `PepedawnRaffle.sol` and familiarize yourself with:
- Existing round state management
- VRF integration
- Current prize distribution logic

### 2.2 Create Test File

```bash
cd Z:\Projects\pepedawn\contracts\test
```

Create `MerkleProofs.t.sol`:

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "forge-std/Test.sol";
import "../src/PepedawnRaffle.sol";
import "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";

contract MerkleProofsTest is Test {
    PepedawnRaffle public raffle;
    
    function setUp() public {
        // Deploy contract
        raffle = new PepedawnRaffle(/* constructor args */);
    }
    
    function testSnapshotParticipants() public {
        // TODO: Test participants snapshot
        assertTrue(false, "Test not implemented");
    }
    
    function testCommitWinners() public {
        // TODO: Test winners commitment
        assertTrue(false, "Test not implemented");
    }
    
    function testClaimWithValidProof() public {
        // TODO: Test valid claim
        assertTrue(false, "Test not implemented");
    }
    
    function testClaimWithInvalidProof() public {
        // TODO: Test invalid claim
        vm.expectRevert("Invalid proof");
        // TODO: Call claim with invalid proof
    }
}
```

### 2.3 Run Failing Tests

```bash
forge test --match-contract MerkleProofsTest -vv
```

**Expected Output**: All tests should fail (not implemented yet).

### 2.4 Implement Contract Extensions

Follow the contract API specification in `contracts/merkle-api.md` to:
1. Add state variables for Merkle roots
2. Implement `snapshotParticipants` function
3. Implement `commitWinners` function
4. Implement `claim` function with Merkle proof verification
5. Implement `withdrawRefund` function

### 2.5 Run Tests Again

```bash
forge test --match-contract MerkleProofsTest -vv
```

**Expected Output**: All tests should pass.

## Step 3: Frontend Service Development (45 minutes)

### 3.1 Create Service Files

```bash
cd Z:\Projects\pepedawn\frontend\src
mkdir -p services
```

Create the following files:
- `services/merkle.js` (MerkleService)
- `services/ipfs.js` (IPFSService)
- `services/claims.js` (ClaimsService)
- `utils/logger.js` (Logger)

### 3.2 Create Test Files

```bash
cd Z:\Projects\pepedawn\frontend
mkdir -p tests
```

Create test files:
- `tests/merkle.test.js`
- `tests/ipfs.test.js`
- `tests/claims.test.js`

### 3.3 Configure Vitest

Create `vitest.config.js`:

```javascript
import { defineConfig } from 'vitest/config';

export default defineConfig({
  test: {
    globals: true,
    environment: 'jsdom',
    setupFiles: './tests/setup.js'
  }
});
```

### 3.4 Write Failing Tests

Example for `tests/merkle.test.js`:

```javascript
import { describe, it, expect } from 'vitest';
import { MerkleService } from '../src/services/merkle.js';

describe('MerkleService', () => {
  it('should build participants tree', async () => {
    const service = new MerkleService();
    const participants = [
      { address: '0x1234...', weight: 100 },
      { address: '0x5678...', weight: 50 }
    ];
    
    const tree = await service.buildParticipantsTree(participants, 1);
    expect(tree).toBeDefined();
    expect(tree.getRoot()).toBeDefined();
  });
  
  it('should generate valid proof', () => {
    // TODO: Implement test
    expect(false).toBe(true);
  });
});
```

### 3.5 Run Failing Tests

```bash
npm test
```

**Expected Output**: Tests should fail (not implemented yet).

### 3.6 Implement Services

Follow the frontend API specification in `contracts/frontend-api.md` to implement:
1. MerkleService with tree building and proof generation
2. IPFSService with timeout and fallback logic
3. ClaimsService with claim and refund functions
4. Logger with structured logging

### 3.7 Run Tests Again

```bash
npm test
```



## Step 5: Mobile Testing (15 minutes)

### 5.1 Test Responsive Layout

```bash
# Open Chrome DevTools
# Press F12 → Toggle device toolbar (Ctrl+Shift+M)
# Select iPhone 12 Pro
```

**Verify**:
- ✓ Leaderboard displays top 20 with "View all" button
- ✓ Claim buttons are 44x44px minimum
- ✓ Addresses are truncated with copy button
- ✓ Tables adapt to narrow screen
- ✓ All features accessible

### 5.2 Test Mobile Wallet

1. **Install MetaMask Mobile** on test device
2. **Connect via WalletConnect**
3. **Test claim transaction** from mobile
4. **Verify UI responsiveness**

**Expected Outcome**: All features work on mobile with appropriate touch targets.


## Step 7: Gas Optimization Check (10 minutes)

### 7.1 Measure Claim Gas

```bash
forge test --match-test testClaimWithValidProof --gas-report
```

**Expected Output**:
- `claim` function: ~100,000-150,000 gas
- `withdrawRefund` function: ~40,000 gas

### 7.2 Optimize if Needed

If gas usage exceeds targets:
1. Review Merkle proof verification logic
2. Optimize storage layout
3. Use packed encoding where possible
4. Re-run gas report

## Step 8: Security Validation (15 minutes)

### 8.1 Run Slither Analysis

```bash
cd Z:\Projects\pepedawn\contracts
slither src/PepedawnRaffle.sol
```

**Expected Output**: No HIGH or CRITICAL severity issues.

### 8.2 Test Reentrancy Protection

```solidity
function testReentrancyProtection() public {
    // TODO: Attempt reentrancy attack on claim function
    vm.expectRevert("ReentrancyGuard: reentrant call");
    // TODO: Call claim recursively
}
```

**Expected Output**: Reentrancy attack should fail.

### 8.3 Test Access Control

```solidity
function testNonOwnerCannotSnapshot() public {
    vm.prank(address(0x1234)); // Non-owner
    vm.expectRevert("Ownable: caller is not the owner");
    raffle.snapshotParticipants(1, bytes32(0), "QmTest", 10);
}
```

**Expected Output**: Non-owner calls should revert.

## Troubleshooting

### Issue: Forge tests fail with "MerkleProof not found"

**Solution**:
```bash
forge install OpenZeppelin/openzeppelin-contracts
forge remappings > remappings.txt
```

### Issue: Frontend tests fail with "Cannot find module 'merkletreejs'"

**Solution**:
```bash
npm install merkletreejs
npm install keccak256
```

### Issue: IPFS fetch always times out

**Solution**:
- Check internet connection
- Try alternative IPFS gateway
- Use local IPFS node for testing
- Mock IPFS responses in tests

### Issue: Mobile wallet connection fails

**Solution**:
- Ensure WalletConnect project ID is configured
- Check that frontend is accessible from mobile device
- Verify HTTPS or ngrok tunnel for mobile testing

### Issue: Merkle proof verification fails on-chain

**Solution**:
- Verify leaf encoding matches contract (`abi.encode`)
- Check that tree uses `sortPairs: true`
- Ensure on-chain root matches computed root
- Verify proof array is not empty

## Success Criteria

✅ All contract tests pass (forge test)  
✅ All frontend tests pass (npm test)  
✅ Complete round lifecycle works end-to-end  
✅ Merkle verification displays "Verified ✓" badge  
✅ Claims work with valid proofs  
✅ Claims fail with invalid proofs  
✅ Refunds withdraw successfully  
✅ Mobile UI is responsive and functional  
✅ Performance targets met (<500ms tree building)  
✅ Gas usage within targets (<150k per claim)  
✅ No security issues from Slither  
✅ Reentrancy protection works  
✅ Access control enforced

## Next Steps

After completing this quickstart:

1. **Review Code**: Conduct peer review of contract and frontend code
2. **Write Documentation**: Update user-facing documentation
3. **Deploy to Testnet**: Deploy to Sepolia for public testing
4. **Conduct Audit**: Engage security auditor for contract review
5. **User Testing**: Conduct usability testing with real users
6. **Mainnet Preparation**: Prepare deployment scripts and migration plan

## Resources

- **Specification**: [spec.md](./spec.md)
- **Data Model**: [data-model.md](./data-model.md)
- **Contract API**: [contracts/merkle-api.md](./contracts/merkle-api.md)
- **Frontend API**: [contracts/frontend-api.md](./contracts/frontend-api.md)
- **Research**: [research.md](./research.md)
- **Constitution**: [../../.specify/memory/constitution.md](../../.specify/memory/constitution.md)

## Support

For questions or issues:
1. Check troubleshooting section above
2. Review specification documents
3. Consult constitution for design principles
4. Open GitHub issue with detailed description

---

**Estimated Total Time**: 2-3 hours  
**Difficulty**: Intermediate  
**Prerequisites**: Solidity, JavaScript, Web3 basics
