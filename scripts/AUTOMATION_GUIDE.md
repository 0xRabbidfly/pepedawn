# PEPEDAWN Automation Guide

## Overview

This guide explains how to set up and use the automated post-commit check system for PEPEDAWN. The system ensures that when you make changes to contracts, all documentation, configuration files, and specs are automatically updated and validated.

## Quick Setup

### 1. Install Dependencies
```bash
npm install
```

### 2. Make Scripts Executable (Linux/Mac)
```bash
chmod +x .git/hooks/post-commit
chmod +x scripts/*.js
```

### 3. Test the System
```bash
# Run all checks
npm run check-all

# Or run individually
npm run post-commit
npm run update-docs
npm run update-configs
```

## How It Works

### Automatic Triggers

1. **After Every Commit**: The post-commit hook automatically runs checks
2. **Contract Changes**: When `PepedawnRaffle.sol` changes, documentation is updated
3. **Configuration Sync**: Addresses and ABIs are synchronized across the project

### What Gets Updated Automatically

#### When Contract Changes:
- ✅ Interface documentation (`specs/001-build-a-simple/contracts/interface-documentation.md`)
- ✅ Quickstart guide (`specs/001-build-a-simple/quickstart.md`)
- ✅ README.md
- ✅ Removes references to deprecated functions
- ✅ Adds documentation for new features

#### When Configuration Changes:
- ✅ Contract ABIs in frontend and deployment artifacts
- ✅ Contract addresses across all config files
- ✅ VRF configuration updates
- ✅ Network settings synchronization

## Manual Commands

### Check Everything
```bash
npm run check-all
```

### Update Documentation Only
```bash
npm run update-docs
```

### Update Configurations Only
```bash
npm run update-configs
```

### Run Post-Commit Checks
```bash
npm run post-commit
```

## Understanding the Output

### ✅ Success Messages
- `Contract changes detected` - New changes found and processed
- `Documentation updated` - Docs automatically updated
- `Configuration sync complete` - All configs synchronized
- `All checks passed` - No issues found

### ⚠️ Warning Messages
- `Documentation file missing` - Some docs need to be created
- `Frontend config contains placeholder addresses` - Need to deploy contract
- `Spec contains unresolved clarifications` - Spec needs updates

### ❌ Error Messages
- `Contract file not found` - Run from project root
- `ABI file not found` - Run `forge build` first
- `Addresses file not found` - Deploy contract first

## Workflow Examples

### 1. Making Contract Changes

```bash
# 1. Edit contract
vim contracts/src/PepedawnRaffle.sol

# 2. Commit changes
git add contracts/src/PepedawnRaffle.sol
git commit -m "Add new feature"

# 3. Post-commit hook runs automatically
# - Detects contract changes
# - Updates documentation
# - Validates consistency
# - Reports any issues
```

### 2. Deploying New Contract

```bash
# 1. Deploy contract
forge script script/Deploy.s.sol --rpc-url $SEPOLIA_RPC_URL --broadcast

# 2. Update configurations
npm run update-configs

# 3. Commit deployment artifacts
git add deploy/artifacts/
git commit -m "Deploy contract v1.1"

# 4. Post-commit hook validates everything
```

### 3. Updating Documentation

```bash
# 1. Make manual doc changes
vim specs/001-build-a-simple/contracts/interface-documentation.md

# 2. Run checks to validate
npm run post-commit

# 3. Fix any issues reported
# 4. Commit when clean
git add specs/
git commit -m "Update documentation"
```

## Customization

### Adding New Checks

Edit `scripts/post-commit-check.js`:

```javascript
// In validateDocumentation() method
if (content.includes('your-pattern')) {
  this.warnings.push('Your warning message');
}
```

### Adding New Documentation Updates

Edit `scripts/update-docs.js`:

```javascript
// Add new method
async updateNewDoc() {
  // Your update logic here
}
```

### Adding New Configuration Updates

Edit `scripts/update-configs.js`:

```javascript
// Add new method
async updateNewConfig() {
  // Your update logic here
}
```

## Integration with Specs

The automation system works with your comprehensive specs:

### Spec Files Monitored:
- `specs/001-build-a-simple/spec.md` - Business requirements
- `specs/001-build-a-simple/plan.md` - Technical plan
- `specs/001-build-a-simple/research.md` - Technology decisions
- `specs/001-build-a-simple/data-model.md` - Entity definitions
- `specs/001-build-a-simple/contracts/` - API specifications

### Constitution Compliance:
The system checks for compliance with your Constitution v1.1.0:
- Security requirements
- VRF fairness
- On-chain escrow
- Skill-weighted odds
- Emblem Vault distribution

## Troubleshooting

### Common Issues

1. **"Cannot find module"**
   ```bash
   # Run from project root
   cd Z:\Projects\pepedawn
   node scripts/post-commit-check.js
   ```

2. **"Contract file not found"**
   ```bash
   # Ensure you're in the right directory
   ls contracts/src/PepedawnRaffle.sol
   ```

3. **"ABI file not found"**
   ```bash
   # Compile contracts first
   forge build
   ```

4. **"Addresses file not found"**
   ```bash
   # Deploy contract first
   forge script script/Deploy.s.sol --rpc-url $SEPOLIA_RPC_URL --broadcast
   ```

5. **Git hook not running**
   ```bash
   # Check if hook exists and is executable
   ls -la .git/hooks/post-commit
   chmod +x .git/hooks/post-commit
   ```

### Disabling Automation

If you need to disable automation temporarily:

```bash
# Rename the hook file
mv .git/hooks/post-commit .git/hooks/post-commit.disabled

# Or comment out the script in package.json
# "post-commit": "node scripts/post-commit-check.js",
```

### Manual Override

If automated updates cause issues:

1. **Skip specific updates** by commenting out sections in scripts
2. **Run individual scripts** instead of the full check
3. **Edit files manually** and commit without running hooks

## Best Practices

### 1. Always Run Checks Before Committing
```bash
npm run check-all
```

### 2. Fix Warnings Before Committing
- Address all warnings in the post-commit report
- Don't ignore placeholder addresses or missing docs

### 3. Keep Specs Updated
- Update specs when adding new features
- Remove implementation details from business specs
- Resolve all "NEEDS CLARIFICATION" markers

### 4. Test After Changes
```bash
# After making changes, test everything
npm run check-all
forge test
npm run build
```

## File Structure

```
pepedawn/
├── scripts/
│   ├── post-commit-check.js    # Main validation script
│   ├── update-docs.js          # Documentation updater
│   ├── update-configs.js       # Configuration updater
│   └── README.md               # Detailed script documentation
├── .git/hooks/
│   ├── post-commit             # Git hook (Linux/Mac)
│   └── post-commit.ps1         # Git hook (Windows)
├── package.json                # NPM scripts
└── AUTOMATION_GUIDE.md         # This guide
```

## Monitoring and Maintenance

### Regular Tasks:
1. **Weekly**: Review post-commit reports for patterns
2. **After major changes**: Run full validation suite
3. **Before releases**: Ensure all warnings are resolved

### Performance:
- Scripts are optimized for speed
- File operations are minimal
- Hashing prevents unnecessary updates

## Support

If you encounter issues:

1. **Check the output** - Scripts provide detailed error messages
2. **Review the logs** - Look for specific file paths and error codes
3. **Run manually** - Test individual scripts to isolate issues
4. **Check dependencies** - Ensure all required files exist

The automation system is designed to make your development workflow smoother while ensuring consistency across your comprehensive PEPEDAWN project specifications.
