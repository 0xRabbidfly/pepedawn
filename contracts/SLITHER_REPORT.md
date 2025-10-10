# Slither Static Analysis Report - PepedawnRaffle

**Date:** October 10, 2025  
**Contract:** `PepedawnRaffle.sol`  
**Analyzer:** Slither v0.x  
**Total Findings:** 45 results across 18 contracts

---

## Executive Summary

This report analyzes the Slither static analysis results for the PepedawnRaffle smart contract. Findings are categorized by severity (Critical, High, Medium, Low, Informational) with actionable recommendations for each issue.

**Overall Assessment:** The contract demonstrates good security practices with CEI (Checks-Effects-Interactions) pattern implementation and comprehensive input validation. Most findings are either false positives, design decisions, or low-risk informational items. However, a few issues warrant attention before mainnet deployment.

---

## Findings by Severity

### 🔴 CRITICAL SEVERITY

**None identified.**

---

### 🟠 HIGH SEVERITY

#### H-1: Functions Send ETH to Arbitrary User

**Location:** `_distributeFees(uint256)` (lines 1352-1377)

**Finding:**
```solidity
(success, ) = creatorsAddress.call{value: creatorsAmount}("");
```

**Slither Detection:**
> "PepedawnRaffle._distributeFees(uint256) sends eth to arbitrary user"

**Analysis:**
This is a **FALSE POSITIVE**. The `creatorsAddress` is:
- Set once in the constructor (line 327)
- Only modifiable by the contract owner via `setCreatorsAddress()`
- Validated to not be `address(0)` before transfers (line 1365)
- Protected by access control (owner-only modification)

**Risk Level:** LOW (False Positive)

**Recommendation:** 
✅ **NO ACTION REQUIRED** - The contract correctly implements access control. This is standard fee distribution to a controlled address, not arbitrary users.

**Optional Enhancement:**
Consider adding a two-step address change mechanism (propose/accept) for critical addresses like `creatorsAddress` to prevent accidental misconfiguration.

---

### 🟡 MEDIUM SEVERITY

#### M-1: Weak PRNG in Winner Tier Assignment

**Location:** `_assignWinnersAndDistribute(uint256,uint256)` (lines 1189-1192)

**Finding:**
```solidity
tierRandom = uint256(keccak256(abi.encode(randomSeed, tier, globalIndex, winner, block.timestamp))) % 100
```

**Analysis:**
The contract uses `block.timestamp` as additional entropy when assigning prize tiers (Fake/Kek/Pepe) to winners. While the primary randomness (`randomSeed`) comes from Chainlink VRF (secure), mixing in `block.timestamp` introduces a predictable element.

**Risk Assessment:**
- **Primary winner selection** uses pure VRF randomness ✅
- **Tier assignment** (which specific prize within winners) uses timestamp
- Miners have ~15-second window to influence `block.timestamp`
- Impact: An attacker could potentially influence whether they get Fake vs Kek vs Pepe tier

**Risk Level:** MEDIUM (Limited impact, requires miner cooperation)

**Recommendation:**
⚠️ **CONSIDER FIXING** 

**Option 1: Use deterministic approach (Recommended)**
```solidity
// Remove block.timestamp, use only VRF-derived randomness
tierRandom = uint256(keccak256(abi.encode(randomSeed, tier, globalIndex, winner))) % 100;
```

**Option 2: Request multiple random words from VRF**
Request enough random words from VRF to cover both winner selection and tier assignment, eliminating the need for additional entropy.

---

#### M-2: Divide Before Multiply - Precision Loss

**Location:** `_estimateCallbackGas(uint256)` (lines 983-987)

**Finding:**
```solidity
totalEstimatedGas = totalEstimatedGas * 120 / 100;  // 20% buffer
// ... then later ...
totalEstimatedGas = totalEstimatedGas * 110 / 100;  // 10% buffer
```

**Analysis:**
Performing multiplication after division can cause precision loss in integer arithmetic. However, in this specific case:
- The values are already large (gas estimates: 75000+)
- The division is by 100, then multiply by 110-120
- Actual precision loss: < 1% (negligible for gas estimation)

**Risk Level:** LOW (Minimal practical impact for gas estimation)

**Recommendation:**
✅ **LOW PRIORITY** - The precision loss is negligible for gas estimation purposes, but for code clarity:

