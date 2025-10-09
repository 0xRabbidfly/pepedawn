#!/usr/bin/env node
/**
 * @file manage-round.js
 * @notice Unified CLI for round management
 * @dev Guides owner through full round lifecycle
 * 
 * Commands:
 *   status <roundId>           - Display round state and progress
 *   snapshot <roundId>         - Run snapshot workflow (generate participants file)
 *   request-vrf <roundId>      - Request VRF randomness
 *   commit-winners <roundId>   - Generate and commit winners
 *   interactive                - Interactive mode with step-by-step guidance
 */

import { ethers } from 'ethers';
import fs from 'fs';
import path from 'path';
import { fileURLToPath } from 'url';
import dotenv from 'dotenv';
import { execSync } from 'child_process';

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);

// Load environment variables
dotenv.config({ path: path.join(__dirname, '../../.env') });

// ABI for the functions we need
const RAFFLE_ABI = [
  "function getRound(uint256) view returns (tuple(uint256 id, uint64 startTime, uint64 endTime, uint8 status, uint256 totalTickets, uint256 totalWeight, uint256 totalWagered, uint256 vrfRequestId, uint64 vrfRequestedAt, bool feesDistributed, uint256 participantCount, bytes32 validProofHash, bytes32 participantsRoot, bytes32 winnersRoot, bytes32 vrfSeed))",
  "function currentRoundId() view returns (uint256)",
  "function getParticipantsData(uint256) view returns (bytes32, string)",
  "function getWinnersData(uint256) view returns (bytes32, string)"
];

// Round status enum
const RoundStatus = {
  0: 'Created',
  1: 'Open',
  2: 'Closed',
  3: 'Snapshot',
  4: 'VRFRequested',
  5: 'WinnersReady',
  6: 'Distributed',
  7: 'Refunded'
};

/**
 * Setup contract connection
 */
function setupContract() {
  const rpcUrl = process.env.SEPOLIA_RPC_URL || process.env.RPC_URL;
  if (!rpcUrl) {
    throw new Error('SEPOLIA_RPC_URL or RPC_URL not set in environment');
  }
  
  const contractAddress = process.env.CONTRACT_ADDRESS;
  if (!contractAddress) {
    throw new Error('CONTRACT_ADDRESS not set in environment');
  }
  
  const provider = new ethers.JsonRpcProvider(rpcUrl);
  const contract = new ethers.Contract(contractAddress, RAFFLE_ABI, provider);
  
  return { contract, contractAddress, rpcUrl };
}

/**
 * Display round status
 */
async function displayStatus(roundId) {
  console.log('\n=== Round Status ===');
  
  const { contract } = setupContract();
  const round = await contract.getRound(roundId);
  
  const status = RoundStatus[Number(round.status)];
  const startDate = new Date(Number(round.startTime) * 1000).toISOString();
  const endDate = new Date(Number(round.endTime) * 1000).toISOString();
  
  console.log(`\nRound ID: ${roundId}`);
  console.log(`Status: ${status} (${round.status})`);
  console.log(`Start Time: ${startDate}`);
  console.log(`End Time: ${endDate}`);
  console.log(`\nParticipation:`);
  console.log(`  Participants: ${round.participantCount}`);
  console.log(`  Total Tickets: ${round.totalTickets}`);
  console.log(`  Total Weight: ${round.totalWeight}`);
  console.log(`  Total Wagered: ${ethers.formatEther(round.totalWagered)} ETH`);
  
  console.log(`\nMerkle Data:`);
  console.log(`  Participants Root: ${round.participantsRoot === ethers.ZeroHash ? 'Not set' : round.participantsRoot}`);
  
  // Fetch participants CID if root is set
  if (round.participantsRoot !== ethers.ZeroHash) {
    try {
      const data = await contract.getParticipantsData(roundId);
      const cid = data[1]; // getParticipantsData returns (bytes32 root, string cid)
      console.log(`  Participants CID: ${cid || 'Not set'}`);
    } catch (error) {
      console.log(`  Participants CID: Unable to fetch (${error.message.split(':')[0]})`);
    }
  }
  
  console.log(`  Winners Root: ${round.winnersRoot === ethers.ZeroHash ? 'Not set' : round.winnersRoot}`);
  
  // Fetch winners CID if root is set
  if (round.winnersRoot !== ethers.ZeroHash) {
    try {
      const data = await contract.getWinnersData(roundId);
      const cid = data[1]; // getWinnersData returns (bytes32 root, string cid)
      console.log(`  Winners CID: ${cid || 'Not set'}`);
    } catch (error) {
      console.log(`  Winners CID: Unable to fetch (${error.message.split(':')[0]})`);
    }
  }
  
  console.log(`\nVRF Data:`);
  console.log(`  VRF Request ID: ${round.vrfRequestId === 0n ? 'Not requested' : round.vrfRequestId}`);
  console.log(`  VRF Seed: ${round.vrfSeed === ethers.ZeroHash ? 'Not fulfilled' : round.vrfSeed}`);
  
  console.log(`\nFinancial:`);
  console.log(`  Fees Distributed: ${round.feesDistributed ? 'Yes' : 'No'}`);
  
  // Display next steps based on status
  displayNextSteps(round, roundId);
  
  return round;
}

