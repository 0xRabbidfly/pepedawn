// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Test} from "forge-std/Test.sol";
import {PepedawnRaffle} from "../src/PepedawnRaffle.sol";

/**
 * @title Deployed Contract Test
 * @notice Test the deployed PepedawnRaffle contract on Sepolia
 */
contract DeployedContractTest is Test {
    PepedawnRaffle public raffle;
    
    // Deployed contract address on Sepolia
    address constant DEPLOYED_CONTRACT = 0xb3374E843e7504afF9A63533A3fA452d9570F47D;
    
    function setUp() public {
        // Connect to the deployed contract
        raffle = PepedawnRaffle(DEPLOYED_CONTRACT);
    }
    
    function testContractDeployed() public {
        vm.skip(true); // Skip: Requires Sepolia fork
        // Test that we can read basic contract state
        assertTrue(address(raffle) != address(0));
        assertTrue(raffle.owner() != address(0));
        assertTrue(raffle.creatorsAddress() != address(0));
        assertTrue(raffle.emblemVaultAddress() != address(0));
        assertEq(raffle.currentRoundId(), 0); // Should start with 0 rounds
    }
    
    function testConstants() public {
        vm.skip(true); // Skip: Requires Sepolia fork
        // Test that constants are set correctly
        assertEq(raffle.MIN_WAGER(), 0.005 ether);
        assertEq(raffle.BUNDLE_5_PRICE(), 0.0225 ether);
        assertEq(raffle.BUNDLE_10_PRICE(), 0.04 ether);
        assertEq(raffle.WALLET_CAP(), 1.0 ether);
        assertEq(raffle.PROOF_MULTIPLIER(), 1400);
        assertEq(raffle.CREATORS_FEE_PCT(), 80);
        assertEq(raffle.NEXT_ROUND_FEE_PCT(), 20);
        assertEq(raffle.ROUND_DURATION(), 2 weeks);
    }
    
    function testPrizeTiers() public {
        vm.skip(true); // Skip: Requires Sepolia fork
        // Test prize tier constants
        assertEq(raffle.FAKE_PACK_TIER(), 1);
        assertEq(raffle.KEK_PACK_TIER(), 2);
        assertEq(raffle.PEPE_PACK_TIER(), 3);
    }
    
    function testRoundStatusEnum() public {
        // Test that we can access the RoundStatus enum values
        assertEq(uint8(PepedawnRaffle.RoundStatus.Created), 0);
        assertEq(uint8(PepedawnRaffle.RoundStatus.Open), 1);
        assertEq(uint8(PepedawnRaffle.RoundStatus.Closed), 2);
        assertEq(uint8(PepedawnRaffle.RoundStatus.Snapshot), 3);
        assertEq(uint8(PepedawnRaffle.RoundStatus.VRFRequested), 4);
        assertEq(uint8(PepedawnRaffle.RoundStatus.Distributed), 5);
    }
    
    function testGetRound() public {
        vm.skip(true); // Skip: Requires Sepolia fork
        // Test getting round info (should return empty round for non-existent round)
        PepedawnRaffle.Round memory round = raffle.getRound(1);
        assertEq(round.id, 0); // Non-existent round should return id 0
    }
    
    function testGetUserStats() public {
        vm.skip(true); // Skip: Requires Sepolia fork
        // Test getting user stats (should return zeros for non-existent user)
        (uint256 wagered, uint256 tickets, uint256 weight, bool hasProof) = raffle.getUserStats(1, address(this));
        assertEq(wagered, 0);
        assertEq(tickets, 0);
        assertEq(weight, 0);
        assertFalse(hasProof);
    }
    
    function testGetRoundParticipants() public {
        vm.skip(true); // Skip: Requires Sepolia fork
        // Test getting round participants (should return empty array for non-existent round)
        address[] memory participants = raffle.getRoundParticipants(1);
        assertEq(participants.length, 0);
    }
    
    function testGetRoundWinners() public {
        vm.skip(true); // Skip: Requires Sepolia fork
        // Test getting round winners (should return empty array for non-existent round)
        PepedawnRaffle.WinnerAssignment[] memory winners = raffle.getRoundWinners(1);
        assertEq(winners.length, 0);
    }
}
