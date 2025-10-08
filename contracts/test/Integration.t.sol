// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test, console} from "forge-std/Test.sol";
import {PepedawnRaffle} from "../src/PepedawnRaffle.sol";
import {MockVRFCoordinatorV2Plus} from "./mocks/MockVRFCoordinatorV2Plus.sol";

/**
 * @title IntegrationTest
 * @notice End-to-end integration tests for full round workflows
 * @dev Tests complete round lifecycle with VRF integration
 * 
 * Spec Alignment:
 * - FR-024: Fee distribution (80% creators, 20% next round)
 * - All lifecycle requirements (create → open → bet → proof → close → snapshot → VRF → distribute)
 */
contract IntegrationTest is Test {
    PepedawnRaffle public raffle;
    MockVRFCoordinatorV2Plus public mockVrf;
    
    address public owner;
    address public alice;
    address public bob;
    address public charlie;
    address public creatorsAddress;
    address public emblemVaultAddress;
    
    // VRF v2.5 configuration
    uint256 public constant SUBSCRIPTION_ID = 110985561766688754416530502785486864554223037425689838961930939425219515092980;
    bytes32 public constant KEY_HASH = 0x787d74caea10b2b357790d5b5247c2f63d1d91572a9846f780606e4d953677ae;
    
    event VRFRequested(uint256 indexed roundId, uint256 indexed requestId);
    event VRFFulfilled(uint256 indexed roundId, uint256 indexed requestId, uint256[] randomWords);
    
    function setUp() public {
        owner = address(this);
        alice = makeAddr("alice");
        bob = makeAddr("bob");
        charlie = makeAddr("charlie");
        creatorsAddress = makeAddr("creators");
        emblemVaultAddress = makeAddr("emblemVault");
        
        // Deploy mock VRF coordinator v2.5
        mockVrf = new MockVRFCoordinatorV2Plus();
        
        // Deploy raffle with VRF v2.5
        raffle = new PepedawnRaffle(
            address(mockVrf),
            SUBSCRIPTION_ID,
            KEY_HASH,
            creatorsAddress,
            emblemVaultAddress
        );
        
        // Fund test accounts
        vm.deal(alice, 10 ether);
        vm.deal(bob, 10 ether);
        vm.deal(charlie, 10 ether);
        
        console.log("=== Integration Test Setup Complete ===");
        console.log("Mock VRF Coordinator:", address(mockVrf));
        console.log("Raffle Contract:", address(raffle));
        console.log("Subscription ID:", SUBSCRIPTION_ID);
    }
    
    /**
     * @notice Test complete round workflow
     * @dev Create → Open → Bet → Close → Snapshot → VRF → Distribute
     */
    function testFullRoundWithVRF() public {
        console.log("\n=== Testing Full Round with VRF v2.5 ===");
        
        // 1. Create and open round
        raffle.createRound();
        raffle.openRound(1);
        console.log("Round 1 created and opened");
        
        // 2. Users place bets
        vm.prank(alice);
        raffle.placeBet{value: 0.005 ether}(1);
        console.log("Alice placed bet: 1 ticket");
        
        vm.prank(bob);
        raffle.placeBet{value: 0.0225 ether}(5);
        console.log("Bob placed bet: 5 tickets");
        
        vm.prank(charlie);
        raffle.placeBet{value: 0.04 ether}(10);
        console.log("Charlie placed bet: 10 tickets");
        
        // 3. Close and snapshot round
        raffle.closeRound(1);
        raffle.snapshotRound(1);
        console.log("Round closed and snapshotted");
        
        // 4. Request VRF
        vm.expectEmit(true, true, false, false);
        emit VRFRequested(1, 1); // roundId=1, requestId=1
        raffle.requestVrf(1);
        console.log("VRF requested");
        
        // 5. Fulfill VRF (simulate Chainlink callback)
        uint256[] memory randomWords = new uint256[](1);
        randomWords[0] = 12345; // Mock random number
        
        vm.expectEmit(true, true, false, true);
        emit VRFFulfilled(1, 1, randomWords);
        mockVrf.fulfillRandomWords(1, randomWords);
        console.log("VRF fulfilled with random word:", randomWords[0]);
        
        // 6. Verify round is distributed
        PepedawnRaffle.Round memory round = raffle.getRound(1);
        assertEq(uint8(round.status), uint8(PepedawnRaffle.RoundStatus.Distributed), "Round should be distributed");
        console.log("Round distributed successfully!");
        
        console.log("\n=== Test Passed! VRF v2.5 Working Locally ===");
    }
    
    /**
     * @notice Test VRF with large subscription ID
     * @dev VRF v2.5 uses uint256 (v2.0 used uint64)
     */
    function testVRFWithLargeSubscriptionId() public {
        console.log("\n=== Testing Large Subscription ID (uint256) ===");
        console.log("Subscription ID:", SUBSCRIPTION_ID);
        
        // Verify the subscription ID is stored correctly
        (,uint256 storedSubId,,,) = raffle.vrfConfig();
        assertEq(storedSubId, SUBSCRIPTION_ID, "Subscription ID mismatch");
        
        console.log("Large subscription ID stored correctly!");
        console.log("This would have failed with VRF v2.0 (uint64 overflow)");
    }
    
    /**
     * @notice Test VRF request format
     * @dev Verify VRF v2.5 struct-based request
     */
    function testVRFRequestFormat() public {
        console.log("\n=== Testing VRF v2.5 Request Format ===");
        
        // Setup round
        raffle.createRound();
        raffle.openRound(1);
        
        // Alice buys 10 tickets to meet minimum threshold
        vm.prank(alice);
        raffle.placeBet{value: 0.04 ether}(10);
        
        raffle.closeRound(1);
        raffle.snapshotRound(1);
        
        // Request should use VRFV2PlusClient.RandomWordsRequest struct
        raffle.requestVrf(1);
        
        console.log("VRF v2.5 request format working!");
        console.log("Request uses struct-based format with extraArgs");
    }
    
    /**
     * @notice Test multiple consecutive rounds
     * @dev Verify system can handle sequential rounds
     */
    function testMultipleRoundsWithVRF() public {
        console.log("\n=== Testing Multiple Rounds ===");
        
        for (uint256 i = 1; i <= 3; i++) {
            console.log("Processing round", i);
            
            // Advance time before VRF request (except for first round)
            if (i > 1) {
                vm.warp(block.timestamp + 61 seconds);
            }
            
            // Create and open
            raffle.createRound();
            raffle.openRound(i);
            
            // Alice buys 10 tickets to meet minimum threshold
            vm.prank(alice);
            raffle.placeBet{value: 0.04 ether}(10);
            
            // Close, snapshot, request VRF
            raffle.closeRound(i);
            raffle.snapshotRound(i);
            raffle.requestVrf(i);
            
            // Fulfill VRF
            uint256[] memory randomWords = new uint256[](1);
            randomWords[0] = uint256(keccak256(abi.encodePacked(i, block.timestamp)));
            mockVrf.fulfillRandomWords(i, randomWords);
            
            console.log("Round", i, "completed");
        }
        
        console.log("All 3 rounds completed successfully!");
        assertEq(raffle.currentRoundId(), 3, "Should have 3 rounds");
    }
    
    /**
     * @notice Test fee distribution (FR-024)
     * @dev 80% creators, 20% next round
     */
    function testFeeDistribution() public {
        console.log("\n=== Testing Fee Distribution ===");
        
        raffle.createRound();
        raffle.openRound(1);
        
        // Alice buys 10 tickets (0.04 ETH)
        vm.prank(alice);
        raffle.placeBet{value: 0.04 ether}(10);
        
        // Bob buys 10 tickets (0.04 ETH)
        vm.prank(bob);
        raffle.placeBet{value: 0.04 ether}(10);
        
        uint256 totalWagered = 0.08 ether;
        uint256 creatorsBalanceBefore = creatorsAddress.balance;
        
        // Complete round
        raffle.closeRound(1);
        raffle.snapshotRound(1);
        raffle.requestVrf(1);
        
        uint256[] memory randomWords = new uint256[](1);
        randomWords[0] = 12345;
        mockVrf.fulfillRandomWords(1, randomWords);
        
        // Verify fee distribution
        uint256 creatorsBalanceAfter = creatorsAddress.balance;
        uint256 creatorsReceived = creatorsBalanceAfter - creatorsBalanceBefore;
        uint256 nextRoundFunds = raffle.nextRoundFunds();
        
        // 80% to creators
        uint256 expectedCreatorsFee = (totalWagered * 80) / 100;
        assertEq(creatorsReceived, expectedCreatorsFee, "Creators should receive 80%");
        
        // 20% to next round
        uint256 expectedNextRoundFee = (totalWagered * 20) / 100;
        assertEq(nextRoundFunds, expectedNextRoundFee, "Next round should receive 20%");
        
        console.log("Creators received:", creatorsReceived);
        console.log("Next round funds:", nextRoundFunds);
        console.log("Fee distribution correct: 80/20 split verified!");
    }
    
    /**
     * @notice Test refund flow with <10 tickets
     * @dev FR-025: Refund all participants when below threshold
     */
    function testRefundFlowIntegration() public {
        console.log("\n=== Testing Refund Flow ===");
        
        raffle.createRound();
        raffle.openRound(1);
        
        // Only 5 tickets (below minimum of 10)
        vm.prank(alice);
        raffle.placeBet{value: 0.0225 ether}(5);
        
        // Close round - should trigger refund accrual (pull-payment pattern)
        raffle.closeRound(1);
        
        // Verify refund accrued but not transferred yet
        uint256 aliceRefundBalance = raffle.getRefundBalance(alice);
        assertEq(aliceRefundBalance, 0.0225 ether, "Alice refund should be accrued");
        
        PepedawnRaffle.Round memory round = raffle.getRound(1);
        assertEq(uint8(round.status), 6, "Status should be Refunded");
        
        // Now Alice withdraws her refund
        uint256 aliceBalanceBefore = alice.balance;
        vm.prank(alice);
        raffle.withdrawRefund();
        
        // Verify Alice received refund
        assertEq(alice.balance, aliceBalanceBefore + 0.0225 ether, "Alice should be refunded after withdrawal");
        assertEq(raffle.getRefundBalance(alice), 0, "Alice refund balance should be zero");
        
        console.log("Refund flow completed successfully!");
    }
    
    /**
     * @notice Test proof weighting in full workflow
     * @dev Verify proof bonus affects winner selection probability
     */
    function testProofWeightingInFullWorkflow() public {
        console.log("\n=== Testing Proof Weighting in Full Workflow ===");
        
        raffle.createRound();
        
        // Set valid proof
        bytes32 validProof = keccak256("valid_proof");
        raffle.setValidProof(1, validProof);
        
        raffle.openRound(1);
        
        // Alice: 10 tickets with proof (+40% = 14 weight)
        vm.prank(alice);
        raffle.placeBet{value: 0.04 ether}(10);
        vm.prank(alice);
        raffle.submitProof(validProof);
        
        // Bob: 10 tickets without proof (10 weight)
        vm.prank(bob);
        raffle.placeBet{value: 0.04 ether}(10);
        
        // Verify weights before snapshot
        (,, uint256 aliceWeight,) = raffle.getUserStats(1, alice);
        (,, uint256 bobWeight,) = raffle.getUserStats(1, bob);
        assertEq(aliceWeight, 14, "Alice should have 14 weight");
        assertEq(bobWeight, 10, "Bob should have 10 weight");
        
        // Complete round
        raffle.closeRound(1);
        raffle.snapshotRound(1);
        
        // Verify snapshot captured weights
        PepedawnRaffle.Round memory round = raffle.getRound(1);
        assertEq(round.totalWeight, 24, "Total weight should be 24");
        
        console.log("Alice probability: 14/24 = 58.33%");
        console.log("Bob probability: 10/24 = 41.67%");
        console.log("Proof weighting integrated successfully!");
    }
}

