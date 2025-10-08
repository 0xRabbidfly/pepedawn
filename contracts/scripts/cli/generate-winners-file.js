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
  "function getRound(uint256) view returns (tuple(uint256 id, uint64 startTime, uint64 endTime, uint8 status, uint256 totalTickets, uint256 totalWeight, uint256 totalWagered, uint256 vrfRequestId, uint64 vrfRequestedAt, bool feesDistributed, uint256 participantCount, bytes32 validProofHash, bytes32 participantsRoot, bytes32 winnersRoot, bytes32 vrfSeed))",
  "function getRoundParticipants(uint256) view returns (address[])",
  "function getUserStats(uint256, address) view returns (uint256 wagered, uint256 tickets, uint256 weight, bool hasProof)",
  "function getRoundWinners(uint256) view returns (tuple(uint256 roundId, address wallet, uint8 prizeTier, uint256 vrfRequestId, uint256 blockNumber)[])"
];

// Prize tier constants (from contract)
const FAKE_PACK_TIER = 1;
const KEK_PACK_TIER = 2;
const PEPE_PACK_TIER = 3;

/**
 * Generate Merkle tree leaf for a winner
 * Leaf format: keccak256(abi.encode(address, uint8 prizeTier, uint8 prizeIndex))
 */
function generateLeaf(address, prizeTier, prizeIndex) {
  return ethers.solidityPackedKeccak256(
    ['address', 'uint8', 'uint8'],
    [address, prizeTier, prizeIndex]
  );
}

/**
 * Reconstruct winner selection from VRF seed (matches on-chain algorithm)
 * This is a simplified version - the actual on-chain selection is more complex
 */
function selectWinnerFromParticipants(participants, totalWeight, randomSeed, winnerIndex) {
  // Generate random weight for this winner
  const randomHash = ethers.keccak256(
    ethers.AbiCoder.defaultAbiCoder().encode(
      ['uint256', 'uint256'],
      [randomSeed, winnerIndex]
    )
  );
  const randomWeight = BigInt(randomHash) % totalWeight;
  
  // Find winner by cumulative weight (binary search simulation)
  let cumulative = 0n;
  for (const participant of participants) {
    cumulative += BigInt(participant.weight);
    if (cumulative > randomWeight) {
      return participant.address;
    }
  }
  
  // Fallback to last participant (edge case)
  return participants[participants.length - 1].address;
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
  console.log(`Round status: ${round.status} (5 = Distributed expected)`);
  
  // Validate round status
  if (round.status !== 5n) { // Distributed status
    console.warn(`\n⚠️  Warning: Round is not in Distributed status (current: ${round.status})`);
    console.warn('    Expected status: 5 (Distributed)');
    console.warn('    Continuing anyway...\n');
  }
  
  // Validate VRF seed exists
  if (round.vrfSeed === ethers.ZeroHash) {
    throw new Error('VRF seed not set - VRF has not been fulfilled yet');
  }
  
  console.log(`VRF Seed: ${round.vrfSeed}`);
  console.log(`Total weight: ${round.totalWeight}`);
  
  // Get winners from contract (they were already assigned on-chain)
  console.log('\nFetching winners from contract...');
  const onChainWinners = await contract.getRoundWinners(roundId);
  console.log(`Found ${onChainWinners.length} winners on-chain`);
  
  // Convert to our format
  const winners = [];
  for (let i = 0; i < onChainWinners.length; i++) {
    const winner = onChainWinners[i];
    winners.push({
      address: winner.wallet,
      prizeTier: Number(winner.prizeTier),
      prizeIndex: i, // Prize index is the order in the winners array
      vrfRequestId: winner.vrfRequestId.toString(),
      blockNumber: winner.blockNumber.toString()
    });
  }
  
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
    roundId: roundId.toString(),
    vrfSeed: round.vrfSeed,
    vrfRequestId: round.vrfRequestId.toString(),
    totalWeight: round.totalWeight.toString(),
    winnerCount: winners.length,
    generatedAt: new Date().toISOString(),
    derivation: "Winners selected on-chain via VRF and weighted lottery",
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
  console.log('\n2. Commit winners root on-chain:');
  console.log(`   cast send $CONTRACT_ADDRESS "commitWinners(uint256,bytes32,string)" ${roundId} ${root} "<IPFS_CID>" --private-key $PRIVATE_KEY --rpc-url $SEPOLIA_RPC_URL`);
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
