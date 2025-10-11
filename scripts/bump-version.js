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

// Update rules.html with version
const rulesHtmlPath = path.join(__dirname, '..', 'frontend', 'rules.html');
let rulesHtml = fs.readFileSync(rulesHtmlPath, 'utf8');

// Add or update version in footer
if (rulesHtml.includes('<!-- VERSION_PLACEHOLDER -->')) {
  rulesHtml = rulesHtml.replace(
    /<!-- VERSION_PLACEHOLDER -->.*?<!-- \/VERSION_PLACEHOLDER -->/s,
    `<!-- VERSION_PLACEHOLDER --><div class="version">v${newVersion}</div><!-- /VERSION_PLACEHOLDER -->`
  );
} else {
  // Add version placeholder before closing footer or body tag
  if (rulesHtml.includes('</footer>')) {
    rulesHtml = rulesHtml.replace(
      '</footer>',
      '        <!-- VERSION_PLACEHOLDER --><div class="version">v' + newVersion + '</div><!-- /VERSION_PLACEHOLDER -->\n      </footer>'
    );
  } else if (rulesHtml.includes('</main>')) {
    rulesHtml = rulesHtml.replace(
      '</main>',
      '</main>\n      <footer>\n        <!-- VERSION_PLACEHOLDER --><div class="version">v' + newVersion + '</div><!-- /VERSION_PLACEHOLDER -->\n      </footer>'
    );
  }
}

fs.writeFileSync(rulesHtmlPath, rulesHtml);
console.log(`✅ Updated rules.html with v${newVersion}`);

// Build frontend with new version
console.log('🔨 Building frontend...');
try {
  execSync('cd frontend && npm run build', { stdio: 'inherit' });
  console.log('✅ Frontend built successfully');
} catch (error) {
  console.error('❌ Frontend build failed');
  process.exit(1);
}

// Git operations
console.log('📝 Creating git commit...');
try {
  execSync(`git add package.json frontend/rules.html frontend/dist`, { stdio: 'inherit' });
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

