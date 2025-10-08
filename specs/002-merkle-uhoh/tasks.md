# Implementation Tasks: PEPEDAWN Merkle-Based Claims System

**Branch**: `002-merkle-uhoh`  
**Date**: October 8, 2025  
**Spec**: [spec.md](./spec.md) | [Plan](./plan.md)

## Strategy: Minimize Breaking Changes

This implementation extends the existing `001-build-a-simple` contract with Merkle-based claims while preserving:
- ✅ Betting mechanics (placeBet, submitProof)
- ✅ VRF integration (requestVrf, fulfillRandomWords)
- ✅ Round lifecycle (createRound, openRound, closeRound)
- ✅ Security (denylist, pause, refunds)

**New Additions**:
- Merkle root storage (participantsRoot, winnersRoot)
- IPFS CID storage (strings per round)
- Pull-payment claims (claim function with Merkle proofs)
- Pull-payment refunds (withdrawRefund)
- Six-state lifecycle (vs previous states)
- ERC721Holder for NFT custody

**Key Deviations from Candidate Contract** (`pepedawn_raffle_merged.txt`):
1. ❌ **Candidate uses simple Merkle library** - We'll use OpenZeppelin MerkleProof (battle-tested)
2. ⚠️ **Candidate has minimal owner pattern** - We'll use Ownable2Step (security best practice from original)
3. ⚠️ **Candidate stores commitments struct** - We'll use separate mappings (gas optimization)
4. ✅ **Candidate uses pull-payments** - Correct, matches spec
5. ⚠️ **Candidate has claimedBitmap** - We'll use mapping (simpler, less gas-optimized but clearer)
6. ⚠️ **Candidate has seed-only VRF** - We'll keep original winner selection logic (preserve working code)

---

## Task Breakdown

### Phase 0: Setup & Analysis [COMPLETED]

- [x] Review spec, plan, and data-model
- [x] Analyze candidate contract
- [x] Identify breaking changes
- [x] Create task list

---

### Phase 1: Contract Refactoring (Core Changes)

#### T001: Update Round Struct and State Enum [P]
**File**: `contracts/src/PepedawnRaffle.sol`  
**Priority**: HIGH  
**Complexity**: Medium  
**Estimated Time**: 2 hours

**Description**: Update data structures to support Merkle-based system.

**Changes**:
```solidity
// ADD to Round struct:
bytes32 participantsRoot;
bytes32 winnersRoot;

// ADD mappings:
mapping(uint256 => string) public participantsCIDs;
mapping(uint256 => string) public winnersCIDs;
mapping(uint256 => mapping(uint8 => address)) public claims;
mapping(uint256 => mapping(address => uint8)) public claimCounts;
mapping(uint256 => mapping(uint8 => uint256)) public prizeNFTs;

// MODIFY RoundStatus enum:
enum RoundStatus {
    Created,
    Open,
    Closed,
    Snapshot,       // RENAME from existing
    VRFRequested,
    Distributed     // KEEP for backward compatibility
    // Note: Candidate uses different names, we preserve existing for minimal breakage
}
```

