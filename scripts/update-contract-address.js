#!/usr/bin/env node

/**
 * Update Contract Address Script
 * 
 * Updates addresses.json with a new contract address and syncs all config files.
 * Use this after deploying a new contract.
 */

const fs = require('fs');
const path = require('path');

class ConfigurationUpdater {
  constructor() {
    this.contractPath = 'contracts/src/PepedawnRaffle.sol';
    this.abiPath = 'contracts/out/PepedawnRaffle.sol/PepedawnRaffle.json';
    this.addressesPath = 'deploy/artifacts/addresses.json';
    this.envPath = 'contracts/.env';
    this.frontendConfigPath = 'frontend/src/contract-config.js';
    this.frontendAddressesPath = 'frontend/public/deploy/artifacts/addresses.json';
    this.frontendAbiPath = 'frontend/public/deploy/PepedawnRaffle-abi.json';
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

    const addressesJson = JSON.parse(fs.readFileSync(this.addressesPath, 'utf8'));
    // Resolve latest PepedawnRaffle address (prefer Sepolia 11155111 if present)
    const sepolia = addressesJson['11155111'] || {};
    const mainnet = addressesJson['1'] || {};
    const latestAddress = sepolia.PepedawnRaffle || mainnet.PepedawnRaffle || null;
    
    // Also update contracts/deploy/artifacts/addresses.json
    const contractsAddressesPath = 'contracts/deploy/artifacts/addresses.json';
    const contractsAddressesDir = path.dirname(contractsAddressesPath);
    if (!fs.existsSync(contractsAddressesDir)) {
      fs.mkdirSync(contractsAddressesDir, { recursive: true });
    }
    fs.writeFileSync(contractsAddressesPath, JSON.stringify(addressesJson, null, 2));
    console.log(`✅ Contracts addresses updated - ${contractsAddressesPath}`);
    
    // Update frontend addresses
    const frontendArtifactsDir = path.dirname(this.frontendAddressesPath);
    if (!fs.existsSync(frontendArtifactsDir)) {
      fs.mkdirSync(frontendArtifactsDir, { recursive: true });
    }
    fs.writeFileSync(this.frontendAddressesPath, JSON.stringify(addressesJson, null, 2));
    console.log(`✅ Frontend addresses updated - ${this.frontendAddressesPath}`);

    // Update frontend config with latest address
    if (fs.existsSync(this.frontendConfigPath) && latestAddress) {
      let content = fs.readFileSync(this.frontendConfigPath, 'utf8');
      // Replace pattern: address: "0x..."
      const cfgAddrRegex = /address:\s*"0x[a-fA-F0-9]{40}"/;
      const newCfgAddr = `address: "${latestAddress}"`;
      if (cfgAddrRegex.test(content)) {
        content = content.replace(cfgAddrRegex, newCfgAddr);
        fs.writeFileSync(this.frontendConfigPath, content);
        console.log(`✅ Frontend contract-config updated - ${this.frontendConfigPath}`);
      } else {
        console.warn('⚠️  Could not find address field in frontend contract-config.js');
      }
    }
  }

