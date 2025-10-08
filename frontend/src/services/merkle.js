// Merkle Service for proof generation and verification
// Uses merkletreejs library with keccak256 hashing

import { ethers } from 'ethers';
import { MerkleTree } from 'merkletreejs';

/**
 * Build Merkle tree from participants data
 * @param {Array} participants - Array of participant objects with address and weight
 * @returns {MerkleTree} - Constructed Merkle tree
 */
export function buildParticipantsTree(participants) {
  if (!participants || participants.length === 0) {
    throw new Error('Cannot build tree: no participants provided');
  }
  
  // Generate leaves: keccak256(abi.encode(address, uint128 weight))
  const leaves = participants.map(p => {
    const encoded = ethers.AbiCoder.defaultAbiCoder().encode(
      ['address', 'uint128'],
      [p.address, BigInt(p.weight)]
    );
    return ethers.keccak256(encoded);
  });
  
  // Build tree with sorted pairs for deterministic root
  const tree = new MerkleTree(leaves, ethers.keccak256, { sortPairs: true });
  
  return tree;
}

/**
 * Build Merkle tree from winners data
 * @param {Array} winners - Array of winner objects with address, prizeTier, and prizeIndex
 * @returns {MerkleTree} - Constructed Merkle tree
 */
export function buildWinnersTree(winners) {
  if (!winners || winners.length === 0) {
    throw new Error('Cannot build tree: no winners provided');
  }
  
  // Generate leaves: keccak256(abi.encode(address, uint8 prizeTier, uint8 prizeIndex))
  const leaves = winners.map(w => {
    const encoded = ethers.AbiCoder.defaultAbiCoder().encode(
      ['address', 'uint8', 'uint8'],
      [w.address, w.prizeTier, w.prizeIndex]
    );
    return ethers.keccak256(encoded);
  });
  
  // Build tree with sorted pairs for deterministic root
  const tree = new MerkleTree(leaves, ethers.keccak256, { sortPairs: true });
  
  return tree;
}

/**
 * Generate Merkle proof for a participant
 * @param {Array} participants - Array of all participants
 * @param {string} address - Address to generate proof for
 * @returns {Array<string>} - Merkle proof (array of hashes)
 */
export function generateParticipantProof(participants, address) {
  const tree = buildParticipantsTree(participants);
  
  // Find the participant
  const participant = participants.find(
    p => p.address.toLowerCase() === address.toLowerCase()
  );
  
  if (!participant) {
    throw new Error(`Address ${address} not found in participants`);
  }
  
  // Generate leaf for this participant
  const encoded = ethers.AbiCoder.defaultAbiCoder().encode(
    ['address', 'uint128'],
    [participant.address, BigInt(participant.weight)]
  );
  const leaf = ethers.keccak256(encoded);
  
  // Get proof
  const proof = tree.getHexProof(leaf);
  
  return proof;
}

/**
 * Generate Merkle proof for a winner
 * @param {Array} winners - Array of all winners
 * @param {string} address - Address to generate proof for
 * @param {number} prizeIndex - Prize index to generate proof for
 * @returns {Array<string>} - Merkle proof (array of hashes)
 */
export function generateWinnerProof(winners, address, prizeIndex) {
  const tree = buildWinnersTree(winners);
  
  // Find the winner entry
  const winner = winners.find(
    w => w.address.toLowerCase() === address.toLowerCase() && w.prizeIndex === prizeIndex
  );
  
  if (!winner) {
    throw new Error(`Winner not found: ${address} for prize ${prizeIndex}`);
  }
  
  // Generate leaf for this winner
  const encoded = ethers.AbiCoder.defaultAbiCoder().encode(
    ['address', 'uint8', 'uint8'],
    [winner.address, winner.prizeTier, winner.prizeIndex]
  );
  const leaf = ethers.keccak256(encoded);
  
  // Get proof
  const proof = tree.getHexProof(leaf);
  
  return proof;
}

