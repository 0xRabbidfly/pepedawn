// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title PepedawnRaffle (Remix Version)
 * @notice Skill-weighted decentralized raffle with Chainlink VRF and Emblem Vault prizes
 * @dev Simplified version for Remix IDE deployment and testing
 * 
 * REMIX SETUP INSTRUCTIONS:
 * 1. Copy this file to Remix IDE
 * 2. In Remix, go to "File Managers" and create a new file called "PepedawnRaffle-Remix.sol"
 * 3. Paste this code
 * 4. Go to "Solidity Compiler" tab
 * 5. Set compiler version to 0.8.20+
 * 6. Compile the contract
 * 7. Go to "Deploy & Run Transactions" tab
 * 8. Deploy with constructor parameters (see constructor comments below)
 * 
 * NOTE: This is a simplified version for Remix testing. The production version
 * uses external libraries and has additional features. Always use the main
 * PepedawnRaffle.sol for production deployments.
 */

// Simplified interfaces for Remix compatibility
interface VRFCoordinatorV2Interface {
    function requestRandomWords(
        bytes32 keyHash,
        uint64 subId,
        uint16 minimumRequestConfirmations,
        uint32 callbackGasLimit,
        uint32 numWords
    ) external returns (uint256 requestId);
    
    function getRequestConfig() external view returns (uint16, uint32, bytes32[] memory);
}

interface VRFConsumerBaseV2 {
    function rawFulfillRandomWords(uint256 requestId, uint256[] memory randomWords) external;
}

// Simplified implementations for Remix
contract ReentrancyGuard {
    uint256 private constant _NOT_ENTERED = 1;
    uint256 private constant _ENTERED = 2;
    uint256 private _status;

    constructor() {
        _status = _NOT_ENTERED;
    }

    modifier nonReentrant() {
        require(_status != _ENTERED, "ReentrancyGuard: reentrant call");
        _status = _ENTERED;
        _;
        _status = _NOT_ENTERED;
    }
}

contract Pausable {
    bool private _paused;

    event Paused(address account);
    event Unpaused(address account);

    modifier whenNotPaused() {
        require(!_paused, "Pausable: paused");
        _;
    }

    modifier whenPaused() {
        require(_paused, "Pausable: not paused");
        _;
    }

    function paused() public view returns (bool) {
        return _paused;
    }

    function _pause() internal whenNotPaused {
        _paused = true;
        emit Paused(msg.sender);
    }

    function _unpause() internal whenPaused {
        _paused = false;
        emit Unpaused(msg.sender);
    }
}

contract Ownable2Step {
    address private _owner;
    address private _pendingOwner;

    event OwnershipTransferStarted(address indexed previousOwner, address indexed newOwner);
    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    constructor() {
        _owner = msg.sender;
        emit OwnershipTransferred(address(0), msg.sender);
    }

    modifier onlyOwner() {
        require(owner() == msg.sender, "Ownable: caller is not the owner");
        _;
    }

    function owner() public view returns (address) {
        return _owner;
    }

    function pendingOwner() public view returns (address) {
        return _pendingOwner;
    }

    function transferOwnership(address newOwner) public onlyOwner {
        _pendingOwner = newOwner;
        emit OwnershipTransferStarted(_owner, newOwner);
    }

    function acceptOwnership() external {
        address sender = msg.sender;
        require(pendingOwner() == sender, "Ownable2Step: caller is not the new owner");
        _transferOwnership(sender);
    }

    function _transferOwnership(address newOwner) internal {
        delete _pendingOwner;
        address oldOwner = _owner;
        _owner = newOwner;
        emit OwnershipTransferred(oldOwner, newOwner);
    }
}

/**
 * @title PepedawnRaffle (Remix Version)
 * @notice Simplified version for Remix IDE testing
 */
