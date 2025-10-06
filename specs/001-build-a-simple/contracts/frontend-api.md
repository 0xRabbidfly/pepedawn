# Frontend API Interface: PEPEDAWN Web Application

**Feature**: 001-build-a-simple  
**Date**: 2025-10-06  
**Framework**: Vite MPA + ethers.js v6

## Wallet Integration

### Connection Management

#### `connectWallet() -> Promise<{address: string, provider: object}>`
**Purpose**: Connect user's Ethereum wallet (MetaMask, WalletConnect, etc.)  
**Returns**: Wallet address and provider instance  
**Error Handling**: 
- No wallet installed → Show installation instructions
- User rejection → Show retry option
- Network mismatch → Prompt network switch

#### `disconnectWallet() -> void`
**Purpose**: Clear wallet connection state  
**Effects**: Reset UI to disconnected state

#### `getWalletAddress() -> string | null`
**Purpose**: Get currently connected wallet address  
**Returns**: Address string or null if not connected

### Network Management

#### `checkNetwork() -> Promise<boolean>`
**Purpose**: Verify connected to correct Ethereum network  
**Returns**: True if on correct network (mainnet/testnet)  
**Effects**: Show network switch prompt if incorrect

#### `switchNetwork(chainId: number) -> Promise<void>`
**Purpose**: Request wallet to switch to specified network  
**Parameters**: Target chain ID  
**Error Handling**: User rejection, unsupported network

## Contract Interaction

### Read Operations

#### `getCurrentRound() -> Promise<RoundData>`
**Purpose**: Get current active round information  
**Returns**: 
```typescript
interface RoundData {
  id: number;
  startTime: number;
  endTime: number;
  status: string;
  totalTickets: number;
  totalWeight: number;
  totalWagered: string; // ETH amount as string
}
```

#### `getUserStats(roundId: number, address: string) -> Promise<UserStats>`
**Purpose**: Get user's participation data for a round  
**Returns**:
```typescript
interface UserStats {
  wagered: string; // ETH amount
  tickets: number;
  weight: number;
  hasProof: boolean;
}
```

#### `getLeaderboard(roundId: number) -> Promise<LeaderboardEntry[]>`
**Purpose**: Get current leaderboard with Fake Pack odds  
**Returns**:
```typescript
interface LeaderboardEntry {
  address: string;
  fakePackOdds: number; // Percentage (0-100)
  rank: number;
  effectiveWeight: number;
}
```

#### `getRoundWinners(roundId: number) -> Promise<WinnerData[]>`
**Purpose**: Get winners for completed round  
**Returns**:
```typescript
interface WinnerData {
  address: string;
  prizeTier: number; // 1=Fake, 2=Kek, 3=Pepe
  prizeDescription: string;
}
```

### Write Operations

#### `placeBet(tickets: number) -> Promise<TransactionResult>`
**Purpose**: Place a wager in current round  
**Parameters**: Number of tickets (1, 5, or 10)  
**Preconditions**: 
- Wallet connected
- Current round is open
- Sufficient ETH balance
- Won't exceed 1.0 ETH cap
**Returns**:
```typescript
interface TransactionResult {
  hash: string;
  success: boolean;
  error?: string;
}
```

#### `submitProof(proofHash: string) -> Promise<TransactionResult>`
**Purpose**: Submit puzzle proof for weight bonus  
**Parameters**: Proof hash as hex string  
**Preconditions**:
- Wallet connected
- Has existing wager in current round
- No previous proof submitted
- Valid proof hash

## UI State Management

### Application State

#### `AppState`
```typescript
interface AppState {
  wallet: {
    connected: boolean;
    address: string | null;
    balance: string; // ETH balance
  };
  round: {
    current: RoundData | null;
    userStats: UserStats | null;
    leaderboard: LeaderboardEntry[];
  };
  ui: {
    loading: boolean;
    error: string | null;
    page: 'title' | 'main' | 'rules';
  };
}
```

### State Updates

