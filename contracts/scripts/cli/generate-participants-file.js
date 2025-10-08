#!/usr/bin/env node
/**
 * @file generate-participants-file.js
 * @notice Generate Participants File with Merkle tree for a round
 * @dev Queries contract for all participants, calculates weights, builds Merkle tree
 * 
 * Usage:
 *   node generate-participants-file.js <roundId> [--output participants-round-<roundId>.json]
 * 
 * Output:
 *   - JSON file with participants data and Merkle root
 *   - Merkle root hash for on-chain commitment
 *   - Instructions for next steps
 */

import { ethers } from 'ethers';
import { MerkleTree } from 'merkletreejs';
import fs from 'fs';
import path from 'path';
import { fileURLToPath } from 'url';
import dotenv from 'dotenv';

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);

// Load environment variables
dotenv.config({ path: path.join(__dirname, '../../.env') });

// ABI for the functions we need
const RAFFLE_ABI = [
  "function getRound(uint256) view returns (tuple(uint256 id, uint64 startTime, uint64 endTime, uint8 status, uint256 totalTickets, uint256 totalWeight, uint256 totalWagered, uint256 vrfRequestId, uint64 vrfRequestedAt, bool feesDistributed, uint256 participantCount, bytes32 validProofHash, bytes32 participantsRoot, bytes32 winnersRoot, bytes32 vrfSeed))",
  "function getRoundParticipants(uint256) view returns (address[])",
  "function getUserStats(uint256, address) view returns (uint256 wagered, uint256 tickets, uint256 weight, bool hasProof)"
];

/**
 * Generate Merkle tree leaf for a participant
 * Leaf format: keccak256(abi.encode(address, uint128 weight))
 */
function generateLeaf(address, weight) {
  return ethers.solidityPackedKeccak256(
    ['address', 'uint128'],
    [address, weight]
  );
}

/**
 * Main function to generate participants file
 */
