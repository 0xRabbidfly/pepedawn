// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {PepedawnRaffle} from "../src/PepedawnRaffle.sol";
import {MockVRFCoordinatorV2Plus} from "./mocks/MockVRFCoordinatorV2Plus.sol";
import {IVRFCoordinatorV2Plus} from "@chainlink/contracts/vrf/dev/interfaces/IVRFCoordinatorV2Plus.sol";

/**
 * @title CoreTest
 * @notice Basic contract operations: deployment, constants, smoke tests
 * @dev Tests fundamental contract behavior and initial state
 * 
 * Spec Alignment:
 * - FR-001: Wallet connection capability
 * - FR-002: Prize tier configuration
 * - FR-021: Network and VRF configuration
 */
contract CoreTest is Test {
    PepedawnRaffle public raffle;
    MockVRFCoordinatorV2Plus public mockVrfCoordinator;
    
    address public owner;
    address public creatorsAddress;
    address public emblemVaultAddress;
    
    // VRF configuration
    uint256 public constant SUBSCRIPTION_ID = 1;
    bytes32 public constant KEY_HASH = keccak256("test");
    
    function setUp() public {
        owner = address(this);
        creatorsAddress = makeAddr("creators");
        emblemVaultAddress = makeAddr("emblemVault");
        
        // Deploy mock VRF coordinator
        mockVrfCoordinator = new MockVRFCoordinatorV2Plus();
        
        // Deploy contract
        raffle = new PepedawnRaffle(
            address(mockVrfCoordinator),
            SUBSCRIPTION_ID,
            KEY_HASH,
            creatorsAddress,
            emblemVaultAddress
        );
    }
    
    // ============================================
    // Deployment & Initial State Tests
    // ============================================
    
    /**
     * @notice Test contract deploys successfully
     * @dev Verify deployment and basic address checks
     */
    function testDeployment() public {
        assertTrue(address(raffle) != address(0), "Contract should be deployed");
        assertEq(raffle.owner(), owner, "Owner should be deployer");
        assertEq(raffle.creatorsAddress(), creatorsAddress, "Creators address mismatch");
        assertEq(raffle.emblemVaultAddress(), emblemVaultAddress, "Emblem vault address mismatch");
        assertEq(raffle.currentRoundId(), 0, "Initial round ID should be 0");
    }
    
    /**
     * @notice Test constructor validates VRF coordinator
     * @dev Zero address should revert
     */
    function testConstructorValidatesVRFCoordinator() public {
        vm.expectRevert(); // VRFConsumerBaseV2Plus throws ZeroAddress error
        new PepedawnRaffle(
            address(0),
            SUBSCRIPTION_ID,
            KEY_HASH,
            creatorsAddress,
            emblemVaultAddress
        );
    }
    
    /**
     * @notice Test constructor validates creators address
     * @dev Zero address should revert
     */
    function testConstructorValidatesCreatorsAddress() public {
        vm.expectRevert("Invalid address: zero address");
        new PepedawnRaffle(
            address(mockVrfCoordinator),
            SUBSCRIPTION_ID,
            KEY_HASH,
            address(0),
            emblemVaultAddress
        );
    }
    
    /**
     * @notice Test constructor validates emblem vault address
     * @dev Zero address should revert
     */
    function testConstructorValidatesEmblemVaultAddress() public {
        vm.expectRevert("Invalid address: zero address");
        new PepedawnRaffle(
            address(mockVrfCoordinator),
            SUBSCRIPTION_ID,
            KEY_HASH,
            creatorsAddress,
            address(0)
        );
    }
    
    /**
     * @notice Test constructor validates VRF subscription ID
     * @dev Zero subscription ID should revert
     */
    function testConstructorValidatesSubscriptionId() public {
        vm.expectRevert("Invalid VRF subscription ID");
        new PepedawnRaffle(
            address(mockVrfCoordinator),
            0,
            KEY_HASH,
            creatorsAddress,
            emblemVaultAddress
        );
    }
    
    /**
     * @notice Test constructor validates VRF key hash
     * @dev Zero key hash should revert
     */
    function testConstructorValidatesKeyHash() public {
        vm.expectRevert("Invalid VRF key hash");
        new PepedawnRaffle(
            address(mockVrfCoordinator),
            SUBSCRIPTION_ID,
            bytes32(0),
            creatorsAddress,
            emblemVaultAddress
        );
    }
    
    // ============================================
    // Constants Tests (FR-017, FR-023, FR-019)
    // ============================================
    
    /**
     * @notice Test wager constants are set correctly
     * @dev Verify pricing tiers match spec
     */
    function testWagerConstants() public {
        assertEq(raffle.MIN_WAGER(), 0.005 ether, "Min wager should be 0.005 ETH");
        assertEq(raffle.BUNDLE_5_PRICE(), 0.0225 ether, "5-ticket bundle should be 0.0225 ETH");
        assertEq(raffle.BUNDLE_10_PRICE(), 0.04 ether, "10-ticket bundle should be 0.04 ETH");
    }
    
    /**
     * @notice Test wallet cap constant
     * @dev FR-023: 1.0 ETH per wallet per round
     */
    function testWalletCapConstant() public {
        assertEq(raffle.WALLET_CAP(), 1.0 ether, "Wallet cap should be 1.0 ETH");
    }
    
    /**
     * @notice Test proof multiplier constant
     * @dev FR-019: +40% weight bonus (1.4x multiplier = 1400/1000)
     */
    function testProofMultiplierConstant() public {
        assertEq(raffle.PROOF_MULTIPLIER(), 1400, "Proof multiplier should be 1400 (1.4x)");
    }
    
    /**
     * @notice Test fee distribution constants
     * @dev FR-024: 80% creators, 20% next round
     */
    function testFeeConstants() public {
        assertEq(raffle.CREATORS_FEE_PCT(), 80, "Creators fee should be 80%");
        assertEq(raffle.NEXT_ROUND_FEE_PCT(), 20, "Next round fee should be 20%");
    }
    
    /**
     * @notice Test round duration constant
     * @dev FR-004: 2-week rounds
     */
    function testRoundDurationConstant() public {
        assertEq(raffle.ROUND_DURATION(), 2 weeks, "Round duration should be 2 weeks");
    }
    
    /**
     * @notice Test minimum ticket threshold constant
     * @dev FR-025: 10 tickets minimum for distribution
     */
    function testMinimumTicketThreshold() public {
        assertEq(raffle.MIN_TICKETS_FOR_DISTRIBUTION(), 10, "Minimum tickets should be 10");
    }
    
    /**
     * @notice Test circuit breaker constants
     * @dev Security: MAX_PARTICIPANTS and MAX_TOTAL_WAGER
     */
    function testCircuitBreakerConstants() public {
        assertEq(raffle.MAX_PARTICIPANTS_PER_ROUND(), 100, "Max participants should be 100");
        assertEq(raffle.MAX_TOTAL_WAGER_PER_ROUND(), 100 ether, "Max total wager should be 100 ETH");
    }
    
    /**
     * @notice Test VRF timeout constant
     * @dev Security: 1 hour timeout for VRF requests
     */
    function testVRFTimeoutConstant() public {
        assertEq(raffle.VRF_REQUEST_TIMEOUT(), 1 hours, "VRF timeout should be 1 hour");
    }
    
    // ============================================
    // Prize Tier Constants (FR-002)
    // ============================================
    
    /**
     * @notice Test prize tier constants
     * @dev FR-002: 1=Fake, 2=Kek, 3=Pepe
     */
    function testPrizeTierConstants() public {
        assertEq(raffle.FAKE_PACK_TIER(), 1, "Fake pack tier should be 1");
        assertEq(raffle.KEK_PACK_TIER(), 2, "Kek pack tier should be 2");
        assertEq(raffle.PEPE_PACK_TIER(), 3, "Pepe pack tier should be 3");
    }
    
    // ============================================
    // Initial State Tests
    // ============================================
    
    /**
     * @notice Test initial security state
     * @dev Contract should not be paused on deployment
     */
    function testInitialSecurityState() public {
        assertFalse(raffle.paused(), "Contract should not be paused initially");
        assertFalse(raffle.emergencyPaused(), "Emergency pause should be off initially");
        assertEq(raffle.lastVrfRequestTime(), 0, "No VRF requests initially");
    }
    
    /**
     * @notice Test initial VRF configuration
     * @dev FR-021: Verify VRF config matches constructor params
     */
    function testInitialVRFConfig() public {
        (
            IVRFCoordinatorV2Plus coordinator,
            uint256 subId,
            bytes32 keyHash,
            uint32 callbackGasLimit,
            uint16 requestConfirmations
        ) = raffle.vrfConfig();
        
        assertEq(address(coordinator), address(mockVrfCoordinator), "VRF coordinator mismatch");
        assertEq(subId, SUBSCRIPTION_ID, "Subscription ID mismatch");
        assertEq(keyHash, KEY_HASH, "Key hash mismatch");
        assertTrue(callbackGasLimit > 0, "Callback gas limit should be set");
        assertTrue(requestConfirmations > 0, "Request confirmations should be set");
    }
    
    /**
     * @notice Test initial financial state
     * @dev Contract should have zero balance and next round funds
     */
    function testInitialFinancialState() public {
        assertEq(address(raffle).balance, 0, "Contract should have zero balance initially");
        assertEq(raffle.nextRoundFunds(), 0, "Next round funds should be zero initially");
    }
    
    // ============================================
    // View Function Tests
    // ============================================
    
    /**
     * @notice Test getRound for non-existent round
     * @dev Should return round with id=0
     */
    function testGetRoundNonExistent() public {
        PepedawnRaffle.Round memory round = raffle.getRound(999);
        assertEq(round.id, 0, "Non-existent round should return id=0");
    }
    
    /**
     * @notice Test getUserStats for non-existent user
     * @dev Should return zeros
     */
    function testGetUserStatsNonExistent() public {
        (uint256 wagered, uint256 tickets, uint256 weight, bool hasProof) = 
            raffle.getUserStats(1, makeAddr("nobody"));
        
        assertEq(wagered, 0, "Wagered should be 0");
        assertEq(tickets, 0, "Tickets should be 0");
        assertEq(weight, 0, "Weight should be 0");
        assertFalse(hasProof, "Should not have proof");
    }
    
    /**
     * @notice Test getRoundParticipants for non-existent round
     * @dev Should return empty array
     */
    function testGetRoundParticipantsNonExistent() public {
        address[] memory participants = raffle.getRoundParticipants(999);
        assertEq(participants.length, 0, "Should return empty array");
    }
    
    /**
     * @notice Test getRoundWinners for non-existent round
     * @dev Should return empty array
     */
    function testGetRoundWinnersNonExistent() public {
        PepedawnRaffle.WinnerAssignment[] memory winners = raffle.getRoundWinners(999);
        assertEq(winners.length, 0, "Should return empty array");
    }
    
    // ============================================
    // Smoke Tests (Basic Operations)
    // ============================================
    
    /**
     * @notice Smoke test: Create and open a round
     * @dev Verify basic round workflow works
     */
    function testSmokeCreateAndOpenRound() public {
        // Create round
        raffle.createRound();
        assertEq(raffle.currentRoundId(), 1, "Round should be created");
        
        // Get round details
        PepedawnRaffle.Round memory round = raffle.getRound(1);
        assertEq(round.id, 1, "Round ID should be 1");
        assertEq(uint8(round.status), 0, "Status should be Created");
        
        // Open round
        raffle.openRound(1);
        round = raffle.getRound(1);
        assertEq(uint8(round.status), 1, "Status should be Open");
    }
    
    /**
     * @notice Smoke test: Place a bet
     * @dev Verify basic betting works
     */
    function testSmokePlaceBet() public {
        // Setup
        raffle.createRound();
        raffle.openRound(1);
        
        address bettor = makeAddr("bettor");
        vm.deal(bettor, 1 ether);
        
        // Place bet
        vm.prank(bettor);
        raffle.placeBet{value: 0.005 ether}(1);
        
        // Verify
        (uint256 wagered, uint256 tickets, uint256 weight,) = raffle.getUserStats(1, bettor);
        assertEq(wagered, 0.005 ether, "Wagered amount mismatch");
        assertEq(tickets, 1, "Ticket count mismatch");
        assertTrue(weight > 0, "Weight should be set");
    }
    
    /**
     * @notice Smoke test: Submit proof
     * @dev Verify basic proof submission works
     */
    function testSmokeSubmitProof() public {
        // Setup
        raffle.createRound();
        raffle.openRound(1);
        
        address bettor = makeAddr("bettor");
        vm.deal(bettor, 1 ether);
        
        // Place bet
        vm.prank(bettor);
        raffle.placeBet{value: 0.005 ether}(1);
        
        // Submit proof
        vm.prank(bettor);
        raffle.submitProof(keccak256("test_proof"));
        
        // Verify
        (,,, bool hasProof) = raffle.getUserStats(1, bettor);
        assertTrue(hasProof, "Should have proof submitted");
    }
}