contract PepedawnRaffle is ReentrancyGuard, Pausable, Ownable2Step {
    // =============================================================================
    // CONSTANTS
    // =============================================================================
    
    uint256 public constant MIN_WAGER = 0.005 ether;
    uint256 public constant BUNDLE_5_PRICE = 0.0225 ether;
    uint256 public constant BUNDLE_10_PRICE = 0.04 ether;
    uint256 public constant WALLET_CAP = 1.0 ether;
    uint256 public constant PROOF_MULTIPLIER = 1400; // 1.4x = +40%
    uint256 public constant CREATORS_FEE_PCT = 80;
    uint256 public constant NEXT_ROUND_FEE_PCT = 20;
    uint256 public constant ROUND_DURATION = 2 weeks;
    
    // Prize tier constants
    uint8 public constant FAKE_PACK_TIER = 1;
    uint8 public constant KEK_PACK_TIER = 2;
    uint8 public constant PEPE_PACK_TIER = 3;
    
    // Security constants
    uint256 public constant MAX_PARTICIPANTS_PER_ROUND = 10000;
    uint256 public constant MAX_TOTAL_WAGER_PER_ROUND = 1000 ether;
    uint256 public constant VRF_REQUEST_TIMEOUT = 1 hours;
    
    // =============================================================================
    // ENUMS
    // =============================================================================
    
    enum RoundStatus {
        Created,
        Open,
        Closed,
        Snapshot,
        VRFRequested,
        Distributed
    }
    
    // =============================================================================
    // STATE VARIABLES
    // =============================================================================
    
    // VRF Configuration (set in constructor)
    VRFCoordinatorV2Interface public vrfCoordinator;
    uint64 public subscriptionId;
    bytes32 public keyHash;
    uint32 public callbackGasLimit = 500000;
    uint16 public requestConfirmations = 3;
    
    // Contract addresses
    address public creatorsAddress;
    address public emblemVaultAddress;
    
    // Round management
    uint256 public currentRoundId;
    mapping(uint256 => RoundInfo) public rounds;
    mapping(uint256 => mapping(address => ParticipantInfo)) public participants;
    
    // VRF state
    mapping(uint256 => uint256) public vrfRequests; // roundId => requestId
    mapping(uint256 => uint256) public vrfRequestTimes; // requestId => timestamp
    
    // =============================================================================
    // STRUCTS
    // =============================================================================
    
    struct RoundInfo {
        uint256 startTime;
        uint256 endTime;
        RoundStatus status;
        uint256 totalTickets;
        uint256 totalWeight;
        uint256 totalWagered;
        uint256 participantCount;
        uint256 vrfRequestId;
        uint256[] randomWords;
        address[] winners;
        uint256[] prizeTiers;
    }
    
    struct ParticipantInfo {
        uint256 totalWagered;
        uint256 ticketCount;
        uint256 effectiveWeight;
        bool hasSubmittedProof;
        bytes32 proofHash;
    }
    
    // =============================================================================
    // EVENTS
    // =============================================================================
    
    event RoundCreated(uint256 indexed roundId, uint256 startTime, uint256 endTime);
    event RoundOpened(uint256 indexed roundId);
    event RoundClosed(uint256 indexed roundId, uint256 totalTickets, uint256 totalWeight, uint256 totalWagered);
    event RoundSnapshot(uint256 indexed roundId, uint256 totalTickets, uint256 totalWeight);
    event VRFRequested(uint256 indexed roundId, uint256 requestId);
    event VRFReceived(uint256 indexed roundId, uint256 requestId, uint256[] randomWords);
    event BetPlaced(uint256 indexed roundId, address indexed wallet, uint256 amount, uint256 tickets, uint256 effectiveWeight);
    event ProofSubmitted(address indexed wallet, uint256 indexed roundId, bytes32 proofHash, uint256 newWeight);
    event PrizesDistributed(uint256 indexed roundId, address[] winners, uint256[] prizeTiers);
    event EmergencyWithdrawal(address indexed token, uint256 amount);
    
    // =============================================================================
    // CONSTRUCTOR
    // =============================================================================
    
    /**
     * @notice Constructor for PepedawnRaffle
     * @param _vrfCoordinator Chainlink VRF Coordinator address
     * @param _subscriptionId Chainlink VRF subscription ID
     * @param _keyHash Chainlink VRF key hash
     * @param _creatorsAddress Address to receive creator fees
     * @param _emblemVaultAddress Emblem Vault contract address
     * 
     * REMIX DEPLOYMENT PARAMETERS (for testing):
     * - _vrfCoordinator: Use testnet VRF coordinator (e.g., 0x...)
     * - _subscriptionId: Your VRF subscription ID (e.g., 123)
     * - _keyHash: VRF key hash for your network (e.g., 0x...)
     * - _creatorsAddress: Your wallet address for fees
     * - _emblemVaultAddress: Mock address for testing (e.g., 0x...)
     */
    constructor(
        address _vrfCoordinator,
        uint64 _subscriptionId,
        bytes32 _keyHash,
        address _creatorsAddress,
        address _emblemVaultAddress
    ) {
        vrfCoordinator = VRFCoordinatorV2Interface(_vrfCoordinator);
        subscriptionId = _subscriptionId;
        keyHash = _keyHash;
        creatorsAddress = _creatorsAddress;
        emblemVaultAddress = _emblemVaultAddress;
    }
    
    // =============================================================================
    // ROUND MANAGEMENT (Owner Only)
    // =============================================================================
    
    function createRound() external onlyOwner {
        require(
            currentRoundId == 0 || rounds[currentRoundId].status == RoundStatus.Distributed,
            "Previous round not completed"
        );
        
        currentRoundId++;
        uint256 startTime = block.timestamp;
        uint256 endTime = startTime + ROUND_DURATION;
        
        rounds[currentRoundId] = RoundInfo({
            startTime: startTime,
            endTime: endTime,
            status: RoundStatus.Created,
            totalTickets: 0,
            totalWeight: 0,
            totalWagered: 0,
            participantCount: 0,
            vrfRequestId: 0,
            randomWords: new uint256[](0),
            winners: new address[](0),
            prizeTiers: new uint256[](0)
        });
        
        emit RoundCreated(currentRoundId, startTime, endTime);
    }
    
    function openRound(uint256 roundId) external onlyOwner {
        require(rounds[roundId].status == RoundStatus.Created, "Round not in Created status");
        rounds[roundId].status = RoundStatus.Open;
        emit RoundOpened(roundId);
    }
    
    function closeRound(uint256 roundId) external onlyOwner {
        require(rounds[roundId].status == RoundStatus.Open, "Round not open");
        rounds[roundId].status = RoundStatus.Closed;
        
        RoundInfo storage round = rounds[roundId];
        emit RoundClosed(roundId, round.totalTickets, round.totalWeight, round.totalWagered);
    }
    
    function snapshotRound(uint256 roundId) external onlyOwner {
        require(rounds[roundId].status == RoundStatus.Closed, "Round not closed");
        rounds[roundId].status = RoundStatus.Snapshot;
        
        RoundInfo storage round = rounds[roundId];
        emit RoundSnapshot(roundId, round.totalTickets, round.totalWeight);
    }
    
    // =============================================================================
    // USER FUNCTIONS
    // =============================================================================
    
    function placeBet(uint256 tickets) external payable nonReentrant whenNotPaused {
        require(tickets == 1 || tickets == 5 || tickets == 10, "Invalid ticket count");
        require(currentRoundId > 0, "No active round");
        
        RoundInfo storage round = rounds[currentRoundId];
        require(round.status == RoundStatus.Open, "Round not open for betting");
        
        uint256 expectedPrice;
        if (tickets == 1) expectedPrice = MIN_WAGER;
        else if (tickets == 5) expectedPrice = BUNDLE_5_PRICE;
        else if (tickets == 10) expectedPrice = BUNDLE_10_PRICE;
        
        require(msg.value == expectedPrice, "Incorrect payment amount");
        
        ParticipantInfo storage participant = participants[currentRoundId][msg.sender];
        require(participant.totalWagered + msg.value <= WALLET_CAP, "Wallet cap exceeded");
        
        participant.totalWagered += msg.value;
        participant.ticketCount += tickets;
        
        // Calculate effective weight (with proof multiplier if applicable)
        uint256 baseWeight = tickets * 1000; // Base weight per ticket
        if (participant.hasSubmittedProof) {
            participant.effectiveWeight = (baseWeight * PROOF_MULTIPLIER) / 1000;
        } else {
            participant.effectiveWeight = baseWeight;
        }
        
        round.totalTickets += tickets;
        round.totalWeight += participant.effectiveWeight;
        round.totalWagered += msg.value;
        
        if (participant.ticketCount == tickets) { // First bet in this round
            round.participantCount++;
        }
        
        emit BetPlaced(currentRoundId, msg.sender, msg.value, tickets, participant.effectiveWeight);
    }
    
    function submitProof(bytes32 proofHash) external {
        require(currentRoundId > 0, "No active round");
        require(proofHash != bytes32(0), "Invalid proof hash");
        
        RoundInfo storage round = rounds[currentRoundId];
        require(round.status == RoundStatus.Open, "Round not open");
        
        ParticipantInfo storage participant = participants[currentRoundId][msg.sender];
        require(participant.ticketCount > 0, "Must place bet before submitting proof");
        require(!participant.hasSubmittedProof, "Proof already submitted for this round");
        
        participant.hasSubmittedProof = true;
        participant.proofHash = proofHash;
        
        // Recalculate weight with proof multiplier
        uint256 baseWeight = participant.ticketCount * 1000;
        uint256 newWeight = (baseWeight * PROOF_MULTIPLIER) / 1000;
        
        round.totalWeight = round.totalWeight - participant.effectiveWeight + newWeight;
        participant.effectiveWeight = newWeight;
        
        emit ProofSubmitted(msg.sender, currentRoundId, proofHash, newWeight);
    }
    
    // =============================================================================
    // VRF FUNCTIONS (Simplified for Remix)
    // =============================================================================
    
    function requestVRF(uint256 roundId) external onlyOwner {
        require(rounds[roundId].status == RoundStatus.Snapshot, "Round not in Snapshot status");
        require(rounds[roundId].totalTickets > 0, "No participants in round");
        
        uint256 requestId = vrfCoordinator.requestRandomWords(
            keyHash,
            subscriptionId,
            requestConfirmations,
            callbackGasLimit,
            1 // Number of random words needed
        );
        
        vrfRequests[roundId] = requestId;
        vrfRequestTimes[requestId] = block.timestamp;
        rounds[roundId].vrfRequestId = requestId;
        rounds[roundId].status = RoundStatus.VRFRequested;
        
        emit VRFRequested(roundId, requestId);
    }
    
    // Simplified VRF fulfillment for Remix testing
    function fulfillRandomWords(uint256 requestId, uint256[] memory randomWords) external {
        // In production, this would be called by VRF Coordinator
        // For Remix testing, we'll allow manual calls
        
        uint256 roundId = 0;
        for (uint256 i = 1; i <= currentRoundId; i++) {
            if (vrfRequests[i] == requestId) {
                roundId = i;
                break;
            }
        }
        
        require(roundId > 0, "Invalid request ID");
        require(rounds[roundId].status == RoundStatus.VRFRequested, "Round not in VRFRequested status");
        
        rounds[roundId].randomWords = randomWords;
        
        // Simple winner selection for Remix testing
        _selectWinners(roundId, randomWords[0]);
        
        emit VRFReceived(roundId, requestId, randomWords);
    }
    
    function _selectWinners(uint256 roundId, uint256 randomWord) internal {
        RoundInfo storage round = rounds[roundId];
        
        // Simplified winner selection for Remix testing
        // In production, this would use weighted random selection
        uint256 winnerCount = 10; // 1 Fake + 1 Kek + 8 Pepe
        address[] memory winnerList = new address[](winnerCount);
        uint256[] memory prizeList = new uint256[](winnerCount);
        
        // Mock winners for testing (in production, use proper weighted selection)
        for (uint256 i = 0; i < winnerCount; i++) {
            winnerList[i] = address(uint160(randomWord + i));
            if (i == 0) prizeList[i] = FAKE_PACK_TIER;
            else if (i == 1) prizeList[i] = KEK_PACK_TIER;
            else prizeList[i] = PEPE_PACK_TIER;
        }
        
        round.winners = winnerList;
        round.prizeTiers = prizeList;
        round.status = RoundStatus.Distributed;
        
        emit PrizesDistributed(roundId, winnerList, prizeList);
    }
    
    // =============================================================================
    // VIEW FUNCTIONS
    // =============================================================================
    
    function getRoundInfo(uint256 roundId) external view returns (RoundInfo memory) {
        return rounds[roundId];
    }
    
    function getParticipantInfo(uint256 roundId, address participant) external view returns (ParticipantInfo memory) {
        return participants[roundId][participant];
    }
    
    function getCurrentRoundStatus() external view returns (RoundStatus) {
        if (currentRoundId == 0) return RoundStatus.Created;
        return rounds[currentRoundId].status;
    }
    
    // =============================================================================
    // EMERGENCY FUNCTIONS
    // =============================================================================
    
    function pause() external onlyOwner {
        _pause();
    }
    
    function unpause() external onlyOwner {
        _unpause();
    }
    
    function emergencyWithdraw() external onlyOwner {
        uint256 balance = address(this).balance;
        require(balance > 0, "No funds to withdraw");
        
        (bool success, ) = payable(creatorsAddress).call{value: balance}("");
        require(success, "Withdrawal failed");
        
        emit EmergencyWithdrawal(address(0), balance);
    }
    
    // =============================================================================
    // RECEIVE FUNCTION
    // =============================================================================
    
    receive() external payable {
        // Allow contract to receive ETH
    }
}