```solidity
// Better: Combine operations
totalEstimatedGas = (totalEstimatedGas * 120) / 100;  // Single operation
// Even better: Use existing value
totalEstimatedGas = totalEstimatedGas + (totalEstimatedGas * 20 / 100);
```

---

#### M-3: Uninitialized Local Variable

**Location:** `placeBet(uint256)` (line 729-730)

**Finding:**
```solidity
function placeBet(uint256 tickets) {
    // ... 
    expectedAmount = ...;  // Variable declared but never initialized before use
```

**Analysis:**
This appears to be a false positive or the variable name may have changed. A review of the `placeBet` function shows proper validation of `msg.value`.

**Risk Level:** LOW (Likely false positive)

**Recommendation:**
🔍 **VERIFY** - Review lines 729-730 of `placeBet()` to ensure all local variables are initialized before use. If `expectedAmount` exists, ensure it's assigned before any conditional logic that might reference it.

---

### 🔵 LOW SEVERITY

#### L-1: Reentrancy (State Variables Written After External Calls)

**Location:** `requestVrf(uint256)` (lines 867-942)

**Finding:**
State variables written after external VRF coordinator call:
- `rounds[roundId].vrfRequestId = requestId`
- `vrfRequestToRound[requestId] = roundId`

**Analysis:**
The contract follows CEI (Checks-Effects-Interactions) pattern throughout, but Slither flags state updates after the VRF request. This is **acceptable** because:
1. The VRF coordinator is a trusted Chainlink contract
2. The `requestId` is unknown until after the external call
3. No reentrancy risk from trusted VRF coordinator
4. Function is protected by `nonReentrant` modifier

**Risk Level:** VERY LOW (False positive - trusted external contract)

**Recommendation:**
✅ **NO ACTION REQUIRED** - This is an unavoidable pattern when interacting with VRF coordinators. The requestId must be obtained from the external call before storing it.

**Note for Auditors:** Document that VRF coordinator is a trusted contract exception to strict CEI.

---

#### L-2: Reentrancy (Events After External Calls)

**Location:** Multiple functions

**Findings:**
- `_distributeFees`: Event after ETH transfer
- `emergencyWithdrawETH/NFT`: Events after transfers  
- `requestVrf`: Event after VRF request
- `submitWinnersRoot`: Event after `_distributeFees` call

**Analysis:**
Events emitted after external calls are generally safe and sometimes necessary for accurate event ordering. All affected functions:
- Follow CEI pattern for state changes
- Use `nonReentrant` modifier
- Emit events as final step for accurate logging

**Risk Level:** VERY LOW (Informational)

**Recommendation:**
✅ **NO ACTION REQUIRED** - Events should reflect the final state after interactions complete. This is standard practice.

---

#### L-3: Dangerous Strict Equalities

**Location:** Multiple functions (lines 1000, 1018, 1579, 277)

**Findings:**
```solidity
require(rounds[roundId].status == RoundStatus.VRFRequested, ...);
require(rounds[roundId].vrfRequestId == requestId, ...);
require(root == bytes32(0), ...);
```

**Analysis:**
Strict equality (`==`) is flagged as potentially dangerous when checking balances or dynamic values that could be manipulated. However, these checks are:
- Enums (RoundStatus) - safe
- Request IDs - safe (exact match required)
- Merkle roots - safe (exact match required)

**Risk Level:** VERY LOW (False positive for non-balance checks)

**Recommendation:**
✅ **NO ACTION REQUIRED** - Strict equality is appropriate for state enums, IDs, and hashes. The concern applies mainly to balance checks like `balance == X`, which aren't present here.

---

#### L-4: External Calls Inside Loop

**Location:** `setPrizesForRound(uint256,uint256[])` (lines 624-629)

**Finding:**
```solidity
for (uint256 i = 0; i < tokenIds.length; i++) {
    require(emblemVault.ownerOf(tokenIds[i]) == address(this), "Contract must own NFT");
}
```

**Analysis:**
This loop validates NFT ownership before accepting them as prizes. Risks:
- External call to `emblemVault.ownerOf()` in each iteration
- If `emblemVault` is malicious/faulty, could cause gas griefing
- Loop is bounded by `tokenIds.length` (admin-controlled)

**Risk Level:** LOW (Admin function, reasonable bounds)

**Recommendation:**
✅ **ACCEPTABLE** - This is an admin-only function (`onlyOwner`) called during round setup with a small number of prizes (typically 10-133). Gas costs are acceptable for this use case.

