# Data Model (Phase 1)

## Entities

### Round
- id (uint256)
- startTime (uint64)
- endTime (uint64)
- status (enum)
- feeSplit: creators 80%, nextRound 20%
- vrf: subId, keyHash, callbackGasLimit, confirmations
- prizeTiers: Fake/Kek/Pepe counts; vault asset ids (preloaded)

### Wager
- wallet (address)
- roundId (uint256)
- amount (uint256)
- tickets (uint256)
- effectiveWeight (uint256)
- createdAt (uint64)

### PuzzleProof
- wallet (address)
- roundId (uint256)
- proofRef (bytes/uri)
- verified (bool)
- weightMultiplier (uint16) // 1400 = 1.4x

### LeaderboardEntry (derived)
- wallet (address)
- fakePackOddsPct (uint16)
- rank (uint32)

### WinnerAssignment
- roundId (uint256)
- wallet (address)
- prizeTier (uint8)
- vrfRequestId (uint256)
- blockNumber (uint256)
