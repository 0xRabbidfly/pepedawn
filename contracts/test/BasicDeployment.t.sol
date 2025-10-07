// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "forge-std/Test.sol";
import "../src/PepedawnRaffle.sol";

contract BasicDeploymentTest is Test {
    PepedawnRaffle public raffle;
    
    // Mock addresses for testing without VRF
    address constant MOCK_VRF_COORDINATOR = 0x8103B0A8A00be2DDC778e6e7eaa21791Cd364625;
    uint256 constant MOCK_SUBSCRIPTION_ID = 1;
    bytes32 constant MOCK_KEY_HASH = 0x474e34a077df58807dbe9c96d3c009b23b3c6d0cce433e59bbf5b34f823bc56c;
    address constant MOCK_CREATORS = address(0x1234);
    address constant MOCK_EMBLEM_VAULT = address(0x5678);
    
    function setUp() public {
        // Deploy with mock VRF parameters
        raffle = new PepedawnRaffle(
            MOCK_VRF_COORDINATOR,
            MOCK_SUBSCRIPTION_ID,
            MOCK_KEY_HASH,
            MOCK_CREATORS,
            MOCK_EMBLEM_VAULT
        );
    }
    
    function testDeployment() public {
        assertTrue(address(raffle) != address(0));
        assertEq(raffle.owner(), address(this));
        assertEq(raffle.creatorsAddress(), MOCK_CREATORS);
        assertEq(raffle.emblemVaultAddress(), MOCK_EMBLEM_VAULT);
        assertEq(raffle.currentRoundId(), 0);
    }
    
    function testCreateRound() public {
        raffle.createRound();
        assertEq(raffle.currentRoundId(), 1);
        
        PepedawnRaffle.Round memory round = raffle.getRound(1);
        assertEq(round.id, 1);
        assertTrue(round.startTime > 0);
        assertTrue(round.endTime > round.startTime);
    }
    
    function testOpenRound() public {
        raffle.createRound();
        raffle.openRound(1);
        
        PepedawnRaffle.Round memory round = raffle.getRound(1);
        assertEq(round.id, 1);
        assertEq(uint8(round.status), 1); // RoundStatus.Open
    }
    
    function testPlaceBet() public {
        raffle.createRound();
        raffle.openRound(1);
        
        // Test single ticket bet (0.005 ETH)
        vm.deal(address(this), 1 ether);
        raffle.placeBet{value: 0.005 ether}(1);
        
        (uint256 wagered, uint256 tickets, uint256 weight, bool hasProof) = raffle.getUserStats(1, address(this));
        assertEq(wagered, 0.005 ether);
        assertEq(tickets, 1);
        assertEq(weight, 1); // No proof yet
        assertFalse(hasProof);
    }
    
    function testSubmitProof() public {
        raffle.createRound();
        raffle.openRound(1);
        
        // First place a bet
        vm.deal(address(this), 1 ether);
        raffle.placeBet{value: 0.005 ether}(1);
        
        // Then submit proof
        bytes32 proofHash = keccak256("test-proof");
        raffle.submitProof(proofHash);
        
        (uint256 wagered, uint256 tickets, uint256 weight, bool hasProof) = raffle.getUserStats(1, address(this));
        assertEq(wagered, 0.005 ether);
        assertEq(tickets, 1);
        assertEq(weight, 1); // 1 * 1400 / 1000 = 1 (truncated)
        assertTrue(hasProof);
    }
    
    function testBundlePricing() public {
        raffle.createRound();
        raffle.openRound(1);
        
        vm.deal(address(this), 1 ether);
        
        // Test 5-ticket bundle
        raffle.placeBet{value: 0.0225 ether}(5);
        (uint256 wagered, uint256 tickets, , ) = raffle.getUserStats(1, address(this));
        assertEq(wagered, 0.0225 ether);
        assertEq(tickets, 5);
        
        // Test 10-ticket bundle
        raffle.placeBet{value: 0.04 ether}(10);
        (wagered, tickets, , ) = raffle.getUserStats(1, address(this));
        assertEq(wagered, 0.0625 ether); // 0.0225 + 0.04
        assertEq(tickets, 15); // 5 + 10
    }
}
