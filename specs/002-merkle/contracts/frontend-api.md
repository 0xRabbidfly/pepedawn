# Frontend API: Merkle Proof Claims

**Feature**: 002-merkle  
**Date**: October 8, 2025  
**Framework**: Vanilla JavaScript + Vite

## Overview

This document specifies the frontend service interfaces for Merkle proof generation, IPFS file fetching, and claims management.

## Service: MerkleService

**Purpose**: Generate Merkle trees and proofs for participants and winners.

### Constructor

```javascript
class MerkleService {
  /**
   * @param {Object} options - Configuration options
   * @param {boolean} options.useWorker - Use Web Worker for large trees (default: true)
   * @param {number} options.workerThreshold - Participant count to trigger worker (default: 100)
   */
  constructor(options = {}) {
    this.useWorker = options.useWorker ?? true;
    this.workerThreshold = options.workerThreshold ?? 100;
    this.cache = new Map(); // In-memory cache
  }
}
```

### Methods

#### buildParticipantsTree

```javascript
/**
 * Build Merkle tree from participants data
 * @param {Array<Object>} participants - Array of {address, weight}
 * @param {number} roundId - Round ID for caching
 * @returns {Promise<MerkleTree>} The constructed Merkle tree
 * @throws {Error} If participants array is empty or invalid
 */
async buildParticipantsTree(participants, roundId) {
  // Validate input
  if (!Array.isArray(participants) || participants.length === 0) {
    throw new Error('Invalid participants array');
  }
  
  // Check cache
  const cacheKey = `participants-${roundId}`;
  if (this.cache.has(cacheKey)) {
    return this.cache.get(cacheKey);
  }
  
  // Generate leaves
  const leaves = participants.map(p => 
    keccak256(ethers.AbiCoder.defaultAbiCoder().encode(
      ['address', 'uint128'],
      [p.address, p.weight]
    ))
  );
  
  // Build tree (use worker if large)
  let tree;
  if (this.useWorker && participants.length >= this.workerThreshold) {
    tree = await this._buildTreeInWorker(leaves);
  } else {
    tree = new MerkleTree(leaves, keccak256, { sortPairs: true });
  }
  
  // Cache and return
  this.cache.set(cacheKey, tree);
  return tree;
}
```

**Test Cases**:
- ✓ Builds tree for valid participants
- ✗ Throws error for empty array
- ✗ Throws error for invalid participant data
- ✓ Uses worker for large trees (≥100 participants)
- ✓ Uses main thread for small trees (<100 participants)
- ✓ Caches tree for subsequent calls
- ✓ Returns cached tree on second call

#### buildWinnersTree

```javascript
/**
 * Build Merkle tree from winners data
 * @param {Array<Object>} winners - Array of {address, prizeTier, prizeIndex}
 * @param {number} roundId - Round ID for caching
 * @returns {Promise<MerkleTree>} The constructed Merkle tree
 * @throws {Error} If winners array is invalid (must be exactly 10)
 */
async buildWinnersTree(winners, roundId) {
  // Validate input
  if (!Array.isArray(winners) || winners.length !== 10) {
    throw new Error('Winners array must contain exactly 10 entries');
  }
  
  // Check cache
  const cacheKey = `winners-${roundId}`;
  if (this.cache.has(cacheKey)) {
    return this.cache.get(cacheKey);
  }
  
  // Generate leaves
  const leaves = winners.map(w => 
    keccak256(ethers.AbiCoder.defaultAbiCoder().encode(
      ['address', 'uint8', 'uint8'],
      [w.address, w.prizeTier, w.prizeIndex]
    ))
  );
  
  // Build tree (winners always small, no worker needed)
  const tree = new MerkleTree(leaves, keccak256, { sortPairs: true });
  
  // Cache and return
  this.cache.set(cacheKey, tree);
  return tree;
}
```

**Test Cases**:
- ✓ Builds tree for valid winners (10 entries)
- ✗ Throws error for wrong number of winners
- ✗ Throws error for invalid winner data
- ✓ Caches tree for subsequent calls
- ✓ Never uses worker (always small)

#### generateProof

