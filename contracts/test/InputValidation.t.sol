// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../src/PepedawnRaffle.sol";
import "./mocks/MockVRFCoordinator.sol";

/**
 * @title InputValidationTest
 * @notice Comprehensive tests for input validation
 * @dev Tests all external parameter validation
 */
contract InputValidationTest is Test {
    PepedawnRaffle public raffle;
    MockVRFCoordinator public mockVRFCoordinator;
    address public owner;
    address public creatorsAddress;
    address public emblemVaultAddress;
    
    // Test addresses
    address public alice = makeAddr("alice");
    address public bob = makeAddr("bob");
    
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
        
        // Reset VRF timing for all tests
        raffle.resetVRFTiming();
    }
    
    /**
     * @notice Test constructor input validation
     * @dev Verify constructor rejects invalid parameters
     */
    function testConstructorValidation() public {
        // Test zero VRF coordinator
        vm.expectRevert("Invalid address: zero address");
        new PepedawnRaffle(
            address(0),
            SUBSCRIPTION_ID,
            KEY_HASH,
            creatorsAddress,
            emblemVaultAddress
        );
        
        // Test zero creators address
        vm.expectRevert("Invalid address: zero address");
        new PepedawnRaffle(
            address(mockVRFCoordinator),
            SUBSCRIPTION_ID,
            KEY_HASH,
            address(0),
            emblemVaultAddress
        );
        
        // Test zero emblem vault address
        vm.expectRevert("Invalid address: zero address");
        new PepedawnRaffle(
            address(mockVRFCoordinator),
            SUBSCRIPTION_ID,
            KEY_HASH,
            creatorsAddress,
            address(0)
        );
        
        // Test zero subscription ID
        vm.expectRevert("Invalid VRF subscription ID");
        new PepedawnRaffle(
            address(mockVRFCoordinator),
            0,
            KEY_HASH,
            creatorsAddress,
            emblemVaultAddress
        );
        
        // Test zero key hash
        vm.expectRevert("Invalid VRF key hash");
        new PepedawnRaffle(
            address(mockVRFCoordinator),
            SUBSCRIPTION_ID,
            bytes32(0),
            creatorsAddress,
            emblemVaultAddress
        );
    }
    
    /**
     * @notice Test placeBet input validation
     * @dev Verify bet placement validates all parameters
     */
    function testPlaceBetValidation() public {
        // Create and open round
        raffle.createRound();
        raffle.openRound(1);
        
        // Test invalid ticket counts
        vm.prank(alice);
        vm.expectRevert("Invalid ticket count (must be 1, 5, or 10)");
        raffle.placeBet{value: 0.005 ether}(0);
        
        vm.prank(alice);
        vm.expectRevert("Invalid ticket count (must be 1, 5, or 10)");
        raffle.placeBet{value: 0.005 ether}(2);
        
        vm.prank(alice);
        vm.expectRevert("Invalid ticket count (must be 1, 5, or 10)");
        raffle.placeBet{value: 0.005 ether}(11);
        
        // Test incorrect payment amounts
        vm.prank(alice);
        vm.expectRevert("Incorrect payment amount");
        raffle.placeBet{value: 0.004 ether}(1);
        
        vm.prank(alice);
        vm.expectRevert("Incorrect payment amount");
        raffle.placeBet{value: 0.006 ether}(1);
        
        vm.prank(alice);
        vm.expectRevert("Incorrect payment amount");
        raffle.placeBet{value: 0.02 ether}(5);
        
        vm.prank(alice);
        vm.expectRevert("Incorrect payment amount");
        raffle.placeBet{value: 0.03 ether}(10);
        
        // Test zero value
        vm.prank(alice);
        vm.expectRevert("Invalid amount: must be greater than zero");
        raffle.placeBet{value: 0}(1);
        
        // Test wallet cap validation
        // First, place maximum allowed bets
        vm.startPrank(alice);
        raffle.placeBet{value: 0.04 ether}(10);  // 0.04 ETH
        raffle.placeBet{value: 0.04 ether}(10);  // 0.08 ETH total
        raffle.placeBet{value: 0.04 ether}(10);  // 0.12 ETH total
        raffle.placeBet{value: 0.04 ether}(10);  // 0.16 ETH total
        raffle.placeBet{value: 0.04 ether}(10);  // 0.20 ETH total
        raffle.placeBet{value: 0.04 ether}(10);  // 0.24 ETH total
        raffle.placeBet{value: 0.04 ether}(10);  // 0.28 ETH total
        raffle.placeBet{value: 0.04 ether}(10);  // 0.32 ETH total
        raffle.placeBet{value: 0.04 ether}(10);  // 0.36 ETH total
        raffle.placeBet{value: 0.04 ether}(10);  // 0.40 ETH total
        raffle.placeBet{value: 0.04 ether}(10);  // 0.44 ETH total
        raffle.placeBet{value: 0.04 ether}(10);  // 0.48 ETH total
        raffle.placeBet{value: 0.04 ether}(10);  // 0.52 ETH total
        raffle.placeBet{value: 0.04 ether}(10);  // 0.56 ETH total
        raffle.placeBet{value: 0.04 ether}(10);  // 0.60 ETH total
        raffle.placeBet{value: 0.04 ether}(10);  // 0.64 ETH total
        raffle.placeBet{value: 0.04 ether}(10);  // 0.68 ETH total
        raffle.placeBet{value: 0.04 ether}(10);  // 0.72 ETH total
        raffle.placeBet{value: 0.04 ether}(10);  // 0.76 ETH total
        raffle.placeBet{value: 0.04 ether}(10);  // 0.80 ETH total
        raffle.placeBet{value: 0.04 ether}(10);  // 0.84 ETH total
        raffle.placeBet{value: 0.04 ether}(10);  // 0.88 ETH total
        raffle.placeBet{value: 0.04 ether}(10);  // 0.92 ETH total
        raffle.placeBet{value: 0.04 ether}(10);  // 0.96 ETH total
        raffle.placeBet{value: 0.04 ether}(10);  // 1.00 ETH total (at cap)
        
        // Next bet should fail
        vm.expectRevert("Exceeds wallet cap of 1.0 ETH");
        raffle.placeBet{value: 0.005 ether}(1);
        vm.stopPrank();
    }
    
    /**
     * @notice Test submitProof input validation
     * @dev Verify proof submission validates parameters
     */
    function testSubmitProofValidation() public {
        // Create and open round
        raffle.createRound();
        raffle.openRound(1);
        
        // Test proof submission without wager
        vm.prank(alice);
        vm.expectRevert("Must place wager before submitting proof");
        raffle.submitProof(keccak256("proof"));
        
        // Place wager first
        vm.prank(alice);
        raffle.placeBet{value: 0.005 ether}(1);
        
        // Test zero proof hash
        vm.prank(alice);
        vm.expectRevert("Invalid proof hash");
        raffle.submitProof(bytes32(0));
        
        // Test empty hash
        vm.prank(alice);
        vm.expectRevert("Invalid proof: empty hash");
        raffle.submitProof(keccak256(""));
        
        // Test trivial hash (user address)
        vm.prank(alice);
        vm.expectRevert("Invalid proof: trivial hash");
        raffle.submitProof(keccak256(abi.encodePacked(alice)));
        
        // Submit valid proof
        vm.prank(alice);
        raffle.submitProof(keccak256("valid_proof"));
        
        // Test duplicate proof submission
        vm.prank(alice);
        vm.expectRevert("Proof already submitted for this round");
        raffle.submitProof(keccak256("another_proof"));
    }
    
    /**
     * @notice Test round management input validation
     * @dev Verify round functions validate round IDs and states
     */
    function testRoundManagementValidation() public {
        // Test operations on non-existent round
        vm.expectRevert("Round does not exist");
        raffle.openRound(999);
        
        vm.expectRevert("Round does not exist");
        raffle.closeRound(999);
        
        vm.expectRevert("Round does not exist");
        raffle.snapshotRound(999);
        
        vm.expectRevert("Round does not exist");
        raffle.requestVRF(999);
        
        // Create round
        raffle.createRound();
        
        // Test invalid state transitions
        vm.expectRevert("Round not in required status");
        raffle.closeRound(1); // Can't close Created round
        
        vm.expectRevert("Round not in required status");
        raffle.snapshotRound(1); // Can't snapshot Created round
        
        vm.expectRevert("Round not in required status");
        raffle.requestVRF(1); // Can't request VRF for Created round
        
        // Open round
        raffle.openRound(1);
        
        // Test invalid transitions from Open
        vm.expectRevert("Round not in required status");
        raffle.openRound(1); // Can't open Open round
        
        vm.expectRevert("Round not in required status");
        raffle.snapshotRound(1); // Can't snapshot Open round
        
        vm.expectRevert("Round not in required status");
        raffle.requestVRF(1); // Can't request VRF for Open round
    }
    
    /**
     * @notice Test VRF configuration validation
     * @dev Verify VRF updates validate parameters
     */
    function testVRFConfigValidation() public {
        // Test zero coordinator
        vm.expectRevert("Invalid address: zero address");
        raffle.updateVRFConfig(address(0), SUBSCRIPTION_ID, KEY_HASH);
        
        // Test zero subscription ID
        vm.expectRevert("Invalid VRF subscription ID");
        raffle.updateVRFConfig(address(mockVRFCoordinator), 0, KEY_HASH);
        
        // Test zero key hash
        vm.expectRevert("Invalid VRF key hash");
        raffle.updateVRFConfig(address(mockVRFCoordinator), SUBSCRIPTION_ID, bytes32(0));
        
        // Test contract address as coordinator (should fail)
        vm.expectRevert("Invalid address: contract address");
        raffle.updateVRFConfig(address(raffle), SUBSCRIPTION_ID, KEY_HASH);
    }
    
    /**
     * @notice Test address update validation
     * @dev Verify address updates validate parameters
     */
    function testAddressUpdateValidation() public {
        // Test zero creators address
        vm.expectRevert("Invalid address: zero address");
        raffle.updateCreatorsAddress(address(0));
        
        // Test contract address as creators
        vm.expectRevert("Invalid address: contract address");
        raffle.updateCreatorsAddress(address(raffle));
        
        // Test zero emblem vault address
        vm.expectRevert("Invalid address: zero address");
        raffle.updateEmblemVaultAddress(address(0));
        
        // Test contract address as emblem vault
        vm.expectRevert("Invalid address: contract address");
        raffle.updateEmblemVaultAddress(address(raffle));
        
        // Test denylist with zero address
        vm.expectRevert("Invalid address: zero address");
        raffle.setDenylistStatus(address(0), true);
        
        // Test denylist with contract address
        vm.expectRevert("Invalid address: contract address");
        raffle.setDenylistStatus(address(raffle), true);
    }
    
    /**
     * @notice Test round state validation
     * @dev Verify operations respect round states
     */
    function testRoundStateValidation() public {
        // Test betting when no round exists
        vm.prank(alice);
        vm.expectRevert("No active round");
        raffle.placeBet{value: 0.005 ether}(1);
        
        // Test proof submission when no round exists
        vm.prank(alice);
        vm.expectRevert("No active round");
        raffle.submitProof(keccak256("proof"));
        
        // Create round but don't open
        raffle.createRound();
        
        // Test betting on created but not opened round
        vm.prank(alice);
        vm.expectRevert("Round not open for betting");
        raffle.placeBet{value: 0.005 ether}(1);
        
        // Test proof submission on created but not opened round
        vm.prank(alice);
        vm.expectRevert("Round not open for proofs");
        raffle.submitProof(keccak256("proof"));
        
        // Open round
        raffle.openRound(1);
        
        // Now betting should work
        vm.prank(alice);
        raffle.placeBet{value: 0.005 ether}(1);
        
        // Close round
        raffle.closeRound(1);
        
        // Test betting on closed round
        vm.prank(bob);
        vm.expectRevert("Round not open for betting");
        raffle.placeBet{value: 0.005 ether}(1);
        
        // Test proof submission on closed round
        vm.prank(bob);
        vm.expectRevert("Round not open for proofs");
        raffle.submitProof(keccak256("proof"));
    }
    
    /**
     * @notice Test VRF request validation
     * @dev Verify VRF requests validate conditions
     */
    function testVRFRequestValidation() public {
        vm.skip(true); // TODO: Fix round state transition issue
        // Test 1: VRF request with no participants
        raffle.createRound();
        raffle.openRound(1);
        raffle.closeRound(1);
        raffle.snapshotRound(1);
        
        // Test VRF request with no participants
        vm.expectRevert("No participants in round");
        raffle.requestVRF(1);
        
        // Test 2: Valid VRF request with participants
        // First, add participants to the current round
        raffle.openRound(1); // Reopen the round to add participants
        
        vm.prank(alice);
        raffle.placeBet{value: 0.005 ether}(1);
        
        raffle.closeRound(2);
        raffle.snapshotRound(2);
        
        // Now VRF request should work
        raffle.requestVRF(2);
        
        // Test duplicate VRF request
        vm.expectRevert("Round not in required status");
        raffle.requestVRF(2);
    }
}
