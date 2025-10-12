// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {PepedawnRaffle} from "../src/PepedawnRaffle.sol";
import {MockVRFCoordinatorV2Plus} from "./mocks/MockVRFCoordinatorV2Plus.sol";
import {IERC1155} from "@openzeppelin/contracts/token/ERC1155/IERC1155.sol";

/**
 * @title ClaimsTest  
 * @notice Test prize claiming with Merkle proofs
 * @dev Tests claim function, validation, NFT transfers, and claim limits
 */
contract ClaimsTest is Test {
    PepedawnRaffle public raffle;
    MockVRFCoordinatorV2Plus public mockVrfCoordinator;
    MockERC1155 public emblemVault;
    
    address public owner;
    address public creatorsAddress;
    address public alice = makeAddr("alice");
    address public bob = makeAddr("bob");
    address public charlie = makeAddr("charlie");
    
    // VRF configuration
    uint256 public constant SUBSCRIPTION_ID = 1;
    bytes32 public constant KEY_HASH = keccak256("test");
    
    // Sample data for testing
    bytes32 public constant SAMPLE_PARTICIPANTS_ROOT = keccak256("participants_root");
    bytes32 public winnersRoot;
    string public constant SAMPLE_CID = "QmTest123456789";
    
    function setUp() public {
        owner = address(this);
        creatorsAddress = makeAddr("creators");
        
        // Deploy mock contracts
        mockVrfCoordinator = new MockVRFCoordinatorV2Plus();
        emblemVault = new MockERC1155("https://emblem.vault/");
        
        // Deploy raffle contract
        raffle = new PepedawnRaffle(
            address(mockVrfCoordinator),
            SUBSCRIPTION_ID,
            KEY_HASH,
            creatorsAddress,
            address(emblemVault)
        );
        
        // Fund test accounts
        vm.deal(alice, 10 ether);
        vm.deal(bob, 10 ether);
        vm.deal(charlie, 10 ether);
        
        // Mint NFTs to contract for prizes (ERC1155: to, id, amount, data)
        for (uint256 i = 0; i < 10; i++) {
            emblemVault.mint(address(raffle), 1000 + i, 1, "");
        }
        
        // Reset VRF timing by directly manipulating storage (test only)
        // lastVrfRequestTime is at storage slot (calculate based on contract layout)
        vm.store(address(raffle), bytes32(uint256(10)), bytes32(uint256(0)));
    }
    
    // ============================================
    // Claim Workflow Tests
    // ============================================
    
    /**
     * @notice Test successful claim with valid proof
     * @dev Full workflow: round → VRF → commit winners → claim
     */
    function testClaimWithValidProof() public {
        // Setup complete round
        uint256 roundId = _setupCompletedRound();
        
        // Generate Merkle tree for winners
        // Alice wins prize 0 (tier 1), Bob wins prize 1 (tier 2)
        bytes32[] memory leaves = new bytes32[](10);
        leaves[0] = keccak256(abi.encodePacked(alice, uint8(1), uint8(0)));
        leaves[1] = keccak256(abi.encodePacked(bob, uint8(2), uint8(1)));
        for (uint8 i = 2; i < 10; i++) {
            leaves[i] = keccak256(abi.encodePacked(charlie, uint8(3), i));
        }
        
        winnersRoot = _calculateMerkleRoot(leaves);
        raffle.submitWinnersRoot(roundId, winnersRoot, SAMPLE_CID);
        
        // Generate proof for Alice (prize 0)
        bytes32[] memory proof = _generateProof(leaves, 0);
        
        // Alice claims prize
        uint256 balanceBefore = emblemVault.balanceOf(alice, 1000);
        
        vm.prank(alice);
        vm.expectEmit(true, true, true, true);
        emit PrizeClaimed(roundId, alice, 0, 1, 1000);
        raffle.claim(roundId, 0, 1, proof);
        
        // Verify NFT transferred (ERC1155: balanceOf takes address AND tokenId)
        assertEq(emblemVault.balanceOf(alice, 1000), balanceBefore + 1, "NFT not transferred");
        
        // Verify claim recorded
        (address claimer, bool claimed) = raffle.getClaimStatus(roundId, 0);
        assertTrue(claimed, "Claim not recorded");
        assertEq(claimer, alice, "Wrong claimer");
    }
    
    /**
     * @notice Test claim with invalid proof fails
     * @dev Should revert when Merkle proof doesn't match
     */
    function testClaimWithInvalidProof() public {
        uint256 roundId = _setupCompletedRound();
        
        // Setup winners (Alice wins prize 0)
        bytes32[] memory leaves = new bytes32[](10);
        leaves[0] = keccak256(abi.encodePacked(alice, uint8(1), uint8(0)));
        for (uint8 i = 1; i < 10; i++) {
            leaves[i] = keccak256(abi.encodePacked(bob, uint8(3), i));
        }
        
        winnersRoot = _calculateMerkleRoot(leaves);
        raffle.submitWinnersRoot(roundId, winnersRoot, SAMPLE_CID);
        
        // Bob tries to claim Alice's prize with invalid proof
        bytes32[] memory invalidProof = new bytes32[](1);
        invalidProof[0] = leaves[1];
        
        vm.prank(bob);
        vm.expectRevert("Invalid Merkle proof");
        raffle.claim(roundId, 0, 1, invalidProof);
    }
    
    /**
     * @notice Test cannot claim prize twice
     * @dev Second claim should revert
     */
    function testCannotClaimTwice() public {
        uint256 roundId = _setupCompletedRound();
        
        // Setup winners
        bytes32[] memory leaves = new bytes32[](10);
        leaves[0] = keccak256(abi.encodePacked(alice, uint8(1), uint8(0)));
        for (uint8 i = 1; i < 10; i++) {
            leaves[i] = keccak256(abi.encodePacked(bob, uint8(3), i));
        }
        
        winnersRoot = _calculateMerkleRoot(leaves);
        raffle.submitWinnersRoot(roundId, winnersRoot, SAMPLE_CID);
        
        // First claim succeeds
        bytes32[] memory proof = _generateProof(leaves, 0);
        vm.prank(alice);
        raffle.claim(roundId, 0, 1, proof);
        
        // Second claim fails
        vm.prank(alice);
        vm.expectRevert("Prize already claimed");
        raffle.claim(roundId, 0, 1, proof);
    }
    
    /**
     * @notice Test cannot exceed ticket-based claim limit
     * @dev User with 1 ticket cannot claim 2 prizes
     */
    function testCannotExceedTicketCount() public {
        // Create round where Alice buys only 1 ticket but "wins" 2 prizes
        raffle.createRound();
        
        uint256[] memory tokenIds = new uint256[](10);
        for (uint8 i = 0; i < 10; i++) {
            tokenIds[i] = 1000 + i;
        }
        raffle.setPrizesForRound(1, tokenIds);
        
        raffle.openRound(1);
        
        // Alice buys 1 ticket
        vm.prank(alice);
        raffle.buyTickets{value: 0.005 ether}(1);
        
        // Bob buys 10 tickets to meet minimum (total 11)
        vm.prank(bob);
        raffle.buyTickets{value: 0.04 ether}(10);
        
        raffle.closeRound(1);
        raffle.snapshotRound(1);
        raffle.commitParticipantsRoot(1, SAMPLE_PARTICIPANTS_ROOT, SAMPLE_CID);
        
        // Request VRF
        raffle.requestVrf(1);
        PepedawnRaffle.Round memory round = raffle.getRound(1);
        uint256[] memory randomWords = new uint256[](1);
        randomWords[0] = 12345;
        mockVrfCoordinator.fulfillRandomWords(round.vrfRequestId, randomWords);
        
        // Commit winners where Alice "wins" prizes 0 and 1
        bytes32[] memory leaves = new bytes32[](10);
        leaves[0] = keccak256(abi.encodePacked(alice, uint8(1), uint8(0)));
        leaves[1] = keccak256(abi.encodePacked(alice, uint8(2), uint8(1)));
        for (uint8 i = 2; i < 10; i++) {
            leaves[i] = keccak256(abi.encodePacked(bob, uint8(3), i));
        }
        
        winnersRoot = _calculateMerkleRoot(leaves);
        raffle.submitWinnersRoot(1, winnersRoot, SAMPLE_CID);
        
        // Alice claims first prize - should succeed
        bytes32[] memory proof0 = _generateProof(leaves, 0);
        vm.prank(alice);
        raffle.claim(1, 0, 1, proof0);
        
        // Alice tries to claim second prize - should fail (only 1 ticket)
        bytes32[] memory proof1 = _generateProof(leaves, 1);
        vm.prank(alice);
        vm.expectRevert("Claim limit exceeded");
        raffle.claim(1, 1, 2, proof1);
    }
    
    /**
     * @notice Test claim transfers correct NFT
     * @dev Verify the specific prize NFT is transferred
     */
    function testClaimTransfersNFT() public {
        uint256 roundId = _setupCompletedRound();
        
        // Setup winners
        bytes32[] memory leaves = new bytes32[](10);
        leaves[0] = keccak256(abi.encodePacked(alice, uint8(1), uint8(0)));
        for (uint8 i = 1; i < 10; i++) {
            leaves[i] = keccak256(abi.encodePacked(bob, uint8(3), i));
        }
        
        winnersRoot = _calculateMerkleRoot(leaves);
        raffle.submitWinnersRoot(roundId, winnersRoot, SAMPLE_CID);
        
        // Verify contract owns NFT before claim (ERC1155: balanceOf(address, tokenId))
        assertEq(emblemVault.balanceOf(address(raffle), 1000), 1, "Contract should own NFT");
        
        // Alice claims
        bytes32[] memory proof = _generateProof(leaves, 0);
        vm.prank(alice);
        raffle.claim(roundId, 0, 1, proof);
        
        // Verify Alice now owns NFT
        assertEq(emblemVault.balanceOf(alice, 1000), 1, "Alice should own NFT");
        assertEq(emblemVault.balanceOf(address(raffle), 1000), 0, "Contract should no longer own NFT");
    }
    
    /**
     * @notice Test claim emits correct event
     * @dev Verify PrizeClaimed event with all parameters
     */
    function testClaimEmitsEvent() public {
        uint256 roundId = _setupCompletedRound();
        
        bytes32[] memory leaves = new bytes32[](10);
        leaves[0] = keccak256(abi.encodePacked(alice, uint8(1), uint8(0)));
        for (uint8 i = 1; i < 10; i++) {
            leaves[i] = keccak256(abi.encodePacked(bob, uint8(3), i));
        }
        
        winnersRoot = _calculateMerkleRoot(leaves);
        raffle.submitWinnersRoot(roundId, winnersRoot, SAMPLE_CID);
        
        bytes32[] memory proof = _generateProof(leaves, 0);
        
        vm.prank(alice);
        vm.expectEmit(true, true, true, true);
        emit PrizeClaimed(roundId, alice, 0, 1, 1000);
        raffle.claim(roundId, 0, 1, proof);
    }
    
    /**
     * @notice Test claim in wrong round state fails
     * @dev Should revert when round not ready for claims
     */
    function testClaimInWrongState() public {
        raffle.createRound();
        raffle.openRound(1);
        
        vm.prank(alice);
        raffle.buyTickets{value: 0.0225 ether}(5);
        
        // Try to claim before round is complete
        bytes32[] memory emptyProof = new bytes32[](0);
        vm.prank(alice);
        vm.expectRevert("Round not ready for claims");
        raffle.claim(1, 0, 1, emptyProof);
    }
    
    /**
     * @notice Test multiple claims by same winner
     * @dev User with multiple tickets can claim multiple prizes
     */
    function testMultipleClaimsSameWinner() public {
        // Setup round where Alice has 5 tickets
        raffle.createRound();
        
        uint256[] memory tokenIds = new uint256[](10);
        for (uint8 i = 0; i < 10; i++) {
            tokenIds[i] = 1000 + i;
        }
        raffle.setPrizesForRound(1, tokenIds);
        
        raffle.openRound(1);
        
        vm.prank(alice);
        raffle.buyTickets{value: 0.0225 ether}(5);
        
        vm.prank(bob);
        raffle.buyTickets{value: 0.0225 ether}(5);
        
        raffle.closeRound(1);
        raffle.snapshotRound(1);
        raffle.commitParticipantsRoot(1, SAMPLE_PARTICIPANTS_ROOT, SAMPLE_CID);
        
        raffle.requestVrf(1);
        PepedawnRaffle.Round memory round = raffle.getRound(1);
        uint256[] memory randomWords = new uint256[](1);
        randomWords[0] = 12345;
        mockVrfCoordinator.fulfillRandomWords(round.vrfRequestId, randomWords);
        
        // Alice wins prizes 0, 1, 2
        bytes32[] memory leaves = new bytes32[](10);
        leaves[0] = keccak256(abi.encodePacked(alice, uint8(1), uint8(0)));
        leaves[1] = keccak256(abi.encodePacked(alice, uint8(2), uint8(1)));
        leaves[2] = keccak256(abi.encodePacked(alice, uint8(3), uint8(2)));
        for (uint8 i = 3; i < 10; i++) {
            leaves[i] = keccak256(abi.encodePacked(bob, uint8(3), i));
        }
        
        winnersRoot = _calculateMerkleRoot(leaves);
        raffle.submitWinnersRoot(1, winnersRoot, SAMPLE_CID);
        
        // Alice claims all 3 prizes (within her 5-ticket limit)
        for (uint8 i = 0; i < 3; i++) {
            bytes32[] memory proof = _generateProof(leaves, i);
            vm.prank(alice);
            raffle.claim(1, i, i == 0 ? uint8(1) : (i == 1 ? uint8(2) : uint8(3)), proof);
        }
        
        // Verify Alice owns all 3 NFTs (check each token individually)
        assertEq(emblemVault.balanceOf(alice, 1000), 1, "Alice should own prize 0");
        assertEq(emblemVault.balanceOf(alice, 1001), 1, "Alice should own prize 1");
        assertEq(emblemVault.balanceOf(alice, 1002), 1, "Alice should own prize 2");
    }
    
    // ============================================
    // Helper Functions
    // ============================================
    
    /**
     * @notice Setup a completed round ready for claims
     * @return roundId The ID of the setup round
     */
    function _setupCompletedRound() internal returns (uint256 roundId) {
        raffle.createRound();
        roundId = 1;
        
        // Set prizes BEFORE opening round
        uint256[] memory tokenIds = new uint256[](10);
        for (uint8 i = 0; i < 10; i++) {
            tokenIds[i] = 1000 + i;
        }
        raffle.setPrizesForRound(roundId, tokenIds);
        
        raffle.openRound(roundId);
        
        // Add participants
        vm.prank(alice);
        raffle.buyTickets{value: 0.0225 ether}(5);
        
        vm.prank(bob);
        raffle.buyTickets{value: 0.0225 ether}(5);
        
        // Close and snapshot
        raffle.closeRound(roundId);
        raffle.snapshotRound(roundId);
        raffle.commitParticipantsRoot(roundId, SAMPLE_PARTICIPANTS_ROOT, SAMPLE_CID);
        
        // Request and fulfill VRF
        raffle.requestVrf(roundId);
        PepedawnRaffle.Round memory round = raffle.getRound(roundId);
        uint256[] memory randomWords = new uint256[](1);
        randomWords[0] = 12345;
        mockVrfCoordinator.fulfillRandomWords(round.vrfRequestId, randomWords);
        
        return roundId;
    }
    
    /**
     * @notice Calculate Merkle root from leaves (simplified)
     */
    function _calculateMerkleRoot(bytes32[] memory leaves) internal pure returns (bytes32) {
        require(leaves.length > 0, "Empty leaves");
        
        if (leaves.length == 1) {
            return leaves[0];
        }
        
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
     * @notice Generate Merkle proof for a leaf (simplified)
     */
    function _generateProof(bytes32[] memory leaves, uint256 index) internal pure returns (bytes32[] memory) {
        require(index < leaves.length, "Invalid index");
        
        // Simplified proof generation - in production use merkletreejs
        uint256 proofLength = 0;
        uint256 tempCount = leaves.length;
        while (tempCount > 1) {
            proofLength++;
            tempCount = (tempCount + 1) / 2;
        }
        
        bytes32[] memory proof = new bytes32[](proofLength);
        uint256 proofIndex = 0;
        uint256 currentIndex = index;
        bytes32[] memory currentLevel = leaves;
        uint256 currentCount = leaves.length;
        
        while (currentCount > 1) {
            if (currentIndex % 2 == 0) {
                if (currentIndex + 1 < currentCount) {
                    proof[proofIndex++] = currentLevel[currentIndex + 1];
                }
            } else {
                proof[proofIndex++] = currentLevel[currentIndex - 1];
            }
            
            // Build next level
            bytes32[] memory nextLevel = new bytes32[]((currentCount + 1) / 2);
            for (uint256 i = 0; i < currentCount; i += 2) {
                if (i + 1 < currentCount) {
                    nextLevel[i / 2] = _hashPair(currentLevel[i], currentLevel[i + 1]);
                } else {
                    nextLevel[i / 2] = currentLevel[i];
                }
            }
            
            currentLevel = nextLevel;
            currentCount = (currentCount + 1) / 2;
            currentIndex = currentIndex / 2;
        }
        
        return proof;
    }
    
    /**
     * @notice Hash pair of bytes32 (sorted)
     */
    function _hashPair(bytes32 a, bytes32 b) internal pure returns (bytes32) {
        return a < b ? keccak256(abi.encodePacked(a, b)) : keccak256(abi.encodePacked(b, a));
    }
    
    // ============================================
    // Events
    // ============================================
    
    event PrizeClaimed(
        uint256 indexed roundId,
        address indexed winner,
        uint8 prizeIndex,
        uint8 prizeTier,
        uint256 tokenId
    );
}

/**
 * @notice Mock ERC1155 for testing NFT transfers (Emblem Vault uses ERC1155)
 */
contract MockERC1155 is IERC1155 {
    string public uri;
    
    // Mapping from token ID to account balances
    mapping(uint256 => mapping(address => uint256)) private _balances;
    
    // Mapping from account to operator approvals
    mapping(address => mapping(address => bool)) private _operatorApprovals;
    
    constructor(string memory _uri) {
        uri = _uri;
    }
    
    function mint(address to, uint256 id, uint256 amount, bytes memory data) external {
        require(to != address(0), "Mint to zero address");
        require(amount > 0, "Amount must be greater than 0");
        
        _balances[id][to] += amount;
        
        emit TransferSingle(msg.sender, address(0), to, id, amount);
        
        _doSafeTransferAcceptanceCheck(msg.sender, address(0), to, id, amount, data);
    }
    
    function balanceOf(address account, uint256 id) external view returns (uint256) {
        require(account != address(0), "Balance query for zero address");
        return _balances[id][account];
    }
    
    function balanceOfBatch(
        address[] memory accounts,
        uint256[] memory ids
    ) external view returns (uint256[] memory) {
        require(accounts.length == ids.length, "Accounts and IDs length mismatch");
        
        uint256[] memory batchBalances = new uint256[](accounts.length);
        
        for (uint256 i = 0; i < accounts.length; ++i) {
            batchBalances[i] = _balances[ids[i]][accounts[i]];
        }
        
        return batchBalances;
    }
    
    function setApprovalForAll(address operator, bool approved) external {
        require(msg.sender != operator, "Setting approval for self");
        _operatorApprovals[msg.sender][operator] = approved;
        emit ApprovalForAll(msg.sender, operator, approved);
    }
    
    function isApprovedForAll(address account, address operator) external view returns (bool) {
        return _operatorApprovals[account][operator];
    }
    
    function safeTransferFrom(
        address from,
        address to,
        uint256 id,
        uint256 amount,
        bytes memory data
    ) external {
        require(
            from == msg.sender || _operatorApprovals[from][msg.sender],
            "Caller is not owner nor approved"
        );
        require(to != address(0), "Transfer to zero address");
        
        uint256 fromBalance = _balances[id][from];
        require(fromBalance >= amount, "Insufficient balance");
        
        _balances[id][from] = fromBalance - amount;
        _balances[id][to] += amount;
        
        emit TransferSingle(msg.sender, from, to, id, amount);
        
        _doSafeTransferAcceptanceCheck(msg.sender, from, to, id, amount, data);
    }
    
    function safeBatchTransferFrom(
        address from,
        address to,
        uint256[] memory ids,
        uint256[] memory amounts,
        bytes memory data
    ) external {
        require(
            from == msg.sender || _operatorApprovals[from][msg.sender],
            "Caller is not owner nor approved"
        );
        require(ids.length == amounts.length, "IDs and amounts length mismatch");
        require(to != address(0), "Transfer to zero address");
        
        for (uint256 i = 0; i < ids.length; ++i) {
            uint256 id = ids[i];
            uint256 amount = amounts[i];
            
            uint256 fromBalance = _balances[id][from];
            require(fromBalance >= amount, "Insufficient balance");
            
            _balances[id][from] = fromBalance - amount;
            _balances[id][to] += amount;
        }
        
        emit TransferBatch(msg.sender, from, to, ids, amounts);
        
        _doSafeBatchTransferAcceptanceCheck(msg.sender, from, to, ids, amounts, data);
    }
    
    function supportsInterface(bytes4) external pure returns (bool) {
        return true;
    }
    
    function _doSafeTransferAcceptanceCheck(
        address operator,
        address from,
        address to,
        uint256 id,
        uint256 amount,
        bytes memory data
    ) private {
        if (to.code.length > 0) {
            // Contract recipient - would normally check onERC1155Received
            // For testing, we skip this check
        }
    }
    
    function _doSafeBatchTransferAcceptanceCheck(
        address operator,
        address from,
        address to,
        uint256[] memory ids,
        uint256[] memory amounts,
        bytes memory data
    ) private {
        if (to.code.length > 0) {
            // Contract recipient - would normally check onERC1155BatchReceived
            // For testing, we skip this check
        }
    }
}
