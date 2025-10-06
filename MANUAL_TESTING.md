# Testing Workflow

## Philosophy
Hybrid approach: **Automated pre-commit tests** for fast local feedback + **Simplified CI/CD** for basic remote checks + **Manual exploratory testing** for thorough coverage.

## Quick Testing Commands

### Smart Contracts
```bash
# Navigate to contracts directory
cd contracts

# Fast unit tests (core functionality)
forge test --match-path "test/{BasicDeployment,AccessControl,InputValidation}.t.sol"

# Integration tests (full workflows)
forge test --match-path "test/{Round,Security,ScenarioFullRound}.t.sol"

# Specific test when debugging
forge test --match-test "testSpecificFunction" -vvv

# Format check
forge fmt --check
```

### Frontend
```bash
# Navigate to frontend directory
cd frontend

# Type checking
npm run type-check

# Linting
npm run lint

# Development server
npm run dev

# Build (when needed - may have Rollup issues on Windows)
npm run build
```

## Testing Strategy

### Pre-commit (Automated)
The pre-commit hook automatically runs:
1. **Unit tests**: BasicDeployment, AccessControl, InputValidation, Wager, WinnerSelection, Distribution, EmergencyControls, Governance
2. **Integration tests**: Round, Security, ScenarioFullRound  
3. **Frontend type checking**: TypeScript compilation
4. **Frontend linting**: ESLint checks

Just commit normally - tests run automatically and prevent bad commits!

### Before Deployment
1. **Full contract test suite**: Run all tests including security tests
2. **Frontend build**: Ensure frontend builds successfully
3. **Integration testing**: Test contract + frontend interaction
4. **Exploratory testing**: Manual testing of edge cases

### Deployment Testing
1. **Testnet deployment**: Deploy to Sepolia and test manually
2. **VRF testing**: Test VRF functionality with real Chainlink (requires funding)
3. **User acceptance**: Test from end-user perspective

## GitHub Actions (Simplified CI/CD)
The remote CI now only does basic checks:
- ✅ Contract compilation and formatting
- ✅ Frontend type checking and linting  
- ❌ No tests (run locally via pre-commit)
- ❌ No frontend build (due to platform issues)

This ensures commits don't break basic compilation while avoiding problematic build steps.

## Benefits of This Hybrid Approach
- **Fast local feedback**: Pre-commit catches issues immediately
- **Reliable CI**: Simple remote checks that don't fail due to platform issues
- **Comprehensive coverage**: Automated tests + manual exploration
- **Cost effective**: Minimal CI minutes, most testing done locally
- **Developer friendly**: Tests run when you need them, not when CI decides

## When to Run Full Test Suite
- Before major releases
- When touching security-critical code
- When refactoring core functionality
- Before mainnet deployment
