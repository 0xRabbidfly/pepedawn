# Research: User-Facing Behavior Updates (VRF Seed + Merkle + Claims)

**Feature**: 002-merkle  
**Date**: October 8, 2025  
**Status**: Complete

## Overview

This document consolidates research findings for implementing Merkle proof-based claims, IPFS file verification, and enhanced UI features for the PEPEDAWN raffle system.

## 1. Merkle Tree Libraries (Solidity)

### Decision: OpenZeppelin MerkleProof

**Rationale**:
- Battle-tested library with extensive audits
- Gas-efficient verification (single `keccak256` per proof element)
- Already included in project dependencies (OpenZeppelin Contracts)
- Standard implementation used across DeFi protocols
- Simple API: `MerkleProof.verify(proof, root, leaf)`

**Alternatives Considered**:
- **Custom Implementation**: Rejected due to audit overhead and reinventing wheel
- **Murky (Foundry library)**: Good for testing but not production-ready for contracts
- **solidity-merkle-trees**: Less maintained, no audit history

**Implementation Notes**:
- Leaf format: `keccak256(abi.encode(address, uint8 prizeTier, uint8 prizeIndex))` for winners
- Leaf format: `keccak256(abi.encode(address, uint128 weight))` for participants
- Store only roots on-chain (32 bytes each)
- Generate proofs off-chain in frontend

## 2. JavaScript Merkle Tree Libraries

### Decision: merkletreejs

**Rationale**:
- Most popular JS Merkle library (2.5k+ GitHub stars)
- Supports keccak256 hashing (matches Solidity)
- Simple API for tree construction and proof generation
- Works in browser and Node.js
- Active maintenance and documentation

**Alternatives Considered**:
- **@openzeppelin/merkle-tree**: Newer, less battle-tested in production
- **merkle-lib**: Lower-level, requires more boilerplate
- **Custom implementation**: Rejected due to complexity and testing burden

**Implementation Notes**:
```javascript
import { MerkleTree } from 'merkletreejs';
import { keccak256 } from 'ethers';

// Create tree
const leaves = participants.map(p => 
  keccak256(ethers.AbiCoder.defaultAbiCoder().encode(
    ['address', 'uint128'],
    [p.address, p.weight]
  ))
);
const tree = new MerkleTree(leaves, keccak256, { sortPairs: true });

// Generate proof
const leaf = keccak256(ethers.AbiCoder.defaultAbiCoder().encode(
  ['address', 'uint128'],
  [userAddress, userWeight]
));
const proof = tree.getHexProof(leaf);
```

**Performance**:
- Tree construction: O(n log n) for n participants
- Proof generation: O(log n) per proof
- Expected: <500ms for 1000 participants on modern browsers

## 3. IPFS Integration

### Decision: ipfs-http-client with fallback gateways

**Rationale**:
- Official IPFS HTTP client library
- Supports both public gateways and local nodes
- Timeout and retry capabilities
- Works in browser via bundlers (Vite)

