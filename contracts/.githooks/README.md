# Git Hooks for PepedawnRaffle

This directory contains git hooks to automate quality checks during development.

## Pre-Commit Hook

The pre-commit hook runs the fast test suite before allowing commits. This provides immediate feedback and prevents broken code from being committed.

### Features
- ✅ Runs in **<5 seconds** (fast pre-commit profile)
- ✅ Tests core functionality (75 essential tests)
- ✅ Catches issues before they reach the repository
- ✅ Can be skipped with `--no-verify` if needed

### Installation

#### Option 1: Bash (Linux/Mac/Git Bash on Windows)
```bash
cd Z:\Projects\pepedawn
bash contracts/.githooks/install.sh
```

#### Option 2: PowerShell (Windows)
```powershell
cd Z:\Projects\pepedawn
.\contracts\.githooks\install.ps1
```

#### Option 3: Manual Installation
```bash
# From project root
cp contracts/.githooks/pre-commit .git/hooks/pre-commit
chmod +x .git/hooks/pre-commit
```

### Usage

Once installed, the hook runs automatically before every commit:

```bash
git add .
git commit -m "Your commit message"
# 🧪 Running pre-commit tests...
# (tests run automatically)
# ✅ Pre-commit tests passed!
```

### Skipping the Hook

If you need to commit without running tests (not recommended):

```bash
git commit --no-verify -m "Your commit message"
```

### What Tests Are Run?

The pre-commit hook uses the `pre-commit` Foundry profile, which runs **all test files** with optimized settings:

- **Core.t.sol** - Deployment, constants, smoke tests (25 tests)
- **RoundLifecycle.t.sol** - Round states and transitions (26 tests)
- **BettingAndProofs.t.sol** - Wagers, proofs, validation (24 tests)
- **WinnerSelection.t.sol** - Weighted lottery, prize distribution (11 tests)
- **Security.t.sol** - Reentrancy, VRF security (12 tests)
- **Governance.t.sol** - Access control, pause mechanisms (19 tests)
- **Integration.t.sol** - End-to-end workflows (7 tests)
- **DeployedContractTest.t.sol** - Network tests (1 active, 7 skipped)

**Total**: 125 active tests (7 network tests skipped)  
**Actual Duration**: ~1 second ⚡ (faster than expected!)  
**Fuzz Runs**: 100 (optimized for speed)

### Troubleshooting

#### "forge: command not found"
Make sure Foundry is installed and in your PATH:
```bash
curl -L https://foundry.paradigm.xyz | bash
foundryup
```

#### Hook doesn't run
Verify the hook is installed and executable:
```bash
ls -la .git/hooks/pre-commit
# Should show executable permissions (rwxr-xr-x)
```

#### Tests are slow
The pre-commit profile is optimized for speed (100 fuzz runs). If tests are still slow:
1. Check if you're running the correct profile (`FOUNDRY_PROFILE=pre-commit`)
2. Ensure you're not running the full test suite by accident
3. Try `forge clean` and rebuild

### Uninstalling

To remove the hook:
```bash
rm .git/hooks/pre-commit
```

---

**Note**: The pre-commit hook is optional but highly recommended for development. It catches issues early and maintains code quality.