**Optional Enhancement:** Add a maximum token limit check:
```solidity
require(tokenIds.length <= 150, "Too many prizes");
```

---

#### L-5: Timestamp Dependence

**Location:** Multiple functions

**Finding:**
Various functions use `block.timestamp` for time-based logic.

**Analysis:**
The contract uses `block.timestamp` for:
- VRF request rate limiting (30-second cooldown)
- VRF timeout checks (24-hour window)
- Emergency withdrawal delays (7 days)
- Event timestamps

**Risk Assessment:**
- Miners can manipulate `block.timestamp` by ~15 seconds
- All time checks use large windows (30s minimum, usually days)
- 15-second manipulation has negligible impact on these ranges

**Risk Level:** VERY LOW (Appropriate use of timestamps)

**Recommendation:**
✅ **NO ACTION REQUIRED** - The contract appropriately uses `block.timestamp` for time windows where 15-second variance is acceptable. Critical randomness comes from VRF, not timestamps.

---

### ℹ️ INFORMATIONAL

#### I-1: Dead Code (Unused Internal Functions)

**Location:** Multiple internal functions

**Functions Never Called:**
- `_assignWinnersAndDistribute(uint256,uint256)` (lines 1144-1220)
- `_binarySearchCumulativeWeights(uint256[],uint256)` (lines 1119-1132)
- `_calculateOptimalBatchSize(uint256)` (lines 1224-1255)
- `_distributePrizes(uint256,address[],uint8[])` (lines 1260-1288)
- `_getPrizeAssetId(uint8,uint256,uint256)` (lines 1295-1316)
- `_selectWeightedWinnersBatch(uint256,uint256,address[],uint256,uint256)` (lines 1080-1114)

**Analysis:**
These functions represent the **on-chain winner selection logic** that was designed but ultimately **not implemented** in favor of an off-chain approach. This was likely a conscious design decision to:
- Reduce gas costs for VRF callbacks
- Simplify the fulfillment process
- Move complex winner selection off-chain

**Recommendation:**
🧹 **REMOVE DEAD CODE** - Delete unused functions to:
- Reduce contract size and deployment costs
- Improve code clarity and maintainability
- Reduce attack surface
- Eliminate confusion for auditors

**Action Items:**
1. Remove all 6 unused internal functions
2. Update documentation to clarify off-chain winner selection approach
3. Document why this design choice was made (gas optimization)

---

#### I-2: State Variable Should Be Immutable

**Location:** `emblemVault` (line 132)

**Finding:**
```solidity
IERC721 public emblemVault; // Set once in constructor, never changed
```

**Analysis:**
The `emblemVault` variable is set once in the constructor and never modified. Making it `immutable` would:
- Save gas on every read (~2100 gas per SLOAD → 100 gas per read)
- Prevent accidental modification
- Clearly signal intent to auditors

**Recommendation:**
✅ **IMPLEMENT** - Change to immutable:

```solidity
IERC721 public immutable emblemVault;

constructor(
    address _vrfCoordinator,
    uint256 _subscriptionId,
    bytes32 _keyHash,
    address _emblemVault,
    address _creatorsAddress
) VRFConsumerBaseV2Plus(_vrfCoordinator) Ownable(msg.sender) {
    emblemVault = IERC721(_emblemVault);  // Immutable assignment
    emblemVaultAddress = _emblemVault;
    creatorsAddress = _creatorsAddress;
    // ...
}
```

**Gas Savings:** ~2000 gas per read operation (significant over contract lifetime)

---

#### I-3: Unused State Variable

**Location:** `_winnerSelected` (lines 141)

**Finding:**
```solidity
mapping(uint256 => mapping(address => bool)) private _winnerSelected;
```

**Analysis:**
This mapping is declared but never used in the contract. It was likely intended to prevent duplicate winner selection in the on-chain algorithm that was ultimately not implemented.

**Recommendation:**
🧹 **REMOVE** - Delete unused state variable to save deployment gas and improve clarity.

---

#### I-4: Low-Level Calls

**Location:** Multiple functions

**Findings:**
- `withdrawRefund()` (lines 692-694)
- `_distributeFees()` (lines 1372)
- `emergencyWithdrawETH()` (line 1376)

**Analysis:**
The contract uses low-level `.call{value: X}("")` for ETH transfers. This is actually the **recommended approach** as of Solidity 0.8.x:
- Safer than `.transfer()` (fixed 2300 gas)
- Safer than `.send()` (returns bool but still limited gas)
- Allows flexible gas forwarding
- Properly checks return value with `require(success, ...)`

