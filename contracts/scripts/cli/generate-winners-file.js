#!/usr/bin/env node
/**
 * @file generate-winners-file.js
 * @notice Generate Winners File with Merkle tree after VRF fulfillment
 * @dev Fetches VRF seed, reconstructs winner selection deterministically
 * 
 * Usage:
 *   node generate-winners-file.js <roundId> [--output winners-round-<roundId>.json]
 * 
 * Output:
 *   - JSON file with winners data and Merkle root
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
  "function getRound(uint256) view returns (tuple(uint256 id, uint64 startTime, uint64 endTime, uint8 status, uint256 totalTickets, uint256 totalWeight, uint256 totalWagered, uint256 vrfRequestId, uint64 vrfRequestedAt, bool feesDistributed, uint256 participantCount, bytes32 validProofHash, bytes32 participantsRoot, bytes32 winnersRoot, bytes32 vrfSeed))"
];

// Prize tier constants (from contract)
const FAKE_PACK_TIER = 1;
const KEK_PACK_TIER = 2;
const PEPE_PACK_TIER = 3;

/**
 * Generate Merkle tree leaf for a winner
 * Leaf format: keccak256(abi.encodePacked(address, uint8 prizeTier, uint8 prizeIndex))
 */
function generateLeaf(address, prizeTier, prizeIndex) {
  return ethers.solidityPackedKeccak256(
    ['address', 'uint8', 'uint8'],
    [address, prizeTier, prizeIndex]
  );
}

/**
 * Select winners off-chain using VRF seed - RAFFLE MODEL
 * @param participants Array of participant objects with {address, weight, tickets}
 * @param vrfSeed The VRF seed (bytes32)
 * @param totalWeight Total weight of all participants
 * @return Array of 10 winners with {address, prizeTier, prizeIndex}
 * 
 * RAFFLE LOGIC:
 * - Each ticket can win ONE pack (tickets are consumed on win)
 * - Each participant can win multiple packs (up to their ticket count)
 * - After each win, the winning ticket is removed from the pool
 * - Total weight decreases by the ticket weight (1 or 1.4 if proof bonus)
 * - Odds change dynamically like a physical raffle
 */
function selectWinnersOffChain(participants, vrfSeed, totalWeight) {
  const winners = [];
  const numPrizes = 10;
  
  // Convert vrfSeed to uint256 for hashing
  const seedUint = BigInt(vrfSeed);
  
  // Create mutable participant pool with remaining tickets and weight
  // Each participant tracks: address, ticketsRemaining, weightPerTicket, totalRemainingWeight
  const participantPool = participants.map(p => ({
    address: p.address,
    ticketsRemaining: Number(p.tickets),
    totalRemainingWeight: BigInt(p.weight), // This will decrease as tickets are consumed
    weightPerTicket: BigInt(p.weight) / BigInt(p.tickets), // Weight per ticket (1 or 1.4)
    hasProof: p.hasProof || false
  }));
  
  let currentTotalWeight = BigInt(totalWeight);
  
  console.log('\n=== Raffle Selection Process ===');
  console.log(`Starting total weight: ${currentTotalWeight}`);
  console.log(`Prizes to distribute: ${numPrizes}\n`);
  
  for (let i = 0; i < numPrizes; i++) {
    // Check if we have any tickets left
    const totalTicketsRemaining = participantPool.reduce((sum, p) => sum + p.ticketsRemaining, 0);
    if (totalTicketsRemaining === 0 || currentTotalWeight === 0n) {
      console.warn(`⚠️  Only ${i} prizes awarded - no tickets remaining`);
      break;
    }
    
    // Generate random hash for this prize (deterministic based on VRF seed + prize index)
    const randomHash = ethers.keccak256(
      ethers.AbiCoder.defaultAbiCoder().encode(
        ['uint256', 'uint256'],
        [seedUint, i]
      )
    );
    
    // Convert to random weight in range [0, currentTotalWeight)
    const randomWeight = BigInt(randomHash) % currentTotalWeight;
    
    // Find winner by cumulative weight (weighted lottery)
    let cumulative = 0n;
    let winnerAddress = null;
    let winnerIndex = -1;
    
    for (let j = 0; j < participantPool.length; j++) {
      const participant = participantPool[j];
      
      // Skip participants with no tickets remaining
      if (participant.ticketsRemaining === 0) continue;
      
      cumulative += participant.totalRemainingWeight;
      if (cumulative > randomWeight) {
        winnerAddress = participant.address;
        winnerIndex = j;
        break;
      }
    }
    
    // Fallback: shouldn't happen, but pick last participant with tickets
    if (winnerAddress === null) {
      for (let j = participantPool.length - 1; j >= 0; j--) {
        if (participantPool[j].ticketsRemaining > 0) {
          winnerIndex = j;
          winnerAddress = participantPool[j].address;
          break;
        }
      }
    }
    
    // Assign prize tier
    const prizeTier = getPrizeTier(i);
    
    winners.push({
      address: winnerAddress,
      prizeTier: prizeTier,
      prizeIndex: i
    });
    
    // CRITICAL: Consume one ticket from the winner (raffle mechanic)
    const winner = participantPool[winnerIndex];
    winner.ticketsRemaining -= 1;
    winner.totalRemainingWeight -= winner.weightPerTicket;
    currentTotalWeight -= winner.weightPerTicket;
    
    console.log(`Prize ${i + 1} (Tier ${prizeTier}): ${winnerAddress}`);
    console.log(`  - Tickets remaining for winner: ${winner.ticketsRemaining}`);
    console.log(`  - Total weight remaining: ${currentTotalWeight}\n`);
  }
  
  console.log('=== Raffle Complete ===\n');
  
  return winners;
}

