#!/usr/bin/env node

/**
 * Documentation Updater for PEPEDAWN
 * 
 * This script automatically updates documentation when contract changes are detected.
 * It reads the current contract and updates relevant documentation files.
 */

const fs = require('fs');
const path = require('path');

class DocumentationUpdater {
  constructor() {
    this.contractPath = 'contracts/src/PepedawnRaffle.sol';
    this.docsPath = 'specs/001-build-a-simple/contracts/interface-documentation.md';
    this.contractContent = '';
    this.contractInfo = {};
  }

  /**
   * Main execution function
   */
  async run() {
    console.log('📚 PEPEDAWN Documentation Updater Starting...\n');
    
    try {
      // 1. Read and parse contract
      await this.parseContract();
      
      // 2. Extract contract information
      this.extractContractInfo();
      
      // 3. Update interface documentation
      await this.updateInterfaceDocumentation();
      
      // 4. Update quickstart guide
      await this.updateQuickstartGuide();
      
      // 5. Update README
      await this.updateREADME();
      
      console.log('✅ Documentation update complete!');
      
    } catch (error) {
      console.error('❌ Documentation update failed:', error.message);
      process.exit(1);
    }
  }

  /**
   * Read and parse the contract file
   */
  async parseContract() {
    if (!fs.existsSync(this.contractPath)) {
      throw new Error(`Contract file not found: ${this.contractPath}`);
    }
    
    this.contractContent = fs.readFileSync(this.contractPath, 'utf8');
    console.log('✅ Contract file loaded');
  }

