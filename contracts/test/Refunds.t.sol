// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {PepedawnRaffle} from "../src/PepedawnRaffle.sol";
import {MockVRFCoordinatorV2Plus} from "./mocks/MockVRFCoordinatorV2Plus.sol";

/**
 * @title RefundsTest
 * @notice Test pull-payment refund system
 * @dev Tests refund accrual, withdrawal, reentrancy protection, and accumulation
 */
contract RefundsTest is Test {
    PepedawnRaffle public raffle;
    MockVRFCoordinatorV2Plus public mockVrfCoordinator;
    
    address public owner;
    address public creatorsAddress;
    address public emblemVaultAddress;
    address public alice = makeAddr("alice");
    address public bob = makeAddr("bob");
    address public charlie = makeAddr("charlie");
    
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
        
        // Fund test accounts
        vm.deal(alice, 10 ether);
        vm.deal(bob, 10 ether);
        vm.deal(charlie, 10 ether);
        
        // Reset VRF timing
        raffle.resetVrfTiming();
    }
    
    // ============================================
    // Refund Accrual Tests
    // ============================================
    
    /**
     * @notice Test refunds accrue when round has <10 tickets
     * @dev Refunds should be added to mapping, not immediately transferred
     */
    function testRefundAccrual() public {
        // Create round with insufficient tickets
        raffle.createRound();
        raffle.openRound(1);
        
        // Alice and Bob bet (total 6 tickets < 10)
        uint256 aliceWager = 0.0225 ether; // 5 tickets
        uint256 bobWager = 0.005 ether;    // 1 ticket
        
        vm.prank(alice);
        raffle.placeBet{value: aliceWager}(5);
        
        vm.prank(bob);
        raffle.placeBet{value: bobWager}(1);
        
        // Close round (should trigger refunds)
        raffle.closeRound(1);
        
        // Verify refunds accrued (not transferred yet)
        uint256 aliceRefund = raffle.getRefundBalance(alice);
        uint256 bobRefund = raffle.getRefundBalance(bob);
        
        assertEq(aliceRefund, aliceWager, "Alice refund incorrect");
        assertEq(bobRefund, bobWager, "Bob refund incorrect");
        
        // Verify ETH still in contract (not transferred)
        assertGt(address(raffle).balance, 0, "Contract should hold ETH");
    }
    
    /**
     * @notice Test withdrawRefund transfers ETH correctly
     * @dev Should transfer full refund amount and zero balance
     */
    function testWithdrawRefund() public {
        // Setup refund scenario
        raffle.createRound();
        raffle.openRound(1);
        
        uint256 wagerAmount = 0.0225 ether;
        vm.prank(alice);
        raffle.placeBet{value: wagerAmount}(5);
        
        raffle.closeRound(1);
        
        // Alice withdraws refund
        uint256 balanceBefore = alice.balance;
        
        vm.prank(alice);
        vm.expectEmit(true, true, true, true);
        emit RefundWithdrawn(alice, wagerAmount);
        raffle.withdrawRefund();
        
        // Verify ETH transferred
        assertEq(alice.balance, balanceBefore + wagerAmount, "Refund not transferred");
        
        // Verify refund balance zeroed
        assertEq(raffle.getRefundBalance(alice), 0, "Refund balance not cleared");
    }
    
    /**
     * @notice Test cannot withdraw zero refund
     * @dev Should revert when refund balance is zero
     */
    function testCannotWithdrawZero() public {
        // Try to withdraw with no refund
        vm.prank(alice);
        vm.expectRevert("No refund available");
        raffle.withdrawRefund();
    }
    
    /**
     * @notice Test reentrancy protection on withdrawRefund
     * @dev Malicious contract should not be able to reenter
     */
    function testReentrancyProtection() public {
        // Deploy malicious contract
        ReentrancyAttacker attacker = new ReentrancyAttacker(address(raffle));
        vm.deal(address(attacker), 10 ether);
        
        // Setup refund for attacker
        raffle.createRound();
        raffle.openRound(1);
        
        vm.prank(address(attacker));
        raffle.placeBet{value: 0.0225 ether}(5);
        
        raffle.closeRound(1);
        
        // Attacker tries to exploit (should fail)
        vm.prank(address(attacker));
        vm.expectRevert(); // ReentrancyGuard will revert
        attacker.attack();
    }
    
    /**
     * @notice Test multiple refunds accumulate correctly
     * @dev User's refunds from different rounds should sum
     */
    function testMultipleRefundsAccumulate() public {
        // Round 1: Alice bets and gets refund
        raffle.createRound();
        raffle.openRound(1);
        
        uint256 wager1 = 0.0225 ether;
        vm.prank(alice);
        raffle.placeBet{value: wager1}(5);
        
        raffle.closeRound(1);
        
        // Round 2: Alice bets again and gets another refund
        
        raffle.createRound();
        raffle.openRound(2);
        
        uint256 wager2 = 0.005 ether;
        vm.prank(alice);
        raffle.placeBet{value: wager2}(1);
        
        raffle.closeRound(2);
        
        // Verify refunds accumulated
        uint256 totalRefund = raffle.getRefundBalance(alice);
        assertEq(totalRefund, wager1 + wager2, "Refunds not accumulated");
        
        // Withdraw and verify
        uint256 balanceBefore = alice.balance;
        vm.prank(alice);
        raffle.withdrawRefund();
        
        assertEq(alice.balance, balanceBefore + wager1 + wager2, "Total refund incorrect");
    }
    
    /**
     * @notice Test refund after round closes below minimum threshold
     * @dev Test full workflow: bet → close (< 10 tickets) → refund
     */
    function testRefundAfterBelowMinimum() public {
        // Create round
        raffle.createRound();
        raffle.openRound(1);
        
        // Two participants, total 6 tickets (below minimum of 10)
        vm.prank(alice);
        raffle.placeBet{value: 0.005 ether}(1); // 1 ticket
        
        vm.prank(bob);
        raffle.placeBet{value: 0.0225 ether}(5);   // 5 tickets
        
        // Verify total tickets
        PepedawnRaffle.Round memory round = raffle.getRound(1);
        assertEq(round.totalTickets, 6, "Should have 6 tickets");
        
        // Close round
        raffle.closeRound(1);
        
        // Verify round status is Refunded
        round = raffle.getRound(1);
        assertEq(uint8(round.status), uint8(PepedawnRaffle.RoundStatus.Refunded), "Round should be Refunded");
        
        // Verify refunds available
        assertEq(raffle.getRefundBalance(alice), 0.005 ether, "Alice refund incorrect");
        assertEq(raffle.getRefundBalance(bob), 0.0225 ether, "Bob refund incorrect");
        
        // Both withdraw
        vm.prank(alice);
        raffle.withdrawRefund();
        
        vm.prank(bob);
        raffle.withdrawRefund();
        
        // Verify balances cleared
        assertEq(raffle.getRefundBalance(alice), 0, "Alice balance not cleared");
        assertEq(raffle.getRefundBalance(bob), 0, "Bob balance not cleared");
    }
    
    /**
     * @notice Test refund does not occur when threshold is met
     * @dev With ≥10 tickets, no refunds should be issued
     */
    function testNoRefundWhenThresholdMet() public {
        raffle.createRound();
        raffle.openRound(1);
        
        // Alice and Bob each buy 5 tickets (total 10 = threshold)
        vm.prank(alice);
        raffle.placeBet{value: 0.0225 ether}(5);
        
        vm.prank(bob);
        raffle.placeBet{value: 0.0225 ether}(5);
        
        // Close round
        raffle.closeRound(1);
        
        // Verify no refunds issued
        assertEq(raffle.getRefundBalance(alice), 0, "Alice should have no refund");
        assertEq(raffle.getRefundBalance(bob), 0, "Bob should have no refund");
        
        // Verify round status is Closed (not Refunded)
        PepedawnRaffle.Round memory round = raffle.getRound(1);
        assertEq(uint8(round.status), uint8(PepedawnRaffle.RoundStatus.Closed), "Round should be Closed");
    }
    
    /**
     * @notice Test partial withdrawals are not possible
     * @dev withdrawRefund should transfer full balance only
     */
    function testFullRefundOnly() public {
        // Setup refund
        raffle.createRound();
        raffle.openRound(1);
        
        uint256 wagerAmount = 0.0225 ether;
        vm.prank(alice);
        raffle.placeBet{value: wagerAmount}(5);
        
        raffle.closeRound(1);
        
        // Withdraw full refund
        vm.prank(alice);
        raffle.withdrawRefund();
        
        // Verify balance is zero (can't withdraw again)
        vm.prank(alice);
        vm.expectRevert("No refund available");
        raffle.withdrawRefund();
    }
    
    /**
     * @notice Test refund events are emitted correctly
     * @dev Verify ParticipantRefunded and RefundWithdrawn events
     */
    function testRefundEvents() public {
        raffle.createRound();
        raffle.openRound(1);
        
        uint256 wagerAmount = 0.0225 ether;
        vm.prank(alice);
        raffle.placeBet{value: wagerAmount}(5);
        
        // Close round - should emit ParticipantRefunded
        vm.expectEmit(true, true, true, true);
        emit ParticipantRefunded(1, alice, wagerAmount);
        raffle.closeRound(1);
        
        // Withdraw - should emit RefundWithdrawn
        vm.prank(alice);
        vm.expectEmit(true, true, true, true);
        emit RefundWithdrawn(alice, wagerAmount);
        raffle.withdrawRefund();
    }
    
    /**
     * @notice Test contract can handle multiple refund withdrawals in same block
     * @dev Multiple users should be able to withdraw refunds independently
     */
    function testMultipleWithdrawalsInBlock() public {
        // Setup refunds for multiple users
        raffle.createRound();
        raffle.openRound(1);
        
        vm.prank(alice);
        raffle.placeBet{value: 0.0225 ether}(5);
        
        vm.prank(bob);
        raffle.placeBet{value: 0.005 ether}(1);
        
        vm.prank(charlie);
        raffle.placeBet{value: 0.005 ether}(1);
        
        raffle.closeRound(1);
        
        // All withdraw in same block
        uint256 aliceBalBefore = alice.balance;
        uint256 bobBalBefore = bob.balance;
        uint256 charlieBalBefore = charlie.balance;
        
        vm.prank(alice);
        raffle.withdrawRefund();
        
        vm.prank(bob);
        raffle.withdrawRefund();
        
        vm.prank(charlie);
        raffle.withdrawRefund();
        
        // Verify all received refunds
        assertEq(alice.balance, aliceBalBefore + 0.0225 ether, "Alice refund failed");
        assertEq(bob.balance, bobBalBefore + 0.005 ether, "Bob refund failed");
        assertEq(charlie.balance, charlieBalBefore + 0.005 ether, "Charlie refund failed");
    }
    
    // ============================================
    // Events
    // ============================================
    
    event RefundWithdrawn(address indexed user, uint256 amount);
    event ParticipantRefunded(uint256 indexed roundId, address indexed participant, uint256 amount);
}

/**
 * @notice Malicious contract for testing reentrancy protection
 */
contract ReentrancyAttacker {
    PepedawnRaffle public raffle;
    bool public attacking;
    
    constructor(address _raffle) {
        raffle = PepedawnRaffle(_raffle);
    }
    
    receive() external payable {
        // Try to reenter on first call
        if (!attacking) {
            attacking = true;
            raffle.withdrawRefund(); // This should revert due to ReentrancyGuard
        }
    }
    
    function attack() external {
        raffle.withdrawRefund(); // This triggers the attack
    }
    
    // Allow contract to place bets
    function placeBet(uint256 tickets) external payable {
        raffle.placeBet{value: msg.value}(tickets);
    }
}