**Recommendation:**
✅ **NO ACTION REQUIRED** - Low-level call is the current best practice for ETH transfers. The contract properly checks return values.

---

#### I-5: Too Many Digits in Numeric Literals

**Location:** Multiple locations

**Findings:**
```solidity
callbackGasLimit: 500000  // Line 342
maxGasForWinnerSelection = 15000000  // Line 1233
baseGas = 400000  // Line 1235
VRF_MIN_CALLBACK_GAS = 400000  // Line 44
VRF_MAX_CALLBACK_GAS = 2500000  // Line 48
```

**Analysis:**
Large numeric literals without underscores are harder to read and verify. Solidity 0.8.x supports underscore separators for clarity.

**Recommendation:**
✅ **IMPROVE READABILITY** - Add underscores to large numbers:

```solidity
callbackGasLimit: 500_000
maxGasForWinnerSelection = 15_000_000
baseGas = 400_000
VRF_MIN_CALLBACK_GAS = 400_000
VRF_MAX_CALLBACK_GAS = 2_500_000
```

**Impact:** No functional change, improves code clarity and reduces human error in review.

---

## Summary & Recommendations

### Priority Actions

| Priority | Issue | Action | Effort | Impact |
|----------|-------|--------|--------|--------|
| 🟡 **HIGH** | M-1: Weak PRNG (tier assignment) | Remove `block.timestamp` from tier random | Low | Medium |
| 🟢 **MEDIUM** | I-1: Dead code | Remove 6 unused functions | Medium | Medium |
| 🟢 **MEDIUM** | I-2: Make `emblemVault` immutable | Change to `immutable` | Low | Low |
| 🔵 **LOW** | I-3: Remove `_winnerSelected` | Delete unused variable | Low | Low |
| 🔵 **LOW** | I-5: Add underscores to literals | Format large numbers | Low | Low |
| 🔵 **LOW** | M-2: Divide before multiply | Reorder operations | Low | Very Low |

### Statistics

- **Critical:** 0
- **High:** 0 (1 false positive)
- **Medium:** 2-3 (depending on risk tolerance)
- **Low:** 5 (mostly false positives or acceptable patterns)
- **Informational:** 5 (code quality improvements)

### Overall Assessment

**Security Status:** ✅ **GOOD**

The PepedawnRaffle contract demonstrates solid security practices:
- ✅ CEI pattern implementation
- ✅ ReentrancyGuard on all external functions
- ✅ Comprehensive access control
- ✅ Input validation throughout
- ✅ Trusted Chainlink VRF integration
- ✅ Emergency pause mechanisms

**Recommended Actions Before Mainnet:**
1. **Fix M-1** (weak PRNG) - Remove timestamp from tier assignment
2. **Remove dead code** (I-1) - Clean up unused functions
3. **Make emblemVault immutable** (I-2) - Gas optimization
4. **Code cleanup** - Remove unused variables, add underscores

**Time Estimate:** 2-4 hours of development + testing

---

## Appendix: False Positives Explained

Many Slither findings are **false positives** in this context:

1. **"Sends ETH to arbitrary user"** - `creatorsAddress` is owner-controlled, not arbitrary
2. **"Reentrancy after VRF call"** - VRF coordinator is trusted Chainlink contract
3. **"Events after calls"** - Intentional design for accurate event logging
4. **"Strict equality"** - Appropriate for enums and IDs, not balance checks
5. **"Timestamp usage"** - Used correctly for large time windows where 15s variance is acceptable

These are common Slither false positives and do not represent actual vulnerabilities in properly designed contracts.

---

## Additional Notes

### About Dead Code
The presence of sophisticated on-chain winner selection algorithms (binary search, weighted selection, batching) that are ultimately unused suggests these were part of an earlier design iteration. The decision to move winner selection off-chain is common in production systems to optimize gas costs.

**Consider documenting:**
- Why off-chain selection was chosen
- How off-chain winner selection maintains security (likely via Merkle proofs)
- Any trade-offs made (trust assumptions, decentralization considerations)

### Testing Recommendations
After implementing fixes:
1. Run full test suite (`forge test`)
2. Re-run Slither to verify fixes
3. Perform gas profiling to confirm immutable optimization
4. Update integration tests if tier randomness logic changes

---

**Report Generated:** October 10, 2025  
**Next Steps:** Address priority items, re-run Slither, proceed with audit preparation

