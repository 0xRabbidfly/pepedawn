// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {PepedawnRaffle} from "../src/PepedawnRaffle.sol";
import {IVRFCoordinatorV2Plus} from "@chainlink/contracts/vrf/dev/interfaces/IVRFCoordinatorV2Plus.sol";
import {Pausable} from "@openzeppelin/contracts/utils/Pausable.sol";
import {MockVRFCoordinatorV2Plus} from "./mocks/MockVRFCoordinatorV2Plus.sol";

/**
 * @title GovernanceTest
 * @notice Tests for access control, ownership, emergency controls, and configuration
 * @dev Consolidated from AccessControl.t.sol, EmergencyControls.t.sol, and Governance.t.sol
 * 
 * Spec Alignment:
 * - FR-016: Disclaimers and compliance
 * - FR-018: Eligibility (denylist)
 */
contract GovernanceTest is Test {
    PepedawnRaffle public raffle;
    MockVRFCoordinatorV2Plus public mockVrfCoordinator;
    address public owner;
    address public creatorsAddress;
    address public emblemVaultAddress;
    
    // Test addresses
    address public alice = makeAddr("alice");
    address public bob = makeAddr("bob");
    address public newOwner = makeAddr("newOwner");
    address public malicious = makeAddr("malicious");
    address public newCreators = makeAddr("newCreators");
    address public newEmblemVault = makeAddr("newEmblemVault");
    address public newVrfCoordinator = makeAddr("newVrfCoordinator");
    
    // VRF configuration
    uint256 public constant SUBSCRIPTION_ID = 1;
    bytes32 public constant KEY_HASH = keccak256("test");
    
    // Events
    event OwnershipTransferRequested(address indexed from, address indexed to);
    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);
    event AddressDenylisted(address indexed wallet, bool denylisted);
    event EmergencyPauseToggled(bool paused);
    
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
        
        // Fund test accounts
        vm.deal(alice, 10 ether);
        vm.deal(bob, 10 ether);
        vm.deal(malicious, 10 ether);
        vm.deal(newOwner, 10 ether);
        
        // Reset VRF timing by directly manipulating storage (test only)
        // lastVrfRequestTime is at slot 16 (not slot 10 which is subscriptionId!)
        vm.store(address(raffle), bytes32(uint256(16)), bytes32(uint256(0)));
    }
    
    // ============================================
    // Ownership Transfer Tests (ConfirmedOwner)
    // ============================================
    
    /**
     * @notice Test two-step ownership transfer
     * @dev Uses ConfirmedOwner pattern for security
     */
    function testSecureOwnershipTransfer() public {
        // Verify initial owner
        assertEq(raffle.owner(), owner, "Initial owner should be deployer");
        
        // Step 1: Transfer ownership (sets pending owner)
        vm.expectEmit(true, true, false, false);
        emit OwnershipTransferRequested(owner, newOwner);
        raffle.transferOwnership(newOwner);
        
        // Verify owner hasn't changed yet
        assertEq(raffle.owner(), owner, "Owner should not change until accepted");
        
        // Step 2: Accept ownership from new owner
        vm.expectEmit(true, true, false, false);
        emit OwnershipTransferred(owner, newOwner);
        vm.prank(newOwner);
        raffle.acceptOwnership();
        
        // Verify ownership transferred
        assertEq(raffle.owner(), newOwner, "Ownership should be transferred");
    }
    
    /**
     * @notice Test non-pending owner cannot accept ownership
     * @dev Security test for ownership transfer
     */
    function testCannotAcceptOwnershipIfNotPending() public {
        raffle.transferOwnership(newOwner);
        
        // Malicious user tries to accept
        vm.prank(malicious);
        vm.expectRevert("Must be proposed owner");
        raffle.acceptOwnership();
        
        // Verify owner unchanged
        assertEq(raffle.owner(), owner, "Owner should not change");
    }
    
    /**
     * @notice Test ownership transfer cancellation
     * @dev Owner can cancel pending transfer
     */
    function testOwnershipTransferCancellation() public {
        // Initiate transfer
        raffle.transferOwnership(newOwner);
        
        // Cancel by transferring to zero address
        raffle.transferOwnership(address(0));
        
        // Original owner still has control
        assertEq(raffle.owner(), owner, "Owner should remain unchanged");
        raffle.createRound();
        
        // New owner cannot accept
        vm.prank(newOwner);
        vm.expectRevert("Must be proposed owner");
        raffle.acceptOwnership();
    }
    
    /**
     * @notice Test multiple ownership transfers
     * @dev Verify chain of ownership transfers works
     */
    function testMultipleOwnershipTransfers() public {
        address secondOwner = makeAddr("secondOwner");
        address thirdOwner = makeAddr("thirdOwner");
        
        // First transfer: owner → newOwner
        raffle.transferOwnership(newOwner);
        vm.prank(newOwner);
        raffle.acceptOwnership();
        assertEq(raffle.owner(), newOwner, "First transfer failed");
        
        // Second transfer: newOwner → secondOwner
        vm.prank(newOwner);
        raffle.transferOwnership(secondOwner);
        vm.prank(secondOwner);
        raffle.acceptOwnership();
        assertEq(raffle.owner(), secondOwner, "Second transfer failed");
        
        // Third transfer: secondOwner → thirdOwner
        vm.prank(secondOwner);
        raffle.transferOwnership(thirdOwner);
        vm.prank(thirdOwner);
        raffle.acceptOwnership();
        assertEq(raffle.owner(), thirdOwner, "Third transfer failed");
        
        // Only current owner has control
        vm.prank(thirdOwner);
        raffle.createRound();
    }
    
    // ============================================
    // Access Control Tests
    // ============================================
    
    /**
     * @notice Test owner-only functions are protected
     * @dev All administrative functions require owner
     */
    function testOwnerOnlyFunctions() public {
        // Test createRound
        vm.prank(malicious);
        vm.expectRevert("Only callable by owner");
        raffle.createRound();
        
        // Create round as owner
        raffle.createRound();
        
        // Test openRound
        vm.prank(malicious);
        vm.expectRevert("Only callable by owner");
        raffle.openRound(1);
        
        // Open round as owner
        raffle.openRound(1);
        
        // Add participants for further tests
        vm.prank(alice);
        raffle.buyTickets{value: 0.04 ether}(10);
        
        // Test closeRound
        vm.prank(malicious);
        vm.expectRevert("Only callable by owner");
        raffle.closeRound(1);
        
        // Close as owner
        raffle.closeRound(1);
        
        // Test snapshotRound
        vm.prank(malicious);
        vm.expectRevert("Only callable by owner");
        raffle.snapshotRound(1);
        
        // Snapshot as owner
        raffle.snapshotRound(1);
        
        // Test requestVrf
        vm.prank(malicious);
        vm.expectRevert("Only callable by owner");
        raffle.requestVrf(1);
    }
    
    /**
     * @notice Test security management functions are owner-only
     * @dev Verify security controls are protected
     */
    function testSecurityManagementAccess() public {
        // Test setDenylistStatus
        vm.prank(malicious);
        vm.expectRevert("Only callable by owner");
        raffle.setDenylistStatus(alice, true);
        
        // Test setEmergencyPause
        vm.prank(malicious);
        vm.expectRevert("Only callable by owner");
        raffle.setEmergencyPause(true);
        
        // Test pause
        vm.prank(malicious);
        vm.expectRevert("Only callable by owner");
        raffle.pause("test");
        
        // Test unpause
        vm.prank(malicious);
        vm.expectRevert("Only callable by owner");
        raffle.unpause();
        
        // Test updateVrfConfig
        vm.prank(malicious);
        vm.expectRevert("Only callable by owner");
        raffle.updateVrfConfig(address(mockVrfCoordinator), SUBSCRIPTION_ID, KEY_HASH);
        
        // Test updateCreatorsAddress
        vm.prank(malicious);
        vm.expectRevert("Only callable by owner");
        raffle.updateCreatorsAddress(alice);
        
        // Test updateEmblemVaultAddress
        vm.prank(malicious);
        vm.expectRevert("Only callable by owner");
        raffle.updateEmblemVaultAddress(alice);
    }
    
    /**
     * @notice Test governance during active rounds
     * @dev Ownership changes don't disrupt active rounds
     */
    function testGovernanceDuringActiveRounds() public {
        // Create and populate active round
        raffle.createRound();
        raffle.openRound(1);
        
        vm.prank(alice);
        raffle.buyTickets{value: 0.04 ether}(10);
        
        // Transfer ownership during active round
        raffle.transferOwnership(newOwner);
        vm.prank(newOwner);
        raffle.acceptOwnership();
        
        // New owner can manage the round
        vm.prank(newOwner);
        raffle.closeRound(1);
        
        vm.prank(newOwner);
        raffle.snapshotRound(1);
        
        vm.prank(newOwner);
        raffle.commitParticipantsRoot(1, keccak256("participants"), "test-cid");
        
        vm.prank(newOwner);
        raffle.requestVrf(1);
        
        // Round state preserved
        PepedawnRaffle.Round memory round = raffle.getRound(1);
        assertEq(uint256(round.status), 4, "Status should be VRFRequested");
        
        // User data preserved
        (uint256 wagered, uint256 tickets,,) = raffle.getUserStats(1, alice);
        assertEq(wagered, 0.04 ether, "Wagered amount preserved");
        assertEq(tickets, 10, "Tickets preserved");
    }
    
    // ============================================
    // Configuration Management Tests
    // ============================================
    
    /**
     * @notice Test VRF configuration updates
     * @dev Owner can update VRF parameters
     */
    function testVRFConfigurationUpdates() public {
        raffle.updateVrfConfig(newVrfCoordinator, SUBSCRIPTION_ID + 1, keccak256("newKey"));
        
        (IVRFCoordinatorV2Plus coordinator, uint256 subId, bytes32 keyHash,,) = raffle.vrfConfig();
        assertEq(address(coordinator), newVrfCoordinator, "Coordinator not updated");
        assertEq(subId, SUBSCRIPTION_ID + 1, "Subscription ID not updated");
        assertEq(keyHash, keccak256("newKey"), "Key hash not updated");
    }
    
    /**
     * @notice Test creators address updates
     * @dev Owner can update creators address
     */
    function testCreatorsAddressUpdate() public {
        raffle.updateCreatorsAddress(newCreators);
        assertEq(raffle.creatorsAddress(), newCreators, "Creators address not updated");
    }
    
    /**
     * @notice Test emblem vault address updates
     * @dev Owner can update emblem vault address
     */
    function testEmblemVaultAddressUpdate() public {
        raffle.updateEmblemVaultAddress(newEmblemVault);
        assertEq(raffle.emblemVaultAddress(), newEmblemVault, "Emblem vault address not updated");
    }
    
    /**
     * @notice Test configuration validation
     * @dev All configuration updates validate inputs
     */
    function testConfigurationValidation() public {
        // VRF configuration validation
        vm.expectRevert("Invalid address: zero address");
        raffle.updateVrfConfig(address(0), SUBSCRIPTION_ID, KEY_HASH);
        
        vm.expectRevert("Invalid VRF subscription ID");
        raffle.updateVrfConfig(newVrfCoordinator, 0, KEY_HASH);
        
        vm.expectRevert("Invalid VRF key hash");
        raffle.updateVrfConfig(newVrfCoordinator, SUBSCRIPTION_ID, bytes32(0));
        
        // Creators address validation
        vm.expectRevert("Invalid address: zero address");
        raffle.updateCreatorsAddress(address(0));
        
        vm.expectRevert("Invalid address: contract address");
        raffle.updateCreatorsAddress(address(raffle));
        
        // Emblem vault address validation
        vm.expectRevert("Invalid address: zero address");
        raffle.updateEmblemVaultAddress(address(0));
        
        vm.expectRevert("Invalid address: contract address");
        raffle.updateEmblemVaultAddress(address(raffle));
    }
    
    /**
     * @notice Test configuration changes during active rounds
     * @dev Config changes don't break ongoing rounds
     */
    function testConfigurationChangesDuringActiveRounds() public {
        raffle.createRound();
        raffle.openRound(1);
        
        vm.prank(alice);
        raffle.buyTickets{value: 0.04 ether}(10);
        
        // Change creators address during active round
        address originalCreators = raffle.creatorsAddress();
        raffle.updateCreatorsAddress(newCreators);
        
        // Complete round
        raffle.closeRound(1);
        raffle.snapshotRound(1);
        raffle.commitParticipantsRoot(1, keccak256("participants"), "test-cid");
        raffle.requestVrf(1);
        
        // Config updated
        assertEq(raffle.creatorsAddress(), newCreators, "Config should be updated");
        assertNotEq(raffle.creatorsAddress(), originalCreators, "Config should have changed");
    }
    
    // ============================================
    // Denylist Tests (FR-018)
    // ============================================
    
    /**
     * @notice Test denylist functionality
     * @dev FR-018: Denylisted addresses cannot participate
     */
    function testDenylistFunctionality() public {
        // Denylist alice
        vm.expectEmit(true, false, false, true);
        emit AddressDenylisted(alice, true);
        raffle.setDenylistStatus(alice, true);
        
        assertTrue(raffle.denylisted(alice), "Alice should be denylisted");
        
        // Create and open round
        raffle.createRound();
        raffle.openRound(1);
        
        // Alice cannot bet
        vm.prank(alice);
        vm.expectRevert("Address is denylisted");
        raffle.buyTickets{value: 0.005 ether}(1);
        
        // Alice cannot submit proof
        vm.prank(alice);
        vm.expectRevert("Address is denylisted");
        raffle.submitProof(keccak256("proof"));
        
        // Remove from denylist
        vm.expectEmit(true, false, false, true);
        emit AddressDenylisted(alice, false);
        raffle.setDenylistStatus(alice, false);
        
        assertFalse(raffle.denylisted(alice), "Alice should not be denylisted");
        
        // Alice can now participate
        vm.prank(alice);
        raffle.buyTickets{value: 0.005 ether}(1);
    }
    
    /**
     * @notice Test denylist validation
     * @dev Cannot denylist zero or contract address
     */
    function testDenylistValidation() public {
        vm.expectRevert("Invalid address: zero address");
        raffle.setDenylistStatus(address(0), true);
        
        vm.expectRevert("Invalid address: contract address");
        raffle.setDenylistStatus(address(raffle), true);
    }
    
    // ============================================
    // Emergency Controls Tests
    // ============================================
    
    /**
     * @notice Test emergency pause functionality
     * @dev Emergency pause stops all admin operations
     */
    function testEmergencyPause() public {
        assertFalse(raffle.emergencyPaused(), "Should not be emergency paused initially");
        
        // Activate emergency pause
        vm.expectEmit(false, false, false, true);
        emit EmergencyPauseToggled(true);
        raffle.setEmergencyPause(true);
        
        assertTrue(raffle.emergencyPaused(), "Should be emergency paused");
        
        // Cannot create rounds when emergency paused
        vm.expectRevert("Emergency pause is active");
        raffle.createRound();
        
        // Deactivate emergency pause
        vm.expectEmit(false, false, false, true);
        emit EmergencyPauseToggled(false);
        raffle.setEmergencyPause(false);
        
        assertFalse(raffle.emergencyPaused(), "Should not be emergency paused");
        
        // Operations work again
        raffle.createRound();
    }
    
    /**
     * @notice Test regular pause functionality
     * @dev Regular pause uses OpenZeppelin Pausable
     */
    function testRegularPause() public {
        assertFalse(raffle.paused(), "Should not be paused initially");
        
        // Create and open round
        raffle.createRound();
        raffle.openRound(1);
        
        // Activate regular pause
        raffle.pause("Test pause");
        assertTrue(raffle.paused(), "Should be paused");
        
        // User operations blocked
        vm.prank(alice);
        vm.expectRevert(Pausable.EnforcedPause.selector);
        raffle.buyTickets{value: 0.005 ether}(1);
        
        vm.prank(alice);
        vm.expectRevert(Pausable.EnforcedPause.selector);
        raffle.submitProof(keccak256("proof"));
        
        // Unpause
        raffle.unpause();
        assertFalse(raffle.paused(), "Should not be paused");
        
        // Operations work again
        vm.prank(alice);
        raffle.buyTickets{value: 0.005 ether}(1);
    }
    
    /**
     * @notice Test view functions work during pause
     * @dev Read operations not affected by pause
     */
    function testViewFunctionsWorkDuringPause() public {
        // Create round with data
        raffle.createRound();
        raffle.openRound(1);
        
        vm.prank(alice);
        raffle.buyTickets{value: 0.005 ether}(1);
        
        // Activate both pause mechanisms
        raffle.pause("Emergency test");
        raffle.setEmergencyPause(true);
        
        // View functions still work
        PepedawnRaffle.Round memory round = raffle.getRound(1);
        assertEq(round.totalTickets, 1, "View should work");
        
        (uint256 wagered,,,) = raffle.getUserStats(1, alice);
        assertEq(wagered, 0.005 ether, "View should work");
        
        address[] memory participants = raffle.getRoundParticipants(1);
        assertEq(participants.length, 1, "View should work");
        
        uint256 currentRound = raffle.currentRoundId();
        assertEq(currentRound, 1, "View should work");
    }
    
    /**
     * @notice Test combined pause states
     * @dev Both pause mechanisms work independently
     */
    function testCombinedPauseStates() public {
        raffle.createRound();
        raffle.openRound(1);
        
        // Add enough tickets to meet minimum before testing pauses
        vm.prank(alice);
        raffle.buyTickets{value: 0.04 ether}(10);
        
        // Emergency pause blocks BOTH admin and user operations
        raffle.setEmergencyPause(true);
        
        // Admin operations blocked by emergency pause
        vm.expectRevert("Emergency pause is active");
        raffle.closeRound(1);
        
        // User operations also blocked by emergency pause
        vm.prank(bob);
        vm.expectRevert("Emergency pause is active");
        raffle.buyTickets{value: 0.005 ether}(1);
        
        // Remove emergency pause
        raffle.setEmergencyPause(false);
        
        // Now test regular pause (blocks all state changes)
        raffle.pause("Block all state changes");
        
        // Admin operations blocked by regular pause
        vm.expectRevert(Pausable.EnforcedPause.selector);
        raffle.closeRound(1);
        
        // User operations also blocked by regular pause
        vm.prank(bob);
        vm.expectRevert(Pausable.EnforcedPause.selector);
        raffle.buyTickets{value: 0.005 ether}(1);
        
        // Remove regular pause
        raffle.unpause();
        
        // Everything works now
        vm.prank(bob);
        raffle.buyTickets{value: 0.005 ether}(1);
        
        raffle.closeRound(1);
    }
    
    // ============================================
    // Initial State Tests
    // ============================================
    
    /**
     * @notice Test initial governance state
     * @dev Verify correct initial configuration
     */
    function testInitialGovernanceState() public {
        // Verify initial owner
        assertEq(raffle.owner(), owner, "Initial owner mismatch");
        
        // Verify initial configuration
        assertEq(raffle.creatorsAddress(), creatorsAddress, "Initial creators mismatch");
        assertEq(raffle.emblemVaultAddress(), emblemVaultAddress, "Initial emblem vault mismatch");
        
        (
            IVRFCoordinatorV2Plus coordinator,
            uint256 subId,
            bytes32 keyHash,
            uint32 callbackGasLimit,
            uint16 requestConfirmations
        ) = raffle.vrfConfig();
        assertEq(address(coordinator), address(mockVrfCoordinator), "Initial VRF coordinator mismatch");
        assertEq(subId, SUBSCRIPTION_ID, "Initial subscription ID mismatch");
        assertEq(keyHash, KEY_HASH, "Initial key hash mismatch");
        assertTrue(callbackGasLimit > 0, "Callback gas limit should be set");
        assertTrue(requestConfirmations > 0, "Request confirmations should be set");
        
        // Verify initial security state
        assertFalse(raffle.paused(), "Should not be paused initially");
        assertFalse(raffle.emergencyPaused(), "Should not be emergency paused initially");
    }
}
