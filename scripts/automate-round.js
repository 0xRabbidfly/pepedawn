#!/usr/bin/env node

/**
 * PEPEDAWN Round Automation Script
 * 
 * Automates the entire round lifecycle for testing:
 * - OPEN: Deploy → Create round → Set prizes → Open round
 * - VRF: OPEN + Place bets → Close → Snapshot → Commit participants → Request VRF
 * - FULL: VRF + Wait for VRF → Generate winners → Commit winners
 * 
 * Usage:
 *   node scripts/automate-round.js OPEN
 *   node scripts/automate-round.js VRF
 *   node scripts/automate-round.js FULL
 */

const { execSync } = require('child_process');
const fs = require('fs');
const path = require('path');
require('dotenv').config({ path: path.join(__dirname, '../contracts/.env') });

// Load environment variables
function loadEnv() {
  // dotenv already loaded above, but verify key variables exist
  if (!process.env.SEPOLIA_RPC_URL) {
    throw new Error('SEPOLIA_RPC_URL not found in contracts/.env');
  }
  if (!process.env.PRIVATE_KEY) {
    throw new Error('PRIVATE_KEY not found in contracts/.env');
  }
  console.log('✅ Environment variables loaded from contracts/.env');
}

function exec(cmd, options = {}) {
  console.log(`\n💻 Executing: ${cmd.substring(0, 80)}${cmd.length > 80 ? '...' : ''}`);
  try {
    const result = execSync(cmd, {
      cwd: path.join(__dirname, '../contracts'),
      encoding: 'utf8',
      stdio: options.silent ? 'pipe' : 'inherit',
      ...options
    });
    return result;
  } catch (error) {
    console.error('❌ Command failed:', error.message);
    if (!options.allowFail) {
      process.exit(1);
    }
    return null;
  }
}

function sleep(ms) {
  return new Promise(resolve => setTimeout(resolve, ms));
}

async function deployContract() {
  console.log('\n🚀 ========================================');
  console.log('   DEPLOYING NEW CONTRACT');
  console.log('========================================\n');
  
  // Build contracts first
  console.log('🔨 Building contracts...');
  exec('forge build');
  
  console.log('\n🚀 Deploying...');
  exec(
    `forge script scripts/forge/Deploy.s.sol --rpc-url ${process.env.SEPOLIA_RPC_URL} --broadcast`
  );
  
  // Read contract address from deployment broadcast file
  const broadcastPath = path.join(__dirname, '../contracts/broadcast/Deploy.s.sol/11155111/run-latest.json');
  if (!fs.existsSync(broadcastPath)) {
    throw new Error('Deployment broadcast file not found');
  }
  
  const broadcast = JSON.parse(fs.readFileSync(broadcastPath, 'utf8'));
  const contractAddress = broadcast.transactions[0].contractAddress;
  
  if (!contractAddress) {
    throw new Error('Could not extract contract address from broadcast file');
  }
  
  console.log(`\n✅ Contract deployed: ${contractAddress}`);
  
  // Try to verify on Etherscan (non-blocking)
  console.log('\n🔍 Attempting Etherscan verification...');
  const verifyResult = exec(
    `forge verify-contract ${contractAddress} src/PepedawnRaffle.sol:PepedawnRaffle --chain sepolia --watch`,
    { allowFail: true }
  );
  
  if (verifyResult) {
    console.log('✅ Contract verified on Etherscan!');
  } else {
    console.log('⚠️  Etherscan verification failed (continuing anyway)');
    console.log('   You can verify manually later if needed.');
  }
  
  // Update configs (run from project root, not contracts dir)
  console.log('\n📝 Updating configs...');
  execSync(`node ${path.join(__dirname, 'update-contract-address.js')} ${contractAddress}`, {
    cwd: path.join(__dirname, '..'),
    stdio: 'inherit'
  });
  execSync(`node ${path.join(__dirname, 'update-abi.js')}`, {
    cwd: path.join(__dirname, '..'),
    stdio: 'inherit'
  });
  
  // Add as VRF consumer automatically
  console.log('\n📡 Adding contract as VRF consumer...');
  
  // Check if VRF config exists
  if (!process.env.VRF_COORDINATOR || !process.env.VRF_SUBSCRIPTION_ID) {
    console.log('⚠️  VRF_COORDINATOR or VRF_SUBSCRIPTION_ID not set in .env');
    console.log('   Add manually at: https://vrf.chain.link/');
  } else {
    try {
      exec(
        `cast send ${process.env.VRF_COORDINATOR} "addConsumer(uint256,address)" ${process.env.VRF_SUBSCRIPTION_ID} ${contractAddress} --private-key ${process.env.PRIVATE_KEY} --rpc-url ${process.env.SEPOLIA_RPC_URL}`,
        { allowFail: true }
      );
      console.log('✅ Contract added as VRF consumer!');
    } catch (error) {
      console.log('⚠️  Failed to add VRF consumer automatically.');
      console.log('   You may not be the subscription owner, or it may already be added.');
      console.log('   Add manually at: https://vrf.chain.link/');
    }
  }
  
  return contractAddress;
}