```javascript
/**
 * Generate Merkle proof for a specific leaf
 * @param {MerkleTree} tree - The Merkle tree
 * @param {Object} data - The data to prove (participant or winner)
 * @param {string} type - 'participant' or 'winner'
 * @returns {Array<string>} The Merkle proof (hex strings)
 * @throws {Error} If leaf not found in tree
 */
generateProof(tree, data, type) {
  let leaf;
  
  if (type === 'participant') {
    leaf = keccak256(ethers.AbiCoder.defaultAbiCoder().encode(
      ['address', 'uint128'],
      [data.address, data.weight]
    ));
  } else if (type === 'winner') {
    leaf = keccak256(ethers.AbiCoder.defaultAbiCoder().encode(
      ['address', 'uint8', 'uint8'],
      [data.address, data.prizeTier, data.prizeIndex]
    ));
  } else {
    throw new Error('Invalid type: must be "participant" or "winner"');
  }
  
  const proof = tree.getHexProof(leaf);
  
  if (proof.length === 0) {
    throw new Error('Leaf not found in tree');
  }
  
  return proof;
}
```

**Test Cases**:
- ✓ Generates proof for valid participant
- ✓ Generates proof for valid winner
- ✗ Throws error for invalid type
- ✗ Throws error for leaf not in tree
- ✓ Proof verifies against root

#### verifyProof

```javascript
/**
 * Verify a Merkle proof
 * @param {Array<string>} proof - The Merkle proof
 * @param {string} root - The Merkle root (hex string)
 * @param {string} leaf - The leaf to verify (hex string)
 * @returns {boolean} True if proof is valid
 */
verifyProof(proof, root, leaf) {
  return MerkleTree.verify(proof, leaf, root, keccak256, { sortPairs: true });
}
```

**Test Cases**:
- ✓ Returns true for valid proof
- ✓ Returns false for invalid proof
- ✓ Returns false for wrong root
- ✓ Returns false for wrong leaf

## Service: IPFSService

**Purpose**: Fetch and verify IPFS files with timeout and fallback.

### Constructor

```javascript
class IPFSService {
  /**
   * @param {Object} options - Configuration options
   * @param {Array<string>} options.gateways - IPFS gateway URLs
   * @param {number} options.timeout - Timeout per gateway in ms (default: 20000)
   * @param {number} options.maxRetries - Max retries per gateway (default: 1)
   */
  constructor(options = {}) {
    this.gateways = options.gateways ?? [
      'https://gateway.pinata.cloud/ipfs',
      'https://infura-ipfs.io/ipfs',
      'https://ipfs.io/ipfs'
    ];
    this.timeout = options.timeout ?? 20000; // 20 seconds per gateway
    this.maxRetries = options.maxRetries ?? 1;
  }
}
```

### Methods

#### fetchFile

```javascript
/**
 * Fetch file from IPFS with timeout and fallback
 * @param {string} cid - IPFS CID
 * @param {number} totalTimeout - Total timeout in ms (default: 60000)
 * @returns {Promise<Object>} The parsed JSON file
 * @throws {Error} If all gateways fail or timeout
 */
async fetchFile(cid, totalTimeout = 60000) {
  const startTime = Date.now();
  
  for (const gateway of this.gateways) {
    // Check total timeout
    if (Date.now() - startTime >= totalTimeout) {
      throw new Error('IPFS fetch timeout: service unavailable');
    }
    
    try {
      const url = `${gateway}/${cid}`;
      const controller = new AbortController();
      const timeoutId = setTimeout(() => controller.abort(), this.timeout);
      
      const response = await fetch(url, { signal: controller.signal });
      clearTimeout(timeoutId);
      
      if (response.ok) {
        const data = await response.json();
        logger.info('ipfs_fetch_success', { cid, gateway, duration: Date.now() - startTime });
        return data;
      }
    } catch (error) {
      logger.warn('ipfs_fetch_failed', { cid, gateway, error: error.message });
      continue;
    }
  }
  
  logger.error('ipfs_fetch_all_failed', { cid, duration: Date.now() - startTime });
  throw new Error('All IPFS gateways failed');
}
```

**Test Cases**:
- ✓ Fetches file from first gateway on success
- ✓ Falls back to second gateway on first failure
- ✓ Falls back to third gateway on second failure
- ✗ Throws error after all gateways fail
- ✗ Throws error after 60-second total timeout
- ✓ Logs success with duration
- ✓ Logs failures with error details

#### verifyFile

