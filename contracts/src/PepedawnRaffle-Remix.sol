// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

// Simplified VRF interface for Remix testing
interface VRFCoordinatorV2Interface {
  function requestRandomWords(
    bytes32 keyHash,
    uint64 subId,
    uint16 minimumRequestConfirmations,
    uint32 callbackGasLimit,
    uint32 numWords
  ) external returns (uint256 requestId);
}

// Simplified VRF Consumer Base for Remix testing
abstract contract VRFConsumerBaseV2 {
  VRFCoordinatorV2Interface internal immutable i_vrfCoordinator;
  
  constructor(address _vrfCoordinator) {
    i_vrfCoordinator = VRFCoordinatorV2Interface(_vrfCoordinator);
  }
  
  function rawFulfillRandomWords(uint256 requestId, uint256[] memory randomWords) external {
    if (msg.sender != address(i_vrfCoordinator)) {
      revert("OnlyCoordinatorCanFulfill");
    }
    fulfillRandomWords(requestId, randomWords);
  }
  
  function fulfillRandomWords(uint256 requestId, uint256[] memory randomWords) internal virtual;
}

/**
 * @title PepedawnRaffle (Remix Version)
 * @notice Skill-weighted decentralized raffle with Chainlink VRF and Emblem Vault prizes
 * @dev Simplified version for Remix IDE testing
 */