async function createAndOpenRound(contractAddress) {
  console.log('\n🎲 ========================================');
  console.log('   CREATING & OPENING ROUND');
  console.log('========================================\n');
  
  // Get current round ID
  const currentRoundIdHex = exec(
    `cast call ${contractAddress} "currentRoundId()" --rpc-url ${process.env.SEPOLIA_RPC_URL}`,
    { silent: true }
  ).trim();
  const currentRoundId = parseInt(currentRoundIdHex, 16);
  const roundId = currentRoundId + 1;
  
  console.log(`📊 Current round: ${currentRoundId}, creating round: ${roundId}`);
  
  // Create round
  console.log(`\n📝 Creating round ${roundId}...`);
  exec(`cast send ${contractAddress} "createRound()" --private-key ${process.env.PRIVATE_KEY} --rpc-url ${process.env.SEPOLIA_RPC_URL} --gas-limit 500000`);
  
  await sleep(2000); // Wait for block confirmation
  
  // Set prizes (using mock NFT IDs 1-10)
  console.log('🎁 Setting prizes for round...');
  try {
    exec(`cast send ${contractAddress} "setPrizesForRound(uint256,uint256[])" ${roundId} "[1,2,3,4,5,6,7,8,9,10]" --private-key ${process.env.PRIVATE_KEY} --rpc-url ${process.env.SEPOLIA_RPC_URL}`, { allowFail: true });
    console.log('✅ Prizes set!');
  } catch (error) {
    console.log('⚠️  Failed to set prizes - contract may not have NFTs yet.');
    console.log('   Transfer 10 NFTs to contract before running a full round.');
    console.log('   Continuing without prizes (for testing betting/proof flow)...');
  }
  
  await sleep(1000);
  
  // Set valid proof
  console.log('🧩 Setting puzzle proof...');
  const proofHash = execSync(`cast keccak256 "pepedawn2025"`, { encoding: 'utf8' }).trim();
  exec(`cast send ${contractAddress} "setValidProof(uint256,bytes32)" ${roundId} ${proofHash} --private-key ${process.env.PRIVATE_KEY} --rpc-url ${process.env.SEPOLIA_RPC_URL}`);
  
  await sleep(2000);
  
  // Open round
  console.log(`🟢 Opening round ${roundId} for betting...`);
  exec(`cast send ${contractAddress} "openRound(uint256)" ${roundId} --private-key ${process.env.PRIVATE_KEY} --rpc-url ${process.env.SEPOLIA_RPC_URL}`);
  
  console.log(`\n✅ Round ${roundId} opened! Users can now place bets.`);
  return roundId;
}

async function placeBetsAndClose(contractAddress, roundId = 1) {
  console.log('\n🎰 ========================================');
  console.log('   PLACING BETS & CLOSING ROUND');
  console.log('========================================\n');
  
  // Place bet (10 tickets for 0.04 ETH)
  console.log('💰 Placing bet (10 tickets, 0.04 ETH)...');
  exec(`cast send ${contractAddress} "placeBet(uint256)" 10 --value 0.04ether --private-key ${process.env.PRIVATE_KEY} --rpc-url ${process.env.SEPOLIA_RPC_URL}`);
  
  await sleep(2000);
  
  // Close round
  console.log('🔒 Closing round...');
  exec(`cast send ${contractAddress} "closeRound(uint256)" ${roundId} --private-key ${process.env.PRIVATE_KEY} --rpc-url ${process.env.SEPOLIA_RPC_URL}`);
  
  await sleep(2000);
  
  // Snapshot round
  console.log('📸 Taking snapshot...');
  exec(`cast send ${contractAddress} "snapshotRound(uint256)" ${roundId} --private-key ${process.env.PRIVATE_KEY} --rpc-url ${process.env.SEPOLIA_RPC_URL}`);
  
  console.log('\n✅ Round closed and snapshotted!');
}

