#!/usr/bin/env node

/**
 * Local deployment script for pepedawn.art
 * This script helps test the deployment process locally
 */

const fs = require('fs');
const path = require('path');

const DIST_DIR = path.join(__dirname, 'dist');
const DEPLOY_DIR = path.join(__dirname, 'deploy-test');

console.log('🚀 Starting local deployment test...');

// Check if dist directory exists
if (!fs.existsSync(DIST_DIR)) {
  console.error('❌ dist/ directory not found. Run "npm run build" first.');
  process.exit(1);
}

// Create deploy-test directory
if (!fs.existsSync(DEPLOY_DIR)) {
  fs.mkdirSync(DEPLOY_DIR, { recursive: true });
  console.log('📁 Created deploy-test directory');
}

// Copy files from dist to deploy-test
function copyDirectory(src, dest) {
  if (!fs.existsSync(dest)) {
    fs.mkdirSync(dest, { recursive: true });
  }
  
  const entries = fs.readdirSync(src, { withFileTypes: true });
  
  for (const entry of entries) {
    const srcPath = path.join(src, entry.name);
    const destPath = path.join(dest, entry.name);
    
    if (entry.isDirectory()) {
      copyDirectory(srcPath, destPath);
    } else {
      fs.copyFileSync(srcPath, destPath);
    }
  }
}

try {
  copyDirectory(DIST_DIR, DEPLOY_DIR);
  console.log('✅ Files copied to deploy-test directory');
  
  // Verify critical PNG files are included
  const pngFiles = ['counterparty.png', 'raven_cutout_800.png', 'PEPEDAWN_thumbnail.png'];
  console.log('\n🖼️  Verifying PNG files:');
  pngFiles.forEach(file => {
    const filePath = path.join(DEPLOY_DIR, file);
    if (fs.existsSync(filePath)) {
      console.log(`   ✅ ${file}`);
    } else {
      console.log(`   ❌ ${file} - MISSING!`);
    }
  });
  
  // List copied files
  const files = fs.readdirSync(DEPLOY_DIR, { recursive: true });
  console.log('📋 Copied files:');
  files.forEach(file => {
    console.log(`   - ${file}`);
  });
  
  console.log('\n🎉 Local deployment test completed successfully!');
  console.log('📂 Check the deploy-test/ directory for the files that would be deployed.');
  console.log('🔗 To deploy to production, configure FTP credentials in GitHub Secrets:');
  console.log('   - FTP_SERVER: Your FTP hostname');
  console.log('   - FTP_USERNAME: Your FTP username');
  console.log('   - FTP_PASSWORD: Your FTP password');
  
} catch (error) {
  console.error('❌ Deployment test failed:', error.message);
  process.exit(1);
}
