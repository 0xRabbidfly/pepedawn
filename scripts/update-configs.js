#!/usr/bin/env node

/**
 * Configuration Updater for PEPEDAWN
 * 
 * This script automatically updates configuration files when contract changes are detected.
 * It synchronizes contract addresses, ABIs, and other configs across the project.
 */

const fs = require('fs');
const path = require('path');

class ConfigurationUpdater {
  constructor() {
    this.contractPath = 'contracts/src/PepedawnRaffle.sol';
    this.abiPath = 'contracts/out/PepedawnRaffle.sol/PepedawnRaffle.json';
    this.addressesPath = 'deploy/artifacts/addresses.json';
    this.frontendConfigPath = 'frontend/src/contract-config.js';
    this.frontendAddressesPath = 'frontend/public/deploy/artifacts/addresses.json';
  }

  /**
   * Main execution function
   */
  async run() {
    console.log('⚙️  PEPEDAWN Configuration Updater Starting...\n');
    
    try {
      // 1. Check if contract was compiled
      await this.checkContractCompilation();
      
      // 2. Update ABI if needed
      await this.updateABI();
      
      // 3. Update contract addresses
      await this.updateAddresses();
      
      // 4. Update frontend configuration
      await this.updateFrontendConfig();
      
      // 5. Update VRF configuration
      await this.updateVRFConfig();
      
      console.log('✅ Configuration update complete!');
      
    } catch (error) {
      console.error('❌ Configuration update failed:', error.message);
      process.exit(1);
    }
  }

  /**
   * Check if contract needs to be compiled
   */
  async checkContractCompilation() {
    if (!fs.existsSync(this.abiPath)) {
      console.log('⚠️  Contract ABI not found. Run "forge build" first.');
      return false;
    }
    
    // Check if ABI is newer than contract
    const contractStats = fs.statSync(this.contractPath);
    const abiStats = fs.statSync(this.abiPath);
    
    if (contractStats.mtime > abiStats.mtime) {
      console.log('⚠️  Contract is newer than ABI. Run "forge build" first.');
      return false;
    }
    
    console.log('✅ Contract compilation is up to date');
    return true;
  }

  /**
   * Update ABI in configuration files
   */
  async updateABI() {
    if (!fs.existsSync(this.abiPath)) {
      console.log('⚠️  ABI file not found, skipping ABI update');
      return;
    }

    const abiData = JSON.parse(fs.readFileSync(this.abiPath, 'utf8'));
    const abi = abiData.abi;

    // Update frontend config
    if (fs.existsSync(this.frontendConfigPath)) {
      let content = fs.readFileSync(this.frontendConfigPath, 'utf8');
      
      // Find and replace ABI
      const abiRegex = /const\s+CONTRACT_ABI\s*=\s*\[[\s\S]*?\];/;
      const newAbi = `const CONTRACT_ABI = ${JSON.stringify(abi, null, 2)};`;
      
      if (abiRegex.test(content)) {
        content = content.replace(abiRegex, newAbi);
      } else {
        // Add ABI if not found
        content = content.replace(/(const\s+CONTRACT_ADDRESS)/, `${newAbi}\n\n$1`);
      }
      
      fs.writeFileSync(this.frontendConfigPath, content);
      console.log('✅ Frontend ABI updated');
    }

    // Update deployment artifacts
    const artifactsPath = 'deploy/artifacts/abis/';
    if (!fs.existsSync(artifactsPath)) {
      fs.mkdirSync(artifactsPath, { recursive: true });
    }
    
    fs.writeFileSync(
      path.join(artifactsPath, 'PepedawnRaffle.json'),
      JSON.stringify(abi, null, 2)
    );
    console.log('✅ ABI artifacts updated');
  }