async function commitParticipantsAndRequestVRF(contractAddress, roundId = 1) {
  console.log('\n🌳 ========================================');
  console.log('   COMMITTING PARTICIPANTS & REQUESTING VRF');
  console.log('========================================\n');
  
  // Generate participants file
  console.log('📄 Generating participants file...');
  const cliDir = path.join(__dirname, '../contracts/scripts/cli');
  execSync(`node manage-round.js snapshot ${roundId}`, {
    cwd: cliDir,
    stdio: 'inherit'
  });
  
  const participantsFile = path.join(cliDir, `participants-round-${roundId}.json`);
  const participantsData = JSON.parse(fs.readFileSync(participantsFile, 'utf8'));
  const participantsRoot = participantsData.merkle.root;
  
  console.log(`\n📋 Participants Root: ${participantsRoot}`);
  console.log('💡 File auto-copied to frontend/public/participants/ for local testing');
  
  // For testing, use a mock CID (in production, upload to IPFS first)
  const mockCID = `bafkrei-test-participants-${roundId}-${Date.now()}`;
  
  // Commit participants root
  console.log('🌳 Committing participants root...');
  exec(`cast send ${contractAddress} "commitParticipantsRoot(uint256,bytes32,string)" ${roundId} ${participantsRoot} "${mockCID}" --private-key ${process.env.PRIVATE_KEY} --rpc-url ${process.env.SEPOLIA_RPC_URL}`);
  
  await sleep(2000);
  
  // Request VRF
  console.log('🎲 Requesting VRF randomness...');
  exec(`cast send ${contractAddress} "requestVrf(uint256)" ${roundId} --private-key ${process.env.PRIVATE_KEY} --rpc-url ${process.env.SEPOLIA_RPC_URL}`);
  
  console.log('\n✅ VRF requested! Wait 1-5 minutes for fulfillment...');
  console.log('💡 Monitor status: cd contracts/scripts/cli && node manage-round.js status 1');
}