  /**
   * Extract key information from contract
   */
  extractContractInfo() {
    const info = {
      functions: [],
      events: [],
      constants: [],
      structs: [],
      enums: [],
      modifiers: [],
      hasDynamicGas: false,
      hasSecurityFeatures: false,
      version: '0.8.20'
    };

    // Extract functions
    const functionRegex = /function\s+(\w+)\s*\([^)]*\)\s*(?:external|public|internal|private)?\s*(?:view|pure|payable)?\s*(?:returns\s*\([^)]*\))?\s*{/g;
    let match;
    while ((match = functionRegex.exec(this.contractContent)) !== null) {
      info.functions.push(match[1]);
    }

    // Extract events
    const eventRegex = /event\s+(\w+)\s*\([^)]*\);/g;
    while ((match = eventRegex.exec(this.contractContent)) !== null) {
      info.events.push(match[1]);
    }

    // Extract constants
    const constantRegex = /uint256\s+public\s+constant\s+(\w+)\s*=\s*[^;]+;/g;
    while ((match = constantRegex.exec(this.contractContent)) !== null) {
      info.constants.push(match[1]);
    }

    // Extract structs
    const structRegex = /struct\s+(\w+)\s*{[^}]+}/g;
    while ((match = structRegex.exec(this.contractContent)) !== null) {
      info.structs.push(match[1]);
    }

    // Extract enums
    const enumRegex = /enum\s+(\w+)\s*{[^}]+}/g;
    while ((match = enumRegex.exec(this.contractContent)) !== null) {
      info.enums.push(match[1]);
    }

    // Extract modifiers
    const modifierRegex = /modifier\s+(\w+)\s*\([^)]*\)\s*{[^}]+}/g;
    while ((match = modifierRegex.exec(this.contractContent)) !== null) {
      info.modifiers.push(match[1]);
    }

    // Check for dynamic gas estimation
    info.hasDynamicGas = this.contractContent.includes('_estimateCallbackGas') || 
                        this.contractContent.includes('estimateVRFCallbackGas');

    // Check for security features
    info.hasSecurityFeatures = this.contractContent.includes('ReentrancyGuard') ||
                              this.contractContent.includes('Pausable') ||
                              this.contractContent.includes('denylisted') ||
                              this.contractContent.includes('emergencyPaused');

    this.contractInfo = info;
    console.log('✅ Contract information extracted');
  }

  /**
   * Update interface documentation
   */
  async updateInterfaceDocumentation() {
    if (!fs.existsSync(this.docsPath)) {
      console.log('⚠️  Interface documentation not found, skipping...');
      return;
    }

    let content = fs.readFileSync(this.docsPath, 'utf8');
    
    // Update dynamic gas estimation section
    if (this.contractInfo.hasDynamicGas) {
      const dynamicGasSection = `
### Dynamic Gas Estimation

The contract now uses dynamic gas estimation for VRF callbacks following Chainlink best practices:

#### \`estimateVRFCallbackGas(uint256 roundId) external view returns (uint32)\`
**Purpose**: Estimate gas required for VRF callback based on round complexity  
**Returns**: Estimated gas limit with safety buffer  
**Calculation**: Base gas + winner selection + prize distribution + storage operations + complexity multipliers

#### Gas Estimation Formula
- **Base Gas**: 50,000 (function overhead, events, basic checks)
- **Winner Selection**: 20,000 (selection algorithm)
- **Prize Distribution**: 15,000 per winner (max 10 winners)
- **Fee Distribution**: 25,000 (fee calculation and transfer)
- **Storage Operations**: 5,000 per participant
- **Event Emissions**: 10,000 (multiple events)
- **Complexity Multipliers**: +20% for >100 participants, +10% for >1000 total weight
- **Safety Buffer**: 30% added to final estimate

#### Benefits
- Prevents VRF callback failures due to insufficient gas
- Scales automatically with round complexity
- Follows Chainlink recommended practices
- Reduces manual gas configuration overhead
`;

      // Replace or add dynamic gas section
      if (content.includes('### Dynamic Gas Estimation')) {
        content = content.replace(/### Dynamic Gas Estimation[\s\S]*?(?=###|\n##|$)/, dynamicGasSection.trim());
      } else {
        // Add before the last section
        const lastSectionIndex = content.lastIndexOf('## ');
        if (lastSectionIndex !== -1) {
          content = content.slice(0, lastSectionIndex) + dynamicGasSection + '\n\n' + content.slice(lastSectionIndex);
        }
      }
    }

    // Remove references to removed functions
    content = content.replace(/#### `updateVRFGasConfig[^`]*`[\s\S]*?(?=####|##|$)/g, '');
    content = content.replace(/event VRFGasConfigUpdated[^}]*}/g, '');

    // Update function list
    const functionList = this.contractInfo.functions
      .filter(fn => !fn.startsWith('_')) // Remove private functions
      .map(fn => `- \`${fn}()\``)
      .join('\n');

    if (content.includes('### Available Functions')) {
      content = content.replace(/### Available Functions[\s\S]*?(?=###|##|$)/, 
        `### Available Functions\n\n${functionList}\n`);
    }

    fs.writeFileSync(this.docsPath, content);
    console.log('✅ Interface documentation updated');
  }

  /**
   * Update quickstart guide
   */
  async updateQuickstartGuide() {
    const quickstartPath = 'specs/001-build-a-simple/quickstart.md';
    if (!fs.existsSync(quickstartPath)) {
      console.log('⚠️  Quickstart guide not found, skipping...');
      return;
    }

    let content = fs.readFileSync(quickstartPath, 'utf8');
    
    // Add dynamic gas estimation information
    if (this.contractInfo.hasDynamicGas) {
      const gasInfo = `
### Dynamic Gas Estimation

The contract now automatically estimates VRF callback gas based on round complexity:

\`\`\`bash
# Check estimated gas for a round
forge call PepedawnRaffle estimateVRFCallbackGas --rpc-url $SEPOLIA_RPC_URL --args 1
\`\`\`

This eliminates the need for manual gas configuration and prevents callback failures.
`;

      // Add after the deployment section
      if (content.includes('### 3. Deploy to Testnet')) {
        content = content.replace(/(### 3\. Deploy to Testnet[\s\S]*?)(### 4\.)/, 
          `$1${gasInfo}\n\n$2`);
      }
    }

    fs.writeFileSync(quickstartPath, content);
    console.log('✅ Quickstart guide updated');
  }

  /**
   * Update README
   */
  async updateREADME() {
    const readmePath = 'README.md';
    if (!fs.existsSync(readmePath)) {
      console.log('⚠️  README not found, skipping...');
      return;
    }

    let content = fs.readFileSync(readmePath, 'utf8');
    
    // Update feature list
    if (this.contractInfo.hasDynamicGas) {
      if (!content.includes('Dynamic gas estimation')) {
        content = content.replace(/(## Features[\s\S]*?)(## |$)/, 
          `$1- **Dynamic Gas Estimation**: Automatic VRF callback gas calculation based on round complexity\n$2`);
      }
    }

    // Update security features
    if (this.contractInfo.hasSecurityFeatures) {
      if (!content.includes('Security Features')) {
        const securitySection = `
## Security Features

- **Reentrancy Protection**: All external calls protected with reentrancy guards
- **Access Control**: Owner-only functions with secure transfer mechanisms
- **Input Validation**: All external parameters validated
- **Emergency Controls**: Pause functionality for critical operations
- **Circuit Breakers**: Protection against unusual conditions
- **VRF Security**: Request validation and manipulation protection
- **Dynamic Gas Management**: Prevents callback failures

`;
        content = content.replace(/(## Features[\s\S]*?)(## |$)/, 
          `$1${securitySection}$2`);
      }
    }

    fs.writeFileSync(readmePath, content);
    console.log('✅ README updated');
  }
}

// Run the updater
if (require.main === module) {
  const updater = new DocumentationUpdater();
  updater.run().catch(console.error);
}

module.exports = DocumentationUpdater;
