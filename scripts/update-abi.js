#!/usr/bin/env node

/**
 * Safe ABI Updater for PEPEDAWN
 * 
 * This script safely updates the ABI in frontend configuration files
 * without breaking existing JSON structure.
 */

const fs = require('fs');
const path = require('path');

class ABIUpdater {
  constructor() {
    this.abiPath = 'contracts/out/PepedawnRaffle.sol/PepedawnRaffle.json';
    this.frontendConfigPath = 'frontend/src/contract-config.js';
    this.frontendAbiPath = 'frontend/public/deploy/PepedawnRaffle-abi.json';
  }

  /**
   * Main execution function
   */
  async run() {
    console.log('🔧 PEPEDAWN ABI Updater Starting...\n');
    
    try {
      // 1. Check if ABI exists
      if (!fs.existsSync(this.abiPath)) {
        console.error('❌ ABI file not found. Run "forge build" first.');
        process.exit(1);
      }

      // 2. Read ABI from compiled contract
      const abiData = JSON.parse(fs.readFileSync(this.abiPath, 'utf8'));
      const abi = abiData.abi;
      console.log(`📋 Loaded ABI with ${abi.length} functions/events`);

      // 3. Update frontend config file
      await this.updateFrontendConfig(abi);

      // 4. Update standalone ABI file
      await this.updateStandaloneABI(abi);

      console.log('\n✅ ABI update complete!');
      
    } catch (error) {
      console.error('❌ ABI update failed:', error.message);
      process.exit(1);
    }
  }

  /**
   * Update ABI in frontend config using safe replacement
   */
  async updateFrontendConfig(abi) {
    if (!fs.existsSync(this.frontendConfigPath)) {
      console.warn('⚠️  Frontend config not found, skipping');
      return;
    }

    // Create backup
    const backupPath = this.frontendConfigPath + '.backup';
    fs.copyFileSync(this.frontendConfigPath, backupPath);
    console.log('💾 Created backup:', backupPath);

    let content = fs.readFileSync(this.frontendConfigPath, 'utf8');

    // Find the start and end of the ABI section
    const abiStartRegex = /abi:\s*\[/;
    const abiStartMatch = content.match(abiStartRegex);

    if (!abiStartMatch) {
      console.error('❌ Could not find ABI start in frontend config');
      return;
    }

    const abiStartIndex = content.indexOf(abiStartMatch[0]);
    const beforeAbi = content.substring(0, abiStartIndex);

    // Find the end of the CONTRACT_CONFIG object (closing brace)
    const afterAbiStart = content.indexOf('};', abiStartIndex);
    const afterConfig = content.substring(afterAbiStart);

    // Format the new ABI
    const abiFormatted = JSON.stringify(abi, null, 2).replace(/^/gm, '  ');
    const newAbiSection = `abi: ${abiFormatted}`;

    // Reconstruct the file
    const newContent = beforeAbi + newAbiSection + '\n' + afterConfig;

    // Validate the new content is valid JavaScript
    try {
      // Simple validation - check for balanced braces
      const openBraces = (newContent.match(/{/g) || []).length;
      const closeBraces = (newContent.match(/}/g) || []).length;
      
      if (openBraces !== closeBraces) {
        throw new Error('Unbalanced braces in generated content');
      }

      fs.writeFileSync(this.frontendConfigPath, newContent);
      console.log('✅ Frontend config ABI updated');

      // Clean up backup on success
      fs.unlinkSync(backupPath);
      
    } catch (error) {
      console.error('❌ Generated content validation failed:', error.message);
      console.log('🔄 Restoring backup...');
      fs.copyFileSync(backupPath, this.frontendConfigPath);
      fs.unlinkSync(backupPath);
      throw error;
    }
  }

  /**
   * Update standalone ABI file
   */
  async updateStandaloneABI(abi) {
    const abiDir = path.dirname(this.frontendAbiPath);
    if (!fs.existsSync(abiDir)) {
      fs.mkdirSync(abiDir, { recursive: true });
    }
    
    fs.writeFileSync(this.frontendAbiPath, JSON.stringify(abi, null, 2));
    console.log('✅ Standalone ABI file updated');
  }
}

// Run the updater
if (require.main === module) {
  const updater = new ABIUpdater();
  updater.run().catch(console.error);
}

module.exports = ABIUpdater;