async function generateParticipantsFile(roundId, outputPath) {
  console.log('\n=== Generate Participants File ===');
  console.log(`Round ID: ${roundId}`);
  
  // Setup provider and contract
  const rpcUrl = process.env.SEPOLIA_RPC_URL || process.env.RPC_URL;
  if (!rpcUrl) {
    throw new Error('SEPOLIA_RPC_URL or RPC_URL not set in environment');
  }
  
  const contractAddress = process.env.CONTRACT_ADDRESS;
  if (!contractAddress) {
    throw new Error('CONTRACT_ADDRESS not set in environment');
  }
  
  console.log(`\nConnecting to: ${rpcUrl}`);
  console.log(`Contract: ${contractAddress}`);
  
  const provider = new ethers.JsonRpcProvider(rpcUrl);
  const contract = new ethers.Contract(contractAddress, RAFFLE_ABI, provider);
  
  // Get round data
  console.log('\nFetching round data...');
  const round = await contract.getRound(roundId);
  console.log(`Round status: ${round.status} (3 = Snapshot expected)`);
  console.log(`Total tickets: ${round.totalTickets}`);
  console.log(`Total weight: ${round.totalWeight}`);
  
  // Validate round status
  if (round.status !== 3n) { // Snapshot status
    console.warn(`\n⚠️  Warning: Round is not in Snapshot status (current: ${round.status})`);
    console.warn('    Expected status: 3 (Snapshot)');
    console.warn('    Continuing anyway...\n');
  }
  
  // Get participants
  console.log('\nFetching participants...');
  const participantAddresses = await contract.getRoundParticipants(roundId);
  console.log(`Found ${participantAddresses.length} participants`);
  
  // Get stats for each participant with rate limiting
  console.log('\nFetching participant stats...');
  const participants = [];
  
  // Helper function to add delay for rate limiting
  const delay = ms => new Promise(resolve => setTimeout(resolve, ms));
  
  for (let i = 0; i < participantAddresses.length; i++) {
    const address = participantAddresses[i];
    
    // Retry logic for rate limit errors
    let retries = 3;
    let stats;
    
    while (retries > 0) {
      try {
        stats = await contract.getUserStats(roundId, address);
        break; // Success, exit retry loop
      } catch (error) {
        if (error.message.includes('Too Many Requests') && retries > 1) {
          console.log(`  ⏳ Rate limited, waiting 2 seconds... (${retries - 1} retries left)`);
          await delay(2000); // Wait 2 seconds before retry
          retries--;
        } else {
          throw error; // Not a rate limit error or out of retries
        }
      }
    }
    
    participants.push({
      address: address,
      weight: stats.weight.toString(),
      tickets: stats.tickets.toString(),
      wagered: ethers.formatEther(stats.wagered),
      hasProof: stats.hasProof
    });
    
    if ((i + 1) % 10 === 0) {
      console.log(`  Processed ${i + 1}/${participantAddresses.length}...`);
    }
    
    // Add small delay between requests to avoid rate limiting
    if (i < participantAddresses.length - 1) {
      await delay(100); // 100ms delay between requests
    }
  }
  
  console.log(`\nProcessed ${participants.length} participants`);
  
  // Generate Merkle tree
  console.log('\nGenerating Merkle tree...');
  const leaves = participants.map(p => generateLeaf(p.address, p.weight));
  const tree = new MerkleTree(leaves, ethers.keccak256, { sortPairs: true });
  const root = tree.getHexRoot();
  
  console.log(`Merkle root: ${root}`);
  
  // Create output file structure
  const outputData = {
    roundId: roundId.toString(),
    totalWeight: round.totalWeight.toString(),
    totalTickets: round.totalTickets.toString(),
    participantCount: participants.length,
    generatedAt: new Date().toISOString(),
    participants: participants,
    merkle: {
      root: root,
      leafFormat: "keccak256(abi.encode(address, uint128 weight))"
    }
  };
  
  // Write to file
  console.log(`\nWriting to ${outputPath}...`);
  fs.writeFileSync(outputPath, JSON.stringify(outputData, null, 2));
  console.log('✅ File written successfully!');
  
  // Display summary and next steps
  console.log('\n=== Summary ===');
  console.log(`Round ID: ${roundId}`);
  console.log(`Participants: ${participants.length}`);
  console.log(`Total Weight: ${round.totalWeight}`);
  console.log(`Merkle Root: ${root}`);
  console.log(`Output File: ${outputPath}`);
  
  console.log('\n=== Next Steps ===');
  console.log('1. Upload file to IPFS:');
  console.log(`   node upload-to-ipfs.js ${outputPath}`);
  console.log('\n2. Commit root on-chain:');
  console.log(`   cast send $CONTRACT_ADDRESS "commitParticipantsRoot(uint256,bytes32,string)" ${roundId} ${root} "<IPFS_CID>" --private-key $PRIVATE_KEY --rpc-url $SEPOLIA_RPC_URL`);
  console.log('\n3. Request VRF:');
  console.log(`   cast send $CONTRACT_ADDRESS "requestVrf(uint256)" ${roundId} --private-key $PRIVATE_KEY --rpc-url $SEPOLIA_RPC_URL`);
  
  return {
    root,
    file: outputPath,
    participants: participants.length
  };
}

// Parse command line arguments
const args = process.argv.slice(2);
if (args.length === 0 || args[0] === '--help' || args[0] === '-h') {
  console.log(`
Usage: node generate-participants-file.js <roundId> [--output <path>]

Arguments:
  <roundId>         Round ID to generate participants file for
  --output <path>   Output file path (default: participants-round-<roundId>.json)

Example:
  node generate-participants-file.js 1
  node generate-participants-file.js 1 --output custom-participants.json

Environment Variables (required):
  CONTRACT_ADDRESS    - Deployed contract address
  SEPOLIA_RPC_URL     - Sepolia RPC endpoint
  `);
  process.exit(0);
}

const roundId = args[0];
const outputIndex = args.indexOf('--output');
const outputPath = outputIndex !== -1 && args[outputIndex + 1]
  ? args[outputIndex + 1]
  : `participants-round-${roundId}.json`;

// Run the script
generateParticipantsFile(roundId, outputPath)
  .then((result) => {
    console.log('\n✅ Success!');
    process.exit(0);
  })
  .catch((error) => {
    console.error('\n❌ Error:', error.message);
    if (error.stack) {
      console.error('\nStack trace:', error.stack);
    }
    process.exit(1);
  });