/**
 * Display next steps based on current status
 */
function displayNextSteps(round, roundId) {
  const status = Number(round.status);
  
  console.log('\n=== Next Steps ===');
  
  if (status === 0) { // Created
    console.log('1. Open the round for betting:');
    console.log(`   cast send $CONTRACT_ADDRESS "openRound(uint256)" ${roundId} --private-key $PRIVATE_KEY --rpc-url $SEPOLIA_RPC_URL`);
  } else if (status === 1) { // Open
    console.log('Round is currently accepting bets.');
    console.log('When ready to close:');
    console.log(`   cast send $CONTRACT_ADDRESS "closeRound(uint256)" ${roundId} --private-key $PRIVATE_KEY --rpc-url $SEPOLIA_RPC_URL`);
    console.log(`\nNote: If round has <10 tickets, closeRound() will automatically refund all participants.`);
  } else if (status === 2) { // Closed
    console.log('1. Take snapshot:');
    console.log(`   node manage-round.js snapshot ${roundId}`);
    console.log('   OR manually:');
    console.log(`   cast send $CONTRACT_ADDRESS "snapshotRound(uint256)" ${roundId} --private-key $PRIVATE_KEY --rpc-url $SEPOLIA_RPC_URL`);
  } else if (status === 3) { // Snapshot
    if (round.participantsRoot === ethers.ZeroHash) {
      console.log('1. Generate and commit participants file:');
      console.log(`   node manage-round.js snapshot ${roundId}`);
    } else {
      console.log('1. Request VRF:');
      console.log(`   node manage-round.js request-vrf ${roundId}`);
    }
  } else if (status === 4) { // VRFRequested
    console.log('Waiting for VRF fulfillment...');
    console.log('This usually takes 5-30 minutes depending on network confirmations.');
    console.log('\nCheck back later or monitor events on Etherscan.');
  } else if (status === 5) { // WinnersReady
    console.log('✅ VRF fulfilled! Random seed received.');
    console.log('1. Generate and submit winners Merkle root:');
    console.log(`   node manage-round.js commit-winners ${roundId}`);
  } else if (status === 6) { // Distributed
    if (round.winnersRoot === ethers.ZeroHash) {
      console.log('⚠️  Warning: Status is Distributed but winnersRoot not set.');
      console.log('1. Generate and submit winners file:');
      console.log(`   node manage-round.js commit-winners ${roundId}`);
    } else {
      console.log('✅ Round is complete!');
      console.log('Winners can now claim their prizes via the frontend.');
    }
  } else if (status === 7) { // Refunded
    console.log('✅ Round was refunded (had <10 tickets).');
    console.log('Participants can withdraw their refunds via the frontend.');
  }
}

/**
 * Snapshot workflow: generate participants file
 */
async function snapshotWorkflow(roundId) {
  console.log('\n=== Snapshot Workflow ===');
  console.log(`Round ID: ${roundId}`);
  
  // Check round status
  const { contract } = setupContract();
  const round = await contract.getRound(roundId);
  
  if (Number(round.status) !== 3) {
    console.log(`\n⚠️  Round is not in Snapshot status (current: ${RoundStatus[Number(round.status)]})`);
    console.log('You need to call snapshotRound() first:');
    console.log(`   cast send $CONTRACT_ADDRESS "snapshotRound(uint256)" ${roundId} --private-key $PRIVATE_KEY --rpc-url $SEPOLIA_RPC_URL`);
    return;
  }
  
  // Generate participants file
  console.log('\n1. Generating participants file...');
  const participantsFile = `participants-round-${roundId}.json`;
  
  try {
    execSync(`node ${path.join(__dirname, 'generate-participants-file.js')} ${roundId}`, {
      stdio: 'inherit'
    });
  } catch (error) {
    console.error('Failed to generate participants file');
    throw error;
  }
  
  // Read the generated file to get the root
  const participantsData = JSON.parse(fs.readFileSync(participantsFile, 'utf8'));
  const root = participantsData.merkle.root;
  
  console.log('\n2. Next: Upload to IPFS');
  console.log(`   node upload-to-ipfs.js ${participantsFile}`);
  console.log('\n3. Then commit root on-chain:');
  console.log(`   cast send $CONTRACT_ADDRESS "commitParticipantsRoot(uint256,bytes32,string)" ${roundId} ${root} "<IPFS_CID>" --private-key $PRIVATE_KEY --rpc-url $SEPOLIA_RPC_URL`);
}