#### `updateWalletState(connected: boolean, address?: string) -> void`
**Purpose**: Update wallet connection state  
**Effects**: Refresh UI, load user data if connected

#### `updateRoundData(roundData: RoundData) -> void`
**Purpose**: Update current round information  
**Effects**: Refresh leaderboard, user stats

#### `updateLeaderboard(entries: LeaderboardEntry[]) -> void`
**Purpose**: Update leaderboard display  
**Effects**: Re-render leaderboard component

## Event Handling

### Contract Events

#### `subscribeToRoundEvents() -> void`
**Purpose**: Listen for round lifecycle events  
**Events Monitored**:
- `RoundCreated`: New round started
- `RoundOpened`: Betting opened
- `RoundClosed`: Betting closed
- `BetPlaced`: New wager (update leaderboard)
- `ProofSubmitted`: Proof submitted (update weights)

#### `subscribeToUserEvents(address: string) -> void`
**Purpose**: Listen for user-specific events  
**Events Monitored**:
- User's bet confirmations
- User's proof submissions
- Prize wins

### UI Events

#### `onWalletConnect() -> void`
**Purpose**: Handle successful wallet connection  
**Effects**: Load user data, subscribe to events

#### `onWalletDisconnect() -> void`
**Purpose**: Handle wallet disconnection  
**Effects**: Clear user data, unsubscribe from events

#### `onNetworkChange(chainId: number) -> void`
**Purpose**: Handle network switch  
**Effects**: Validate network, reload contract data

## Page-Specific APIs

### Title Page (`index.html`)

#### `initTitlePage() -> void`
**Purpose**: Initialize title page with animation and audio  
**Effects**:
- Start CSS animations
- Setup audio controls (user-triggered)
- Setup enter button handler

#### `playAudio() -> void`
**Purpose**: Start title music (user-triggered)  
**Preconditions**: User interaction occurred  
**Error Handling**: Graceful degradation if audio unavailable

### Main Page (`main.html`)

#### `initMainPage() -> void`
**Purpose**: Initialize betting interface and leaderboard  
**Effects**:
- Connect wallet if previously connected
- Load current round data
- Setup real-time updates

#### `refreshLeaderboard() -> void`
**Purpose**: Update leaderboard display  
**Effects**: Fetch latest data, re-render table

#### `validateBetAmount(tickets: number) -> {valid: boolean, error?: string}`
**Purpose**: Validate bet before submission  
**Returns**: Validation result with error message if invalid

### Rules Page (`rules.html`)

#### `initRulesPage() -> void`
**Purpose**: Initialize rules and about content  
**Effects**: Load static content, setup navigation

## Error Handling

### Error Types
```typescript
interface AppError {
  type: 'wallet' | 'network' | 'contract' | 'validation';
  message: string;
  code?: string;
  recoverable: boolean;
}
```

### Error Display

#### `showError(error: AppError) -> void`
**Purpose**: Display error message to user  
**Effects**: Show error modal/toast with appropriate actions

#### `clearError() -> void`
**Purpose**: Clear current error state  
**Effects**: Hide error display

## Performance Optimization

### Caching Strategy

#### `cacheRoundData(roundId: number, data: RoundData) -> void`
**Purpose**: Cache round data to reduce contract calls  
**TTL**: 30 seconds for active rounds, permanent for completed

#### `cacheLeaderboard(roundId: number, entries: LeaderboardEntry[]) -> void`
**Purpose**: Cache leaderboard data  
**TTL**: 10 seconds (frequent updates expected)

### Batch Operations

#### `batchContractCalls(calls: ContractCall[]) -> Promise<any[]>`
**Purpose**: Batch multiple read operations  
**Benefits**: Reduce RPC calls, improve performance

## Security Considerations

### Input Validation
- Sanitize all user inputs
- Validate proof hashes format
- Check bet amounts against limits

### Transaction Safety
- Display transaction details before signing
- Implement transaction timeout handling
- Show clear success/failure states

### Privacy
- No sensitive data logging
- Minimal data collection
- Clear privacy disclosures
