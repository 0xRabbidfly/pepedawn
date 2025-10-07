#!/usr/bin/env node

const { execSync } = require('child_process');
const path = require('path');

console.log('🔍 Running pre-commit checks...');

// Test files to run (matching GitHub Actions)
const testFiles = [
    'test/BasicDeployment.t.sol',
    'test/AccessControl.t.sol',
    'test/InputValidation.t.sol',
    'test/Wager.t.sol',
    'test/WinnerSelection.t.sol',
    'test/Distribution.t.sol',
    'test/EmergencyControls.t.sol',
    'test/Governance.t.sol',
    'test/Round.t.sol',
    'test/Security.t.sol',
    'test/ScenarioFullRound.t.sol'
];

try {
    // Change to contracts directory
    process.chdir(path.join(__dirname, '..', 'contracts'));
    
    console.log('🧪 Running smart contract tests...');
    
    // Run each test file
    for (const testFile of testFiles) {
        console.log(`Running ${testFile}...`);
        try {
            execSync(`forge test --match-path "${testFile}"`, { 
                stdio: 'inherit',
                cwd: process.cwd()
            });
            console.log(`✅ ${testFile} passed`);
        } catch (error) {
            console.error(`❌ Test failed: ${testFile}`);
            process.exit(1);
        }
    }
    
    console.log('✅ All smart contract tests passed!');
    
    // Run frontend build and linting
    console.log('🔍 Running frontend build...');
    process.chdir(path.join(__dirname, '..', 'frontend'));
    
    try {
        execSync('npm run build', { 
            stdio: 'inherit',
            cwd: process.cwd()
        });
        console.log('✅ Frontend build completed!');
        // Ensure newly built assets are included in this commit
        try {
            execSync('git add -A dist', {
                stdio: 'inherit',
                cwd: process.cwd()
            });
            console.log('✅ Staged frontend/dist for commit');
        } catch (err) {
            console.warn('⚠️  Could not stage frontend/dist automatically:', err?.message || err);
        }
    } catch (error) {
        console.error('❌ Frontend build failed!');
        process.exit(1);
    }
    
    console.log('🔍 Running frontend linting...');
    try {
        execSync('npm run lint', { 
            stdio: 'inherit',
            cwd: process.cwd()
        });
        console.log('✅ Frontend linting passed!');
    } catch (error) {
        console.error('❌ Frontend linting failed!');
        process.exit(1);
    }
    
    console.log('✅ All pre-commit checks passed!');
    
} catch (error) {
    console.error('❌ Pre-commit checks failed:', error.message);
    process.exit(1);
}