/**
 * Get prize tier for a given prize index
 */
function getPrizeTier(prizeIndex) {
  if (prizeIndex === 0) return FAKE_PACK_TIER;  // 1st place
  if (prizeIndex === 1) return KEK_PACK_TIER;   // 2nd place
  return PEPE_PACK_TIER;                        // 3rd-10th place
}

/**
 * Main function to generate winners file
 */
async function generateWinnersFile(roundId, outputPath) {
  console.log('\n=== Generate Winners File ===');
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
  console.log(`Round status: ${round.status} (5 = WinnersReady expected)`);
  
  // Validate round status  
  if (round.status !== 5n) { // WinnersReady status
    console.warn(`\n⚠️  Warning: Round is not in WinnersReady status (current: ${round.status})`);
    console.warn('    Expected status: 5 (WinnersReady - VRF fulfilled, awaiting Merkle root)');
    console.warn('    Continuing anyway...\n');
  }
  
  // Validate VRF seed exists
  if (round.vrfSeed === ethers.ZeroHash) {
    throw new Error('VRF seed not set - VRF has not been fulfilled yet');
  }
  
  console.log(`VRF Seed: ${round.vrfSeed}`);
  console.log(`Total weight: ${round.totalWeight}`);
  
  // Load participants file (required for off-chain winner selection)
  console.log('\nLoading participants file...');
  const participantsFile = `participants-round-${roundId}.json`;
  
  if (!fs.existsSync(participantsFile)) {
    throw new Error(`Participants file not found: ${participantsFile}\nRun: node generate-participants-file.js ${roundId}`);
  }
  
  const participantsData = JSON.parse(fs.readFileSync(participantsFile, 'utf8'));
  console.log(`Loaded ${participantsData.participants.length} participants from file`);
  
  // Select winners OFF-CHAIN using VRF seed
  console.log('\nSelecting winners off-chain using VRF seed...');
  console.log('(This produces identical results to on-chain selection)');
  
  const winners = selectWinnersOffChain(
    participantsData.participants,
    round.vrfSeed,
    round.totalWeight
  );
  
  console.log(`Selected ${winners.length} winners`);
  
  // Add metadata to winners
  winners.forEach(w => {
    w.vrfRequestId = round.vrfRequestId.toString();
    w.blockNumber = 'N/A (selected off-chain)';
  });
  
  console.log('\nWinners by tier:');
  const tierCounts = { 1: 0, 2: 0, 3: 0 };
  winners.forEach(w => tierCounts[w.prizeTier]++);
  console.log(`  Fake Pack (Tier 1): ${tierCounts[1]}`);
  console.log(`  Kek Pack (Tier 2): ${tierCounts[2]}`);
  console.log(`  Pepe Pack (Tier 3): ${tierCounts[3]}`);
  
  // Generate Merkle tree
  console.log('\nGenerating Merkle tree...');
  const leaves = winners.map(w => generateLeaf(w.address, w.prizeTier, w.prizeIndex));
  const tree = new MerkleTree(leaves, ethers.keccak256, { sortPairs: true });
  const root = tree.getHexRoot();
  
  console.log(`Merkle root: ${root}`);
  
  // Create output file structure
  const outputData = {
    version: "1.0",
    roundId: roundId.toString(),
    vrfSeed: round.vrfSeed,
    vrfRequestId: round.vrfRequestId.toString(),
    totalWeight: round.totalWeight.toString(),
    winnerCount: winners.length,
    generatedAt: new Date().toISOString(),
    derivation: "Winners selected OFF-CHAIN using VRF seed (deterministic, verifiable)",
    selectionMethod: "Weighted lottery with cumulative weights (matches on-chain algorithm)",
    winners: winners,
    merkle: {
      root: root,
      leafFormat: "keccak256(abi.encode(address, uint8 prizeTier, uint8 prizeIndex))"
    }
  };
  
  // Write to file
  console.log(`\nWriting to ${outputPath}...`);
  fs.writeFileSync(outputPath, JSON.stringify(outputData, null, 2));
  console.log('✅ File written successfully!');
  
  // Auto-copy to frontend for local testing
  try {
    const frontendWinnersDir = path.join(__dirname, '../../../frontend/public/winners');
    if (!fs.existsSync(frontendWinnersDir)) {
      fs.mkdirSync(frontendWinnersDir, { recursive: true });
    }
    const frontendWinnersPath = path.join(frontendWinnersDir, `winners-round-${roundId}.json`);
    fs.copyFileSync(outputPath, frontendWinnersPath);
    console.log(`✅ Copied to frontend: ${frontendWinnersPath}`);
  } catch (error) {
    console.warn('⚠️  Could not copy to frontend:', error.message);
  }
  
  // Display summary and next steps
  console.log('\n=== Summary ===');
  console.log(`Round ID: ${roundId}`);
  console.log(`Winners: ${winners.length}`);
  console.log(`VRF Seed: ${round.vrfSeed}`);
  console.log(`Merkle Root: ${root}`);
  console.log(`Output File: ${outputPath}`);
  
  console.log('\n=== Next Steps ===');
  console.log('1. Upload file to IPFS:');
  console.log(`   node upload-to-ipfs.js ${outputPath}`);
  console.log('\n2. Submit winners root on-chain:');
  console.log(`   cast send $CONTRACT_ADDRESS "submitWinnersRoot(uint256,bytes32,string)" ${roundId} ${root} "<IPFS_CID>" --private-key $PRIVATE_KEY --rpc-url $SEPOLIA_RPC_URL`);
  console.log('\n3. Winners can now claim their prizes using the frontend with Merkle proofs!');
  
  return {
    root,
    file: outputPath,
    winners: winners.length
  };
}

// Parse command line arguments
const args = process.argv.slice(2);
if (args.length === 0 || args[0] === '--help' || args[0] === '-h') {
  console.log(`
Usage: node generate-winners-file.js <roundId> [--output <path>]

Arguments:
  <roundId>         Round ID to generate winners file for
  --output <path>   Output file path (default: winners-round-<roundId>.json)

Example:
  node generate-winners-file.js 1
  node generate-winners-file.js 1 --output custom-winners.json

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
  : `winners-round-${roundId}.json`;

// Run the script
generateWinnersFile(roundId, outputPath)
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
