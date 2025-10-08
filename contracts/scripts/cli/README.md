# PEPEDAWN Owner CLI Scripts

This directory contains Node.js scripts for managing PEPEDAWN raffle rounds with Merkle-based claims system.

## Setup

### Install Dependencies

```bash
cd contracts/scripts/cli
npm install
```

### Environment Variables

Create a `.env` file in `contracts/` directory:

```env
CONTRACT_ADDRESS=0x...
SEPOLIA_RPC_URL=https://sepolia.drpc.org
PRIVATE_KEY=0x...  # Only needed for transactions
```

## Scripts

### 1. Round Management (Unified CLI)

`manage-round.js` - Main entry point for round lifecycle management

```bash
# Check round status and see next steps
node manage-round.js status <roundId>

# Generate participants file after snapshot
node manage-round.js snapshot <roundId>

# Get VRF request command (with validation)
node manage-round.js request-vrf <roundId>

# Generate winners file after VRF fulfillment
node manage-round.js commit-winners <roundId>
```

**Example Workflow:**
```bash
# 1. Check current state
node manage-round.js status 1

# 2. After closing and snapshotting round
node manage-round.js snapshot 1

# 3. Upload to IPFS (follow instructions)
node upload-to-ipfs.js participants-round-1.json

# 4. Commit root on-chain (copy command from output)

# 5. Request VRF
node manage-round.js request-vrf 1

# 6. Wait for VRF (5-30 minutes)

# 7. Generate winners file
node manage-round.js commit-winners 1

# 8. Upload to IPFS
node upload-to-ipfs.js winners-round-1.json

# 9. Commit winners root on-chain
```

### 2. Generate Participants File

`generate-participants-file.js` - Query contract and create Merkle tree for participants

```bash
node generate-participants-file.js <roundId> [--output <path>]
```

**Output:**
- `participants-round-<roundId>.json` - JSON file with:
  - All participants with addresses, weights, tickets
  - Merkle root for on-chain commitment
  - Merkle leaf format specification

**Example:**
```bash
node generate-participants-file.js 1
# Creates participants-round-1.json with Merkle root
```

### 3. Generate Winners File

`generate-winners-file.js` - Fetch winners from contract and create Merkle tree

```bash
node generate-winners-file.js <roundId> [--output <path>]
```

**Output:**
- `winners-round-<roundId>.json` - JSON file with:
  - All winners with addresses, prize tiers, indices
  - VRF seed for reproducibility
  - Merkle root for claims verification

**Example:**
```bash
node generate-winners-file.js 1
# Creates winners-round-1.json with Merkle root
```

### 4. IPFS Upload Helper

`upload-to-ipfs.js` - Validate files and provide upload instructions

```bash
node upload-to-ipfs.js <file-path>
```

**Supported Services:**
- NFT.Storage (recommended, free, 100GB)
- Web3.Storage (free, 1TB)
- Pinata (free tier: 1GB)
- IPFS Desktop/CLI (local)

**Example:**
```bash
node upload-to-ipfs.js participants-round-1.json
# Displays upload instructions and next steps
```

## Complete Round Workflow

### Prerequisites

1. **VRF Subscription**: Create and fund subscription at vrf.chain.link
2. **NFT Custody**: Transfer 10 Emblem Vault NFTs to contract
3. **Prize Mapping**: Call `setPrizesForRound()` before opening round

### Round Lifecycle

#### Phase 1: Open Round (2 weeks)

```bash
# Create and open round
cast send $CONTRACT_ADDRESS "createRound()" --private-key $PRIVATE_KEY --rpc-url $SEPOLIA_RPC_URL
cast send $CONTRACT_ADDRESS "openRound(uint256)" 1 --private-key $PRIVATE_KEY --rpc-url $SEPOLIA_RPC_URL

# Set valid proof hash (optional)
cast send $CONTRACT_ADDRESS "setValidProof(uint256,bytes32)" 1 $(cast keccak256 "solution") --private-key $PRIVATE_KEY --rpc-url $SEPOLIA_RPC_URL
```

Users place bets and submit proofs during this phase.

#### Phase 2: Close and Snapshot

```bash
# Close round (checks minimum 10 tickets)
cast send $CONTRACT_ADDRESS "closeRound(uint256)" 1 --private-key $PRIVATE_KEY --rpc-url $SEPOLIA_RPC_URL

# If <10 tickets: automatic refund, round ends
# If 10+ tickets: continue with snapshot

# Take snapshot
cast send $CONTRACT_ADDRESS "snapshotRound(uint256)" 1 --private-key $PRIVATE_KEY --rpc-url $SEPOLIA_RPC_URL
```