/**
 * Verify a participant proof against a root
 * @param {Array<string>} proof - Merkle proof
 * @param {string} root - Merkle root
 * @param {string} address - Participant address
 * @param {string} weight - Participant weight
 * @returns {boolean} - True if proof is valid
 */
export function verifyParticipantProof(proof, root, address, weight) {
  // Generate leaf
  const encoded = ethers.AbiCoder.defaultAbiCoder().encode(
    ['address', 'uint128'],
    [address, BigInt(weight)]
  );
  const leaf = ethers.keccak256(encoded);
  
  // Verify proof
  return MerkleTree.verify(proof, leaf, root, ethers.keccak256, { sortPairs: true });
}

/**
 * Verify a winner proof against a root
 * @param {Array<string>} proof - Merkle proof
 * @param {string} root - Merkle root
 * @param {string} address - Winner address
 * @param {number} prizeTier - Prize tier
 * @param {number} prizeIndex - Prize index
 * @returns {boolean} - True if proof is valid
 */
export function verifyWinnerProof(proof, root, address, prizeTier, prizeIndex) {
  // Generate leaf
  const encoded = ethers.AbiCoder.defaultAbiCoder().encode(
    ['address', 'uint8', 'uint8'],
    [address, prizeTier, prizeIndex]
  );
  const leaf = ethers.keccak256(encoded);
  
  // Verify proof
  return MerkleTree.verify(proof, leaf, root, ethers.keccak256, { sortPairs: true });
}

/**
 * Get all prizes won by a specific address
 * @param {Array} winners - Array of all winners
 * @param {string} address - Address to check
 * @returns {Array} - Array of prize objects user has won
 */
export function getPrizesForAddress(winners, address) {
  return winners.filter(
    w => w.address.toLowerCase() === address.toLowerCase()
  );
}

/**
 * Get prize tier name
 * @param {number} prizeTier - Prize tier number
 * @returns {string} - Human-readable prize tier name
 */
export function getPrizeTierName(prizeTier) {
  switch (prizeTier) {
    case 3:
      return 'Fake Pack (3 PEPEDAWN cards)';
    case 2:
      return 'Kek Pack (2 PEPEDAWN cards)';
    case 1:
      return 'Pepe Pack (1 PEPEDAWN card)';
    default:
      return `Unknown tier (${prizeTier})`;
  }
}

/**
 * Verify Winners File matches on-chain data
 * @param {Object} winnersFile - Winners file from IPFS
 * @param {string} onChainRoot - Root from contract
 * @param {string} onChainSeed - VRF seed from contract
 * @returns {boolean} - True if file is valid
 */
export function verifyWinnersFile(winnersFile, onChainRoot, onChainSeed) {
  // Check VRF seed matches
  if (winnersFile.vrfSeed !== onChainSeed) {
    console.error('VRF seed mismatch:', winnersFile.vrfSeed, 'vs', onChainSeed);
    return false;
  }
  
  // Rebuild tree and check root
  const tree = buildWinnersTree(winnersFile.winners);
  const computedRoot = tree.getHexRoot();
  
  if (computedRoot.toLowerCase() !== onChainRoot.toLowerCase()) {
    console.error('Merkle root mismatch:', computedRoot, 'vs', onChainRoot);
    return false;
  }
  
  console.log('✅ Winners File verified against on-chain data');
  return true;
}

/**
 * Verify Participants File matches on-chain data
 * @param {Object} participantsFile - Participants file from IPFS
 * @param {string} onChainRoot - Root from contract
 * @returns {boolean} - True if file is valid
 */
export function verifyParticipantsFile(participantsFile, onChainRoot) {
  // Rebuild tree and check root
  const tree = buildParticipantsTree(participantsFile.participants);
  const computedRoot = tree.getHexRoot();
  
  if (computedRoot.toLowerCase() !== onChainRoot.toLowerCase()) {
    console.error('Merkle root mismatch:', computedRoot, 'vs', onChainRoot);
    return false;
  }
  
  console.log('✅ Participants File verified against on-chain data');
  return true;
}
