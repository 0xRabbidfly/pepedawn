# Remix Contract Integration Guide

## Quick Setup Steps

### 1. Get Your Contract Address from Remix
1. Open your deployed contract in Remix
2. Copy the contract address (starts with `0xD91...`)
3. Open `frontend/src/contract-config.js`
4. Replace `"0x0000000000000000000000000000000000000000"` with your actual contract address

### 2. Test the Integration
1. Open your frontend in a browser
2. Open browser developer console (F12)
3. Connect your MetaMask wallet (make sure you're on Sepolia testnet)
4. Look for these console messages:
   - ✅ "Contract configuration valid: 0xD91..."
   - ✅ "Contract loaded: 0xD91..."

### 3. Create and Test a Round
In Remix, as the contract owner (creators address):
1. Call `createRound()` 
2. Call `openRound(1)`
3. Go back to your frontend and try placing a bet

## Troubleshooting

### Contract Not Loading
- Check console for "Contract configuration valid" message
- Verify contract address is correct (42 characters starting with 0x)
- Ensure you're on Sepolia testnet in MetaMask

### Transaction Failures
- Make sure you have Sepolia ETH for gas
- Verify the round is open (status = 1 in Remix)
- Check you're calling from the correct account

### Network Issues
- Frontend expects Sepolia testnet (Chain ID: 11155111)
- Switch to Sepolia in MetaMask if needed

## Testing Workflow

1. **Create Round** (in Remix, as owner):
   ```
   createRound() → openRound(1)
   ```

2. **Place Bet** (in frontend):
   - Select ticket bundle
   - Click "Place Bet"
   - Confirm in MetaMask

3. **Submit Proof** (in frontend):
   - Enter any proof text
   - Click "Submit Proof"
   - Confirm in MetaMask

4. **Check Stats**:
   - Your stats should update automatically
   - Leaderboard shows your position

## Contract Functions Available

### Owner Functions (call from creators address in Remix):
- `createRound()` - Create new round
- `openRound(roundId)` - Open round for betting
- `closeRound(roundId)` - Close round
- `requestVRF(roundId)` - Request VRF (needs subscription)

### User Functions (available in frontend):
- `placeBet(roundId)` - Place bet with ETH
- `submitProof(roundId, proofHash)` - Submit puzzle proof
- `getRound(roundId)` - Get round info
- `getUserStats(roundId, user)` - Get user stats

## Next Steps

Once basic integration works:
1. Set up Chainlink VRF subscription for full testing
2. Add more sophisticated UI features
3. Deploy to production network
4. Add contract verification on Etherscan