async function waitForVRFAndCommitWinners(contractAddress, roundId = 1) {
  console.log('\n🎰 ========================================');
  console.log('   WAITING FOR VRF & COMMITTING WINNERS');
  console.log('========================================\n');
  
  // Poll for VRF fulfillment using reliable CLI status checker
  console.log('⏳ Waiting for VRF fulfillment...');
  console.log('💡 This typically takes 1-5 minutes on Sepolia');
  
  let attempts = 0;
  const maxAttempts = 60; // 5 minutes max (5 second intervals) - back to working version
  
  while (attempts < maxAttempts) {
    try {
      const statusOutput = execSync(
        `node manage-round.js status ${roundId}`,
        {
          cwd: path.join(__dirname, '../contracts/scripts/cli'),
          encoding: 'utf8'
        }
      );
      
      // Check for WinnersReady status (exact match from working version)
      if (statusOutput.includes('WinnersReady (5)') || statusOutput.includes('Status: 5')) {
        console.log('✅ VRF fulfilled!');
        break;
      }
      
      // Log progress every 30 seconds
      if (attempts % 6 === 0 && attempts > 0) {
        const elapsed = Math.floor(attempts * 5 / 60);
        const remaining = Math.floor((maxAttempts - attempts) * 5 / 60);
        console.log(`⏳ Still waiting... (${elapsed}m elapsed, ${remaining}m remaining)`);
        console.log(`   Current status: VRFRequested`);
      }
      
    } catch (error) {
      // Continue polling even if status check fails
      if (attempts % 12 === 0) { // Log errors every minute
        console.log(`⚠️  Status check error (continuing): ${error.message.split('\n')[0]}`);
      }
    }
    
    await sleep(5000);
    attempts++;
  }
  
  if (attempts >= maxAttempts) {
    throw new Error(`VRF fulfillment timeout after ${Math.floor(maxAttempts * 5 / 60)} minutes. Check Chainlink VRF dashboard: https://vrf.chain.link/`);
  }
  
  // Generate winners file
  console.log('\n📄 Generating winners file...');
  const cliDir = path.join(__dirname, '../contracts/scripts/cli');
  execSync(`node generate-winners-file.js ${roundId}`, {
    cwd: cliDir,
    stdio: 'inherit'
  });
  
  const winnersFile = path.join(cliDir, `winners-round-${roundId}.json`);
  const winnersData = JSON.parse(fs.readFileSync(winnersFile, 'utf8'));
  const winnersRoot = winnersData.merkle.root;
  
  console.log(`\n📋 Winners Root: ${winnersRoot}`);
  console.log('💡 File auto-copied to frontend/public/winners/ for local testing');
  
  // For testing, use a mock CID
  const mockCID = `bafkrei-test-winners-${roundId}-${Date.now()}`;
  
  // Submit winners root with robust retry logic using CLI status checker
  console.log('🌳 Submitting winners root...');
  let retries = 10; // More retries for reliability
  let submissionSuccess = false;
  
  while (retries > 0 && !submissionSuccess) {
    try {
      // Use the reliable CLI status checker (same as watch mode)
      console.log(`🔍 Verifying round status before submission (attempt ${11 - retries})...`);
      
      const statusOutput = execSync(
        `node manage-round.js status ${roundId}`,
        {
          cwd: path.join(__dirname, '../contracts/scripts/cli'),
          encoding: 'utf8'
        }
      );
      
      // Check if round is in WinnersReady status (flexible matching)
      const isWinnersReady = statusOutput.includes('WinnersReady') || statusOutput.includes('Status: 5');
      
      console.log(`📊 Round status check: ${isWinnersReady ? '✅ WinnersReady' : '❌ Not ready yet'}`);
      
      if (!isWinnersReady) {
        console.log(`⚠️  Round not ready yet, waiting 15 seconds... (${retries} attempts left)`);
        await sleep(15000);
        retries--;
        continue;
      }
      
      console.log(`✅ Round confirmed as WinnersReady, submitting...`);
      
      // Small delay to ensure RPC synchronization
      console.log('⏳ Waiting 5 seconds for RPC sync...');
      await sleep(10000);
      
      // Try the actual submission
      console.log(`🔧 Attempting submission with:`);
      console.log(`   Contract: ${contractAddress}`);
      console.log(`   Round: ${roundId}`);
      console.log(`   Root: ${winnersRoot}`);
      console.log(`   CID: ${mockCID}`);
      
      exec(`cast send ${contractAddress} "submitWinnersRoot(uint256,bytes32,string)" ${roundId} ${winnersRoot} "${mockCID}" --private-key ${process.env.PRIVATE_KEY} --rpc-url ${process.env.SEPOLIA_RPC_URL}`);
      
      submissionSuccess = true;
      console.log('✅ Winners root submitted successfully!');
      
    } catch (error) {
      retries--;
      console.log(`❌ Submission attempt failed:`);
      console.log(`   Full error: ${error.message}`);
      console.log(`   Error type: ${error.constructor.name}`);
      
      if (retries > 0) {
        console.log(`⚠️  Retrying in 20 seconds... (${retries} attempts left)`);
        await sleep(20000); // Longer delay between retries
      } else {
        console.error('\n❌ All retries exhausted. Possible issues:');
        console.error('   1. VRF callback hasn\'t been processed yet (check Chainlink VRF dashboard)');
        console.error('   2. RPC node is behind (try a different RPC URL)');
        console.error('   3. Transaction is timing out (check network congestion)');
        console.error(`\nManual recovery:`);
        console.error(`   cast send ${contractAddress} "submitWinnersRoot(uint256,bytes32,string)" ${roundId} ${winnersRoot} "${mockCID}" --private-key $PRIVATE_KEY --rpc-url $SEPOLIA_RPC_URL`);
        throw error; // Re-throw if all retries failed
      }
    }
  }
  
  // Only report success if submission actually succeeded
  if (!submissionSuccess) {
    throw new Error('Failed to submit winners root after all retry attempts');
  }
  
  console.log('\n✅ Winners committed! Round is complete and ready for claims!');
  console.log(`\n🎉 Check the frontend at http://localhost:5173/main.html`);
}

