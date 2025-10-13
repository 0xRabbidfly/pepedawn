// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test, console} from "forge-std/Test.sol";
import {PepedawnRaffle} from "../src/PepedawnRaffle.sol";
import {MockVRFCoordinatorV2Plus} from "./mocks/MockVRFCoordinatorV2Plus.sol";

/**
 * @title VrfGasOptimizationTest
 * @notice Test suite for validating VRF gas optimization results
 * @dev This test validates the optimized gas constants work correctly
 */
contract VrfGasOptimizationTest is Test {
    PepedawnRaffle public raffle;
    MockVRFCoordinatorV2Plus public vrfCoordinator;
    
    uint256 public constant SUBSCRIPTION_ID = 1;
    bytes32 public constant KEY_HASH = keccak256("test");
    
    address public creatorsAddress = address(0x1234);
    address public emblemVaultAddress = address(0x5678);
    
    function setUp() public {
        // Deploy mock VRF coordinator
        vrfCoordinator = new MockVRFCoordinatorV2Plus();
        
        // Deploy raffle contract
        raffle = new PepedawnRaffle(
            address(vrfCoordinator),
            SUBSCRIPTION_ID,
            KEY_HASH,
            creatorsAddress,
            emblemVaultAddress
        );
    }
    
    /**
     * @notice Test that optimized gas constants are correctly set
     * @dev Validates the Phase 1 optimization constants
     */
    function testOptimizedGasConstants() public {
        console.log("\n=== VRF Gas Optimization Constants ===");
        console.log("VRF_MIN_CALLBACK_GAS: %d", raffle.VRF_MIN_CALLBACK_GAS());
        console.log("VRF_SAFETY_BUFFER_PCT: %d", raffle.VRF_SAFETY_BUFFER_PCT());
        console.log("VRF_VOLATILITY_BUFFER_PCT: %d", raffle.VRF_VOLATILITY_BUFFER_PCT());
        console.log("maxGasPrice: %d gwei", raffle.maxGasPrice() / 1e9);
        
        // Validate optimized values
        assertEq(raffle.VRF_MIN_CALLBACK_GAS(), 250_000, "VRF_MIN_CALLBACK_GAS should be 250,000");
        assertEq(raffle.VRF_SAFETY_BUFFER_PCT(), 25, "VRF_SAFETY_BUFFER_PCT should be 25%");
        assertEq(raffle.VRF_VOLATILITY_BUFFER_PCT(), 15, "VRF_VOLATILITY_BUFFER_PCT should be 15%");
        assertEq(raffle.maxGasPrice(), 100 gwei, "maxGasPrice should be 100 gwei");
        
        console.log("All optimization constants are correctly set!");
    }
    
    /**
     * @notice Test gas estimation for different participant counts
     * @dev Shows the dramatic improvement in gas estimation accuracy
     */
    function testGasEstimationAccuracy() public {
        console.log("\n=== Gas Estimation Accuracy Test ===");
        
        // Test with 10 participants
        _setupSimpleRound(10);
        uint32 estimatedGas10 = raffle.estimateVrfCallbackGas(1);
        console.log("10 participants - Estimated gas: %d", estimatedGas10);
        
        // Validate estimates are reasonable (should be much lower than before)
        assertLt(estimatedGas10, 600_000, "10 participants estimate too high");
        
        console.log("Gas estimates are within reasonable bounds!");
    }
    
    /**
     * @notice Test maxGasPrice update functionality
     * @dev Validates the owner can update maxGasPrice within bounds
     */
    function testMaxGasPriceUpdate() public {
        console.log("\n=== Max Gas Price Update Test ===");
        
        uint256 originalPrice = raffle.maxGasPrice();
        console.log("Original maxGasPrice: %d gwei", originalPrice / 1e9);
        
        // Test valid update
        uint256 newPrice = 150 gwei;
        raffle.updateMaxGasPrice(newPrice);
        assertEq(raffle.maxGasPrice(), newPrice, "Max gas price not updated");
        console.log("Updated maxGasPrice to: %d gwei", newPrice / 1e9);
        
        // Test invalid updates
        vm.expectRevert("Max gas price too low (minimum 50 gwei)");
        raffle.updateMaxGasPrice(30 gwei);
        
        vm.expectRevert("Max gas price too high (maximum 500 gwei)");
        raffle.updateMaxGasPrice(600 gwei);
        
        console.log("Max gas price update validation works correctly!");
    }
    
    /**
     * @notice Test participantsRoot requirement enforcement
     * @dev Validates that VRF requests require participantsRoot to be set
     */
    function testParticipantsRootRequirement() public {
        console.log("\n=== Participants Root Requirement Test ===");
        
        // Setup round without participants root
        raffle.createRound();
        raffle.setValidProof(1, keccak256("test"));
        raffle.openRound(1);
        
        // Add some participants
        address alice = address(0x1001);
        vm.deal(alice, 10 ether);
        vm.prank(alice);
        raffle.buyTickets{value: 0.005 ether}(1);
        
        // Add more participants to avoid refund
        for (uint256 i = 2; i <= 10; i++) {
            address participant = address(uint160(0x1000 + i));
            vm.deal(participant, 10 ether);
            vm.prank(participant);
            raffle.buyTickets{value: 0.005 ether}(1);
        }
        
        raffle.closeRound(1);
        raffle.snapshotRound(1);
        
        // Try to request VRF without participants root (should fail)
        vm.expectRevert("Participants root must be set before VRF request");
        raffle.requestVrf(1);
        
        // Set participants root and try again (should succeed)
        raffle.commitParticipantsRoot(1, keccak256("participants"), "test-cid");
        raffle.requestVrf(1);
        
        console.log("Participants root requirement enforced correctly!");
    }
    
    /**
     * @notice Test resetVrf function for stuck round recovery
     * @dev Validates the new resetVrf function works correctly
     */
    function testResetVrfFunction() public {
        console.log("\n=== Reset VRF Function Test ===");
        
        // Setup round and request VRF
        _setupSimpleRound(10);
        raffle.requestVrf(1);
        
        // Verify round is in VRFRequested status
        (PepedawnRaffle.Round memory round,,,,,) = raffle.getRoundState(1);
        assertEq(uint8(round.status), uint8(PepedawnRaffle.RoundStatus.VRFRequested), "Round not in VRFRequested status");
        
        // Fast forward past timeout
        vm.warp(block.timestamp + 2 hours);
        
        // Reset VRF
        raffle.resetVrf(1);
        
        // Verify round is back to Snapshot status
        (round,,,,,) = raffle.getRoundState(1);
        assertEq(uint8(round.status), uint8(PepedawnRaffle.RoundStatus.Snapshot), "Round not reset to Snapshot status");
        
        // Complete the round to avoid state pollution
        raffle.requestVrf(1);
        uint256[] memory randomWords = new uint256[](1);
        randomWords[0] = 12345;
        vrfCoordinator.fulfillRandomWords(2, randomWords);
        raffle.submitWinnersRoot(1, keccak256("winners"), "test-cid");
        
        console.log("Reset VRF function works correctly!");
    }
    
    /**
     * @notice Test endTime enforcement in buyTickets and submitProof
     * @dev Validates clean window closure
     */
    function testEndTimeEnforcement() public {
        console.log("\n=== End Time Enforcement Test ===");
        
        raffle.createRound();
        raffle.setValidProof(1, keccak256("test"));
        raffle.openRound(1);
        
        address alice = address(0x1001);
        vm.deal(alice, 10 ether);
        
        // Fast forward to exactly endTime
        vm.warp(block.timestamp + 2 weeks);
        
        // Should fail because we're at exactly endTime (not < endTime)
        vm.prank(alice);
        vm.expectRevert("Round window closed");
        raffle.buyTickets{value: 0.005 ether}(1);
        
        // Should also fail for proof submission
        vm.prank(alice);
        vm.expectRevert("Round window closed");
        raffle.submitProof(keccak256("test"));
        
        console.log("End time enforcement works correctly!");
    }
    
    /**
     * @notice Helper function to setup a simple round for testing
     * @param participantCount Number of participants to create
     */
    function _setupSimpleRound(uint256 participantCount) internal {
        // Create round
        raffle.createRound();
        raffle.setValidProof(1, keccak256("test"));
        raffle.openRound(1);
        
        // Add participants
        for (uint256 i = 0; i < participantCount; i++) {
            address participant = address(uint160(0x1000 + i));
            vm.deal(participant, 10 ether);
            
            vm.startPrank(participant);
            raffle.buyTickets{value: 0.005 ether}(1);
            
            // Submit proof for some participants (50% have proofs)
            if (i % 2 == 0) {
                raffle.submitProof(keccak256("test"));
            }
            vm.stopPrank();
        }
        
        // Close and snapshot round
        raffle.closeRound(1);
        raffle.snapshotRound(1);
        
        // Set participants root (required for VRF request)
        raffle.commitParticipantsRoot(1, keccak256("participants"), "test-cid");
    }
}
