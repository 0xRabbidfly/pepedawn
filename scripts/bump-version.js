#!/usr/bin/env node

const fs = require('fs');
const { execSync } = require('child_process');
const path = require('path');

// Get version bump type from command line argument
const bumpType = process.argv[2]; // 'major', 'minor', or 'patch'

if (!['major', 'minor', 'patch'].includes(bumpType)) {
  console.error('❌ Usage: node bump-version.js [major|minor|patch]');
  process.exit(1);
}

// Read current version from package.json
const packageJsonPath = path.join(__dirname, '..', 'package.json');
const packageJson = JSON.parse(fs.readFileSync(packageJsonPath, 'utf8'));
const currentVersion = packageJson.version;

// Parse version
const [major, minor, patch] = currentVersion.split('.').map(Number);

// Calculate new version
let newVersion;
switch (bumpType) {
  case 'major':
    newVersion = `${major + 1}.0.0`;
    break;
  case 'minor':
    newVersion = `${major}.${minor + 1}.0`;
    break;
  case 'patch':
    newVersion = `${major}.${minor}.${patch + 1}`;
    break;
}

console.log(`🔢 Bumping version: ${currentVersion} → ${newVersion} (${bumpType})`);

// Update package.json
packageJson.version = newVersion;
fs.writeFileSync(packageJsonPath, JSON.stringify(packageJson, null, 2) + '\n');
console.log(`✅ Updated package.json to v${newVersion}`);

// Update frontend/src/contract-config.js VERSION constant
const contractConfigPath = path.join(__dirname, '..', 'frontend', 'src', 'contract-config.js');
let contractConfig = fs.readFileSync(contractConfigPath, 'utf8');
contractConfig = contractConfig.replace(
  /export const VERSION = ['"]v[\d.]+['"];/,
  `export const VERSION = 'v${newVersion}';`
);
fs.writeFileSync(contractConfigPath, contractConfig);
console.log(`✅ Updated frontend/src/contract-config.js to v${newVersion}`);

// Update contracts/src/PepedawnRaffle.sol VERSION constant
const contractSolPath = path.join(__dirname, '..', 'contracts', 'src', 'PepedawnRaffle.sol');
let contractSol = fs.readFileSync(contractSolPath, 'utf8');
contractSol = contractSol.replace(
  /string public constant VERSION = "[\d.]+";/,
  `string public constant VERSION = "${newVersion}";`
);
fs.writeFileSync(contractSolPath, contractSol);
console.log(`✅ Updated contracts/src/PepedawnRaffle.sol to ${newVersion}`);

// Note: User will build frontend manually
console.log('⚠️  Remember to run: npm run build');

// Git operations
console.log('📝 Creating git commit...');
try {
  execSync(`git add package.json frontend/src/contract-config.js contracts/src/PepedawnRaffle.sol`, { stdio: 'inherit' });
  execSync(`git commit -m "chore: bump version to v${newVersion} (${bumpType})"`, { stdio: 'inherit' });
  console.log(`✅ Committed version bump to v${newVersion}`);
  
  // Create git tag
  execSync(`git tag -a v${newVersion} -m "Release v${newVersion}"`, { stdio: 'inherit' });
  console.log(`✅ Created git tag v${newVersion}`);
  
  console.log('\n🎉 Version bumped successfully!');
  console.log(`\nTo push to remote, run:`);
  console.log(`  git push origin master`);
  console.log(`  git push origin v${newVersion}`);
  console.log(`\nOr just run: git push --follow-tags`);
  
} catch (error) {
  console.error('❌ Git operations failed:', error.message);
  process.exit(1);
}