async function watchAndAutomate(contractAddress) {
  console.log('\n👁️  ========================================');
  console.log('   WATCH MODE - AUTOMATED ROUND MANAGER');
  console.log('========================================\n');
  console.log(`📋 Contract: ${contractAddress}`);
  console.log('⏱️  Polling every 30 seconds...');
  console.log('🛑 Press Ctrl+C to stop\n');
  
  const state = {
    lastRoundId: 0,
    lastStatus: null,
    snapshotDone: false,
    vrfRequested: false,
    winnersSubmitted: false
  };
  
  async function checkAndAct() {
    try {
      // Get current round
      const currentRoundIdHex = exec(
        `cast call ${contractAddress} "currentRoundId()" --rpc-url ${process.env.SEPOLIA_RPC_URL}`,
        { silent: true }
      ).trim();
      const roundId = parseInt(currentRoundIdHex, 16);
      
      if (roundId === 0) {
        console.log('⏳ No rounds created yet. Waiting...');
        return;
      }
      
      // Reset state on new round
      if (roundId !== state.lastRoundId) {
        state.lastRoundId = roundId;
        state.lastStatus = null;
        state.snapshotDone = false;
        state.vrfRequested = false;
        state.winnersSubmitted = false;
        console.log(`\n🆕 New round detected: ${roundId}`);
      }
      
      // Get round status
      const statusOutput = execSync(
        `node manage-round.js status ${roundId}`,
        {
          cwd: path.join(__dirname, '../contracts/scripts/cli'),
          encoding: 'utf8'
        }
      );
      
      // Parse status
      let status = null;
      if (statusOutput.includes('Created (0)')) status = 0;
      else if (statusOutput.includes('Open (1)')) status = 1;
      else if (statusOutput.includes('Closed (2)')) status = 2;
      else if (statusOutput.includes('Snapshot (3)')) status = 3;
      else if (statusOutput.includes('VRFRequested (4)')) status = 4;
      else if (statusOutput.includes('WinnersReady (5)')) status = 5;
      else if (statusOutput.includes('Distributed (6)')) status = 6;
      
      // Log status changes
      if (status !== state.lastStatus) {
        const statusNames = ['Created', 'Open', 'Closed', 'Snapshot', 'VRFRequested', 'WinnersReady', 'Distributed'];
        console.log(`\n📊 Round ${roundId} status: ${statusNames[status] || 'Unknown'}`);
        state.lastStatus = status;
      }
      
      // Act based on status
      if (status === 2 && !state.snapshotDone) {
        // Closed -> Snapshot
        console.log('\n🤖 Auto-action: Snapshotting round...');
        exec(`cast send ${contractAddress} "snapshotRound(uint256)" ${roundId} --private-key ${process.env.PRIVATE_KEY} --rpc-url ${process.env.SEPOLIA_RPC_URL}`);
        await sleep(2000);
        state.snapshotDone = true;
        
      } else if (status === 3 && !state.vrfRequested) {
        // Snapshot -> Generate participants + Request VRF
        console.log('\n🤖 Auto-action: Generating participants and requesting VRF...');
        await commitParticipantsAndRequestVRF(contractAddress, roundId);
        state.vrfRequested = true;
        
      } else if (status === 5 && !state.winnersSubmitted) {
        // WinnersReady -> Generate and submit winners
        console.log('\n🤖 Auto-action: Generating and submitting winners...');
        
        // Generate winners file
        const cliDir = path.join(__dirname, '../contracts/scripts/cli');
        execSync(`node generate-winners-file.js ${roundId}`, {
          cwd: cliDir,
          stdio: 'inherit'
        });
        
        const winnersFile = path.join(cliDir, `winners-round-${roundId}.json`);
        const winnersData = JSON.parse(fs.readFileSync(winnersFile, 'utf8'));
        const winnersRoot = winnersData.merkle.root;
        const mockCID = `bafkrei-test-winners-${roundId}-${Date.now()}`;
        
        exec(`cast send ${contractAddress} "submitWinnersRoot(uint256,bytes32,string)" ${roundId} ${winnersRoot} "${mockCID}" --private-key ${process.env.PRIVATE_KEY} --rpc-url ${process.env.SEPOLIA_RPC_URL}`);
        
        state.winnersSubmitted = true;
        console.log(`\n✅ Round ${roundId} complete! Winners can now claim prizes.`);
        
      } else if (status === 6) {
        console.log(`✅ Round ${roundId} fully distributed`);
      }
      
    } catch (error) {
      console.error('⚠️  Error in watch loop:', error.message);
    }
  }
  
  // Initial check
  await checkAndAct();
  
  // Poll every 30 seconds
  setInterval(checkAndAct, 30000);
}