contract PepedawnRaffle is VRFConsumerBaseV2 {
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
        uint256 totalWagered;
        uint256 totalTickets;
        uint256 totalWeight;
        mapping(address => bool) hasProof;
        mapping(address => UserStats) userStats;
        uint256[] randomWords;
        uint256 vrfRequestId;
    }
    
    struct UserStats {
        uint256 wagered;
        uint256 tickets;
        uint256 weight;
        bool hasProof;
    }
    
    // =============================================================================
    // STATE VARIABLES
    // =============================================================================
    
    address public immutable creatorsAddress;
    address public immutable emblemVaultAddress;
    uint256 public currentRoundId;
    mapping(uint256 => Round) public rounds;
    
    // VRF Configuration
    bytes32 public immutable keyHash;
    uint64 public immutable subscriptionId;
    uint16 public constant REQUEST_CONFIRMATIONS = 3;
    uint32 public constant CALLBACK_GAS_LIMIT = 500000;
    
    // =============================================================================
    // EVENTS
    // =============================================================================
    
    event RoundCreated(uint256 indexed roundId, uint64 startTime, uint64 endTime);
    event RoundOpened(uint256 indexed roundId);
    event RoundClosed(uint256 indexed roundId);
    event BetPlaced(uint256 indexed roundId, address indexed user, uint256 amount, uint256 tickets, uint256 weight);
    event ProofSubmitted(uint256 indexed roundId, address indexed user, uint256 weight);
    event VRFRequested(uint256 indexed roundId, uint256 indexed requestId);
    event PrizesDistributed(uint256 indexed roundId, uint256[] randomWords);
    
    // =============================================================================
    // MODIFIERS
    // =============================================================================
    
    modifier onlyOwner() {
        require(msg.sender == creatorsAddress, "Only creators can call this function");
        _;
    }
    
    modifier validRound(uint256 _roundId) {
        require(_roundId > 0 && _roundId <= currentRoundId, "Invalid round ID");
        _;
    }
    
    // =============================================================================
    // CONSTRUCTOR
    // =============================================================================
    
    constructor(
        address _vrfCoordinator,
        uint64 _subscriptionId,
        bytes32 _keyHash,
        address _creatorsAddress,
        address _emblemVaultAddress
    ) VRFConsumerBaseV2(_vrfCoordinator) {
        subscriptionId = _subscriptionId;
        keyHash = _keyHash;
        creatorsAddress = _creatorsAddress;
        emblemVaultAddress = _emblemVaultAddress;
    }
    
    // =============================================================================
    // EXTERNAL FUNCTIONS
    // =============================================================================
    
    /**
     * @notice Create a new round
     * @dev Only the creators address can create rounds
     */
    function createRound() external onlyOwner {
        currentRoundId++;
        uint64 startTime = uint64(block.timestamp);
        uint64 endTime = uint64(startTime + ROUND_DURATION);
        
        Round storage round = rounds[currentRoundId];
        round.id = currentRoundId;
        round.startTime = startTime;
        round.endTime = endTime;
        round.status = RoundStatus.Created;
        
        emit RoundCreated(currentRoundId, startTime, endTime);
    }
    
    /**
     * @notice Open a round for betting
     * @param _roundId The round ID to open
     */
    function openRound(uint256 _roundId) external onlyOwner validRound(_roundId) {
        Round storage round = rounds[_roundId];
        require(round.status == RoundStatus.Created, "Round must be in Created status");
        
        round.status = RoundStatus.Open;
        emit RoundOpened(_roundId);
    }
    
    /**
     * @notice Close a round
     * @param _roundId The round ID to close
     */
    function closeRound(uint256 _roundId) external onlyOwner validRound(_roundId) {
        Round storage round = rounds[_roundId];
        require(round.status == RoundStatus.Open, "Round must be in Open status");
        
        round.status = RoundStatus.Closed;
        emit RoundClosed(_roundId);
    }
    
    /**
     * @notice Place a bet in the current round
     * @dev Calculates ticket count and applies proof multiplier if applicable
     */
    function placeBet(uint256 _roundId) external payable validRound(_roundId) {
        Round storage round = rounds[_roundId];
        require(round.status == RoundStatus.Open, "Round must be open");
        require(msg.value >= MIN_WAGER, "Bet amount below minimum");
        
        UserStats storage userStats = round.userStats[msg.sender];
        uint256 newTotalWagered = userStats.wagered + msg.value;
        require(newTotalWagered <= WALLET_CAP, "Exceeds wallet cap");
        
        // Calculate tickets based on amount
        uint256 tickets = _calculateTickets(msg.value);
        
        // Apply proof multiplier if user has proof
        uint256 weight = tickets;
        if (userStats.hasProof) {
            weight = (tickets * PROOF_MULTIPLIER) / 1000;
        }
        
        // Update user stats
        userStats.wagered = newTotalWagered;
        userStats.tickets += tickets;
        userStats.weight += weight;
        
        // Update round totals
        round.totalWagered += msg.value;
        round.totalTickets += tickets;
        round.totalWeight += weight;
        
        emit BetPlaced(_roundId, msg.sender, msg.value, tickets, weight);
    }
    
    /**
     * @notice Submit a proof for weight multiplier
     * @param _roundId The round ID
     * @param _proof The proof data (simplified for Remix)
     */
    function submitProof(uint256 _roundId, bytes32 _proof) external validRound(_roundId) {
        Round storage round = rounds[_roundId];
        require(round.status == RoundStatus.Open, "Round must be open");
        require(!round.hasProof[msg.sender], "Proof already submitted");
        
        // Simplified proof validation (in real implementation, this would verify the proof)
        require(_proof != bytes32(0), "Invalid proof");
        
        round.hasProof[msg.sender] = true;
        
        UserStats storage userStats = round.userStats[msg.sender];
        userStats.hasProof = true;
        
        // Recalculate weight with multiplier
        uint256 oldWeight = userStats.weight;
        uint256 newWeight = (userStats.tickets * PROOF_MULTIPLIER) / 1000;
        userStats.weight = newWeight;
        
        // Update round total weight
        round.totalWeight = round.totalWeight - oldWeight + newWeight;
        
        emit ProofSubmitted(_roundId, msg.sender, newWeight);
    }
    
    /**
     * @notice Request VRF for prize distribution
     * @param _roundId The round ID to distribute prizes for
     */
    function requestVRF(uint256 _roundId) external onlyOwner validRound(_roundId) {
        Round storage round = rounds[_roundId];
        require(round.status == RoundStatus.Closed, "Round must be closed");
        
        round.status = RoundStatus.Snapshot;
        
        uint256 requestId = i_vrfCoordinator.requestRandomWords(
            keyHash,
            subscriptionId,
            REQUEST_CONFIRMATIONS,
            CALLBACK_GAS_LIMIT,
            1
        );
        
        round.vrfRequestId = requestId;
        round.status = RoundStatus.VRFRequested;
        
        emit VRFRequested(_roundId, requestId);
    }
    
    /**
     * @notice VRF callback function
     * @param requestId The VRF request ID
     * @param randomWords Array of random words
     */
    function fulfillRandomWords(uint256 requestId, uint256[] memory randomWords) internal override {
        // Find the round with this request ID
        uint256 roundId = 0;
        for (uint256 i = 1; i <= currentRoundId; i++) {
            if (rounds[i].vrfRequestId == requestId) {
                roundId = i;
                break;
            }
        }
        
        require(roundId > 0, "Invalid request ID");
        
        Round storage round = rounds[roundId];
        round.randomWords = randomWords;
        round.status = RoundStatus.Distributed;
        
        emit PrizesDistributed(roundId, randomWords);
    }
    
    // =============================================================================
    // VIEW FUNCTIONS
    // =============================================================================
    
    /**
     * @notice Get round information
     * @param _roundId The round ID
     * @return id Round ID
     * @return startTime Round start time
     * @return endTime Round end time
     * @return status Round status
     * @return totalWagered Total ETH wagered in round
     * @return totalTickets Total tickets in round
     * @return totalWeight Total weight in round
     * @return vrfRequestId VRF request ID
     */
    function getRound(uint256 _roundId) external view validRound(_roundId) returns (
        uint256 id,
        uint64 startTime,
        uint64 endTime,
        RoundStatus status,
        uint256 totalWagered,
        uint256 totalTickets,
        uint256 totalWeight,
        uint256 vrfRequestId
    ) {
        Round storage round = rounds[_roundId];
        return (
            round.id,
            round.startTime,
            round.endTime,
            round.status,
            round.totalWagered,
            round.totalTickets,
            round.totalWeight,
            round.vrfRequestId
        );
    }
    
    /**
     * @notice Get user statistics for a round
     * @param _roundId The round ID
     * @param _user The user address
     * @return wagered Amount wagered by user
     * @return tickets Number of tickets user has
     * @return weight User's total weight
     * @return hasProof Whether user has submitted proof
     */
    function getUserStats(uint256 _roundId, address _user) external view validRound(_roundId) returns (
        uint256 wagered,
        uint256 tickets,
        uint256 weight,
        bool hasProof
    ) {
        UserStats storage userStats = rounds[_roundId].userStats[_user];
        return (
            userStats.wagered,
            userStats.tickets,
            userStats.weight,
            userStats.hasProof
        );
    }
    
    // =============================================================================
    // INTERNAL FUNCTIONS
    // =============================================================================
    
    /**
     * @notice Calculate number of tickets based on ETH amount
     * @param _amount The ETH amount
     * @return Number of tickets
     */
    function _calculateTickets(uint256 _amount) internal pure returns (uint256) {
        if (_amount >= BUNDLE_10_PRICE) {
            return 10;
        } else if (_amount >= BUNDLE_5_PRICE) {
            return 5;
        } else {
            return 1;
        }
    }
}