/**
 * Request VRF workflow
 */
async function requestVrfWorkflow(roundId) {
  console.log('\n=== Request VRF Workflow ===');
  console.log(`Round ID: ${roundId}`);
  
  // Check round status
  const { contract, contractAddress } = setupContract();
  const round = await contract.getRound(roundId);
  
  if (Number(round.status) !== 3) {
    throw new Error(`Round must be in Snapshot status (current: ${RoundStatus[Number(round.status)]})`);
  }
  
  if (round.participantsRoot === ethers.ZeroHash) {
    throw new Error('Participants root not committed yet. Run snapshot workflow first.');
  }
  
  console.log('\n✅ Ready to request VRF');
  console.log('\nExecute this command:');
  console.log(`cast send ${contractAddress} "requestVrf(uint256)" ${roundId} --private-key $PRIVATE_KEY --rpc-url $SEPOLIA_RPC_URL`);
  console.log('\nNote: Make sure your VRF subscription has enough LINK tokens!');
}

/**
 * Commit winners workflow
 */
async function commitWinnersWorkflow(roundId) {
  console.log('\n=== Commit Winners Workflow ===');
  console.log(`Round ID: ${roundId}`);
  
  // Check round status
  const { contract } = setupContract();
  const round = await contract.getRound(roundId);
  
  if (Number(round.status) !== 5) {
    throw new Error(`Round must be in WinnersReady status (current: ${RoundStatus[Number(round.status)]})`);
  }
  
  if (round.vrfSeed === ethers.ZeroHash) {
    throw new Error('VRF not fulfilled yet. Wait for VRF fulfillment.');
  }
  
  // Generate winners file
  console.log('\n1. Generating winners file...');
  const winnersFile = `winners-round-${roundId}.json`;
  
  try {
    execSync(`node ${path.join(__dirname, 'generate-winners-file.js')} ${roundId}`, {
      stdio: 'inherit'
    });
  } catch (error) {
    console.error('Failed to generate winners file');
    throw error;
  }
  
  // Read the generated file to get the root
  const winnersData = JSON.parse(fs.readFileSync(winnersFile, 'utf8'));
  const root = winnersData.merkle.root;
  
  console.log('\n2. Next: Upload to IPFS');
  console.log(`   node upload-to-ipfs.js ${winnersFile}`);
  console.log('\n3. Then submit winners root on-chain:');
  console.log(`   cast send $CONTRACT_ADDRESS "submitWinnersRoot(uint256,bytes32,string)" ${roundId} ${root} "<IPFS_CID>" --private-key $PRIVATE_KEY --rpc-url $SEPOLIA_RPC_URL`);
}

/**
 * Main CLI handler
 */
async function main() {
  const args = process.argv.slice(2);
  
  if (args.length === 0 || args[0] === '--help' || args[0] === '-h') {
    console.log(`
PEPEDAWN Round Management CLI

Usage: node manage-round.js <command> [arguments]

Commands:
  status <roundId>           Display round state and next steps
  snapshot <roundId>         Generate participants file and show upload instructions
  request-vrf <roundId>      Show VRF request command (validates prerequisites)
  commit-winners <roundId>   Generate winners file and show upload instructions
  
Examples:
  node manage-round.js status 1
  node manage-round.js snapshot 1
  node manage-round.js request-vrf 1
  node manage-round.js commit-winners 1

Environment Variables (required):
  CONTRACT_ADDRESS    - Deployed contract address
  SEPOLIA_RPC_URL     - Sepolia RPC endpoint
  PRIVATE_KEY         - Private key for transactions (for cast commands)
    `);
    process.exit(0);
  }
  
  const command = args[0];
  const roundId = args[1];
  
  try {
    switch (command) {
      case 'status':
        if (!roundId) throw new Error('Round ID required');
        await displayStatus(roundId);
        break;
        
      case 'snapshot':
        if (!roundId) throw new Error('Round ID required');
        await snapshotWorkflow(roundId);
        break;
        
      case 'request-vrf':
        if (!roundId) throw new Error('Round ID required');
        await requestVrfWorkflow(roundId);
        break;
        
      case 'commit-winners':
        if (!roundId) throw new Error('Round ID required');
        await commitWinnersWorkflow(roundId);
        break;
        
      default:
        console.error(`Unknown command: ${command}`);
        console.log('Run with --help for usage information');
        process.exit(1);
    }
  } catch (error) {
    console.error('\n❌ Error:', error.message);
    if (error.stack) {
      console.error('\nStack trace:', error.stack);
    }
    process.exit(1);
  }
}

main();
