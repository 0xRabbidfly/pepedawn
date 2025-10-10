🧪 PEPEDAWN Refactor Test Plan
Pre-Test Setup
[ ] Open browser DevTools Console (F12)
[ ] Open Network tab, filter by "WebSocket" or look for JSON-RPC calls
[ ] Note: You should see dramatically fewer contract calls than before
1️⃣ Main Page - Initial Load (CRITICAL)
Test: Fresh page load with wallet disconnected
[ ] Navigate to main page
[ ] Verify mock data displays (countdown, ticket count)
[ ] Check console - should be NO contract calls
[ ] Status should show "Open" highlighted
Test: Connect wallet
[ ] Click "Connect Wallet"
[ ] Check Network tab - Should see ~3-4 calls total:
currentRoundId
getRoundState (the big one!)
Maybe winnersCIDs if on claims page
[ ] Verify all displays update:
[ ] Round status shows correct status
[ ] Countdown shows correct time
[ ] Ticket count correct
[ ] User stats populate (tickets, weight, odds, cap)
[ ] Dispenser progress correct
Expected: ~3 calls instead of ~15
2️⃣ Main Page - User Actions
Test: Place a bet
[ ] Select ticket bundle (1, 5, or 10)
[ ] Click "Place Bet"
[ ] Approve transaction
[ ] Wait for confirmation
[ ] Verify updates:
[ ] User tickets increase
[ ] User weight increases
[ ] Total tickets increases
[ ] Dispenser progress updates
[ ] Button states correct (proof button should enable)
Test: Submit proof
[ ] Paste proof in input
[ ] Click "Submit Proof"
[ ] Approve transaction
[ ] Verify:
[ ] Proof status updates
[ ] Weight increases (+40%)
[ ] Odds recalculate
[ ] Proof button disables
3️⃣ Claims Section (HIGH RISK AREA)
Test: View claimable prizes (if you won in Round 1)
[ ] Scroll to "Claim Your Packs" section
[ ] Check Network tab - Should see only:
getRoundState (already called on page load)
winnersCIDs (1 call)
[ ] Verify each prize card shows:
[ ] Correct prize tier (Fake/Kek/Pepe Pack)
[ ] Correct prize number (#1, #2, etc.)
[ ] NFT ID is populated (NOT "TBD") ⚠️ THIS IS THE KEY FIX
[ ] Claim status correct (claimed or unclaimed)
Test: Claim a prize (if available)
[ ] Click "Claim Prize" button
[ ] Approve transaction
[ ] Verify prize marked as claimed
Expected: 2 calls total instead of ~20
4️⃣ Leaderboard Page - Round Selector (RISK AREA)
Test: Load leaderboard page
[ ] Navigate to leaderboard page
[ ] Default should show current round
[ ] Verify leaderboard displays correctly
[ ] Check participant list populated
Test: Change round via selector ⚠️ CRITICAL
[ ] Open round selector dropdown
[ ] Select "Round 1"
[ ] Verify:
[ ] Title updates to "Leaderboard Round: 1"
[ ] Leaderboard data refreshes
[ ] Shows correct participants for Round 1
[ ] No errors in console
[ ] Select future round (e.g., Round 3)
[ ] Should show "Future Round" message
[ ] Select "Round 2 (Current)"
[ ] Should load current round data
Expected: Works exactly as before
5️⃣ Winners Section - Round Selector (RISK AREA)
Test: Winners display with selector
[ ] Scroll to Winners section on leaderboard page
[ ] Verify current round winners show (if distributed)
[ ] Open winners round selector
[ ] Select "Round 1"
[ ] Verify:
[ ] Title updates to "Winners - Round 1"
[ ] Podium displays with tiers (🥇🥈🥉)
[ ] Winner addresses shown
[ ] No errors in console
[ ] Try different rounds
[ ] Verify each switches correctly
Expected: Works exactly as before
6️⃣ Periodic Updates (60 second intervals)
Test: Wait for periodic update
[ ] Stay on main page with wallet connected
[ ] Wait 60 seconds
[ ] Check Network tab at 60s mark:
Should see only 2-3 calls:
currentRoundId
getRoundState (batched)
NOT 15+ individual calls
[ ] Verify all UI updates correctly
[ ] No console errors
Expected: ~3 calls every 60s instead of ~15
7️⃣ Wallet Reconnection
Test: Switch accounts
[ ] Open MetaMask
[ ] Switch to different account
[ ] Verify:
[ ] Status shows "Switching wallet..."
[ ] Network tab shows ~3-4 calls
[ ] All stats update to new account
[ ] No errors
Test: Disconnect and reconnect
[ ] Disconnect wallet
[ ] Wait 2 seconds
[ ] Reconnect wallet
[ ] Verify everything loads correctly
8️⃣ Network Switching
Test: Change networks
[ ] Switch from Sepolia to another network (e.g., Mainnet)
[ ] Should see network warning
[ ] Switch back to Sepolia
[ ] Verify:
[ ] Contract reloads
[ ] ~3-4 calls in Network tab
[ ] All data correct
[ ] No errors
9️⃣ Button States
Test: Button enable/disable logic
[ ] Fresh load - betting buttons should be disabled (if no wallet)
[ ] Connect wallet - buttons should enable (if round open)
[ ] Place bet - proof button should enable
[ ] Submit proof - proof button should disable
[ ] Check all states match round status
🔟 Edge Cases
Test: No active round
[ ] If Round 0 (before first round)
[ ] Should show "Being Created..." message
[ ] No errors
[ ] Mock data displays
Test: Refund scenario
[ ] If you have refund balance
[ ] Refund section should display
[ ] Amount correct
[ ] Withdraw works
Test: Closed round
[ ] Wait for round to close (or test on closed round)
[ ] Betting should be disabled
[ ] Proof submission disabled
[ ] Status shows "Closed"
✅ Success Criteria
Performance:
[ ] Network tab shows ~80-90% fewer calls
[ ] Page loads feel faster
[ ] No UI lag or delays
Functionality:
[ ] All features work exactly as before
[ ] No console errors
[ ] No missing data
[ ] NFT IDs display correctly ⚠️ KEY FIX
Critical Checks:
[ ] Round selector works (leaderboard & winners)
[ ] Claims section shows NFT IDs
[ ] Periodic updates efficient
[ ] Wallet switching smooth
🚨 Red Flags to Watch For
If you see any of these, we have a bug:
❌ "TBD" shows for NFT IDs in claims section
❌ Round selector doesn't change data
❌ Leaderboard stuck on one round
❌ Console errors about "round" or "undefined"
❌ Missing participant data
❌ 10+ contract calls on page load
❌ Button states incorrect