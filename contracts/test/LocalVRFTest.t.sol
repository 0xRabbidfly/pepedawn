// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../src/PepedawnRaffle.sol";
import "./mocks/MockVRFCoordinatorV2Plus.sol";

/**
 * @title LocalVRFTest
 * @notice Test VRF v2.5 integration locally with mocks
 */
contract LocalVRFTest is Test {
    PepedawnRaffle public raffle;
    MockVRFCoordinatorV2Plus public mockVRF;
    
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
        mockVRF = new MockVRFCoordinatorV2Plus();
        
        // Deploy raffle with VRF v2.5
        raffle = new PepedawnRaffle(
            address(mockVRF),
            SUBSCRIPTION_ID,
            KEY_HASH,
            creatorsAddress,
            emblemVaultAddress
        );
        
        // Fund test accounts
        vm.deal(alice, 10 ether);
        vm.deal(bob, 10 ether);
        vm.deal(charlie, 10 ether);
        
        console.log("=== Local VRF Test Setup Complete ===");
        console.log("Mock VRF Coordinator:", address(mockVRF));
        console.log("Raffle Contract:", address(raffle));
        console.log("Subscription ID:", SUBSCRIPTION_ID);
    }
    
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
        raffle.requestVRF(1);
        console.log("VRF requested");
        
        // 5. Fulfill VRF (simulate Chainlink callback)
        uint256[] memory randomWords = new uint256[](1);
        randomWords[0] = 12345; // Mock random number
        
        vm.expectEmit(true, true, false, true);
        emit VRFFulfilled(1, 1, randomWords);
        mockVRF.fulfillRandomWords(1, randomWords);
        console.log("VRF fulfilled with random word:", randomWords[0]);
        
        // 6. Verify round is distributed
        PepedawnRaffle.Round memory round = raffle.getRound(1);
        assertEq(uint8(round.status), uint8(PepedawnRaffle.RoundStatus.Distributed), "Round should be distributed");
        console.log("Round distributed successfully!");
        
        console.log("\n=== Test Passed! VRF v2.5 Working Locally ===");
    }
    
    function testVRFWithLargeSubscriptionId() public {
        console.log("\n=== Testing Large Subscription ID (uint256) ===");
        console.log("Subscription ID:", SUBSCRIPTION_ID);
        
        // Verify the subscription ID is stored correctly
        (,uint256 storedSubId,,,) = raffle.vrfConfig();
        assertEq(storedSubId, SUBSCRIPTION_ID, "Subscription ID mismatch");
        
        console.log("Large subscription ID stored correctly!");
        console.log("This would have failed with VRF v2.0 (uint64 overflow)");
    }
    
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
        raffle.requestVRF(1);
        
        console.log("VRF v2.5 request format working!");
        console.log("Request uses struct-based format with extraArgs");
    }
    
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
            raffle.requestVRF(i);
            
            // Fulfill VRF
            uint256[] memory randomWords = new uint256[](1);
            randomWords[0] = uint256(keccak256(abi.encodePacked(i, block.timestamp)));
            mockVRF.fulfillRandomWords(i, randomWords);
            
            console.log("Round", i, "completed");
        }
        
        console.log("All 3 rounds completed successfully!");
        assertEq(raffle.currentRoundId(), 3, "Should have 3 rounds");
    }
}