  /**
   * Update addresses.json with new contract address
   * @param {string} newAddress - New contract address
   * @param {number} chainId - Chain ID (default: 11155111 for Sepolia)
   */
  async updateContractAddress(newAddress, chainId = 11155111) {
    console.log(`📝 Updating contract address to: ${newAddress}`);
    
    let addressesJson = {};
    
    // Read existing addresses if file exists
    if (fs.existsSync(this.addressesPath)) {
      addressesJson = JSON.parse(fs.readFileSync(this.addressesPath, 'utf8'));
    }
    
    // Ensure chain entry exists
    if (!addressesJson[chainId]) {
      addressesJson[chainId] = {};
    }
    
    // Update the address
    addressesJson[chainId].PepedawnRaffle = newAddress;
    addressesJson[chainId].deployedAt = new Date().toISOString();
    addressesJson[chainId].deployedBy = "deployment-script";
    addressesJson[chainId].verified = false; // Will be updated after verification
    
    // Ensure deploy directory exists
    const deployDir = path.dirname(this.addressesPath);
    if (!fs.existsSync(deployDir)) {
      fs.mkdirSync(deployDir, { recursive: true });
    }
    
    // Write updated addresses
    fs.writeFileSync(this.addressesPath, JSON.stringify(addressesJson, null, 2));
    console.log(`✅ Contract address updated - ${this.addressesPath}`);
    
    return addressesJson;
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
    
    // Define VRF config as a JavaScript object
    const vrfConfigObj = {
      coordinator: '0x8103B0A8A00be2DDC778e6e7eaa21791Cd364625', // Sepolia VRF Coordinator
      subscriptionId: 1, // Update with your subscription ID
      keyHash: '0x474e34a077df58807dbe9c96d3c009b23b3c6d0cce433e59bbf5b34f823bc56c', // Sepolia key hash
      callbackGasLimit: 500000, // Dynamic gas estimation
      requestConfirmations: 5
    };
    
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
const VRF_CONFIG = ${JSON.stringify(vrfConfigObj, null, 2)};
`;

    // Add network config if not exists
    if (!content.includes('const NETWORKS')) {
      content = content.replace(/(const\s+CONTRACT_ADDRESS)/, `${networkConfig}\n\n$1`);
    }

    // Update VRF config if exists
    if (content.includes('const VRF_CONFIG')) {
      content = content.replace(/const\s+VRF_CONFIG\s*=\s*{[\s\S]*?};/, 
        `const VRF_CONFIG = ${JSON.stringify(vrfConfigObj, null, 2)};`);
    }

    fs.writeFileSync(this.frontendConfigPath, content);
    console.log('✅ Frontend configuration updated');
  }

  /**
   * Update .env file with new contract address
   */
  async updateEnvFile(newAddress) {
    // Script runs from project root, envPath is relative to project root
    const fullEnvPath = path.resolve(this.envPath);
    if (!fs.existsSync(fullEnvPath)) {
      console.log('⚠️  .env file not found at:', fullEnvPath);
      return;
    }
    
    let envContent = fs.readFileSync(fullEnvPath, 'utf8');
    
    // Update or add CONTRACT_ADDRESS
    if (envContent.includes('CONTRACT_ADDRESS=')) {
      envContent = envContent.replace(
        /CONTRACT_ADDRESS=.*/,
        `CONTRACT_ADDRESS=${newAddress}`
      );
    } else {
      envContent += `\nCONTRACT_ADDRESS=${newAddress}\n`;
    }
    
    fs.writeFileSync(fullEnvPath, envContent);
    console.log(`✅ .env file updated - ${this.envPath}`);
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
    console.log(`✅ VRF configuration updated - ${vrfConfigPath}`);
  }

  /**
   * Register contract as VRF consumer
   */
  async addVRFConsumer(contractAddress) {
    console.log('\n📡 Registering contract as VRF consumer...');
    
    try {
      // Load environment variables
      const envPath = path.resolve(this.envPath);
      if (!fs.existsSync(envPath)) {
        throw new Error('.env file not found at: ' + envPath);
      }
      
      const envContent = fs.readFileSync(envPath, 'utf8');
      const env = {};
      envContent.split(/\r?\n/).forEach(line => {
        line = line.trim();
        if (!line || line.startsWith('#')) return;
        const match = line.match(/^([^=]+)=(.*)$/);
        if (match) {
          const key = match[1].trim();
          const value = match[2].trim();
          env[key] = value;
        }
      });
      
      const vrfCoordinator = env.VRF_COORDINATOR || '0x8103B0A8A00be2DDC778e6e7eaa21791Cd364625';
      const subscriptionId = env.VRF_SUBSCRIPTION_ID;
      const privateKey = env.PRIVATE_KEY;
      const rpcUrl = env.SEPOLIA_RPC_URL;
      
      if (!subscriptionId || !privateKey || !rpcUrl) {
        throw new Error('Missing required env vars: VRF_SUBSCRIPTION_ID, PRIVATE_KEY, SEPOLIA_RPC_URL');
      }
      
      // Execute cast command
      const { execSync } = require('child_process');
      const cmd = `cast send ${vrfCoordinator} "addConsumer(uint256,address)" ${subscriptionId} ${contractAddress} --private-key ${privateKey} --rpc-url ${rpcUrl}`;
      
      execSync(cmd, { 
        stdio: 'inherit', 
        cwd: path.join(__dirname, '..'),
        env: { ...process.env, ...env }
      });
      console.log('✅ Contract registered as VRF consumer');
      
      return true;
    } catch (error) {
      console.log(`⚠️  Auto-registration failed: ${error.message}`);
      console.log('\n📋 Manual registration command:');
      console.log(`cd Z:\\Projects\\pepedawn\\contracts`);
      console.log(`cast send $env:VRF_COORDINATOR "addConsumer(uint256,address)" $env:VRF_SUBSCRIPTION_ID ${contractAddress} --private-key $env:PRIVATE_KEY --rpc-url $env:SEPOLIA_RPC_URL`);
      
      return false;
    }
  }
}

async function main() {
  const args = process.argv.slice(2);
  
  if (args.length === 0) {
    console.log(`
🔧 Update Contract Address

Usage:
  node scripts/update-contract-address.js <contract-address> [chain-id]

Examples:
  node scripts/update-contract-address.js 0xCc0678a598F9c2D12e0770f8e83966bd129482Ca
  node scripts/update-contract-address.js 0xCc0678a598F9c2D12e0770f8e83966bd129482Ca 11155111

Chain IDs:
  1         - Ethereum Mainnet
  11155111  - Sepolia Testnet (default)
`);
    process.exit(1);
  }

  const contractAddress = args[0];
  const chainId = args[1] ? parseInt(args[1]) : 11155111;

  // Validate contract address
  if (!/^0x[a-fA-F0-9]{40}$/.test(contractAddress)) {
    console.error('❌ Invalid contract address format');
    process.exit(1);
  }

  // Validate chain ID
  if (![1, 11155111].includes(chainId)) {
    console.error('❌ Unsupported chain ID. Use 1 (mainnet) or 11155111 (sepolia)');
    process.exit(1);
  }

  console.log('🚀 Updating contract address...\n');
  console.log(`Contract: ${contractAddress}`);
  console.log(`Chain ID: ${chainId} (${chainId === 1 ? 'Mainnet' : 'Sepolia'})\n`);

  try {
    const updater = new ConfigurationUpdater();
    
    // 1. Update addresses.json
    await updater.updateContractAddress(contractAddress, chainId);
    
    // 2. Update .env file
    await updater.updateEnvFile(contractAddress);
    
    // 3. Update all frontend configs
    await updater.updateAddresses();
    await updater.updateFrontendConfig();
    await updater.updateVRFConfig();
    
    // 4. Add as VRF consumer
    await updater.addVRFConsumer(contractAddress);
    
    console.log('\n✅ Contract address update complete!');
    console.log('\n📋 Next steps:');
    console.log('1. Refresh your frontend (F5)');
    console.log('2. Verify the new contract on Etherscan');
    
  } catch (error) {
    console.error('❌ Update failed:', error.message);
    process.exit(1);
  }
}

if (require.main === module) {
  main().catch(console.error);
}

module.exports = main;
