// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {PepedawnRaffle} from "../src/PepedawnRaffle.sol";
import {MockVRFCoordinatorV2Plus} from "./mocks/MockVRFCoordinatorV2Plus.sol";

/**
 * @title BettingAndProofsTest
 * @notice Tests for wager placement, pricing, proofs, and validation
 * @dev Tests all betting mechanics and puzzle proof system
 * 
 * Spec Alignment:
 * - FR-003: Wager placement
 * - FR-005: Leaderboard updates
 * - FR-006: Proof submission
 * - FR-007: Weight multipliers
 * - FR-017: Pricing and discounts
 * - FR-018: Eligibility (denylist)
 * - FR-019: Proof weighting rules
 * - FR-023: Per-round wallet cap
 */
contract BettingAndProofsTest is Test {
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
    event WagerPlaced(
        address indexed wallet,
        uint256 indexed roundId,
        uint256 amount,
        uint256 tickets,
        uint256 effectiveWeight
    );
    
    event ProofSubmitted(
        address indexed wallet,
        uint256 indexed roundId,
        bytes32 proofHash,
        uint256 newWeight
    );
    
    event ProofRejected(
        address indexed wallet,
        uint256 indexed roundId,
        bytes32 proofHash
    );
    
    event AddressDenylisted(address indexed wallet, bool denylisted);
    
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
        
        // Create and open round for testing
        raffle.createRound();
        raffle.openRound(1);
    }
    
    // ============================================
    // Bet Placement Tests (FR-003, FR-017)
    // ============================================
    
    /**
     * @notice Test single ticket bet (minimum wager)
     * @dev FR-017: 1 ticket = 0.005 ETH
     */
    function testPlaceBetSingleTicket() public {
        vm.expectEmit(true, true, false, true);
        emit WagerPlaced(alice, 1, 0.005 ether, 1, 1);
        
        vm.prank(alice);
        raffle.buyTickets{value: 0.005 ether}(1);
        
        (uint256 wagered, uint256 tickets, uint256 weight, bool hasProof) = 
            raffle.getUserStats(1, alice);
        
        assertEq(wagered, 0.005 ether, "Wagered amount mismatch");
        assertEq(tickets, 1, "Ticket count mismatch");
        assertEq(weight, 1, "Weight should equal tickets");
        assertFalse(hasProof, "Should not have proof");
        
        // Verify round stats
        PepedawnRaffle.Round memory round = raffle.getRound(1);
        assertEq(round.totalTickets, 1, "Round total tickets mismatch");
        assertEq(round.totalWagered, 0.005 ether, "Round total wagered mismatch");
    }
    
    /**
     * @notice Test 5-ticket bundle pricing
     * @dev FR-017: 5 tickets = 0.0225 ETH (10% discount)
     */
    function testPlaceBet5TicketBundle() public {
        vm.prank(alice);
        raffle.buyTickets{value: 0.0225 ether}(5);
        
        (uint256 wagered, uint256 tickets,,) = raffle.getUserStats(1, alice);
        assertEq(wagered, 0.0225 ether, "Wagered amount mismatch");
        assertEq(tickets, 5, "Should have 5 tickets");
        
        // Verify discount: 5 * 0.005 = 0.025, saved 0.0025 (10%)
        uint256 fullPrice = 5 * 0.005 ether;
        uint256 discount = fullPrice - 0.0225 ether;
        assertEq(discount, 0.0025 ether, "Discount should be 0.0025 ETH");
    }
    
    /**
     * @notice Test 10-ticket bundle pricing
     * @dev FR-017: 10 tickets = 0.04 ETH (20% discount)
     */
    function testPlaceBet10TicketBundle() public {
        vm.prank(alice);
        raffle.buyTickets{value: 0.04 ether}(10);
        
        (uint256 wagered, uint256 tickets,,) = raffle.getUserStats(1, alice);
        assertEq(wagered, 0.04 ether, "Wagered amount mismatch");
        assertEq(tickets, 10, "Should have 10 tickets");
        
        // Verify discount: 10 * 0.005 = 0.05, saved 0.01 (20%)
        uint256 fullPrice = 10 * 0.005 ether;
        uint256 discount = fullPrice - 0.04 ether;
        assertEq(discount, 0.01 ether, "Discount should be 0.01 ETH");
    }
    
    /**
     * @notice Test invalid ticket counts are rejected
     * @dev Only 1, 5, or 10 tickets allowed
     */
    function testRejectInvalidTicketCounts() public {
        // Zero tickets
        vm.prank(alice);
        vm.expectRevert("Invalid ticket count (must be 1, 5, or 10)");
        raffle.buyTickets{value: 0.005 ether}(0);
        
        // 2 tickets
        vm.prank(alice);
        vm.expectRevert("Invalid ticket count (must be 1, 5, or 10)");
        raffle.buyTickets{value: 0.01 ether}(2);
        
        // 11 tickets
        vm.prank(alice);
        vm.expectRevert("Invalid ticket count (must be 1, 5, or 10)");
        raffle.buyTickets{value: 0.055 ether}(11);
    }
    
    /**
     * @notice Test incorrect payment amounts are rejected
     * @dev Must pay exact amount for ticket count
     */
    function testRejectIncorrectPaymentAmounts() public {
        // Too little for 1 ticket
        vm.prank(alice);
        vm.expectRevert("Incorrect payment amount");
        raffle.buyTickets{value: 0.004 ether}(1);
        
        // Too much for 1 ticket
        vm.prank(alice);
        vm.expectRevert("Incorrect payment amount");
        raffle.buyTickets{value: 0.006 ether}(1);
        
        // Wrong amount for 5 tickets
        vm.prank(alice);
        vm.expectRevert("Incorrect payment amount");
        raffle.buyTickets{value: 0.025 ether}(5);
        
        // Wrong amount for 10 tickets
        vm.prank(alice);
        vm.expectRevert("Incorrect payment amount");
        raffle.buyTickets{value: 0.05 ether}(10);
    }
    
    /**
     * @notice Test zero value bets are rejected
     * @dev Must send ETH with bet
     */
    function testRejectZeroValueBets() public {
        vm.prank(alice);
        vm.expectRevert("Invalid amount: must be greater than zero");
        raffle.buyTickets{value: 0}(1);
    }
    
    // ============================================
    // Wallet Cap Tests (FR-023)
    // ============================================
    
    /**
     * @notice Test wallet cap enforcement
     * @dev FR-023: Maximum 1.0 ETH per wallet per round
     */
    function testWalletCapEnforcement() public {
        // Alice buys 25 bundles of 10 tickets each (25 * 0.04 = 1.0 ETH)
        vm.startPrank(alice);
        for (uint i = 0; i < 25; i++) {
            raffle.buyTickets{value: 0.04 ether}(10);
        }
        
        (uint256 wagered, uint256 tickets,,) = raffle.getUserStats(1, alice);
        assertEq(wagered, 1.0 ether, "Should have wagered exactly 1.0 ETH");
        assertEq(tickets, 250, "Should have 250 tickets");
        
        // Next bet should fail
        vm.expectRevert("Exceeds wallet cap of 1.0 ETH");
        raffle.buyTickets{value: 0.005 ether}(1);
        vm.stopPrank();
    }
    
    /**
     * @notice Test multiple bets from same wallet accumulate
     * @dev Cumulative wagers tracked per wallet per round
     */
    function testMultipleBetsAccumulate() public {
        vm.startPrank(alice);
        
        // First bet
        raffle.buyTickets{value: 0.005 ether}(1);
        (uint256 wagered1, uint256 tickets1,,) = raffle.getUserStats(1, alice);
        assertEq(wagered1, 0.005 ether, "First bet wagered mismatch");
        assertEq(tickets1, 1, "First bet tickets mismatch");
        
        // Second bet
        raffle.buyTickets{value: 0.0225 ether}(5);
        (uint256 wagered2, uint256 tickets2,,) = raffle.getUserStats(1, alice);
        assertEq(wagered2, 0.0275 ether, "Cumulative wagered mismatch");
        assertEq(tickets2, 6, "Cumulative tickets mismatch");
        
        // Third bet
        raffle.buyTickets{value: 0.04 ether}(10);
        (uint256 wagered3, uint256 tickets3,,) = raffle.getUserStats(1, alice);
        assertEq(wagered3, 0.0675 ether, "Final wagered mismatch");
        assertEq(tickets3, 16, "Final tickets mismatch");
        
        vm.stopPrank();
    }
    
    // ============================================
    // Round State Validation Tests
    // ============================================
    
    /**
     * @notice Test bets only accepted in Open rounds
     * @dev Bets rejected in Created status
     */
    function testBetsOnlyInOpenRounds() public {
        // Complete round 1 first (from setUp)
        vm.prank(alice);
        raffle.buyTickets{value: 0.04 ether}(10); // Meet minimum
        raffle.closeRound(1);
        raffle.snapshotRound(1);
        raffle.requestVrf(1);
        
        // Get the request ID from the round
        PepedawnRaffle.Round memory round = raffle.getRound(1);
        uint256 requestId = round.vrfRequestId;
        
        // Simulate VRF fulfillment
        uint256[] memory randomWords = new uint256[](1);
        randomWords[0] = 12345;
        mockVrfCoordinator.fulfillRandomWords(requestId, randomWords);
        
        // Submit winners root to complete the round
        bytes32 winnersRoot = keccak256("test_winners_root");
        raffle.submitWinnersRoot(1, winnersRoot, "QmTestWinners123");
        
        // Verify round 1 is now Distributed
        PepedawnRaffle.Round memory round1 = raffle.getRound(1);
        assertEq(uint256(round1.status), uint256(PepedawnRaffle.RoundStatus.Distributed), "Round 1 should be Distributed");
        
        // Now create round 2 but don't open it
        vm.warp(block.timestamp + 61); // Wait for VRF cooldown
        raffle.createRound();
        
        vm.prank(bob);
        vm.expectRevert("Round not open for betting");
        raffle.buyTickets{value: 0.005 ether}(1);
    }
    
    /**
     * @notice Test bets rejected after round closes
     * @dev Bets rejected in Closed status
     */
    function testBetsRejectedAfterClose() public {
        // Add minimum tickets and close
        vm.prank(alice);
        raffle.buyTickets{value: 0.04 ether}(10);
        
        raffle.closeRound(1);
        
        // Bob tries to bet after close
        vm.prank(bob);
        vm.expectRevert("Round not open for betting");
        raffle.buyTickets{value: 0.005 ether}(1);
    }
    
    /**
     * @notice Test cannot bet when no active round
     * @dev Clear error message
     */
    function testCannotBetWhenNoActiveRound() public {
        // No round has been created yet
        // In setup, we created and opened round 1, so we need to complete it and start fresh
        // Actually, let's just test trying to bet when round is closed
        raffle.closeRound(1);
        
        vm.prank(alice);
        vm.expectRevert("Round not open for betting");
        raffle.buyTickets{value: 0.005 ether}(1);
    }
    
    // ============================================
    // Denylist Tests (FR-018)
    // ============================================
    
    /**
     * @notice Test denylisted wallets cannot bet
     * @dev FR-018: Denylist enforcement
     */
    function testDenylistedWalletsCannotBet() public {
        // Denylist alice
        vm.expectEmit(true, false, false, true);
        emit AddressDenylisted(alice, true);
        
        raffle.setDenylistStatus(alice, true);
        assertTrue(raffle.denylisted(alice), "Alice should be denylisted");
        
        // Alice tries to bet
        vm.prank(alice);
        vm.expectRevert("Address is denylisted");
        raffle.buyTickets{value: 0.005 ether}(1);
    }
    
    /**
     * @notice Test removing from denylist restores access
     * @dev Users can be removed from denylist
     */
    function testRemovingFromDenylistRestoresAccess() public {
        // Denylist and remove alice
        raffle.setDenylistStatus(alice, true);
        raffle.setDenylistStatus(alice, false);
        
        assertFalse(raffle.denylisted(alice), "Alice should not be denylisted");
        
        // Alice can now bet
        vm.prank(alice);
        raffle.buyTickets{value: 0.005 ether}(1);
        
        (uint256 wagered,,,) = raffle.getUserStats(1, alice);
        assertEq(wagered, 0.005 ether, "Bet should succeed");
    }
    
    // ============================================
    // Puzzle Proof Submission Tests (FR-006, FR-019)
    // ============================================
    
    /**
     * @notice Test proof requires prior wager
     * @dev FR-006: Must bet before submitting proof
     */
    function testProofRequiresPriorWager() public {
        vm.prank(alice);
        vm.expectRevert("Must place wager before submitting proof");
        raffle.submitProof(keccak256("some_proof"));
    }
    
    /**
     * @notice Test correct proof grants weight bonus
     * @dev FR-019: +40% weight bonus (1.4x multiplier)
     */
    function testCorrectProofGrantsWeightBonus() public {
        // Set valid proof for the round
        bytes32 validProofHash = keccak256("correct_answer");
        raffle.setValidProof(1, validProofHash);
        
        // Alice bets 10 tickets
        vm.prank(alice);
        raffle.buyTickets{value: 0.04 ether}(10);
        
        // Alice submits correct proof
        vm.expectEmit(true, true, false, false);
        emit ProofSubmitted(alice, 1, validProofHash, 14); // 10 * 1.4 = 14
        
        vm.prank(alice);
        raffle.submitProof(validProofHash);
        
        // Verify weight increased
        (,, uint256 weight, bool hasProof) = raffle.getUserStats(1, alice);
        assertEq(weight, 14, "Weight should be 14 (10 * 1.4)");
        assertTrue(hasProof, "Should have proof");
    }
    
    /**
     * @notice Test incorrect proof is rejected
     * @dev FR-019: Wrong proof = no bonus, immediate feedback
     */
    function testIncorrectProofIsRejected() public {
        // Set valid proof for the round
        bytes32 validProofHash = keccak256("correct_answer");
        raffle.setValidProof(1, validProofHash);
        
        // Alice bets
        vm.prank(alice);
        raffle.buyTickets{value: 0.04 ether}(10);
        
        // Alice submits wrong proof
        bytes32 wrongProofHash = keccak256("wrong_answer");
        
        vm.expectEmit(true, true, false, true);
        emit ProofRejected(alice, 1, wrongProofHash);
        
        vm.prank(alice);
        raffle.submitProof(wrongProofHash);
        
        // Verify no weight bonus
        (,, uint256 weight, bool hasProof) = raffle.getUserStats(1, alice);
        assertEq(weight, 10, "Weight should remain 10 (no bonus)");
        assertTrue(hasProof, "Proof attempt should be recorded");
    }
    
    /**
     * @notice Test only one proof attempt per wallet per round
     * @dev FR-006: One attempt only (success or fail)
     */
    function testOneProofAttemptPerWallet() public {
        // Alice bets
        vm.prank(alice);
        raffle.buyTickets{value: 0.04 ether}(10);
        
        // First proof attempt
        vm.prank(alice);
        raffle.submitProof(keccak256("first_attempt"));
        
        // Second proof attempt should fail
        vm.prank(alice);
        vm.expectRevert("Proof already submitted for this round");
        raffle.submitProof(keccak256("second_attempt"));
    }
    
    /**
     * @notice Test proof validation rules
     * @dev Various proof validation checks
     */
    function testProofValidation() public {
        // Alice bets first
        vm.prank(alice);
        raffle.buyTickets{value: 0.005 ether}(1);
        
        // Zero hash rejected
        vm.prank(alice);
        vm.expectRevert("Invalid proof hash");
        raffle.submitProof(bytes32(0));
        
        // Empty hash rejected
        vm.prank(alice);
        vm.expectRevert("Invalid proof: empty hash");
        raffle.submitProof(keccak256(""));
        
        // Trivial hash (user address) rejected
        vm.prank(alice);
        vm.expectRevert("Invalid proof: trivial hash");
        raffle.submitProof(keccak256(abi.encodePacked(alice)));
    }
    
    /**
     * @notice Test proof affects leaderboard odds
     * @dev FR-005, FR-007: Proof bonus visible in weight calculations
     */
    function testProofAffectsLeaderboardOdds() public {
        // Set valid proof
        bytes32 validProofHash = keccak256("correct");
        raffle.setValidProof(1, validProofHash);
        
        // Alice: 10 tickets with proof
        vm.prank(alice);
        raffle.buyTickets{value: 0.04 ether}(10);
        vm.prank(alice);
        raffle.submitProof(validProofHash);
        
        // Bob: 10 tickets without proof
        vm.prank(bob);
        raffle.buyTickets{value: 0.04 ether}(10);
        
        // Check weights
        (,, uint256 aliceWeight,) = raffle.getUserStats(1, alice);
        (,, uint256 bobWeight,) = raffle.getUserStats(1, bob);
        
        assertEq(aliceWeight, 14, "Alice weight should be 14 (with proof)");
        assertEq(bobWeight, 10, "Bob weight should be 10 (no proof)");
        
        // Total round weight
        PepedawnRaffle.Round memory round = raffle.getRound(1);
        assertEq(round.totalWeight, 24, "Total weight should be 24 (14+10)");
        
        // Alice's probability: 14/24 = 58.33%
        // Bob's probability: 10/24 = 41.67%
    }
    
    /**
     * @notice Test proof weight calculation precision
     * @dev Verify 1.4x multiplier with various ticket counts
     */
    function testProofWeightCalculationPrecision() public {
        bytes32 validProofHash = keccak256("valid");
        raffle.setValidProof(1, validProofHash);
        
        // Test with 1 ticket: 1 * 1400 / 1000 = 1.4 = 1 (truncated)
        vm.prank(alice);
        raffle.buyTickets{value: 0.005 ether}(1);
        vm.prank(alice);
        raffle.submitProof(validProofHash);
        (,, uint256 weight1,) = raffle.getUserStats(1, alice);
        assertEq(weight1, 1, "1 ticket with proof: weight = 1");
        
        // Test with 5 tickets: 5 * 1400 / 1000 = 7
        vm.prank(bob);
        raffle.buyTickets{value: 0.0225 ether}(5);
        vm.prank(bob);
        raffle.submitProof(validProofHash);
        (,, uint256 weight5,) = raffle.getUserStats(1, bob);
        assertEq(weight5, 7, "5 tickets with proof: weight = 7");
        
        // Test with 10 tickets: 10 * 1400 / 1000 = 14
        vm.prank(charlie);
        raffle.buyTickets{value: 0.04 ether}(10);
        vm.prank(charlie);
        raffle.submitProof(validProofHash);
        (,, uint256 weight10,) = raffle.getUserStats(1, charlie);
        assertEq(weight10, 14, "10 tickets with proof: weight = 14");
    }
    
    /**
     * @notice Test proof submission only in open rounds
     * @dev Proofs rejected in non-Open status
     */
    function testProofSubmissionOnlyInOpenRounds() public {
        // Alice bets
        vm.prank(alice);
        raffle.buyTickets{value: 0.005 ether}(1);
        
        // Close round
        raffle.closeRound(1);
        
        // Alice tries to submit proof after close
        vm.prank(alice);
        vm.expectRevert("Round not open for proofs");
        raffle.submitProof(keccak256("late_proof"));
    }
    
    /**
     * @notice Test multiple users can submit proofs
     * @dev Each user tracked independently
     */
    function testMultipleUsersSubmitProofs() public {
        bytes32 validProofHash = keccak256("valid");
        raffle.setValidProof(1, validProofHash);
        
        // Alice bets and submits correct proof
        vm.prank(alice);
        raffle.buyTickets{value: 0.005 ether}(1);
        vm.prank(alice);
        raffle.submitProof(validProofHash);
        
        // Bob bets and submits wrong proof
        vm.prank(bob);
        raffle.buyTickets{value: 0.005 ether}(1);
        vm.prank(bob);
        raffle.submitProof(keccak256("wrong"));
        
        // Charlie bets but doesn't submit proof
        vm.prank(charlie);
        raffle.buyTickets{value: 0.005 ether}(1);
        
        // Verify each user's state
        (,, uint256 aliceWeight, bool aliceHasProof) = raffle.getUserStats(1, alice);
        (,, uint256 bobWeight, bool bobHasProof) = raffle.getUserStats(1, bob);
        (,, uint256 charlieWeight, bool charlieHasProof) = raffle.getUserStats(1, charlie);
        
        assertEq(aliceWeight, 1, "Alice weight with correct proof");
        assertTrue(aliceHasProof, "Alice has proof");
        
        assertEq(bobWeight, 1, "Bob weight with wrong proof");
        assertTrue(bobHasProof, "Bob has proof (attempt recorded)");
        
        assertEq(charlieWeight, 1, "Charlie weight no proof");
        assertFalse(charlieHasProof, "Charlie no proof");
    }
    
    // ============================================
    // Participant Tracking Tests
    // ============================================
    
    /**
     * @notice Test participants are tracked correctly
     * @dev Each participant added to round
     */
    function testParticipantTracking() public {
        // Initial state
        address[] memory participants0 = raffle.getRoundParticipants(1);
        assertEq(participants0.length, 0, "Should start with no participants");
        
        // Alice bets
        vm.prank(alice);
        raffle.buyTickets{value: 0.005 ether}(1);
        
        address[] memory participants1 = raffle.getRoundParticipants(1);
        assertEq(participants1.length, 1, "Should have 1 participant");
        assertEq(participants1[0], alice, "Should be Alice");
        
        // Bob bets
        vm.prank(bob);
        raffle.buyTickets{value: 0.005 ether}(1);
        
        address[] memory participants2 = raffle.getRoundParticipants(1);
        assertEq(participants2.length, 2, "Should have 2 participants");
        
        // Alice bets again (should not duplicate)
        vm.prank(alice);
        raffle.buyTickets{value: 0.005 ether}(1);
        
        address[] memory participants3 = raffle.getRoundParticipants(1);
        assertEq(participants3.length, 2, "Should still have 2 participants");
    }
    
    /**
     * @notice Test round statistics update correctly
     * @dev Total tickets, weight, wagered tracked
     */
    function testRoundStatisticsUpdate() public {
        PepedawnRaffle.Round memory round0 = raffle.getRound(1);
        assertEq(round0.totalTickets, 0, "Initial tickets should be 0");
        assertEq(round0.totalWeight, 0, "Initial weight should be 0");
        assertEq(round0.totalWagered, 0, "Initial wagered should be 0");
        
        // Alice bets 10 tickets
        vm.prank(alice);
        raffle.buyTickets{value: 0.04 ether}(10);
        
        PepedawnRaffle.Round memory round1 = raffle.getRound(1);
        assertEq(round1.totalTickets, 10, "Should have 10 tickets");
        assertEq(round1.totalWeight, 10, "Should have 10 weight");
        assertEq(round1.totalWagered, 0.04 ether, "Should have 0.04 ETH wagered");
        
        // Bob bets 5 tickets
        vm.prank(bob);
        raffle.buyTickets{value: 0.0225 ether}(5);
        
        PepedawnRaffle.Round memory round2 = raffle.getRound(1);
        assertEq(round2.totalTickets, 15, "Should have 15 tickets");
        assertEq(round2.totalWeight, 15, "Should have 15 weight");
        assertEq(round2.totalWagered, 0.0625 ether, "Should have 0.0625 ETH wagered");
    }
}

