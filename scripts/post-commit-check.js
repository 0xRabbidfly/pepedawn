#!/usr/bin/env node

/**
 * Post-Commit Check System for PEPEDAWN
 * 
 * This script runs after every commit to ensure:
 * 1. Contract changes are reflected in documentation
 * 2. Deployment artifacts are updated
 * 3. Configuration files are synchronized
 * 4. Security compliance is maintained
 * 5. All specs are up-to-date
 */

const fs = require('fs');
const path = require('path');
const { execSync } = require('child_process');

// Configuration
const CONFIG = {
  // Contract files to monitor
  contractFiles: [
    'contracts/src/PepedawnRaffle.sol',
    'contracts/test/*.t.sol',
    'contracts/script/*.s.sol'
  ],
  
  // Documentation files to update
  docFiles: [
    'specs/001-build-a-simple/contracts/interface-documentation.md',
    'specs/001-build-a-simple/quickstart.md',
    'specs/001-build-a-simple/data-model.md',
    'README.md'
  ],
  
  // Configuration files to sync
  configFiles: [
    'deploy/artifacts/addresses.json',
    'deploy/artifacts/vrf-config.json',
    'frontend/public/deploy/artifacts/addresses.json',
    'frontend/src/contract-config.js'
  ],
  
  // Spec files to validate
  specFiles: [
    'specs/001-build-a-simple/spec.md',
    'specs/001-build-a-simple/plan.md',
    'specs/001-build-a-simple/research.md'
  ]
};

class PostCommitChecker {
  constructor() {
    this.errors = [];
    this.warnings = [];
    this.changes = [];
    this.contractHash = null;
    this.lastContractHash = null;
  }

  /**
   * Main execution function
   */
  async run() {
    console.log('🔍 PEPEDAWN Post-Commit Check Starting...\n');
    
    try {
      // 1. Detect contract changes
      await this.detectContractChanges();
      
      // 2. Validate documentation consistency
      await this.validateDocumentation();
      
      // 3. Check configuration synchronization
      await this.checkConfigSync();
      
      // 4. Validate spec compliance
      await this.validateSpecCompliance();
      
      // 5. Check security compliance
      await this.checkSecurityCompliance();
      
      // 6. Generate report
      this.generateReport();
      
      // 7. Auto-fix if possible
      if (this.errors.length === 0 && this.warnings.length > 0) {
        await this.autoFix();
      }
      
    } catch (error) {
      console.error('❌ Post-commit check failed:', error.message);
      process.exit(1);
    }
  }

  /**
   * Detect changes in contract files
   */
  async detectContractChanges() {
    console.log('📋 Checking for contract changes...');
    
    try {
      // Get current contract hash
      const contractContent = fs.readFileSync('contracts/src/PepedawnRaffle.sol', 'utf8');
      this.contractHash = this.hashString(contractContent);
      
      // Check if we have a previous hash stored
      const hashFile = '.contract-hash';
      if (fs.existsSync(hashFile)) {
        this.lastContractHash = fs.readFileSync(hashFile, 'utf8').trim();
      }
      
      if (this.contractHash !== this.lastContractHash) {
        this.changes.push('Contract source code changed');
        console.log('✅ Contract changes detected');
        
        // Store new hash
        fs.writeFileSync(hashFile, this.contractHash);
      } else {
        console.log('ℹ️  No contract changes detected');
      }
      
    } catch (error) {
      this.errors.push(`Failed to detect contract changes: ${error.message}`);
    }
  }

  /**
   * Validate documentation consistency
   */
  async validateDocumentation() {
    console.log('📚 Validating documentation consistency...');
    
    for (const docFile of CONFIG.docFiles) {
      if (!fs.existsSync(docFile)) {
        this.warnings.push(`Documentation file missing: ${docFile}`);
        continue;
      }
      
      const content = fs.readFileSync(docFile, 'utf8');
      
      // Check for outdated contract references
      if (content.includes('PepedawnRaffle-Remix.sol')) {
        this.warnings.push(`${docFile} contains reference to removed Remix contract`);
      }
      
      // Check for dynamic gas estimation references
      if (content.includes('updateVRFGasConfig') || content.includes('VRFGasConfigUpdated')) {
        this.warnings.push(`${docFile} contains references to removed manual gas functions`);
      }
      
      // Check for latest contract features
      if (!content.includes('dynamic gas estimation') && docFile.includes('interface-documentation.md')) {
        this.warnings.push(`${docFile} missing dynamic gas estimation documentation`);
      }
    }
    
    console.log('✅ Documentation validation complete');
  }