**Acceptance**:
- [ ] Round struct compiles with new fields
- [ ] New mappings declared
- [ ] Existing tests compile (may fail, that's OK)

---

#### T002: Add ERC721Holder and Import OpenZeppelin MerkleProof [P]
**File**: `contracts/src/PepedawnRaffle.sol`  
**Priority**: HIGH  
**Complexity**: Low  
**Estimated Time**: 1 hour

**Description**: Add contract inheritance for NFT custody and Merkle verification.

**Changes**:
```solidity
import {ERC721Holder} from "@openzeppelin/contracts/token/ERC721/utils/ERC721Holder.sol";
import {MerkleProof} from "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";
import {IERC721} from "@openzeppelin/contracts/token/ERC721/IERC721.sol";

contract PepedawnRaffle is 
    VRFConsumerBaseV2Plus, 
    ReentrancyGuard, 
    Pausable,
    ERC721Holder  // ADD THIS
{
    // Add emblem vault reference
    IERC721 public emblemVault;
}
```

**Acceptance**:
- [ ] Contract compiles with ERC721Holder
- [ ] Can receive ERC721 tokens via safeTransferFrom
- [ ] MerkleProof library available

---

#### T003: Add snapshotRound and commitParticipants Functions
**File**: `contracts/src/PepedawnRaffle.sol`  
**Priority**: HIGH  
**Complexity**: Medium  
**Estimated Time**: 2 hours

**Description**: Implement snapshot workflow.

**Changes**:
```solidity
// MODIFY existing snapshotRound to just transition state
function snapshotRound(uint256 roundId) external onlyOwner {
    Round storage r = rounds[roundId];
    require(r.status == RoundStatus.Closed, "bad status");
    r.status = RoundStatus.Snapshot;
    emit RoundSnapshot(roundId, r.totalTickets, r.totalWeight);
}

// ADD new function
function commitParticipants(
    uint256 roundId, 
    bytes32 participantsRoot, 
    string calldata participantsCid
) external onlyOwner {
    Round storage r = rounds[roundId];
    require(r.status == RoundStatus.Snapshot, "bad status");
    require(participantsRoot != bytes32(0), "zero root");
    
    rounds[roundId].participantsRoot = participantsRoot;
    participantsCIDs[roundId] = participantsCid;
    
    emit ParticipantsRootCommitted(roundId, participantsRoot, participantsCid);
}

// ADD events
event RoundSnapshot(uint256 indexed roundId, uint256 totalTickets, uint256 totalWeight);
event ParticipantsRootCommitted(uint256 indexed roundId, bytes32 root, string cid);
```

**Acceptance**:
- [ ] snapshotRound transitions Open → Snapshot
- [ ] commitParticipants stores root and CID
- [ ] Events emit correctly

---

#### T004: Modify VRF Callback to Store Seed Only
**File**: `contracts/src/PepedawnRaffle.sol`  
**Priority**: HIGH  
**Complexity**: High  
**Estimated Time**: 4 hours

**Description**: **DEVIATION FROM CANDIDATE**: We'll keep existing winner selection but add seed storage.

**Changes**:
```solidity
// MODIFY fulfillRandomWords to store seed
function fulfillRandomWords(uint256 requestId, uint256[] calldata randomWords) internal override {
    uint256 roundId = vrfRequestToRound[requestId];
    Round storage r = rounds[roundId];
    require(r.status == RoundStatus.VRFRequested, "bad status");
    
    // Store seed for reproducibility
    rounds[roundId].vrfSeed = bytes32(randomWords[0]);  // ADD THIS
    
    // KEEP existing winner selection logic (don't break it)
    emit VRFFulfilled(roundId, requestId, randomWords);
    _assignWinnersAndDistribute(roundId, randomWords[0]);
    
    r.status = RoundStatus.Distributed;
}

// ADD to Round struct
bytes32 vrfSeed;
```

**Rationale**: The existing winner selection works. We add seed storage for future reproducibility without breaking current logic.

**Acceptance**:
- [ ] VRF callback stores seed
- [ ] Existing winner selection still works
- [ ] Tests pass for VRF flow

---

#### T005: Add commitWinners Function
**File**: `contracts/src/PepedawnRaffle.sol`  
**Priority**: HIGH  
**Complexity**: Medium  
**Estimated Time**: 2 hours

**Description**: Add function to commit winners Merkle root after VRF.

**Changes**:
```solidity
function commitWinners(
    uint256 roundId,
    bytes32 winnersRoot,
    string calldata winnersCid
) external onlyOwner {
    Round storage r = rounds[roundId];
    require(r.status == RoundStatus.Distributed, "bad status"); // After VRF
    require(winnersRoot != bytes32(0), "zero root");
    
    rounds[roundId].winnersRoot = winnersRoot;
    winnersCIDs[roundId] = winnersCid;
    
    emit WinnersCommitted(roundId, winnersRoot, winnersCid);
}

event WinnersCommitted(uint256 indexed roundId, bytes32 root, string cid);
```

**Acceptance**:
- [ ] commitWinners stores root and CID
- [ ] Can only be called after VRF fulfillment
- [ ] Event emits correctly

---

#### T006: Implement claim Function with Merkle Verification
**File**: `contracts/src/PepedawnRaffle.sol`  
**Priority**: HIGH  
**Complexity**: High  
**Estimated Time**: 4 hours

**Description**: Implement pull-payment claims with Merkle proofs.

**Changes**:
```solidity
function claim(
    uint256 roundId, 
    uint8 prizeIndex, 
    uint8 prizeTier, 
    bytes32[] calldata proof
) external nonReentrant {
    require(prizeIndex < 10, "invalid index");
    Round storage r = rounds[roundId];
    require(
        r.status == RoundStatus.Distributed || r.status == RoundStatus.Closed,
        "bad status"
    );
    require(claims[roundId][prizeIndex] == address(0), "already claimed");
    
    // Verify Merkle proof
    bytes32 leaf = keccak256(abi.encode(msg.sender, prizeTier, prizeIndex));
    require(
        MerkleProof.verify(proof, rounds[roundId].winnersRoot, leaf),
        "invalid proof"
    );
    
    // Check claim limit
    uint256 userTickets = userTicketsInRound[roundId][msg.sender];
    require(claimCounts[roundId][msg.sender] < userTickets, "claim limit");
    
    // Update state
    claims[roundId][prizeIndex] = msg.sender;
    claimCounts[roundId][msg.sender]++;
    
    // Transfer NFT
    uint256 tokenId = prizeNFTs[roundId][prizeIndex];
    emblemVault.safeTransferFrom(address(this), msg.sender, tokenId);
    
    emit PrizeClaimed(roundId, msg.sender, prizeIndex, prizeTier, tokenId);
}

event PrizeClaimed(
    uint256 indexed roundId, 
    address indexed winner, 
    uint8 prizeIndex, 
    uint8 prizeTier, 
    uint256 tokenId
);
```

**Acceptance**:
- [ ] Claim verifies Merkle proof correctly
- [ ] Cannot claim twice
- [ ] NFT transfers to winner
- [ ] Emits event

---

#### T007: Convert Refunds to Pull-Payment Pattern
**File**: `contracts/src/PepedawnRaffle.sol`  
**Priority**: HIGH  
**Complexity**: Medium  
**Estimated Time**: 3 hours

**Description**: Refactor refunds from push to pull pattern.

**Changes**:
```solidity
// ADD mapping
mapping(address => uint256) public refunds;

// MODIFY _refundParticipants (called from closeRound)
function _refundParticipants(uint256 roundId) internal {
    Round storage r = rounds[roundId];
    address[] memory participants = roundParticipants[roundId];
    uint256 totalRefunded = 0;
    
    for (uint256 i = 0; i < participants.length; i++) {
        address participant = participants[i];
        uint256 refundAmount = userWageredInRound[roundId][participant];
        
        if (refundAmount > 0) {
            userWageredInRound[roundId][participant] = 0;
            userTicketsInRound[roundId][participant] = 0;
            userWeightInRound[roundId][participant] = 0;
            
            refunds[participant] += refundAmount;  // ACCRUE instead of transfer
            totalRefunded += refundAmount;
            
            emit ParticipantRefunded(roundId, participant, refundAmount);
        }
    }
    
    r.status = RoundStatus.Refunded;
    emit RoundRefunded(roundId, participants.length, totalRefunded);
}

// ADD withdraw function
function withdrawRefund() external nonReentrant {
    uint256 amt = refunds[msg.sender];
    require(amt > 0, "no refund");
    
    refunds[msg.sender] = 0;  // Zero before transfer
    
    (bool ok, ) = msg.sender.call{value: amt}("");
    require(ok, "transfer failed");
    
    emit RefundWithdrawn(msg.sender, amt);
}

event RefundWithdrawn(address indexed user, uint256 amount);
```

**Acceptance**:
- [ ] Refunds accrue in mapping
- [ ] withdrawRefund transfers ETH
- [ ] Reentrancy protection works
- [ ] Cannot withdraw zero balance

---

#### T008: Add setPrizesForRound Function
**File**: `contracts/src/PepedawnRaffle.sol`  
**Priority**: MEDIUM  
**Complexity**: Low  
**Estimated Time**: 1 hour

**Description**: Allow owner to configure prize NFTs for each round.

**Changes**:
```solidity
function setPrizesForRound(
    uint256 roundId,
    uint256[] calldata tokenIds
) external onlyOwner {
    require(tokenIds.length == 10, "need 10 prizes");
    Round storage r = rounds[roundId];
    require(r.status == RoundStatus.Created, "round started");
    
    for (uint8 i = 0; i < 10; i++) {
        require(
            emblemVault.ownerOf(tokenIds[i]) == address(this),
            "contract must own NFT"
        );
        prizeNFTs[roundId][i] = tokenIds[i];
    }
    
    emit PrizesSet(roundId, tokenIds);
}

event PrizesSet(uint256 indexed roundId, uint256[] tokenIds);
```

**Acceptance**:
- [ ] Can set 10 prizes per round
- [ ] Validates contract owns NFTs
- [ ] Cannot set prizes after round opens

---

#### T009: Update Constructor for Emblem Vault
**File**: `contracts/src/PepedawnRaffle.sol`  
**Priority**: HIGH  
**Complexity**: Low  
**Estimated Time**: 1 hour

**Description**: Add emblemVault parameter to constructor.

**Changes**:
```solidity
constructor(
    address _vrfCoordinator,
    uint256 _subscriptionId,
    bytes32 _keyHash,
    address _creatorsAddress,
    address _emblemVaultAddress  // ADD THIS
) 
    VRFConsumerBaseV2Plus(_vrfCoordinator)
    validAddress(_vrfCoordinator)
    validAddress(_creatorsAddress)
    validAddress(_emblemVaultAddress)  // ADD THIS
{
    // ... existing code ...
    emblemVault = IERC721(_emblemVaultAddress);  // ADD THIS
}
```

**Acceptance**:
- [ ] Constructor accepts emblem vault address
- [ ] Validates address is not zero
- [ ] Contract compiles

---

### Phase 2: Test Consolidation

#### T010: Create MerkleProofs.t.sol [P]
**File**: `contracts/test/MerkleProofs.t.sol`  
**Priority**: HIGH  
**Complexity**: Medium  
**Estimated Time**: 3 hours

**Description**: Test Merkle proof verification for participants and winners.

**Tests**:
```solidity
- testCommitParticipantsRoot()
- testCommitParticipantsRootInvalidState()
- testCommitWinnersRoot()
- testCommitWinnersRootInvalidState()
- testMerkleProofVerification()
- testInvalidMerkleProof()
- testZeroRootRejected()
```

**Acceptance**:
- [ ] All tests pass
- [ ] Valid proofs verify correctly
- [ ] Invalid proofs fail
- [ ] State transitions validated

---

#### T011: Create Claims.t.sol [P]
**File**: `contracts/test/Claims.t.sol`  
**Priority**: HIGH  
**Complexity**: High  
**Estimated Time**: 4 hours

**Description**: Test prize claiming with Merkle proofs.

**Tests**:
```solidity
- testClaimWithValidProof()
- testClaimWithInvalidProof()
- testCannotClaimTwice()
- testCannotExceedTicketCount()
- testClaimTransfersNFT()
- testClaimEmitsEvent()
- testClaimInWrongState()
- testMultipleClaimsSameWinner()
```

**Acceptance**:
- [ ] All tests pass
- [ ] NFT transfers work
- [ ] Duplicate claims blocked
- [ ] Claim limits enforced

---

#### T012: Create Refunds.t.sol [P]
**File**: `contracts/test/Refunds.t.sol`  
**Priority**: HIGH  
**Complexity**: Medium  
**Estimated Time**: 3 hours

**Description**: Test pull-payment refund system.

**Tests**:
```solidity
- testRefundAccrual()
- testWithdrawRefund()
- testCannotWithdrawZero()
- testReentrancyProtection()
- testMultipleRefundsAccumulate()
- testRefundAfterBelowMinimum()
```

**Acceptance**:
- [ ] All tests pass
- [ ] Refunds accrue correctly
- [ ] Withdrawals work
- [ ] Reentrancy blocked

---

#### T013: Update RoundLifecycle.t.sol
**File**: `contracts/test/RoundLifecycle.t.sol`  
**Priority**: HIGH  
**Complexity**: Medium  
**Estimated Time**: 3 hours

**Description**: Update existing tests for new state transitions.

**Changes**:
- Add snapshot → commitParticipants → requestVRF flow
- Add VRF → commitWinners flow
- Update state assertions
- Add seed storage verification

**Acceptance**:
- [ ] All tests pass
- [ ] New states tested
- [ ] Seed storage verified

---

#### T014: Update BettingAndProofs.t.sol
**File**: `contracts/test/BettingAndProofs.t.sol`  
**Priority**: MEDIUM  
**Complexity**: Low  
**Estimated Time**: 2 hours

**Description**: Minimal updates to existing betting tests.

**Changes**:
- Update round status expectations
- Add assertions for new fields
- No functional changes needed (betting logic unchanged)

**Acceptance**:
- [ ] All existing tests still pass
- [ ] New field assertions added

---

#### T015: Update Integration.t.sol
**File**: `contracts/test/Integration.t.sol`  
**Priority**: HIGH  
**Complexity**: High  
**Estimated Time**: 5 hours

**Description**: Create full workflow test with claims.

**Tests**:
```solidity
- testFullRoundWithClaims()
  1. Create round
  2. Users bet
  3. Submit proofs
  4. Snapshot round
  5. Commit participants root
  6. Request VRF
  7. VRF fulfills
  8. Commit winners root
  9. Winners claim prizes
  10. Close round
  11. Non-winners withdraw refunds (if any)
```

**Acceptance**:
- [ ] Full workflow test passes
- [ ] All components integrate
- [ ] Claims work end-to-end
- [ ] Refunds work end-to-end

---

#### T016: Delete Obsolete Test Files
**Files**: Various  
**Priority**: LOW  
**Complexity**: Low  
**Estimated Time**: 30 minutes

**Description**: Remove unused test files.

**Files to Review**:
- Check if `DeployedContractTest.t.sol` still needed (probably yes, update address)
- Remove any UI/frontend tests (none exist currently)
- Check mock files - keep MockVRFCoordinatorV2Plus, remove MockVRFCoordinator if unused

**Acceptance**:
- [ ] Only necessary test files remain
- [ ] All tests compile
- [ ] No broken imports

---

### Phase 3: Owner Scripts (Off-Chain Tools)

#### T017: Create generate-participants-file.js [P]
**File**: `scripts/cli/generate-participants-file.js`  
**Priority**: HIGH  
**Complexity**: Medium  
**Estimated Time**: 3 hours

**Description**: Script to query contract and generate Participants File.

**Features**:
- Query all participants for round
- Calculate weights
- Build Merkle tree
- Output JSON file
- Display root and instructions

**Acceptance**:
- [ ] Generates valid JSON
- [ ] Merkle root matches client calculation
- [ ] File format matches data-model.md

---

#### T018: Create generate-winners-file.js [P]
**File**: `scripts/cli/generate-winners-file.js`  
**Priority**: HIGH  
**Complexity**: High  
**Estimated Time**: 4 hours

**Description**: Script to generate Winners File from VRF seed.

**Features**:
- Fetch VRF seed from contract
- Fetch Participants File
- Run deterministic winner selection
- Build Merkle tree
- Output JSON file

**Acceptance**:
- [ ] Winner selection is deterministic
- [ ] Merkle root matches client calculation
- [ ] File format matches data-model.md

---

#### T019: Create upload-to-ipfs.js [P]
**File**: `scripts/cli/upload-to-ipfs.js`  
**Priority**: MEDIUM  
**Complexity**: Medium  
**Estimated Time**: 2 hours

**Description**: Script to upload JSON files to IPFS.

**Features**:
- Support multiple pinning services (NFT.Storage, Pinata)
- API key configuration
- Return CID
- Verify upload

**Acceptance**:
- [ ] Uploads to IPFS successfully
- [ ] Returns CID
- [ ] Handles errors gracefully

---

#### T020: Create manage-round.js
**File**: `scripts/cli/manage-round.js`  
**Priority**: MEDIUM  
**Complexity**: Medium  
**Estimated Time**: 3 hours

**Description**: Unified CLI for round management.

**Commands**:
- `snapshot <roundId>` - Generate participants file, upload, commit root
- `request-vrf <roundId>` - Request randomness
- `commit-winners <roundId>` - Generate winners file, upload, commit root
- `close <roundId>` - Close round
- `status <roundId>` - Display round state

**Acceptance**:
- [ ] All commands work
- [ ] Clear output and errors
- [ ] Guides user through workflow

---

### Phase 4: Documentation

#### T021: Update README with Merkle Claims Flow
**File**: `contracts/README.md` or repo root `README.md`  
**Priority**: LOW  
**Complexity**: Low  
**Estimated Time**: 1 hour

**Description**: Document new claiming process.

**Sections**:
- Merkle-based claims overview
- Pull-payment benefits
- Owner workflow
- User claiming process
- IPFS file formats

**Acceptance**:
- [ ] Documentation clear
- [ ] Examples provided
- [ ] Links to scripts

---

## Execution Strategy

### Parallel Execution Groups

**Group 1: Core Contract Changes (Sequential)**
Execute T001 → T002 → T003 in sequence (same file).

**Group 2: New Functions (Can be parallel after Group 1)**
- T004, T005, T006, T007, T008, T009 can be done in parallel by different developers (different parts of same file, but independent)

**Group 3: Test Creation (Fully parallel after Group 2)**
- T010, T011, T012 can run in parallel
- T013, T014, T015 can run in parallel
- T016 cleanup after tests pass

**Group 4: Scripts (Fully parallel)**
- T017, T018, T019, T020 can all run in parallel

**Group 5: Documentation**
- T021 at the end

### Dependency Graph

```
T001 (structs) 
  ↓
T002 (imports)
  ↓
T003 (snapshot) → T004 (VRF) → T005 (commitWinners)
  ↓              ↓              ↓
T006 (claim)     T007 (refunds)  T008 (prizes)  T009 (constructor)
  ↓              ↓              ↓              ↓
T010, T011, T012, T013, T014, T015 (tests)
  ↓
T016 (cleanup)

T017, T018, T019, T020 (scripts - parallel with tests)
  ↓
T021 (docs)
```

### Estimated Total Time

- **Phase 1 (Contract)**: 21 hours
- **Phase 2 (Tests)**: 17 hours
- **Phase 3 (Scripts)**: 12 hours
- **Phase 4 (Docs)**: 1 hour
- **Total**: ~51 hours (2-3 sprints for a team)

---

## Risk Mitigation

### Breaking Changes

**Minimal Impact**:
- State transitions slightly different (add Snapshot state)
- New functions added (backward compatible)
- Existing functions mostly unchanged

**Testing Strategy**:
1. Run all existing tests first
2. Update tests for new states
3. Add new tests for new features
4. Full integration test at end

### Rollback Plan

If claims system has issues:
1. Contract can still operate in "legacy mode"
2. Owner can skip commitWinners and manually distribute
3. VRF and betting unchanged

---

## Success Criteria

- [ ] All contract functions compile
- [ ] All tests pass (old and new)
- [ ] Full round workflow works end-to-end
- [ ] Claims work with valid Merkle proofs
- [ ] Refunds work via pull-payment
- [ ] Owner scripts generate valid files
- [ ] IPFS integration works
- [ ] Gas costs within estimates
- [ ] No security vulnerabilities

---

## Notes for Implementation

**Critical Decisions**:
1. ✅ **Use OpenZeppelin MerkleProof** instead of custom library (security)
2. ✅ **Keep existing winner selection** instead of seed-only (preserve working code)
3. ✅ **Use Ownable2Step** instead of simple owner (security best practice)
4. ✅ **Use separate mappings** instead of Commitments struct (clarity)
5. ✅ **Keep existing round status names** where possible (minimize breakage)

**Next Steps After Tasks**:
1. Deploy to Sepolia testnet
2. Test full workflow with real VRF
3. Upload test IPFS files
4. Run security audit
5. Deploy to mainnet

---

**Status**: TASK BREAKDOWN COMPLETE  
**Ready for**: Implementation Phase  
**Estimated Completion**: 2-3 weeks for full team
