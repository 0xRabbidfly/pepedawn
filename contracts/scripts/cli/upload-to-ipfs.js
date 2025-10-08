#!/usr/bin/env node
/**
 * @file upload-to-ipfs.js
 * @notice Helper script for uploading files to IPFS
 * @dev Provides instructions and validates file before upload
 * 
 * Usage:
 *   node upload-to-ipfs.js <file-path>
 * 
 * Supported Services:
 *   - NFT.Storage (recommended, free, 100GB)
 *   - Web3.Storage (free, 1TB)
 *   - Pinata (free tier: 1GB)
 *   - Manual upload via IPFS desktop/CLI
 */

import fs from 'fs';
import path from 'path';
import { fileURLToPath } from 'url';

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);

/**
 * Validate JSON file and extract relevant info
 */
function validateFile(filePath) {
  console.log(`\nValidating file: ${filePath}`);
  
  if (!fs.existsSync(filePath)) {
    throw new Error(`File not found: ${filePath}`);
  }
  
  const content = fs.readFileSync(filePath, 'utf8');
  let data;
  
  try {
    data = JSON.parse(content);
  } catch (e) {
    throw new Error(`Invalid JSON file: ${e.message}`);
  }
  
  // Determine file type
  const isParticipants = data.participants !== undefined;
  const isWinners = data.winners !== undefined;
  
  if (!isParticipants && !isWinners) {
    throw new Error('Unknown file type - must be participants or winners file');
  }
  
  console.log(`✅ Valid ${isParticipants ? 'participants' : 'winners'} file`);
  console.log(`   Round ID: ${data.roundId}`);
  console.log(`   Merkle Root: ${data.merkle.root}`);
  
  if (isParticipants) {
    console.log(`   Participants: ${data.participants.length}`);
    console.log(`   Total Weight: ${data.totalWeight}`);
  } else {
    console.log(`   Winners: ${data.winners.length}`);
    console.log(`   VRF Seed: ${data.vrfSeed}`);
  }
  
  return { data, isParticipants, isWinners };
}

/**
 * Display upload instructions
 */
function displayInstructions(filePath, data, isParticipants) {
  const fileName = path.basename(filePath);
  const fileType = isParticipants ? 'Participants' : 'Winners';
  
  console.log('\n=== IPFS Upload Instructions ===');
  console.log(`\nFile to upload: ${filePath}`);
  console.log(`File type: ${fileType} File`);
  console.log(`Round ID: ${data.roundId}`);
  console.log(`Merkle Root: ${data.merkle.root}`);
  
  console.log('\n📦 Option 1: NFT.Storage (Recommended - Free, 100GB)');
  console.log('─────────────────────────────────────────────────');
  console.log('1. Visit: https://nft.storage/');
  console.log('2. Sign in with email or GitHub');
  console.log('3. Go to "Files" → "Upload"');
  console.log(`4. Upload: ${fileName}`);
  console.log('5. Copy the CID (starts with "bafybei...")');
  console.log('6. Verify access: https://nftstorage.link/ipfs/<CID>');
  
  console.log('\n📦 Option 2: Web3.Storage (Free, 1TB)');
  console.log('─────────────────────────────────────────────────');
  console.log('1. Visit: https://web3.storage/');
  console.log('2. Sign in with email');
  console.log('3. Go to "Upload" → "Upload Files"');
  console.log(`4. Upload: ${fileName}`);
  console.log('5. Copy the CID');
  console.log('6. Verify access: https://w3s.link/ipfs/<CID>');
  
  console.log('\n📦 Option 3: Pinata (Free tier: 1GB)');
  console.log('─────────────────────────────────────────────────');
  console.log('1. Visit: https://pinata.cloud/');
  console.log('2. Sign up for free account');
  console.log('3. Go to "Upload" → "File"');
  console.log(`4. Upload: ${fileName}`);
  console.log('5. Copy the CID');
  console.log('6. Verify access: https://gateway.pinata.cloud/ipfs/<CID>');
  
  console.log('\n📦 Option 4: IPFS Desktop/CLI (Local)');
  console.log('─────────────────────────────────────────────────');
  console.log('1. Install IPFS Desktop: https://docs.ipfs.tech/install/ipfs-desktop/');
  console.log('2. Start IPFS Desktop');
  console.log(`3. Drag and drop: ${fileName}`);
  console.log('4. Copy the CID');
  console.log('5. File is pinned locally (consider using a pinning service for persistence)');
  
  console.log('\n🔗 After uploading:');
  console.log('─────────────────────────────────────────────────');
  console.log(`1. Test the CID with multiple gateways:`);
  console.log('   - https://ipfs.io/ipfs/<CID>');
  console.log('   - https://cloudflare-ipfs.com/ipfs/<CID>');
  console.log('   - https://gateway.pinata.cloud/ipfs/<CID>');
  console.log('');
  console.log('2. Commit the CID on-chain:');
  
  if (isParticipants) {
    console.log(`   cast send $CONTRACT_ADDRESS "commitParticipantsRoot(uint256,bytes32,string)" ${data.roundId} ${data.merkle.root} "<YOUR_CID>" --private-key $PRIVATE_KEY --rpc-url $SEPOLIA_RPC_URL`);
  } else {
    console.log(`   cast send $CONTRACT_ADDRESS "commitWinners(uint256,bytes32,string)" ${data.roundId} ${data.merkle.root} "<YOUR_CID>" --private-key $PRIVATE_KEY --rpc-url $SEPOLIA_RPC_URL`);
  }
  
  console.log('\n✅ Pro tip: Keep a backup of the CID in a safe place!');
  console.log('   The file will remain accessible as long as it\'s pinned by at least one service.');
}

/**
 * Main function
 */
async function main() {
  const args = process.argv.slice(2);
  
  if (args.length === 0 || args[0] === '--help' || args[0] === '-h') {
    console.log(`
Usage: node upload-to-ipfs.js <file-path>

Arguments:
  <file-path>    Path to the participants or winners JSON file

Example:
  node upload-to-ipfs.js participants-round-1.json
  node upload-to-ipfs.js winners-round-1.json

Description:
  This script validates your file and provides instructions for uploading
  to IPFS using free pinning services (NFT.Storage, Web3.Storage, Pinata)
  or local IPFS.

  After upload, you'll receive a CID (Content Identifier) that you must
  commit on-chain using the contract's commit functions.
    `);
    process.exit(0);
  }
  
  const filePath = path.resolve(args[0]);
  
  try {
    // Validate file
    const { data, isParticipants, isWinners } = validateFile(filePath);
    
    // Display upload instructions
    displayInstructions(filePath, data, isParticipants);
    
    console.log('\n✅ File is ready for upload!');
    console.log('\nFollow the instructions above to upload to your preferred IPFS service.');
    
  } catch (error) {
    console.error('\n❌ Error:', error.message);
    process.exit(1);
  }
}

main();