  /**
   * Check configuration synchronization
   */
  async checkConfigSync() {
    console.log('⚙️  Checking configuration synchronization...');
    
    // Check if deployment artifacts exist
    if (!fs.existsSync('deploy/artifacts/addresses.json')) {
      this.warnings.push('Deployment artifacts missing - run deployment first');
    }
    
    // Check frontend config sync
    const frontendConfig = 'frontend/src/contract-config.js';
    if (fs.existsSync(frontendConfig)) {
      const content = fs.readFileSync(frontendConfig, 'utf8');
      
      // Check for hardcoded addresses that should be dynamic
      if (content.includes('0x0000000000000000000000000000000000000000')) {
        this.warnings.push('Frontend config contains placeholder addresses');
      }
    }
    
    console.log('✅ Configuration sync check complete');
  }

  /**
   * Validate spec compliance
   */
  async validateSpecCompliance() {
    console.log('📋 Validating spec compliance...');
    
    // Check if spec files exist and are readable
    for (const specFile of CONFIG.specFiles) {
      if (!fs.existsSync(specFile)) {
        this.errors.push(`Required spec file missing: ${specFile}`);
        continue;
      }
      
      const content = fs.readFileSync(specFile, 'utf8');
      
      // Check for NEEDS CLARIFICATION markers
      if (content.includes('[NEEDS CLARIFICATION')) {
        this.warnings.push(`${specFile} contains unresolved clarifications`);
      }
      
      // Check for implementation details in spec
      if (content.includes('pragma solidity') || content.includes('function ')) {
        this.warnings.push(`${specFile} contains implementation details (should be business-focused)`);
      }
    }
    
    console.log('✅ Spec compliance validation complete');
  }

  /**
   * Check security compliance
   */
  async checkSecurityCompliance() {
    console.log('🔒 Checking security compliance...');
    
    // Check for security test files
    const securityTests = [
      'contracts/test/Security.t.sol',
      'contracts/test/AccessControl.t.sol',
      'contracts/test/InputValidation.t.sol',
      'contracts/test/EmergencyControls.t.sol',
      'contracts/test/VRFSecurity.t.sol',
      'contracts/test/WinnerSelection.t.sol',
      'contracts/test/Governance.t.sol'
    ];
    
    for (const testFile of securityTests) {
      if (!fs.existsSync(testFile)) {
        this.warnings.push(`Security test file missing: ${testFile}`);
      }
    }
    
    console.log('✅ Security compliance check complete');
  }

  /**
   * Generate comprehensive report
   */
  generateReport() {
    console.log('\n📊 POST-COMMIT CHECK REPORT');
    console.log('=' .repeat(50));
    
    if (this.errors.length > 0) {
      console.log('\n❌ ERRORS (must be fixed):');
      this.errors.forEach((error, index) => {
        console.log(`  ${index + 1}. ${error}`);
      });
    }
    
    if (this.warnings.length > 0) {
      console.log('\n⚠️  WARNINGS (should be addressed):');
      this.warnings.forEach((warning, index) => {
        console.log(`  ${index + 1}. ${warning}`);
      });
    }
    
    if (this.changes.length > 0) {
      console.log('\n📝 CHANGES DETECTED:');
      this.changes.forEach((change, index) => {
        console.log(`  ${index + 1}. ${change}`);
      });
    }
    
    if (this.errors.length === 0 && this.warnings.length === 0) {
      console.log('\n✅ All checks passed! No issues found.');
    }
    
    console.log('\n' + '=' .repeat(50));
  }

  /**
   * Auto-fix common issues
   */
  async autoFix() {
    console.log('\n🔧 Attempting auto-fixes...');
    
    let fixed = 0;
    
    // Auto-fix documentation issues
    for (const docFile of CONFIG.docFiles) {
      if (fs.existsSync(docFile)) {
        let content = fs.readFileSync(docFile, 'utf8');
        let modified = false;
        
        // Remove references to removed functions
        if (content.includes('updateVRFGasConfig')) {
          content = content.replace(/updateVRFGasConfig[^}]*}/g, '');
          modified = true;
        }
        
        if (content.includes('VRFGasConfigUpdated')) {
          content = content.replace(/VRFGasConfigUpdated[^}]*}/g, '');
          modified = true;
        }
        
        if (modified) {
          fs.writeFileSync(docFile, content);
          console.log(`  ✅ Fixed ${docFile}`);
          fixed++;
        }
      }
    }
    
    if (fixed > 0) {
      console.log(`\n✅ Auto-fixed ${fixed} issues`);
    } else {
      console.log('ℹ️  No auto-fixable issues found');
    }
  }

  /**
   * Simple string hashing function
   */
  hashString(str) {
    let hash = 0;
    for (let i = 0; i < str.length; i++) {
      const char = str.charCodeAt(i);
      hash = ((hash << 5) - hash) + char;
      hash = hash & hash; // Convert to 32-bit integer
    }
    return hash.toString();
  }
}

// Run the checker
if (require.main === module) {
  const checker = new PostCommitChecker();
  checker.run().catch(console.error);
}

module.exports = PostCommitChecker;
