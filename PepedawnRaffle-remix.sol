// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

// Remix-compatible imports
import "@chainlink/contracts/src/v0.8/interfaces/VRFCoordinatorV2Interface.sol";
import "@chainlink/contracts/src/v0.8/VRFConsumerBaseV2.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

/**
 * @title PepedawnRaffle
 * @dev A raffle contract for the Pepedawn ecosystem
 */
contract PepedawnRaffle is VRFConsumerBaseV2, Ownable, Pausable, ReentrancyGuard {
    // =============================================================================
    // CONSTANTS
    // =============================================================================
    
    uint256 public constant SINGLE_TICKET_PRICE = 0.01 ether;
    uint256 public constant BUNDLE_5_PRICE = 0.045 ether; // 10% discount
    uint256 public constant BUNDLE_10_PRICE = 0.08 ether; // 20% discount
    
    uint256 public constant ROUND_DURATION = 7 days;
    
    uint256 public constant CREATORS_FEE_PCT = 10; // 10%
    uint256 public constant EMBLEM_VAULT_FEE_PCT = 5; // 5%
    
    uint256 public constant PUZZLE_WEIGHT_MULTIPLIER = 2; // 2x weight for puzzle solvers
    
    uint256 public constant MAX_PARTICIPANTS_PER_ROUND = 10000; // Circuit breaker
    uint256 public constant VRF_REQUEST_TIMEOUT = 1 hours; // VRF timeout
    
    uint8 public constant FAKE_PACK_TIER = 1;
    uint8 public constant REAL_PACK_TIER = 2;
    uint8 public constant LEGENDARY_PACK_TIER = 3;
    
    // =============================================================================
    // ENUMS
    // =============================================================================
    
    enum RoundStatus {
        Created,    // Round created but not open for betting
        Open,       // Round open for betting and proofs
        Closed,     // Round closed, no more bets/proofs
        Snapshot,   // Snapshot taken, ready for VRF
        VRFRequested, // VRF requested, waiting for fulfillment
        Distributed // Prizes distributed, round complete
    }
    
    // =============================================================================
    // STRUCTS
    // =============================================================================
    
    struct Round {
        uint256 id;
        uint64 startTime;
        uint64 endTime;
        RoundStatus status;
        uint256 totalTickets;
        uint256 totalWeight;
        uint256 totalWagered;
        uint256 vrfRequestId;
        uint64 vrfRequestedAt; // Timestamp when VRF was requested
        bool feesDistributed;
        uint256 participantCount; // Track number of participants for circuit breaker
    }
    
    struct VRFConfig {
        VRFCoordinatorV2Interface coordinator;
        uint64 subscriptionId;
        bytes32 keyHash;
        uint32 callbackGasLimit;
        uint16 requestConfirmations;
    }
    
    // =============================================================================
    // STATE VARIABLES
    // =============================================================================
    
    address public creatorsAddress;
    address public emblemVaultAddress;
    
    uint256 public currentRoundId;
    uint256 public nextRoundFunds;
    
    VRFConfig public vrfConfig;
    
    // Security state variables
    mapping(address => bool) public denylisted;
    bool public emergencyPaused;
    uint256 public lastVRFRequestTime;
    
    // Mappings
    mapping(uint256 => Round) public rounds;
    mapping(uint256 => mapping(address => uint256)) public userWageredInRound;
    mapping(uint256 => mapping(address => uint256)) public userTicketsInRound;
    
    // =============================================================================
    // EVENTS
    // =============================================================================
    
    event RoundCreated(uint256 indexed roundId, uint64 startTime, uint64 endTime);
    event RoundOpened(uint256 indexed roundId);
    event RoundClosed(uint256 indexed roundId);
    
    // =============================================================================
    // CONSTRUCTOR
    // =============================================================================
    
    constructor(
        address _vrfCoordinator,
        uint64 _subscriptionId,
        bytes32 _keyHash,
        address _creatorsAddress,
        address _emblemVaultAddress
    ) 
        VRFConsumerBaseV2(_vrfCoordinator) 
        Ownable(msg.sender)
    {
        require(_vrfCoordinator != address(0), "Invalid VRF coordinator");
        require(_creatorsAddress != address(0), "Invalid creators address");
        require(_emblemVaultAddress != address(0), "Invalid emblem vault address");
        require(_subscriptionId > 0, "Invalid VRF subscription ID");
        
        vrfConfig = VRFConfig({
            coordinator: VRFCoordinatorV2Interface(_vrfCoordinator),
            subscriptionId: _subscriptionId,
            keyHash: _keyHash,
            callbackGasLimit: 100000,
            requestConfirmations: 3
        });
        
        creatorsAddress = _creatorsAddress;
        emblemVaultAddress = _emblemVaultAddress;
    }
    
    // =============================================================================
    // ROUND MANAGEMENT
    // =============================================================================
    
    /**
     * @notice Create a new round
     */
    function createRound() external onlyOwner whenNotPaused {
        if (currentRoundId > 0) {
            require(
                rounds[currentRoundId].status == RoundStatus.Distributed,
                "Previous round not completed"
            );
        }
        
        currentRoundId++;
        
        uint64 startTime = uint64(block.timestamp);
        uint64 endTime = startTime + uint64(ROUND_DURATION);
        
        rounds[currentRoundId] = Round({
            id: currentRoundId,
            startTime: startTime,
            endTime: endTime,
            status: RoundStatus.Created,
            totalTickets: 0,
            totalWeight: 0,
            totalWagered: 0,
            vrfRequestId: 0,
            vrfRequestedAt: 0,
            feesDistributed: false,
            participantCount: 0
        });
        
        emit RoundCreated(currentRoundId, startTime, endTime);
    }
    
    /**
     * @notice Open a round for betting
     */
    function openRound(uint256 roundId) external onlyOwner whenNotPaused {
        require(roundId > 0 && roundId <= currentRoundId, "Round does not exist");
        require(rounds[roundId].status == RoundStatus.Created, "Round not in Created status");
        
        rounds[roundId].status = RoundStatus.Open;
        emit RoundOpened(roundId);
    }
    
    /**
     * @notice Close a round
     */
    function closeRound(uint256 roundId) external onlyOwner whenNotPaused {
        require(roundId > 0 && roundId <= currentRoundId, "Round does not exist");
        require(rounds[roundId].status == RoundStatus.Open, "Round not in Open status");
        
        rounds[roundId].status = RoundStatus.Closed;
        emit RoundClosed(roundId);
    }
    
    // =============================================================================
    // PLACEHOLDER FUNCTIONS
    // =============================================================================
    
    /**
     * @notice Place a bet (placeholder)
     */
    function placeBet(uint256 tickets) external payable nonReentrant whenNotPaused {
        require(tickets == 1 || tickets == 5 || tickets == 10, "Invalid ticket count");
        require(currentRoundId > 0, "No active round");
        require(rounds[currentRoundId].status == RoundStatus.Open, "Round not open");
        
        uint256 expectedPrice;
        if (tickets == 1) {
            expectedPrice = SINGLE_TICKET_PRICE;
        } else if (tickets == 5) {
            expectedPrice = BUNDLE_5_PRICE;
        } else {
            expectedPrice = BUNDLE_10_PRICE;
        }
        
        require(msg.value == expectedPrice, "Incorrect payment amount");
        
        // Update round state
        Round storage round = rounds[currentRoundId];
        round.totalTickets += tickets;
        round.totalWagered += msg.value;
        
        // Update user state
        userWageredInRound[currentRoundId][msg.sender] += msg.value;
        userTicketsInRound[currentRoundId][msg.sender] += tickets;
    }
    
    // =============================================================================
    // VRF CALLBACK (Required by VRFConsumerBaseV2)
    // =============================================================================
    
    function fulfillRandomWords(uint256 requestId, uint256[] memory /* randomWords */) internal override {
        // Placeholder implementation
        uint256 roundId = vrfRequestToRound[requestId];
        if (roundId > 0) {
            rounds[roundId].status = RoundStatus.Distributed;
        }
    }
    
    // =============================================================================
    // VIEW FUNCTIONS
    // =============================================================================
    
    /**
     * @notice Get round details
     */
    function getRound(uint256 roundId) external view returns (Round memory) {
        return rounds[roundId];
    }
    
    /**
     * @notice Get user stats for a round
     */
    function getUserRoundStats(uint256 roundId, address user) 
        external 
        view 
        returns (uint256 wagered, uint256 tickets) 
    {
        return (
            userWageredInRound[roundId][user],
            userTicketsInRound[roundId][user]
        );
    }
    
    // Required mapping for VRF
    mapping(uint256 => uint256) public vrfRequestToRound;
}