#### Phase 3: Generate and Commit Participants

```bash
# Generate participants file
node manage-round.js snapshot 1

# Upload to IPFS
node upload-to-ipfs.js participants-round-1.json
# Follow instructions to get CID

# Commit root on-chain
cast send $CONTRACT_ADDRESS "commitParticipantsRoot(uint256,bytes32,string)" 1 <MERKLE_ROOT> "<IPFS_CID>" --private-key $PRIVATE_KEY --rpc-url $SEPOLIA_RPC_URL
```

#### Phase 4: Request VRF

```bash
# Request randomness
cast send $CONTRACT_ADDRESS "requestVrf(uint256)" 1 --private-key $PRIVATE_KEY --rpc-url $SEPOLIA_RPC_URL

# Wait 5-30 minutes for VRF fulfillment
# Monitor on Etherscan for VRFFulfilled event
```

#### Phase 5: Generate and Commit Winners

```bash
# Generate winners file
node manage-round.js commit-winners 1

# Upload to IPFS
node upload-to-ipfs.js winners-round-1.json
# Follow instructions to get CID

# Commit winners root on-chain
cast send $CONTRACT_ADDRESS "commitWinners(uint256,bytes32,string)" 1 <MERKLE_ROOT> "<IPFS_CID>" --private-key $PRIVATE_KEY --rpc-url $SEPOLIA_RPC_URL
```

#### Phase 6: Winners Claim Prizes

Winners use the frontend to:
1. View their wins in the Winners File
2. Generate Merkle proofs client-side
3. Call `claim()` with proof to receive NFTs

## File Formats

### Participants File

```json
{
  "roundId": "1",
  "totalWeight": "123456",
  "totalTickets": "100",
  "participantCount": 50,
  "generatedAt": "2025-10-08T12:00:00.000Z",
  "participants": [
    {
      "address": "0xAbc...",
      "weight": "14",
      "tickets": "10",
      "wagered": "0.04",
      "hasProof": true
    }
  ],
  "merkle": {
    "root": "0x...",
    "leafFormat": "keccak256(abi.encode(address, uint128 weight))"
  }
}
```

### Winners File

```json
{
  "roundId": "1",
  "vrfSeed": "0x...",
  "vrfRequestId": "12345",
  "totalWeight": "123456",
  "winnerCount": 10,
  "generatedAt": "2025-10-08T14:00:00.000Z",
  "derivation": "Winners selected on-chain via VRF and weighted lottery",
  "winners": [
    {
      "address": "0xAbc...",
      "prizeTier": 1,
      "prizeIndex": 0,
      "vrfRequestId": "12345",
      "blockNumber": "67890"
    }
  ],
  "merkle": {
    "root": "0x...",
    "leafFormat": "keccak256(abi.encode(address, uint8 prizeTier, uint8 prizeIndex))"
  }
}
```

## Troubleshooting

### "CONTRACT_ADDRESS not set"

Make sure your `.env` file exists in `contracts/` directory with valid values.

### "Round not in expected status"

Check round status with:
```bash
node manage-round.js status <roundId>
```

Follow the "Next Steps" section in the output.

### "VRF not fulfilled yet"

VRF takes 5-30 minutes depending on network confirmations. Check Etherscan for the VRFFulfilled event.

### "Participants root not committed"

You need to:
1. Generate participants file
2. Upload to IPFS
3. Commit root on-chain

Use `manage-round.js snapshot <roundId>` for guidance.

### IPFS Upload Issues

- Try multiple gateways to verify file accessibility
- Use different pinning services as backup
- Keep local copies of all files
- Test CID retrieval before committing on-chain

## Security Notes

- **Never commit private keys** to version control
- **Verify Merkle roots** match between file and on-chain before committing
- **Test on Sepolia** before mainnet deployment
- **Backup IPFS CIDs** in a secure location
- **Monitor VRF subscription** LINK balance regularly

## Additional Resources

- Contract ABI: `../../PepedawnRaffle-abi.json`
- Deployment addresses: `../../../deploy/artifacts/addresses.json`
- PowerShell CLI: `./interact.ps1` (for basic operations)
- Foundry scripts: `../forge/` (for deployment and automation)

---

**Need Help?**

Check the main guide: [GUIDE.md](./GUIDE.md)

Or run any script with `--help` flag:
```bash
node manage-round.js --help
node generate-participants-file.js --help
```