async function main() {
  try {
    loadEnv();
    
    const mode = process.argv[2]?.toUpperCase();
    const shouldDeploy = process.argv.includes('--deploy');
    
    if (!mode || !['OPEN', 'VRF', 'FULL', 'WATCH'].includes(mode)) {
      console.log(`
🤖 PEPEDAWN Round Automation Script

Usage:
  node scripts/automate-round.js <MODE> [--deploy]

Modes:
  OPEN  - Create round, set prizes, open for betting
          └─ Stops at: Round is open, ready for bets
  
  VRF   - Do OPEN + Place 10 tickets, close, snapshot, commit participants, request VRF
          └─ Stops at: VRF requested, waiting for Chainlink fulfillment
  
  FULL  - Do VRF + Wait for VRF, generate winners, commit winners
          └─ Stops at: Round complete, ready for claims in UI
  
  WATCH - Continuously monitor contract and auto-complete all steps
          └─ Runs forever: Snapshot → Participants → VRF → Winners

Flags:
  --deploy  Deploy a new contract before running (default: use CONTRACT_ADDRESS from .env)

Examples:
  node scripts/automate-round.js OPEN              # Create round 1 on existing contract
  node scripts/automate-round.js WATCH             # Monitor and auto-complete everything
  node scripts/automate-round.js VRF               # Continue with VRF on current round

Requirements:
  - contracts/.env configured with PRIVATE_KEY, SEPOLIA_RPC_URL, etc.
  - CONTRACT_ADDRESS in .env (unless using --deploy)
  - VRF subscription created and funded
  - Sepolia ETH in deployer wallet
      `);
      process.exit(1);
    }
    
    console.log('\n🤖 ========================================');
    console.log(`   PEPEDAWN AUTOMATION - ${mode} MODE`);
    console.log('========================================\n');
    
    let contractAddress;
    
    if (shouldDeploy) {
      console.log('🚀 --deploy flag detected: deploying new contract...\n');
      contractAddress = await deployContract();
    } else {
      contractAddress = process.env.CONTRACT_ADDRESS;
      if (!contractAddress) {
        throw new Error('CONTRACT_ADDRESS not found in contracts/.env. Use --deploy flag or set CONTRACT_ADDRESS in .env');
      }
      console.log(`📋 Using existing contract: ${contractAddress}\n`);
    }
    
    // WATCH mode: Monitor and auto-complete
    if (mode === 'WATCH') {
      await watchAndAutomate(contractAddress);
      return; // Keep running forever
    }
    
    let roundId;
    
    // OPEN mode: Create and open round
    if (mode === 'OPEN' || mode === 'VRF' || mode === 'FULL') {
      roundId = await createAndOpenRound(contractAddress);
      
      if (mode === 'OPEN') {
        console.log('\n🎯 ========================================');
        console.log('   OPEN MODE COMPLETE');
        console.log('========================================');
        console.log(`\n✅ Round ${roundId} is open for betting!`);
        console.log('\n📋 Next Steps:');
        console.log('   1. Test placing bets in UI (http://localhost:5173/main.html)');
        console.log('   2. Or run: node scripts/automate-round.js VRF');
        return;
      }
    }
    
    // VRF mode: Place bets, close, snapshot, commit participants, request VRF
    if (mode === 'VRF' || mode === 'FULL') {
      await placeBetsAndClose(contractAddress, roundId);
      await commitParticipantsAndRequestVRF(contractAddress, roundId);
      
      if (mode === 'VRF') {
        console.log('\n🎲 ========================================');
        console.log('   VRF MODE COMPLETE');
        console.log('========================================');
        console.log('\n✅ VRF requested! Waiting for Chainlink fulfillment (1-5 min)');
        console.log('\n📋 Next Steps:');
        console.log(`   1. Wait 1-5 minutes for VRF fulfillment`);
        console.log(`   2. Monitor: cd contracts/scripts/cli && node manage-round.js status ${roundId}`);
        console.log('   3. Or run: node scripts/automate-round.js FULL');
        return;
      }
    }
    
    // FULL mode: Wait for VRF and commit winners
    if (mode === 'FULL') {
      await waitForVRFAndCommitWinners(contractAddress, roundId);
      
      console.log('\n🎉 ========================================');
      console.log('   FULL MODE COMPLETE - ROUND FINISHED!');
      console.log('========================================');
      console.log('\n✅ Everything is ready!');
      console.log('\n📋 What You Can Test:');
      console.log('   1. View winners podium: http://localhost:5173/leaderboard.html');
      console.log('   2. Claim your prizes: http://localhost:5173/main.html');
      console.log('   3. Check on Etherscan: https://sepolia.etherscan.io/address/' + contractAddress);
      console.log('\n🐸 Happy claiming!');
    }
    
  } catch (error) {
    console.error('\n❌ Automation failed:', error.message);
    if (error.stack) {
      console.error('\nStack:', error.stack);
    }
    process.exit(1);
  }
}

main();