```javascript
/**
 * Verify IPFS file Merkle root matches on-chain root
 * @param {Object} file - The IPFS file (participants or winners)
 * @param {string} onChainRoot - The on-chain Merkle root
 * @param {MerkleService} merkleService - Merkle service instance
 * @returns {Promise<Object>} Verification result {verified, error}
 */
async verifyFile(file, onChainRoot, merkleService) {
  try {
    // Determine file type
    const isParticipants = 'participants' in file;
    const isWinners = 'winners' in file;
    
    if (!isParticipants && !isWinners) {
      return { verified: false, error: 'Invalid file format' };
    }
    
    // Build tree
    let tree;
    if (isParticipants) {
      tree = await merkleService.buildParticipantsTree(file.participants, file.roundId);
    } else {
      tree = await merkleService.buildWinnersTree(file.winners, file.roundId);
    }
    
    // Compare roots
    const computedRoot = tree.getHexRoot();
    const verified = computedRoot.toLowerCase() === onChainRoot.toLowerCase();
    
    if (!verified) {
      logger.error('merkle_verification_failed', {
        roundId: file.roundId,
        computed: computedRoot,
        onChain: onChainRoot
      });
      return { verified: false, error: 'Root mismatch' };
    }
    
    logger.critical('merkle_verification_completed', {
      roundId: file.roundId,
      root: onChainRoot,
      verified: true
    });
    
    return { verified: true, error: null };
  } catch (error) {
    logger.error('merkle_verification_error', { error: error.message });
    return { verified: false, error: error.message };
  }
}
```

**Test Cases**:
- ✓ Returns verified=true for matching roots
- ✓ Returns verified=false for mismatched roots
- ✗ Returns verified=false for invalid file format
- ✓ Logs verification completion
- ✓ Logs verification failure with details

## Service: ClaimsService

**Purpose**: Manage prize claims and refund withdrawals.

### Constructor

```javascript
class ClaimsService {
  /**
   * @param {Object} contract - Ethers contract instance
   * @param {MerkleService} merkleService - Merkle service instance
   * @param {IPFSService} ipfsService - IPFS service instance
   */
  constructor(contract, merkleService, ipfsService) {
    this.contract = contract;
    this.merkleService = merkleService;
    this.ipfsService = ipfsService;
  }
}
```

### Methods

#### getUserWins

```javascript
/**
 * Get user's wins from winners file
 * @param {Object} winnersFile - The winners IPFS file
 * @param {string} userAddress - User's Ethereum address
 * @returns {Array<Object>} Array of {prizeIndex, prizeTier}
 */
getUserWins(winnersFile, userAddress) {
  const normalizedAddress = userAddress.toLowerCase();
  return winnersFile.winners
    .filter(w => w.address.toLowerCase() === normalizedAddress)
    .map(w => ({
      prizeIndex: w.prizeIndex,
      prizeTier: w.prizeTier
    }));
}
```

**Test Cases**:
- ✓ Returns empty array for non-winner
- ✓ Returns single win for winner with one prize
- ✓ Returns multiple wins for winner with multiple prizes
- ✓ Case-insensitive address matching

#### getClaimStatus

```javascript
/**
 * Get claim status for user's wins
 * @param {number} roundId - Round ID
 * @param {Array<Object>} wins - User's wins from getUserWins
 * @returns {Promise<Array<Object>>} Array of {prizeIndex, prizeTier, claimed}
 */
async getClaimStatus(roundId, wins) {
  const statuses = await Promise.all(
    wins.map(async (win) => {
      const { claimer, claimed } = await this.contract.getClaimStatus(
        roundId,
        win.prizeIndex
      );
      return {
        ...win,
        claimed,
        claimer
      };
    })
  );
  return statuses;
}
```

**Test Cases**:
- ✓ Returns claimed=false for unclaimed prizes
- ✓ Returns claimed=true for claimed prizes
- ✓ Returns correct claimer address
- ✓ Handles multiple wins correctly

#### claimPrize