**Gateway Strategy**:
1. **Primary**: Pinata gateway (https://gateway.pinata.cloud/ipfs/{CID})
2. **Fallback 1**: Infura gateway (https://infura-ipfs.io/ipfs/{CID})
3. **Fallback 2**: Public gateway (https://ipfs.io/ipfs/{CID})
4. **User-provided**: Allow manual CID entry for any gateway

**Alternatives Considered**:
- **Direct IPFS node**: Rejected due to browser limitations and UX complexity
- **Centralized storage**: Rejected due to trust requirements
- **Arweave**: Rejected due to different permanence model and cost

**Implementation Notes**:
```javascript
async function fetchIPFSFile(cid, timeout = 60000) {
  const gateways = [
    `https://gateway.pinata.cloud/ipfs/${cid}`,
    `https://infura-ipfs.io/ipfs/${cid}`,
    `https://ipfs.io/ipfs/${cid}`
  ];
  
  for (const gateway of gateways) {
    try {
      const controller = new AbortController();
      const timeoutId = setTimeout(() => controller.abort(), timeout);
      
      const response = await fetch(gateway, { signal: controller.signal });
      clearTimeout(timeoutId);
      
      if (response.ok) return await response.json();
    } catch (error) {
      console.warn(`Gateway ${gateway} failed:`, error);
      continue;
    }
  }
  
  throw new Error('All IPFS gateways failed');
}
```

**Timeout Strategy**:
- 60-second total timeout (per clarification)
- 20 seconds per gateway attempt
- Show retry UI after timeout
- Provide copyable CID for manual gateway use

## 4. Mobile Wallet Integration

### Decision: Multi-wallet support via Web3Modal or RainbowKit

**Rationale**:
- **Web3Modal**: Supports MetaMask mobile, WalletConnect, Coinbase Wallet
- **RainbowKit**: Better UX, modern design, built on wagmi/viem
- Both handle mobile deep-linking automatically
- WalletConnect v2 for mobile wallet connections

**Alternatives Considered**:
- **Direct MetaMask integration**: Rejected due to limited wallet support
- **Custom wallet detection**: Rejected due to maintenance burden
- **wagmi alone**: Good but lacks pre-built UI components

**Implementation Notes**:
- Use WalletConnect v2 for mobile connections
- Handle deep-linking for mobile wallet apps
- Test on MetaMask mobile, Trust Wallet, Rainbow Wallet
- Ensure transaction signing works on mobile

**Mobile-Specific Considerations**:
- Touch targets: 44x44px minimum (per clarification)
- Responsive tables: Horizontal scroll or stacked layout
- Address truncation: Show first 6 and last 4 characters
- Copy-to-clipboard for all hashes and addresses
- Loading states optimized for slower mobile connections

## 5. Client-Side Proof Generation Performance

### Decision: Web Workers for large trees

**Rationale**:
- Merkle tree construction can block UI for >100 participants
- Web Workers offload computation to separate thread
- Maintains responsive UI during proof generation

**Implementation Strategy**:
- **Small trees (<100 participants)**: Main thread (fast enough)
- **Large trees (≥100 participants)**: Web Worker
- Cache generated trees in IndexedDB for current round
- Progressive loading: Show UI while tree builds in background

**Alternatives Considered**:
- **Always main thread**: Rejected due to UI blocking on large trees
- **Server-side generation**: Rejected due to trust requirements
- **WASM**: Overkill for this use case, adds complexity

**Implementation Notes**:
```javascript
// merkle-worker.js
self.onmessage = function(e) {
  const { participants, type } = e.data;
  const tree = buildMerkleTree(participants, type);
  self.postMessage({ tree: tree.serialize() });
};

// Main thread
const worker = new Worker('merkle-worker.js');
worker.postMessage({ participants, type: 'winners' });
worker.onmessage = (e) => {
  const tree = MerkleTree.deserialize(e.data.tree);
  // Use tree for proof generation
};
```

## 6. State Management for Round States

### Decision: Reactive state with localStorage persistence

**Rationale**:
- Six round states require clear state management
- localStorage for persistence across page reloads
- Event-driven updates from contract events
- No framework overhead (vanilla JS with reactive patterns)

**State Structure**:
```javascript
const roundState = {
  currentState: 'Open',
  roundId: 12,
  participants: {
    cid: 'Qm...',
    root: '0x...',
    verified: false,
    file: null
  },
  winners: {
    cid: 'Qm...',
    root: '0x...',
    verified: false,
    file: null
  },
  vrfSeed: null,
  userClaims: [], // Array of { prizeIndex, prizeTier, claimed }
  userRefund: '0'
};
```

**Alternatives Considered**:
- **React/Vue**: Rejected to maintain vanilla JS approach
- **Redux/Zustand**: Overkill for this scope
- **No persistence**: Rejected due to poor UX on page reload

## 7. Logging and Observability

### Decision: Structured JSON logging with log levels

**Rationale**:
- Per clarification: Log errors + critical actions
- Structured format enables filtering and analysis
- Client-side logging to console + optional remote service
- Log levels: ERROR, WARN, INFO, DEBUG

**Log Events**:
- **Errors**: IPFS timeout, verification failure, transaction rejection, Merkle proof invalid
- **Critical Actions**: Claim submitted, refund withdrawn, verification completed, wallet connected
- **State Changes**: Round state transitions (optional, can be INFO level)

**Implementation Notes**:
```javascript
const logger = {
  error: (event, details) => {
    console.error(JSON.stringify({
      level: 'ERROR',
      timestamp: Date.now(),
      event,
      ...details
    }));
  },
  
  critical: (action, details) => {
    console.log(JSON.stringify({
      level: 'CRITICAL',
      timestamp: Date.now(),
      action,
      ...details
    }));
  }
};

// Usage
logger.error('ipfs_timeout', { cid, gateway, duration: 60000 });
logger.critical('claim_submitted', { roundId, prizeIndex, txHash });
```

**Optional Remote Logging**:
- Consider Sentry or LogRocket for production
- Privacy-conscious: No PII in logs
- User opt-in for remote logging

## 8. Testing Strategy

### Decision: Multi-layer testing approach

**Contract Tests (Foundry)**:
- Unit tests: Merkle verification, claim logic, refund logic

- Fuzz tests: Random Merkle proofs, invalid inputs
- Invariant tests: Claim uniqueness, refund correctness

**Frontend Tests (Vitest)**:
- Unit tests: Merkle service, IPFS service, logger
- Component tests: UI components in isolation


## 9. Gas Optimization

### Findings: Merkle proof verification costs

**Gas Costs**:
- Merkle proof verification: ~3,000-5,000 gas per proof element
- Typical proof depth for 1000 participants: 10 elements
- Total verification: ~30,000-50,000 gas
- Claim transaction total: ~100,000-150,000 gas (including storage updates)

**Optimization Strategies**:
- Store only roots on-chain (32 bytes each)
- Batch claim function for multiple prizes (future enhancement)
- Efficient leaf encoding (packed encoding)
- Sorted pairs in Merkle tree (reduces proof size)

## 10. Security Considerations

### Merkle Proof Security

**Threats**:
- **Proof replay**: Mitigated by roundId in claim function
- **Proof forgery**: Prevented by cryptographic hash function
- **Double claiming**: Prevented by on-chain claim tracking
- **Root manipulation**: Prevented by immutable on-chain storage

**Best Practices**:
- Validate all proof elements
- Check claim status before verification
- Use reentrancy guards on claim function
- Emit events for all claims

### IPFS Security

**Threats**:
- **File tampering**: Mitigated by Merkle root verification
- **Gateway attacks**: Mitigated by multiple fallback gateways
- **Availability**: Mitigated by timeout and retry logic

**Best Practices**:
- Always verify Merkle root matches on-chain root
- Show clear warnings on verification failure
- Provide manual CID entry for user control
- Cache verified files in browser storage

## Summary

All research tasks completed successfully. Key decisions:
1. **Solidity**: OpenZeppelin MerkleProof
2. **JavaScript**: merkletreejs
3. **IPFS**: ipfs-http-client with fallback gateways
4. **Mobile**: Web3Modal/RainbowKit with WalletConnect v2
5. **Performance**: Web Workers for large trees
6. **State**: Reactive state with localStorage
7. **Logging**: Structured JSON with log levels
8. **Testing**: Multi-layer (Foundry + Vitest)
9. **Gas**: Optimized Merkle verification (~100k-150k per claim)
10. **Security**: Comprehensive threat mitigation

**Next Phase**: Design (data-model.md, contracts, quickstart.md)