  /**
   * Update contract addresses
   */
  async updateAddresses() {
    // Check if addresses file exists
    if (!fs.existsSync(this.addressesPath)) {
      console.log('⚠️  Addresses file not found. Deploy contract first.');
      return;
    }

    const addresses = JSON.parse(fs.readFileSync(this.addressesPath, 'utf8'));
    
    // Update frontend addresses
    if (fs.existsSync(this.frontendAddressesPath)) {
      fs.writeFileSync(this.frontendAddressesPath, JSON.stringify(addresses, null, 2));
      console.log('✅ Frontend addresses updated');
    }

    // Update frontend config with latest address
    if (fs.existsSync(this.frontendConfigPath)) {
      let content = fs.readFileSync(this.frontendConfigPath, 'utf8');
      
      // Find and replace contract address
      const addressRegex = /const\s+CONTRACT_ADDRESS\s*=\s*["'][^"']*["']/;
      const newAddress = `const CONTRACT_ADDRESS = "${addresses.PepedawnRaffle || '0x0000000000000000000000000000000000000000'}";`;
      
      if (addressRegex.test(content)) {
        content = content.replace(addressRegex, newAddress);
      } else {
        // Add address if not found
        content = content.replace(/(const\s+CONTRACT_ABI)/, `${newAddress}\n\n$1`);
      }
      
      fs.writeFileSync(this.frontendConfigPath, content);
      console.log('✅ Frontend contract address updated');
    }
  }

  /**
   * Update frontend configuration
   */
  async updateFrontendConfig() {
    if (!fs.existsSync(this.frontendConfigPath)) {
      console.log('⚠️  Frontend config not found, skipping');
      return;
    }

    let content = fs.readFileSync(this.frontendConfigPath, 'utf8');
    
    // Update network configuration
    const networkConfig = `
// Network configuration
const NETWORKS = {
  sepolia: {
    chainId: 11155111,
    name: 'Sepolia',
    rpcUrl: 'https://sepolia.drpc.org',
    blockExplorer: 'https://sepolia.etherscan.io'
  },
  mainnet: {
    chainId: 1,
    name: 'Ethereum Mainnet',
    rpcUrl: 'https://eth.drpc.org',
    blockExplorer: 'https://etherscan.io'
  }
};

// VRF Configuration
const VRF_CONFIG = {
  coordinator: '0x8103B0A8A00be2DDC778e6e7eaa21791Cd364625', // Sepolia VRF Coordinator
  subscriptionId: 1, // Update with your subscription ID
  keyHash: '0x474e34a077df58807dbe9c96d3c009b23b3c6d0cce433e59bbf5b34f823bc56c', // Sepolia key hash
  callbackGasLimit: 500000, // Dynamic gas estimation
  requestConfirmations: 5
};
`;

    // Add network config if not exists
    if (!content.includes('const NETWORKS')) {
      content = content.replace(/(const\s+CONTRACT_ADDRESS)/, `${networkConfig}\n\n$1`);
    }

    // Update VRF config if exists
    if (content.includes('const VRF_CONFIG')) {
      content = content.replace(/const\s+VRF_CONFIG\s*=\s*{[\s\S]*?};/, 
        `const VRF_CONFIG = ${JSON.stringify(VRF_CONFIG, null, 2)};`);
    }

    fs.writeFileSync(this.frontendConfigPath, content);
    console.log('✅ Frontend configuration updated');
  }

  /**
   * Update VRF configuration
   */
  async updateVRFConfig() {
    const vrfConfigPath = 'deploy/artifacts/vrf-config.json';
    
    const vrfConfig = {
      coordinator: '0x8103B0A8A00be2DDC778e6e7eaa21791Cd364625',
      subscriptionId: 1,
      keyHash: '0x474e34a077df58807dbe9c96d3c009b23b3c6d0cce433e59bbf5b34f823bc56c',
      callbackGasLimit: 500000,
      requestConfirmations: 5,
      lastUpdated: new Date().toISOString(),
      notes: 'Dynamic gas estimation enabled - callbackGasLimit calculated per request'
    };

    // Ensure directory exists
    const dir = path.dirname(vrfConfigPath);
    if (!fs.existsSync(dir)) {
      fs.mkdirSync(dir, { recursive: true });
    }

    fs.writeFileSync(vrfConfigPath, JSON.stringify(vrfConfig, null, 2));
    console.log('✅ VRF configuration updated');
  }
}

// Run the updater
if (require.main === module) {
  const updater = new ConfigurationUpdater();
  updater.run().catch(console.error);
}

module.exports = ConfigurationUpdater;
