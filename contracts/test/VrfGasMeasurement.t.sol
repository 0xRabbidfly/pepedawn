// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test, console} from "forge-std/Test.sol";
import {PepedawnRaffle} from "../src/PepedawnRaffle.sol";
import {MockVRFCoordinatorV2Plus} from "./mocks/MockVRFCoordinatorV2Plus.sol";

/**
 * @title VrfGasMeasurementTest
 * @notice Test suite for measuring actual VRF callback gas consumption
 * @dev This test helps tune gas estimation constants for production deployment
 */
contract VrfGasMeasurementTest is Test {
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
     * @notice Test gas consumption for VRF callback with different participant counts
     * @dev This test measures actual gas usage to tune production constants
     */
    function testVrfCallbackGasMeasurement() public {
        // Test with different participant counts
        uint256[] memory participantCounts = new uint256[](4);
        participantCounts[0] = 10;
        participantCounts[1] = 25;
        participantCounts[2] = 50;
        participantCounts[3] = 100;
        
        for (uint256 i = 0; i < participantCounts.length; i++) {
            uint256 participantCount = participantCounts[i];
            
            console.log("\n=== Testing with %d participants ===", participantCount);
            
            // Create and setup round
            _setupRoundWithParticipants(participantCount);
            
            // Measure gas for VRF request
            uint256 gasStart = gasleft();
            raffle.requestVrf(1);
            uint256 gasUsed = gasStart - gasleft();
            
            console.log("VRF request gas used: %d", gasUsed);
            
            // Get estimated callback gas
            uint32 estimatedGas = raffle.estimateVrfCallbackGas(1);
            console.log("Estimated callback gas: %d", estimatedGas);
            
            // Simulate VRF fulfillment and measure callback gas
            uint256[] memory randomWords = new uint256[](1);
            randomWords[0] = uint256(keccak256(abi.encodePacked(block.timestamp, participantCount)));
            
            gasStart = gasleft();
            vrfCoordinator.fulfillRandomWords(1, randomWords);
            gasUsed = gasStart - gasleft();
            
            console.log("Actual callback gas used: %d", gasUsed);
            console.log("Estimation accuracy: %d%%", (estimatedGas * 100) / uint32(gasUsed));
            
            // Complete the round to allow next round creation
            raffle.submitWinnersRoot(1, keccak256("winners"), "winners-cid");
            
            // Reset for next test
            vm.roll(block.number + 1);
        }
    }
    
    /**
     * @notice Test gas consumption with different buffer configurations
     * @dev This helps validate the optimized buffer percentages
     */
    function testBufferConfigurationImpact() public {
        console.log("\n=== Testing Buffer Configuration Impact ===");
        
        // Setup round with 25 participants
        _setupRoundWithParticipants(25);
        
        // Get base estimated gas
        uint32 baseGas = raffle.estimateVrfCallbackGas(1);
        console.log("Base estimated gas: %d", baseGas);
        
        // Calculate with current optimized buffers (25% + 15% = 40%)
        uint32 safetyBuffer = baseGas * 25 / 100;
        uint32 volatilityBuffer = baseGas * 15 / 100;
        uint32 totalBuffer = safetyBuffer + volatilityBuffer;
        uint32 finalGas = baseGas + totalBuffer;
        
        console.log("Safety buffer (25%%): %d", safetyBuffer);
        console.log("Volatility buffer (15%%): %d", volatilityBuffer);
        console.log("Total buffer (40%%): %d", totalBuffer);
        console.log("Final gas estimate: %d", finalGas);
        
        // Calculate cost at different gas prices
        uint256[] memory gasPrices = new uint256[](3);
        gasPrices[0] = 0.4 gwei;
        gasPrices[1] = 1 gwei;
        gasPrices[2] = 2 gwei;
        
        for (uint256 i = 0; i < gasPrices.length; i++) {
            uint256 costWei = finalGas * gasPrices[i];
            uint256 costLink = costWei / 1e18; // Convert to LINK (assuming 1 LINK = 1e18 wei)
            console.log("Cost at %d gwei: %d LINK", gasPrices[i] / 1e9, costLink);
        }
    }
    
    /**
     * @notice Test minimum gas limit enforcement
     * @dev Ensures VRF_MIN_CALLBACK_GAS is properly enforced
     */
    function testMinimumGasLimitEnforcement() public {
        console.log("\n=== Testing Minimum Gas Limit Enforcement ===");
        
        // Create a round with very few participants to test minimum gas
        _setupRoundWithParticipants(1);
        
        uint32 estimatedGas = raffle.estimateVrfCallbackGas(1);
        console.log("Estimated gas for 1 participant: %d", estimatedGas);
        
        // Should be at least VRF_MIN_CALLBACK_GAS
        assertGe(estimatedGas, 250_000, "Estimated gas below minimum");
        
        // Test VRF request succeeds
        raffle.requestVrf(1);
        
        // Verify round status
        (PepedawnRaffle.Round memory round,,,,,) = raffle.getRoundState(1);
        assertEq(uint8(round.status), uint8(PepedawnRaffle.RoundStatus.VRFRequested), "Round not in VRFRequested status");
    }
    
    /**
     * @notice Test maximum gas price enforcement
     * @dev Ensures maxGasPrice is properly enforced
     */
    function testMaxGasPriceEnforcement() public {
        console.log("\n=== Testing Max Gas Price Enforcement ===");
        
        _setupRoundWithParticipants(10);
        
        // Test with gas price below limit (should succeed)
        vm.txGasPrice(50 gwei);
        raffle.requestVrf(1);
        
        // Complete round 1 before creating round 2
        uint256[] memory randomWords = new uint256[](1);
        randomWords[0] = 12345;
        vrfCoordinator.fulfillRandomWords(1, randomWords);
        raffle.submitWinnersRoot(1, keccak256("winners"), "test-cid");
        
        // Reset round for next test
        vm.roll(block.number + 1);
        _setupRoundWithParticipants(10);
        
        // Test with gas price above limit (should fail)
        vm.txGasPrice(150 gwei);
        vm.expectRevert("Gas price too high for VRF request");
        raffle.requestVrf(1);
    }
    
    /**
     * @notice Helper function to setup a round with specified number of participants
     * @param participantCount Number of participants to create
     */
    function _setupRoundWithParticipants(uint256 participantCount) internal {
        // Create round
        raffle.createRound();
        raffle.setValidProof(1, bytes32(uint256(0x1234)));
        raffle.openRound(1);
        
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
        raffle.closeRound(1);
        raffle.snapshotRound(1);
        
        // Set participants root (required for VRF request)
        raffle.commitParticipantsRoot(1, keccak256("participants"), "test-cid");
    }
}
