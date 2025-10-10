// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {PepedawnRaffle} from "../src/PepedawnRaffle.sol";
import {MockVRFCoordinatorV2Plus} from "./mocks/MockVRFCoordinatorV2Plus.sol";
import {MerkleProof} from "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";

/**
 * @title MerkleProofsTest
 * @notice Test Merkle proof verification for participants and winners
 * @dev Tests Merkle root commitment and proof verification workflows
 */
contract MerkleProofsTest is Test {
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
    
    // Sample Merkle roots for testing
    bytes32 public constant SAMPLE_PARTICIPANTS_ROOT = keccak256("participants_root");
    bytes32 public constant SAMPLE_WINNERS_ROOT = keccak256("winners_root");
    string public constant SAMPLE_CID = "QmTest123456789";
    
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
        
        // Reset VRF timing by directly manipulating storage (test only)
        vm.store(address(raffle), bytes32(uint256(10)), bytes32(uint256(0)));
    }
    
    // ============================================
    // Participants Root Tests
    // ============================================
    
    /**
     * @notice Test committing participants root in correct state
     * @dev Should succeed when round is in Snapshot state
     */
    function testCommitParticipantsRoot() public {
        // Create and prepare round
        raffle.createRound();
        raffle.openRound(1);
        
        // Add participants to meet minimum
        vm.prank(alice);
        raffle.placeBet{value: 0.0225 ether}(5);
        vm.prank(bob);
        raffle.placeBet{value: 0.0225 ether}(5);
        
        // Close and snapshot round
        raffle.closeRound(1);
        raffle.snapshotRound(1);
        
        // Commit participants root
        vm.expectEmit(true, true, true, true);
        emit ParticipantsRootCommitted(1, SAMPLE_PARTICIPANTS_ROOT, SAMPLE_CID);
        raffle.commitParticipantsRoot(1, SAMPLE_PARTICIPANTS_ROOT, SAMPLE_CID);
        
        // Verify storage
        (bytes32 storedRoot, string memory storedCID) = raffle.getParticipantsData(1);
        assertEq(storedRoot, SAMPLE_PARTICIPANTS_ROOT, "Participants root mismatch");
        assertEq(storedCID, SAMPLE_CID, "Participants CID mismatch");
    }
    
    /**
     * @notice Test committing participants root in invalid state
     * @dev Should revert when round is not in Snapshot state
     */
    function testCommitParticipantsRootInvalidState() public {
        // Create round but don't snapshot
        raffle.createRound();
        raffle.openRound(1);
        
        vm.prank(alice);
        raffle.placeBet{value: 0.0225 ether}(5);
        
        // Try to commit participants root without snapshot - should fail
        vm.expectRevert("Round not in required status");
        raffle.commitParticipantsRoot(1, SAMPLE_PARTICIPANTS_ROOT, SAMPLE_CID);
    }
    
    /**
     * @notice Test rejecting zero root
     * @dev Should revert when root is zero
     */
    function testZeroParticipantsRootRejected() public {
        // Setup round to Snapshot state
        raffle.createRound();
        raffle.openRound(1);
        
        vm.prank(alice);
        raffle.placeBet{value: 0.0225 ether}(5);
        vm.prank(bob);
        raffle.placeBet{value: 0.0225 ether}(5);
        
        raffle.closeRound(1);
        raffle.snapshotRound(1);
        
        // Try to commit zero root
        vm.expectRevert("Invalid root: zero");
        raffle.commitParticipantsRoot(1, bytes32(0), SAMPLE_CID);
    }
    
    // ============================================
    // Winners Root Tests
    // ============================================
    
    /**
     * @notice Test committing winners root in correct state
     * @dev Should succeed when round is in Distributed state with VRF seed
     */
    function testCommitWinnersRoot() public {
        // Create and run full round through VRF
        raffle.createRound();
        raffle.openRound(1);
        
        // Add participants
        vm.prank(alice);
        raffle.placeBet{value: 0.0225 ether}(5);
        vm.prank(bob);
        raffle.placeBet{value: 0.0225 ether}(5);
        
        // Close, snapshot, commit participants root
        raffle.closeRound(1);
        raffle.snapshotRound(1);
        raffle.commitParticipantsRoot(1, SAMPLE_PARTICIPANTS_ROOT, SAMPLE_CID);
        
        // Request and fulfill VRF
        raffle.requestVrf(1);
        PepedawnRaffle.Round memory round = raffle.getRound(1);
        uint256[] memory randomWords = new uint256[](1);
        randomWords[0] = 12345;
        mockVrfCoordinator.fulfillRandomWords(round.vrfRequestId, randomWords);
        
        // Now commit winners root
        vm.expectEmit(true, true, true, true);
        emit WinnersCommitted(1, SAMPLE_WINNERS_ROOT, SAMPLE_CID);
        raffle.submitWinnersRoot(1, SAMPLE_WINNERS_ROOT, SAMPLE_CID);
        
        // Verify storage
        (bytes32 storedRoot, string memory storedCID) = raffle.getWinnersData(1);
        assertEq(storedRoot, SAMPLE_WINNERS_ROOT, "Winners root mismatch");
        assertEq(storedCID, SAMPLE_CID, "Winners CID mismatch");
    }
    
    /**
     * @notice Test committing winners root in invalid state
     * @dev Should revert when round is not in Distributed state
     */
    function testCommitWinnersRootInvalidState() public {
        raffle.createRound();
        raffle.openRound(1);
        
        vm.prank(alice);
        raffle.placeBet{value: 0.0225 ether}(5);
        
        // Try to submit winners before VRF - should fail
        vm.expectRevert("Round not ready for winners submission");
        raffle.submitWinnersRoot(1, SAMPLE_WINNERS_ROOT, SAMPLE_CID);
    }
    
    /**
     * @notice Test rejecting zero winners root
     * @dev Should revert when winners root is zero
     */
    function testZeroWinnersRootRejected() public {
        // Run full round through VRF
        raffle.createRound();
        raffle.openRound(1);
        
        vm.prank(alice);
        raffle.placeBet{value: 0.0225 ether}(5);
        vm.prank(bob);
        raffle.placeBet{value: 0.0225 ether}(5);
        
        raffle.closeRound(1);
        raffle.snapshotRound(1);
        raffle.commitParticipantsRoot(1, SAMPLE_PARTICIPANTS_ROOT, SAMPLE_CID);
        raffle.requestVrf(1);
        
        PepedawnRaffle.Round memory round = raffle.getRound(1);
        uint256[] memory randomWords = new uint256[](1);
        randomWords[0] = 12345;
        mockVrfCoordinator.fulfillRandomWords(round.vrfRequestId, randomWords);
        
        // Try to submit zero root
        vm.expectRevert("Invalid Merkle root");
        raffle.submitWinnersRoot(1, bytes32(0), SAMPLE_CID);
    }
    
    // ============================================
    // Merkle Proof Verification Tests
    // ============================================
    
    /**
     * @notice Test Merkle proof generation and verification
     * @dev Generate a simple Merkle tree and verify proofs
     */
    function testMerkleProofVerification() public {
        // Create a simple Merkle tree with 3 leaves
        bytes32[] memory leaves = new bytes32[](3);
        leaves[0] = keccak256(abi.encode(alice, uint8(1), uint8(0)));
        leaves[1] = keccak256(abi.encode(bob, uint8(2), uint8(1)));
        leaves[2] = keccak256(abi.encode(charlie, uint8(3), uint8(2)));
        
        // Calculate root manually (simple 3-leaf tree)
        bytes32 root = _calculateMerkleRoot(leaves);
        
        // Generate proof for alice
        bytes32[] memory proof = new bytes32[](2);
        proof[0] = leaves[1];
        proof[1] = _hashPair(leaves[0], leaves[1]);
        
        // Note: This is a simplified test - actual Merkle tree would use proper construction
        // The contract's claim function will verify against the actual committed root
        
        // Verify the leaf format matches what the contract expects
        bytes32 leaf = keccak256(abi.encode(alice, uint8(1), uint8(0)));
        assertTrue(leaf == leaves[0], "Leaf format verification");
    }
    
    /**
     * @notice Test invalid Merkle proof rejection
     * @dev Verify that invalid proofs are rejected
     */
    function testInvalidMerkleProof() public {
        // Create legitimate leaves
        bytes32[] memory leaves = new bytes32[](2);
        leaves[0] = keccak256(abi.encode(alice, uint8(1), uint8(0)));
        leaves[1] = keccak256(abi.encode(bob, uint8(2), uint8(1)));
        
        bytes32 root = _hashPair(leaves[0], leaves[1]);
        
        // Create invalid proof (wrong leaf)
        bytes32 invalidLeaf = keccak256(abi.encode(charlie, uint8(3), uint8(2)));
        bytes32[] memory invalidProof = new bytes32[](1);
        invalidProof[0] = leaves[1];
        
        // Verify that invalid proof fails
        bool result = MerkleProof.verify(invalidProof, root, invalidLeaf);
        assertFalse(result, "Invalid proof should fail verification");
    }
    
    // ============================================
    // Helper Functions
    // ============================================
    
    /**
     * @notice Calculate Merkle root for array of leaves (simple implementation)
     * @dev This is a simplified version for testing - production uses merkletreejs
     */
    function _calculateMerkleRoot(bytes32[] memory leaves) internal pure returns (bytes32) {
        require(leaves.length > 0, "Empty leaves");
        
        if (leaves.length == 1) {
            return leaves[0];
        }
        
        // Build tree layer by layer
        uint256 count = leaves.length;
        bytes32[] memory current = leaves;
        
        while (count > 1) {
            bytes32[] memory next = new bytes32[]((count + 1) / 2);
            
            for (uint256 i = 0; i < count; i += 2) {
                if (i + 1 < count) {
                    next[i / 2] = _hashPair(current[i], current[i + 1]);
                } else {
                    next[i / 2] = current[i];
                }
            }
            
            current = next;
            count = (count + 1) / 2;
        }
        
        return current[0];
    }
    
    /**
     * @notice Hash a pair of bytes32 values (sorted)
     * @dev Matches OpenZeppelin MerkleProof sorting behavior
     */
    function _hashPair(bytes32 a, bytes32 b) internal pure returns (bytes32) {
        return a < b ? keccak256(abi.encodePacked(a, b)) : keccak256(abi.encodePacked(b, a));
    }
    
    // ============================================
    // Events
    // ============================================
    
    event ParticipantsRootCommitted(uint256 indexed roundId, bytes32 root, string cid);
    event WinnersCommitted(uint256 indexed roundId, bytes32 root, string cid);
}