```javascript
/**
 * Claim a prize with Merkle proof
 * @param {number} roundId - Round ID
 * @param {number} prizeIndex - Prize slot index (0-9)
 * @param {number} prizeTier - Prize tier (1-3)
 * @param {string} userAddress - User's address
 * @param {MerkleTree} winnersTree - Winners Merkle tree
 * @returns {Promise<Object>} Transaction result {txHash, success, error}
 */
async claimPrize(roundId, prizeIndex, prizeTier, userAddress, winnersTree) {
  try {
    // Generate proof
    const proof = this.merkleService.generateProof(
      winnersTree,
      { address: userAddress, prizeTier, prizeIndex },
      'winner'
    );
    
    // Submit claim transaction
    const tx = await this.contract.claim(roundId, prizeIndex, prizeTier, proof);
    
    logger.critical('claim_submitted', {
      roundId,
      prizeIndex,
      prizeTier,
      txHash: tx.hash
    });
    
    // Wait for confirmation
    const receipt = await tx.wait();
    
    if (receipt.status === 1) {
      logger.critical('claim_confirmed', {
        roundId,
        prizeIndex,
        txHash: tx.hash
      });
      return { txHash: tx.hash, success: true, error: null };
    } else {
      logger.error('claim_failed', {
        roundId,
        prizeIndex,
        txHash: tx.hash
      });
      return { txHash: tx.hash, success: false, error: 'Transaction failed' };
    }
  } catch (error) {
    logger.error('claim_error', {
      roundId,
      prizeIndex,
      error: error.message
    });
    return { txHash: null, success: false, error: error.message };
  }
}
```

**Test Cases**:
- ✓ Submits claim with valid proof
- ✗ Fails with invalid proof
- ✗ Fails for already claimed prize
- ✓ Returns transaction hash on success
- ✓ Logs claim submission and confirmation
- ✓ Handles transaction rejection

#### withdrawRefund

```javascript
/**
 * Withdraw refund balance
 * @returns {Promise<Object>} Transaction result {txHash, amount, success, error}
 */
async withdrawRefund() {
  try {
    // Get refund balance
    const balance = await this.contract.refunds(await this.contract.signer.getAddress());
    
    if (balance.isZero()) {
      return { txHash: null, amount: '0', success: false, error: 'No refund available' };
    }
    
    // Submit withdrawal transaction
    const tx = await this.contract.withdrawRefund();
    
    logger.critical('refund_withdrawn', {
      amount: balance.toString(),
      txHash: tx.hash
    });
    
    // Wait for confirmation
    const receipt = await tx.wait();
    
    if (receipt.status === 1) {
      return { txHash: tx.hash, amount: balance.toString(), success: true, error: null };
    } else {
      logger.error('refund_withdrawal_failed', { txHash: tx.hash });
      return { txHash: tx.hash, amount: balance.toString(), success: false, error: 'Transaction failed' };
    }
  } catch (error) {
    logger.error('refund_withdrawal_error', { error: error.message });
    return { txHash: null, amount: '0', success: false, error: error.message };
  }
}
```

**Test Cases**:
- ✓ Withdraws refund when balance > 0
- ✗ Fails when balance = 0
- ✓ Returns transaction hash and amount on success
- ✓ Logs withdrawal
- ✓ Handles transaction rejection

## Service: Logger

**Purpose**: Structured logging for observability.

### Methods

```javascript
const logger = {
  /**
   * Log error event
   * @param {string} event - Event name
   * @param {Object} details - Event details
   */
  error(event, details) {
    console.error(JSON.stringify({
      level: 'ERROR',
      timestamp: Date.now(),
      event,
      ...details
    }));
  },
  
  /**
   * Log critical action
   * @param {string} action - Action name
   * @param {Object} details - Action details
   */
  critical(action, details) {
    console.log(JSON.stringify({
      level: 'CRITICAL',
      timestamp: Date.now(),
      action,
      ...details
    }));
  },
  
  /**
   * Log info message
   * @param {string} message - Message
   * @param {Object} details - Message details
   */
  info(message, details) {
    console.log(JSON.stringify({
      level: 'INFO',
      timestamp: Date.now(),
      message,
      ...details
    }));
  },
  
  /**
   * Log warning
   * @param {string} warning - Warning message
   * @param {Object} details - Warning details
   */
  warn(warning, details) {
    console.warn(JSON.stringify({
      level: 'WARN',
      timestamp: Date.now(),
      warning,
      ...details
    }));
  }
};
```

**Test Cases**:
- ✓ Logs error with correct format
- ✓ Logs critical action with correct format
- ✓ Logs info with correct format
- ✓ Logs warning with correct format
- ✓ Includes timestamp in all logs

## Summary

The frontend API consists of 4 main services:
1. **MerkleService**: Tree construction and proof generation
2. **IPFSService**: File fetching with timeout and verification
3. **ClaimsService**: Prize claiming and refund withdrawal
4. **Logger**: Structured logging for observability

All services include comprehensive error handling, logging, and test coverage requirements. The design emphasizes client-side verification, timeout handling, and user-friendly error messages.

**Next**: Quickstart guide for development setup
