// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test, console} from "forge-std/Test.sol";
import {PepedawnRaffle} from "../src/PepedawnRaffle.sol";
import {MockVRFCoordinatorV2Plus} from "./mocks/MockVRFCoordinatorV2Plus.sol";

/**
 * @title VrfTest
 * @notice Consolidated test suite for VRF functionality
 * @dev Tests VRF configuration, gas limits, and business logic
 */
contract VrfTest is Test {
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
     * @notice Test VRF gas configuration constants
     */
    function testVrfGasConstants() public {
        console.log("\n=== VRF Gas Configuration ===");
        console.log("VRF_MIN_CALLBACK_GAS: %d", raffle.VRF_MIN_CALLBACK_GAS());
        console.log("VRF_MAX_CALLBACK_GAS: %d", raffle.VRF_MAX_CALLBACK_GAS());
        console.log("maxGasPrice: %d gwei", raffle.maxGasPrice() / 1e9);
        
        // Validate configuration values
        assertEq(raffle.VRF_MIN_CALLBACK_GAS(), 75_000, "VRF_MIN_CALLBACK_GAS should be 75,000");
        assertEq(raffle.VRF_MAX_CALLBACK_GAS(), 500_000, "VRF_MAX_CALLBACK_GAS should be 500,000");
        assertEq(raffle.maxGasPrice(), 100 gwei, "maxGasPrice should be 100 gwei");
        
        console.log("VRF gas configuration is correct!");
    }
    
    /**
     * @notice Test maxGasPrice update functionality
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
     * @notice Test maxGasPrice enforcement
     */
    function testMaxGasPriceEnforcement() public {
        console.log("\n=== Max Gas Price Enforcement Test ===");
        
        _setupSimpleRound(10);
        
        // Test with gas price below limit (should succeed)
        vm.txGasPrice(50 gwei);
        uint256 roundId = raffle.currentRoundId();
        raffle.requestVrf(roundId);
        
        // Test maxGasPrice is set correctly
        console.log("maxGasPrice is set to: %d gwei", raffle.maxGasPrice() / 1e9);
        assertEq(raffle.maxGasPrice(), 100 gwei, "maxGasPrice should be 100 gwei");
        
        console.log("Max gas price enforcement test completed!");
    }
    
    /**
     * @notice Test participantsRoot requirement enforcement
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
     * @notice Test actual VRF callback gas measurement
     */
    function testVrfCallbackGasMeasurement() public {
        console.log("\n=== VRF Callback Gas Measurement ===");
        
        // Test with 25 participants
        uint256 participantCount = 25;
        console.log("Testing with %d participants", participantCount);
        
        // Create and setup round
        _setupRoundWithParticipants(participantCount);
        
        // Measure gas for VRF request
        uint256 gasStart = gasleft();
        uint256 roundId = raffle.currentRoundId();
        raffle.requestVrf(roundId);
        uint256 gasUsed = gasStart - gasleft();
        
        console.log("VRF request gas used: %d", gasUsed);
        
        // Simulate VRF fulfillment and measure callback gas
        uint256[] memory randomWords = new uint256[](1);
        randomWords[0] = uint256(keccak256(abi.encodePacked(block.timestamp, participantCount)));
        
        gasStart = gasleft();
        vrfCoordinator.fulfillRandomWords(roundId, randomWords);
        gasUsed = gasStart - gasleft();
        
        console.log("Actual callback gas used: %d", gasUsed);
        console.log("Estimated callback gas: 160000");
        console.log("Estimation accuracy: %d%%", (160_000 * 100) / uint32(gasUsed));
        
        // Complete the round
        raffle.submitWinnersRoot(roundId, keccak256("winners"), "winners-cid");
    }
    
    /**
     * @notice Helper function to setup a simple round for testing
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
    
    /**
     * @notice Helper function to setup a round with specified number of participants
     */
    function _setupRoundWithParticipants(uint256 participantCount) internal {
        // Create round
        raffle.createRound();
        uint256 roundId = raffle.currentRoundId();
        raffle.setValidProof(roundId, bytes32(uint256(0x1234)));
        raffle.openRound(roundId);
        
        // Add participants
        for (uint256 i = 0; i < participantCount; i++) {
            address participant = address(uint160(0x1000 + i));
            vm.deal(participant, 10 ether);
            
            vm.startPrank(participant);
            raffle.buyTickets{value: 0.005 ether}(1);
            
            // Submit proof for some participants (50% have proofs)
            if (i % 2 == 0) {
                raffle.submitProof(bytes32(uint256(0x1234)));
            }
            vm.stopPrank();
        }
        
        // Close and snapshot round
        raffle.closeRound(roundId);
        raffle.snapshotRound(roundId);
        
        // Set participants root (required for VRF request)
        raffle.commitParticipantsRoot(roundId, keccak256("participants"), "test-cid");
    }
}
