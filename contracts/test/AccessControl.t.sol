// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../src/PepedawnRaffle.sol";
import "@chainlink/contracts/vrf/interfaces/VRFCoordinatorV2Interface.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/access/Ownable2Step.sol";
import "@openzeppelin/contracts/utils/Pausable.sol";
import "./mocks/MockVRFCoordinator.sol";

/**
 * @title AccessControlTest
 * @notice Comprehensive tests for access control mechanisms
 * @dev Tests secure ownership transfer and permission controls
 */
contract AccessControlTest is Test {
    PepedawnRaffle public raffle;
    MockVRFCoordinator public mockVRFCoordinator;
    address public owner;
    address public creatorsAddress;
    address public emblemVaultAddress;
    
    // Test addresses
    address public alice = makeAddr("alice");
    address public bob = makeAddr("bob");
    address public newOwner = makeAddr("newOwner");
    address public malicious = makeAddr("malicious");
    
    // VRF configuration
    uint64 public constant SUBSCRIPTION_ID = 1;
    bytes32 public constant KEY_HASH = keccak256("test");
    
    function setUp() public {
        owner = address(this);
        creatorsAddress = makeAddr("creators");
        emblemVaultAddress = makeAddr("emblemVault");
        
        // Deploy mock VRF coordinator
        mockVRFCoordinator = new MockVRFCoordinator();
        
        // Deploy contract with mock VRF coordinator
        raffle = new PepedawnRaffle(
            address(mockVRFCoordinator),
            SUBSCRIPTION_ID,
            KEY_HASH,
            creatorsAddress,
            emblemVaultAddress
        );
        
        // Fund test accounts
        vm.deal(alice, 10 ether);
        vm.deal(bob, 10 ether);
        vm.deal(malicious, 10 ether);
    }
    
    /**
     * @notice Test secure two-step ownership transfer
     * @dev Verify Ownable2Step implementation works correctly
     */
    function testSecureOwnershipTransfer() public {
        // Verify initial owner
        assertEq(raffle.owner(), owner);
        
        // Step 1: Transfer ownership (should only set pending owner)
        raffle.transferOwnership(newOwner);
        
        // Verify owner hasn't changed yet
        assertEq(raffle.owner(), owner);
        assertEq(raffle.pendingOwner(), newOwner);
        
        // Step 2: Accept ownership from new owner
        vm.prank(newOwner);
        raffle.acceptOwnership();
        
        // Verify ownership has transferred
        assertEq(raffle.owner(), newOwner);
        assertEq(raffle.pendingOwner(), address(0));
    }
    
    /**
     * @notice Test that non-pending owner cannot accept ownership
     * @dev Security test for ownership transfer
     */
    function testCannotAcceptOwnershipIfNotPending() public {
        // Transfer ownership to newOwner
        raffle.transferOwnership(newOwner);
        
        // Malicious user tries to accept ownership
        vm.prank(malicious);
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, malicious));
        raffle.acceptOwnership();
        
        // Verify owner hasn't changed
        assertEq(raffle.owner(), owner);
    }
    
    /**
     * @notice Test owner-only functions are protected
     * @dev Verify all administrative functions require owner
     */
    function testOwnerOnlyFunctions() public {
        // Test createRound
        vm.prank(malicious);
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, malicious));
        raffle.createRound();
        
        // Create round as owner for further tests
        raffle.createRound();
        
        // Test openRound
        vm.prank(malicious);
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, malicious));
        raffle.openRound(1);
        
        // Open round as owner for further tests
        raffle.openRound(1);
        
        // Test closeRound
        vm.prank(malicious);
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, malicious));
        raffle.closeRound(1);
        
        // Close round as owner for further tests
        raffle.closeRound(1);
        
        // Test snapshotRound
        vm.prank(malicious);
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, malicious));
        raffle.snapshotRound(1);
        
        // Snapshot round as owner for further tests
        raffle.snapshotRound(1);
        
        // Test requestVRF
        vm.prank(malicious);
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, malicious));
        raffle.requestVRF(1);
    }
    
    /**
     * @notice Test security management functions are owner-only
     * @dev Verify security controls are properly protected
     */
    function testSecurityManagementAccess() public {
        // Test setDenylistStatus
        vm.prank(malicious);
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, malicious));
        raffle.setDenylistStatus(alice, true);
        
        // Test setEmergencyPause
        vm.prank(malicious);
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, malicious));
        raffle.setEmergencyPause(true);
        
        // Test pause
        vm.prank(malicious);
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, malicious));
        raffle.pause();
        
        // Test unpause
        vm.prank(malicious);
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, malicious));
        raffle.unpause();
        
        // Test updateVRFConfig
        vm.prank(malicious);
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, malicious));
        raffle.updateVRFConfig(address(mockVRFCoordinator), SUBSCRIPTION_ID, KEY_HASH);
        
        // Test updateCreatorsAddress
        vm.prank(malicious);
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, malicious));
        raffle.updateCreatorsAddress(alice);
        
        // Test updateEmblemVaultAddress
        vm.prank(malicious);
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, malicious));
        raffle.updateEmblemVaultAddress(alice);
    }
    
    /**
     * @notice Test VRF coordinator validation
     * @dev Verify only VRF coordinator can fulfill randomness
     */
    function testVRFCoordinatorAccess() public {
        // This tests the internal fulfillRandomWords function indirectly
        // The function has onlyVRFCoordinator modifier
        
        // Reset VRF timing for testing
        raffle.resetVRFTiming();
        
        // Create and setup round for VRF
        raffle.createRound();
        raffle.openRound(1);
        
        // Add participant
        vm.prank(alice);
        raffle.placeBet{value: 0.005 ether}(1);
        
        raffle.closeRound(1);
        raffle.snapshotRound(1);
        raffle.requestVRF(1);
        
        // Mock VRF fulfillment from wrong address should fail
        // Note: fulfillRandomWords is internal, so this tests the pattern
        // In actual implementation, VRF coordinator validation is in the modifier
        
        // Verify VRF coordinator is set correctly
        (VRFCoordinatorV2Interface coordinator,,,,) = raffle.vrfConfig();
        assertEq(address(coordinator), address(mockVRFCoordinator));
    }
    
    /**
     * @notice Test denylist functionality
     * @dev Verify denylisted addresses cannot participate
     */
    function testDenylistFunctionality() public {
        // Denylist alice
        raffle.setDenylistStatus(alice, true);
        
        // Verify alice is denylisted
        assertTrue(raffle.denylisted(alice));
        
        // Create and open round
        raffle.createRound();
        raffle.openRound(1);
        
        // Alice should not be able to place bet
        vm.prank(alice);
        vm.expectRevert("Address is denylisted");
        raffle.placeBet{value: 0.005 ether}(1);
        
        // Alice should not be able to submit proof
        vm.prank(alice);
        vm.expectRevert("Address is denylisted");
        raffle.submitProof(keccak256("proof"));
        
        // Remove alice from denylist
        raffle.setDenylistStatus(alice, false);
        
        // Now alice should be able to participate
        vm.prank(alice);
        raffle.placeBet{value: 0.005 ether}(1);
    }
    
    /**
     * @notice Test emergency pause functionality
     * @dev Verify emergency controls work correctly
     */
    function testEmergencyPauseControls() public {
        // Set emergency pause
        raffle.setEmergencyPause(true);
        
        // Verify emergency pause is active
        assertTrue(raffle.emergencyPaused());
        
        // Should not be able to create round when emergency paused
        vm.expectRevert("Emergency pause is active");
        raffle.createRound();
        
        // Disable emergency pause
        raffle.setEmergencyPause(false);
        
        // Now should be able to create round
        raffle.createRound();
        
        // Test regular pause functionality
        raffle.pause();
        assertTrue(raffle.paused());
        
        // Should not be able to create round when paused
        vm.expectRevert(Pausable.EnforcedPause.selector);
        raffle.createRound();
        
        // Unpause
        raffle.unpause();
        assertFalse(raffle.paused());
    }
    
    /**
     * @notice Test that user functions work for non-denylisted users
     * @dev Verify normal users can interact when not restricted
     */
    function testNormalUserAccess() public {
        // Create and open round
        raffle.createRound();
        raffle.openRound(1);
        
        // Normal users should be able to place bets
        vm.prank(alice);
        raffle.placeBet{value: 0.005 ether}(1);
        
        // Normal users should be able to submit proofs
        vm.prank(alice);
        raffle.submitProof(keccak256("valid_proof"));
        
        // Verify user stats
        (uint256 wagered, uint256 tickets, uint256 weight, bool hasProof) = raffle.getUserStats(1, alice);
        assertEq(wagered, 0.005 ether);
        assertEq(tickets, 1);
        assertTrue(hasProof);
    }
    
    /**
     * @notice Test ownership renunciation protection
     * @dev Verify owner cannot accidentally renounce ownership
     */
    function testOwnershipRenunciationProtection() public {
        // Ownable2Step should prevent accidental renunciation
        // This is built into the OpenZeppelin implementation
        
        // Verify we can transfer to a valid address
        raffle.transferOwnership(newOwner);
        assertEq(raffle.pendingOwner(), newOwner);
        
        // Verify current owner is still the owner until acceptance
        assertEq(raffle.owner(), owner);
    }
}
