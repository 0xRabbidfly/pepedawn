#!/usr/bin/env node

const fs = require('fs');
const { execSync } = require('child_process');
const path = require('path');

console.log('📝 Injecting build info into HTML files...');

// Get git info
let gitHash = 'unknown';
let gitMessage = 'No commit message';
let gitDate = '';

try {
  gitHash = execSync('git rev-parse --short HEAD', { encoding: 'utf8' }).trim();
  gitMessage = execSync('git log -1 --pretty=%B', { encoding: 'utf8' }).trim();
  gitDate = execSync('git log -1 --pretty=%cd --date=short', { encoding: 'utf8' }).trim();
  console.log(`✅ Git commit: ${gitHash} - ${gitMessage}`);
} catch (error) {
  console.warn('⚠️  Could not get git info:', error.message);
}

// Get version from package.json
const packageJson = JSON.parse(fs.readFileSync(path.join(__dirname, '..', 'package.json'), 'utf8'));
const version = packageJson.version;

// Get build timestamp
const buildDate = new Date().toISOString().split('T')[0]; // YYYY-MM-DD

// Create build info HTML
const buildInfo = `
        <div class="build-info">
          <div class="version">v${version}</div>
          <div class="commit-info">
            <span class="commit-hash" title="${gitMessage}">${gitHash}</span>
            <span class="commit-message">${gitMessage}</span>
          </div>
          <div class="build-date">${buildDate}</div>
        </div>`;

// Update dist/rules.html
const rulesHtmlPath = path.join(__dirname, '..', 'frontend', 'dist', 'rules.html');

if (fs.existsSync(rulesHtmlPath)) {
  let html = fs.readFileSync(rulesHtmlPath, 'utf8');
  
  // Replace the VERSION_PLACEHOLDER section
  if (html.includes('<!-- VERSION_PLACEHOLDER -->')) {
    html = html.replace(
      /<!-- VERSION_PLACEHOLDER -->.*?<!-- \/VERSION_PLACEHOLDER -->/s,
      `<!-- VERSION_PLACEHOLDER -->${buildInfo}<!-- /VERSION_PLACEHOLDER -->`
    );
    
    fs.writeFileSync(rulesHtmlPath, html);
    console.log(`✅ Updated dist/rules.html with build info`);
    console.log(`   Version: v${version}`);
    console.log(`   Commit: ${gitHash} - ${gitMessage}`);
    console.log(`   Built: ${buildDate}`);
  } else {
    console.warn('⚠️  VERSION_PLACEHOLDER not found in rules.html');
  }
} else {
  console.warn('⚠️  dist/rules.html not found. Run npm run build first.');
}

