// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {PepedawnRaffle} from "../src/PepedawnRaffle.sol";
import {MockVRFCoordinatorV2Plus} from "./mocks/MockVRFCoordinatorV2Plus.sol";

/**
 * @title RoundLifecycleTest
 * @notice Tests for round state management, transitions, and refund mechanism
 * @dev Tests round lifecycle from creation to completion/refund
 * 
 * Spec Alignment:
 * - FR-004: Round timeline (2 weeks)
 * - FR-008: Snapshot before VRF
 * - FR-009: VRF request
 * - FR-025: Minimum ticket threshold and refund mechanism
 * - FR-027: Progress tracking toward minimum
 */
contract RoundLifecycleTest is Test {
    PepedawnRaffle public raffle;
    MockVRFCoordinatorV2Plus public mockVrfCoordinator;
    
    address public owner;
    address public creatorsAddress;
    address public emblemVaultAddress;
    address public alice;
    address public bob;
    address public charlie;
    
    // VRF configuration
    uint256 public constant SUBSCRIPTION_ID = 1;
    bytes32 public constant KEY_HASH = keccak256("test");
    
    // Events for testing
    event RoundCreated(uint256 indexed roundId, uint64 startTime, uint64 endTime);
    event RoundOpened(uint256 indexed roundId);
    event RoundClosed(uint256 indexed roundId);
    event RoundSnapshot(uint256 indexed roundId, uint256 totalTickets, uint256 totalWeight);
    event VRFRequested(uint256 indexed roundId, uint256 indexed requestId);
    event ParticipantRefunded(uint256 indexed roundId, address indexed participant, uint256 amount);
    
    function setUp() public {
        owner = address(this);
        creatorsAddress = makeAddr("creators");
        emblemVaultAddress = makeAddr("emblemVault");
        alice = makeAddr("alice");
        bob = makeAddr("bob");
        charlie = makeAddr("charlie");
        
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
        vm.deal(charlie, 10 ether);
        
        // Reset VRF timing by directly manipulating storage (test only)
        vm.store(address(raffle), bytes32(uint256(10)), bytes32(uint256(0)));
    }
    
    // ============================================
    // Round Creation Tests (FR-004)
    // ============================================
    
    /**
     * @notice Test round creation with correct parameters
     * @dev FR-004: Should create round with 2-week duration
     */
    function testCreateRound() public {
        vm.expectEmit(true, false, false, false);
        emit RoundCreated(1, 0, 0); // We don't check exact timestamps
        
        raffle.createRound();
        
        assertEq(raffle.currentRoundId(), 1, "Round ID should increment");
        
        PepedawnRaffle.Round memory round = raffle.getRound(1);
        assertEq(round.id, 1, "Round ID mismatch");
        assertEq(uint8(round.status), 0, "Status should be Created");
        assertTrue(round.startTime > 0, "Start time should be set");
        assertTrue(round.endTime > round.startTime, "End time should be after start");
        assertEq(round.endTime - round.startTime, 2 weeks, "Duration should be 2 weeks");
    }
    
    /**
     * @notice Test cannot create round when previous not completed
     * @dev Only one active round at a time
     */
    function testCannotCreateRoundWhenPreviousNotCompleted() public {
        raffle.createRound();
        
        vm.expectRevert("Previous round not completed");
        raffle.createRound();
    }
    
    /**
     * @notice Test only owner can create round
     * @dev Access control check
     */
    function testOnlyOwnerCanCreateRound() public {
        vm.prank(alice);
        vm.expectRevert("Only callable by owner");
        raffle.createRound();
    }
    
    // ============================================
    // Round Opening Tests
    // ============================================
    
    /**
     * @notice Test opening a round
     * @dev Should transition from Created to Open
     */
    function testOpenRound() public {
        raffle.createRound();
        
        vm.expectEmit(true, false, false, false);
        emit RoundOpened(1);
        
        raffle.openRound(1);
        
        PepedawnRaffle.Round memory round = raffle.getRound(1);
        assertEq(uint8(round.status), 1, "Status should be Open");
    }
    
    /**
     * @notice Test cannot open non-existent round
     * @dev Should revert with clear message
     */
    function testCannotOpenNonExistentRound() public {
        vm.expectRevert("Round does not exist");
        raffle.openRound(999);
    }
    
    /**
     * @notice Test cannot open already opened round
     * @dev Invalid state transition
     */
    function testCannotOpenAlreadyOpenRound() public {
        raffle.createRound();
        raffle.openRound(1);
        
        vm.expectRevert("Round not in required status");
        raffle.openRound(1);
    }
    
    /**
     * @notice Test only owner can open round
     * @dev Access control check
     */
    function testOnlyOwnerCanOpenRound() public {
        raffle.createRound();
        
        vm.prank(alice);
        vm.expectRevert("Only callable by owner");
        raffle.openRound(1);
    }
    
    // ============================================
    // Round Closing Tests (FR-025)
    // ============================================
    
    /**
     * @notice Test closing round with sufficient tickets
     * @dev FR-025: 10+ tickets → Closed status
     */
    function testCloseRoundWithSufficientTickets() public {
        raffle.createRound();
        raffle.openRound(1);
        
        // Alice buys 10 tickets to meet minimum
        vm.prank(alice);
        raffle.placeBet{value: 0.04 ether}(10);
        
        vm.expectEmit(true, false, false, false);
        emit RoundClosed(1);
        
        raffle.closeRound(1);
        
        PepedawnRaffle.Round memory round = raffle.getRound(1);
        assertEq(uint8(round.status), 2, "Status should be Closed");
        assertGe(round.totalTickets, 10, "Should have at least 10 tickets");
    }
    
    /**
     * @notice Test closing round with insufficient tickets triggers refund
     * @dev FR-025: <10 tickets → Refunded status
     */
    function testCloseRoundWithInsufficientTicketsTriggersRefund() public {
        raffle.createRound();
        raffle.openRound(1);
        
        // Alice buys only 5 tickets (below minimum of 10)
        vm.prank(alice);
        raffle.placeBet{value: 0.0225 ether}(5);
        
        // When refunding, RoundClosed is NOT emitted, only ParticipantRefunded and RoundRefunded
        // So we don't expect RoundClosed here
        
        raffle.closeRound(1);
        
        PepedawnRaffle.Round memory round = raffle.getRound(1);
        assertEq(uint8(round.status), 7, "Status should be Refunded");
        assertLt(round.totalTickets, 10, "Should have less than 10 tickets");
        
        // Verify refund accrued (pull-payment pattern)
        uint256 aliceRefundBalance = raffle.getRefundBalance(alice);
        assertEq(aliceRefundBalance, 0.0225 ether, "Alice refund should be accrued");
        
        // Alice withdraws refund
        uint256 aliceBalanceBefore = alice.balance;
        vm.prank(alice);
        raffle.withdrawRefund();
        
        assertEq(alice.balance, aliceBalanceBefore + 0.0225 ether, "Alice should be refunded after withdrawal");
    }
    
    /**
     * @notice Test refund mechanism with multiple participants
     * @dev FR-025: All participants refunded when <10 tickets
     */
    function testRefundMechanismMultipleParticipants() public {
        raffle.createRound();
        raffle.openRound(1);
        
        // Multiple participants, total 7 tickets (below minimum of 10)
        vm.prank(alice);
        raffle.placeBet{value: 0.005 ether}(1); // 1 ticket
        
        vm.prank(bob);
        raffle.placeBet{value: 0.0225 ether}(5); // 5 tickets
        
        vm.prank(charlie);
        raffle.placeBet{value: 0.005 ether}(1); // 1 ticket
        
        // Close round - should trigger refund accrual (pull-payment pattern)
        vm.expectEmit(true, true, false, true);
        emit ParticipantRefunded(1, alice, 0.005 ether);
        vm.expectEmit(true, true, false, true);
        emit ParticipantRefunded(1, bob, 0.0225 ether);
        vm.expectEmit(true, true, false, true);
        emit ParticipantRefunded(1, charlie, 0.005 ether);
        
        raffle.closeRound(1);
        
        // Verify refunds accrued (not transferred yet)
        assertEq(raffle.getRefundBalance(alice), 0.005 ether, "Alice refund not accrued");
        assertEq(raffle.getRefundBalance(bob), 0.0225 ether, "Bob refund not accrued");
        assertEq(raffle.getRefundBalance(charlie), 0.005 ether, "Charlie refund not accrued");
        
        // Contract should still hold ETH until withdrawal
        assertGt(address(raffle).balance, 0, "Contract should hold ETH for refunds");
        
        // Each participant withdraws their refund
        uint256 aliceBalanceBefore = alice.balance;
        vm.prank(alice);
        raffle.withdrawRefund();
        assertEq(alice.balance, aliceBalanceBefore + 0.005 ether, "Alice not refunded");
        
        uint256 bobBalanceBefore = bob.balance;
        vm.prank(bob);
        raffle.withdrawRefund();
        assertEq(bob.balance, bobBalanceBefore + 0.0225 ether, "Bob not refunded");
        
        uint256 charlieBalanceBefore = charlie.balance;
        vm.prank(charlie);
        raffle.withdrawRefund();
        assertEq(charlie.balance, charlieBalanceBefore + 0.005 ether, "Charlie not refunded");
        
        // Contract should have zero balance after all withdrawals
        assertEq(address(raffle).balance, 0, "Contract should have no balance");
    }
    
    /**
     * @notice Test cannot close non-existent round
     * @dev Should revert
     */
    function testCannotCloseNonExistentRound() public {
        vm.expectRevert("Round does not exist");
        raffle.closeRound(999);
    }
    
    /**
     * @notice Test cannot close round not in Open status
     * @dev Invalid state transition
     */
    function testCannotCloseRoundNotOpen() public {
        raffle.createRound();
        
        vm.expectRevert("Round not in required status");
        raffle.closeRound(1);
    }
    
    /**
     * @notice Test only owner can close round
     * @dev Access control check
     */
    function testOnlyOwnerCanCloseRound() public {
        raffle.createRound();
        raffle.openRound(1);
        
        vm.prank(alice);
        vm.expectRevert("Only callable by owner");
        raffle.closeRound(1);
    }
    
    // ============================================
    // Snapshot Tests (FR-008)
    // ============================================
    
    /**
     * @notice Test snapshot captures tickets and weights immutably
     * @dev FR-008: Snapshot before VRF
     */
    function testSnapshotCapturesTicketsAndWeights() public {
        raffle.createRound();
        raffle.openRound(1);
        
        // Add participants
        vm.prank(alice);
        raffle.placeBet{value: 0.04 ether}(10);
        
        vm.prank(bob);
        raffle.placeBet{value: 0.0225 ether}(5);
        
        raffle.closeRound(1);
        
        vm.expectEmit(true, false, false, true);
        emit RoundSnapshot(1, 15, 15); // 15 tickets, 15 weight (no proofs)
        
        raffle.snapshotRound(1);
        
        PepedawnRaffle.Round memory round = raffle.getRound(1);
        assertEq(uint8(round.status), 3, "Status should be Snapshot");
        assertEq(round.totalTickets, 15, "Total tickets mismatch");
        assertEq(round.totalWeight, 15, "Total weight mismatch");
    }
    
    /**
     * @notice Test snapshot with proof bonuses
     * @dev Verify weighted snapshot calculation
     */
    function testSnapshotWithProofBonuses() public {
        raffle.createRound();
        
        // Set valid proof for the round
        raffle.setValidProof(1, keccak256("correct_proof"));
        
        raffle.openRound(1);
        
        // Alice: 10 tickets with correct proof (+40% = 14 weight)
        vm.prank(alice);
        raffle.placeBet{value: 0.04 ether}(10);
        
        vm.prank(alice);
        raffle.submitProof(keccak256("correct_proof"));
        
        // Bob: 5 tickets no proof (5 weight)
        vm.prank(bob);
        raffle.placeBet{value: 0.0225 ether}(5);
        
        raffle.closeRound(1);
        raffle.snapshotRound(1);
        
        PepedawnRaffle.Round memory round = raffle.getRound(1);
        assertEq(round.totalTickets, 15, "Total tickets should be 15");
        assertEq(round.totalWeight, 19, "Total weight should be 19 (14+5)");
    }
    
    /**
     * @notice Test cannot snapshot non-Closed round
     * @dev Invalid state transition
     */
    function testCannotSnapshotNonClosedRound() public {
        raffle.createRound();
        raffle.openRound(1);
        
        vm.expectRevert("Round not in required status");
        raffle.snapshotRound(1);
    }
    
    /**
     * @notice Test cannot snapshot refunded round
     * @dev Refunded rounds skip snapshot
     */
    function testCannotSnapshotRefundedRound() public {
        raffle.createRound();
        raffle.openRound(1);
        
        // Only 5 tickets - will be refunded
        vm.prank(alice);
        raffle.placeBet{value: 0.0225 ether}(5);
        
        raffle.closeRound(1); // This sets status to Refunded
        
        vm.expectRevert("Round not in required status");
        raffle.snapshotRound(1);
    }
    
    /**
     * @notice Test only owner can snapshot round
     * @dev Access control check
     */
    function testOnlyOwnerCanSnapshotRound() public {
        raffle.createRound();
        raffle.openRound(1);
        
        vm.prank(alice);
        raffle.placeBet{value: 0.04 ether}(10);
        
        raffle.closeRound(1);
        
        vm.prank(alice);
        vm.expectRevert("Only callable by owner");
        raffle.snapshotRound(1);
    }
    
    // ============================================
    // VRF Request Tests (FR-009)
    // ============================================
    
    /**
     * @notice Test VRF request after snapshot
     * @dev FR-009: Request randomness for winner selection
     */
    function testVRFRequestAfterSnapshot() public {
        raffle.createRound();
        raffle.openRound(1);
        
        vm.prank(alice);
        raffle.placeBet{value: 0.04 ether}(10);
        
        raffle.closeRound(1);
        raffle.snapshotRound(1);
        
        vm.expectEmit(true, true, false, false);
        emit VRFRequested(1, 1); // requestId will be 1 from mock
        
        raffle.requestVrf(1);
        
        PepedawnRaffle.Round memory round = raffle.getRound(1);
        assertEq(uint8(round.status), 4, "Status should be VRFRequested");
        assertTrue(round.vrfRequestId > 0, "VRF request ID should be set");
        assertTrue(round.vrfRequestedAt > 0, "VRF request timestamp should be set");
    }
    
    /**
     * @notice Test cannot request VRF on non-Snapshot round
     * @dev Invalid state transition
     */
    function testCannotRequestVRFOnNonSnapshotRound() public {
        raffle.createRound();
        raffle.openRound(1);
        
        vm.expectRevert("Round not in required status");
        raffle.requestVrf(1);
    }
    
    /**
     * @notice Test VRF frequency protection
     * @dev Cannot request VRF too frequently (1 minute minimum)
     */
    function testVRFFrequencyProtection() public {
        // First round
        raffle.createRound();
        raffle.openRound(1);
        
        vm.prank(alice);
        raffle.placeBet{value: 0.04 ether}(10);
        
        raffle.closeRound(1);
        raffle.snapshotRound(1);
        raffle.requestVrf(1);
        
        // Fulfill VRF and complete round 1
        uint256[] memory randomWords = new uint256[](1);
        randomWords[0] = 12345;
        mockVrfCoordinator.fulfillRandomWords(1, randomWords);
        
        // Submit winners root to complete round 1
        bytes32 winnersRoot = keccak256("test_winners_root");
        raffle.submitWinnersRoot(1, winnersRoot, "QmTestWinners123");
        
        // Create second round immediately
        raffle.createRound();
        raffle.openRound(2);
        
        vm.prank(bob);
        raffle.placeBet{value: 0.04 ether}(10);
        
        raffle.closeRound(2);
        raffle.snapshotRound(2);
        
        // Should fail - too soon after previous VRF request
        vm.expectRevert("VRF request too frequent");
        raffle.requestVrf(2);
        
        // Wait 61 seconds
        vm.warp(block.timestamp + 61);
        
        // Should work now
        raffle.requestVrf(2);
    }
    
    /**
     * @notice Test only owner can request VRF
     * @dev Access control check
     */
    function testOnlyOwnerCanRequestVRF() public {
        raffle.createRound();
        raffle.openRound(1);
        
        vm.prank(alice);
        raffle.placeBet{value: 0.04 ether}(10);
        
        raffle.closeRound(1);
        raffle.snapshotRound(1);
        
        vm.prank(alice);
        vm.expectRevert("Only callable by owner");
        raffle.requestVrf(1);
    }
    
    // ============================================
    // Progress Tracking Tests (FR-027)
    // ============================================
    
    /**
     * @notice Test progress tracking toward minimum tickets
     * @dev FR-027: Show X/10 tickets needed
     */
    function testProgressTrackingTowardMinimum() public {
        raffle.createRound();
        raffle.openRound(1);
        
        // 0 tickets initially
        PepedawnRaffle.Round memory round = raffle.getRound(1);
        assertEq(round.totalTickets, 0, "Should start with 0 tickets");
        
        // Alice buys 1 ticket
        vm.prank(alice);
        raffle.placeBet{value: 0.005 ether}(1);
        
        round = raffle.getRound(1);
        assertEq(round.totalTickets, 1, "Should have 1 ticket");
        assertLt(round.totalTickets, 10, "Should not meet minimum yet");
        
        // Bob buys 5 tickets
        vm.prank(bob);
        raffle.placeBet{value: 0.0225 ether}(5);
        
        round = raffle.getRound(1);
        assertEq(round.totalTickets, 6, "Should have 6 tickets");
        assertLt(round.totalTickets, 10, "Should not meet minimum yet");
        
        // Charlie buys 5 more tickets
        vm.prank(charlie);
        raffle.placeBet{value: 0.0225 ether}(5);
        
        round = raffle.getRound(1);
        assertEq(round.totalTickets, 11, "Should have 11 tickets");
        
        // Close round
        raffle.closeRound(1);
        
        round = raffle.getRound(1);
        assertGe(round.totalTickets, 10, "Should meet minimum after close");
        assertEq(uint8(round.status), 2, "Should be Closed, not Refunded");
    }
    
    // ============================================
    // State Transition Tests
    // ============================================
    
    /**
     * @notice Test valid state transitions
     * @dev Created → Open → Closed → Snapshot → VRFRequested → Distributed
     */
    function testValidStateTransitions() public {
        raffle.createRound();
        PepedawnRaffle.Round memory round = raffle.getRound(1);
        assertEq(uint8(round.status), 0, "Should be Created");
        
        raffle.openRound(1);
        round = raffle.getRound(1);
        assertEq(uint8(round.status), 1, "Should be Open");
        
        vm.prank(alice);
        raffle.placeBet{value: 0.04 ether}(10);
        
        raffle.closeRound(1);
        round = raffle.getRound(1);
        assertEq(uint8(round.status), 2, "Should be Closed");
        
        raffle.snapshotRound(1);
        round = raffle.getRound(1);
        assertEq(uint8(round.status), 3, "Should be Snapshot");
        
        raffle.requestVrf(1);
        round = raffle.getRound(1);
        assertEq(uint8(round.status), 4, "Should be VRFRequested");
        
        // VRF fulfillment transitions to Distributed
        uint256[] memory randomWords = new uint256[](1);
        randomWords[0] = 12345;
        mockVrfCoordinator.fulfillRandomWords(1, randomWords);
        
        round = raffle.getRound(1);
        assertEq(uint8(round.status), 5, "Should be Distributed");
    }
    
    /**
     * @notice Test refund path state transition
     * @dev Created → Open → Refunded (when <10 tickets)
     */
    function testRefundPathStateTransition() public {
        raffle.createRound();
        PepedawnRaffle.Round memory round = raffle.getRound(1);
        assertEq(uint8(round.status), 0, "Should be Created");
        
        raffle.openRound(1);
        round = raffle.getRound(1);
        assertEq(uint8(round.status), 1, "Should be Open");
        
        // Only 5 tickets
        vm.prank(alice);
        raffle.placeBet{value: 0.0225 ether}(5);
        
        raffle.closeRound(1);
        round = raffle.getRound(1);
        assertEq(uint8(round.status), 7, "Should be Refunded");
    }
    
    /**
     * @notice Test cannot skip states
     * @dev All transitions must be in order
     */
    function testCannotSkipStates() public {
        raffle.createRound();
        
        // Cannot snapshot before closing
        vm.expectRevert("Round not in required status");
        raffle.snapshotRound(1);
        
        // Cannot request VRF before snapshot
        vm.expectRevert("Round not in required status");
        raffle.requestVrf(1);
    }
}

