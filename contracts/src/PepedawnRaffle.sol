// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@chainlink/contracts/vrf/interfaces/VRFCoordinatorV2Interface.sol";
import "@chainlink/contracts/vrf/VRFConsumerBaseV2.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/Pausable.sol";
import "@openzeppelin/contracts/access/Ownable2Step.sol";

/**
 * @title PepedawnRaffle
 * @notice Skill-weighted decentralized raffle with Chainlink VRF and Emblem Vault prizes
 * @dev Implements 2-week rounds with ETH wagers, puzzle proofs for +40% weight, and automatic distribution
 */
contract PepedawnRaffle is VRFConsumerBaseV2, ReentrancyGuard, Pausable, Ownable2Step {
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
    uint256 public constant MAX_PARTICIPANTS_PER_ROUND = 10000; // Circuit breaker
    uint256 public constant MAX_TOTAL_WAGER_PER_ROUND = 1000 ether; // Circuit breaker
    uint256 public constant VRF_REQUEST_TIMEOUT = 1 hours; // VRF timeout protection
    
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
    
    struct Wager {
        address wallet;
        uint256 roundId;
        uint256 amount;
        uint256 tickets;
        uint256 effectiveWeight;
        uint64 createdAt;
    }
    
    struct PuzzleProof {
        address wallet;
        uint256 roundId;
        bytes32 proofHash;
        bool verified;
        uint64 submittedAt;
    }
    
    struct WinnerAssignment {
        uint256 roundId;
        address wallet;
        uint8 prizeTier;
        uint256 vrfRequestId;
        uint256 blockNumber;
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
    mapping(address => bool) public denylisted; // Denylist for blocked addresses
    mapping(uint256 => mapping(address => bool)) private _winnerSelected; // Prevent duplicate winners
    bool public emergencyPaused; // Additional emergency pause state
    uint256 public lastVRFRequestTime; // Track VRF request timing
    
    // Mappings
    mapping(uint256 => Round) public rounds;
    mapping(uint256 => mapping(address => uint256)) public userWageredInRound;
    mapping(uint256 => mapping(address => uint256)) public userTicketsInRound;
    mapping(uint256 => mapping(address => uint256)) public userWeightInRound;
    mapping(uint256 => mapping(address => bool)) public userHasProofInRound;
    mapping(uint256 => mapping(address => PuzzleProof)) public userProofInRound;
    mapping(uint256 => WinnerAssignment[]) public roundWinners;
    mapping(uint256 => uint256) public vrfRequestToRound;
    
    // Arrays for enumeration
    mapping(uint256 => address[]) public roundParticipants;
    mapping(uint256 => mapping(address => bool)) public isParticipant;
    
    // =============================================================================
    // EVENTS
    // =============================================================================
    
    // Round events
    event RoundCreated(uint256 indexed roundId, uint64 startTime, uint64 endTime);
    event RoundOpened(uint256 indexed roundId);
    event RoundClosed(uint256 indexed roundId);
    event RoundSnapshot(uint256 indexed roundId, uint256 totalTickets, uint256 totalWeight);
    
    // Wager events
    event WagerPlaced(
        address indexed wallet,
        uint256 indexed roundId,
        uint256 amount,
        uint256 tickets,
        uint256 effectiveWeight
    );
    
    // Proof events
    event ProofSubmitted(
        address indexed wallet,
        uint256 indexed roundId,
        bytes32 proofHash,
        uint256 newWeight
    );
    
    // VRF events
    event VRFRequested(uint256 indexed roundId, uint256 indexed requestId);
    event VRFFulfilled(uint256 indexed roundId, uint256 indexed requestId, uint256[] randomWords);
    
    // Distribution events
    event WinnersAssigned(uint256 indexed roundId, address[] winners, uint8[] prizeTiers);
    event PrizeDistributed(
        uint256 indexed roundId,
        address indexed winner,
        uint8 prizeTier,
        uint256 assetId
    );
    event FeesDistributed(
        uint256 indexed roundId,
        address indexed creators,
        uint256 creatorsAmount,
        uint256 nextRoundAmount
    );
    
    // Emblem Vault integration events
    event EmblemVaultPrizeAssigned(
        uint256 indexed roundId,
        address indexed winner,
        uint256 indexed assetId,
        uint256 timestamp
    );
    event RoundPrizesDistributed(
        uint256 indexed roundId,
        uint256 winnerCount,
        uint256 timestamp
    );
    
    // Security events
    event AddressDenylisted(address indexed wallet, bool denylisted);
    event EmergencyPauseToggled(bool paused);
    event VRFTimeoutDetected(uint256 indexed roundId, uint256 requestId);
    event CircuitBreakerTriggered(uint256 indexed roundId, string reason);
    event SecurityValidationFailed(address indexed user, string reason);
    
    // =============================================================================
    // MODIFIERS
    // =============================================================================
    
    modifier roundExists(uint256 roundId) {
        require(roundId > 0 && roundId <= currentRoundId, "Round does not exist");
        _;
    }
    
    modifier roundInStatus(uint256 roundId, RoundStatus status) {
        require(rounds[roundId].status == status, "Round not in required status");
        _;
    }
    
    modifier onlyVRFCoordinator() {
        require(msg.sender == address(vrfConfig.coordinator), "Only VRF coordinator");
        _;
    }
    
    modifier notDenylisted(address user) {
        require(!denylisted[user], "Address is denylisted");
        _;
    }
    
    modifier whenNotEmergencyPaused() {
        require(!emergencyPaused, "Emergency pause is active");
        _;
    }
    
    modifier validAddress(address addr) {
        require(addr != address(0), "Invalid address: zero address");
        require(addr != address(this), "Invalid address: contract address");
        _;
    }
    
    modifier validAmount(uint256 amount) {
        require(amount > 0, "Invalid amount: must be greater than zero");
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
    ) 
        VRFConsumerBaseV2(_vrfCoordinator) 
        Ownable(msg.sender)
        validAddress(_vrfCoordinator)
        validAddress(_creatorsAddress)
        validAddress(_emblemVaultAddress)
    {
        // Input validation
        require(_subscriptionId > 0, "Invalid VRF subscription ID");
        require(_keyHash != bytes32(0), "Invalid VRF key hash");
        
        creatorsAddress = _creatorsAddress;
        emblemVaultAddress = _emblemVaultAddress;
        
        vrfConfig = VRFConfig({
            coordinator: VRFCoordinatorV2Interface(_vrfCoordinator),
            subscriptionId: _subscriptionId,
            keyHash: _keyHash,
            callbackGasLimit: 100000,
            requestConfirmations: 3
        });
        
        // Initialize security state
        emergencyPaused = false;
        lastVRFRequestTime = 0;
    }
    
    // =============================================================================
    // SECURITY MANAGEMENT FUNCTIONS
    // =============================================================================
    
    /**
     * @notice Toggle denylist status for an address
     * @param wallet Address to toggle denylist status
     * @param isDenylisted Whether to denylist or remove from denylist
     */
    function setDenylistStatus(address wallet, bool isDenylisted) 
        external 
        onlyOwner 
        validAddress(wallet) 
    {
        denylisted[wallet] = isDenylisted;
        emit AddressDenylisted(wallet, isDenylisted);
    }
    
    /**
     * @notice Emergency pause toggle (additional to Pausable contract)
     * @param paused Whether to pause or unpause
     */
    function setEmergencyPause(bool paused) external onlyOwner {
        emergencyPaused = paused;
        emit EmergencyPauseToggled(paused);
    }
    
    /**
     * @notice Pause contract (Pausable functionality)
     */
    function pause() external onlyOwner {
        _pause();
    }
    
    /**
     * @notice Unpause contract (Pausable functionality)
     */
    function unpause() external onlyOwner {
        _unpause();
    }
    
    /**
     * @notice Update VRF configuration with validation
     * @param _coordinator New VRF coordinator address
     * @param _subscriptionId New subscription ID
     * @param _keyHash New key hash
     */
    function updateVRFConfig(
        address _coordinator,
        uint64 _subscriptionId,
        bytes32 _keyHash
    ) external onlyOwner validAddress(_coordinator) {
        require(_subscriptionId > 0, "Invalid VRF subscription ID");
        require(_keyHash != bytes32(0), "Invalid VRF key hash");
        
        vrfConfig.coordinator = VRFCoordinatorV2Interface(_coordinator);
        vrfConfig.subscriptionId = _subscriptionId;
        vrfConfig.keyHash = _keyHash;
    }
    
    /**
     * @notice Update creators address with validation
     * @param _creatorsAddress New creators address
     */
    function updateCreatorsAddress(address _creatorsAddress) 
        external 
        onlyOwner 
        validAddress(_creatorsAddress) 
    {
        creatorsAddress = _creatorsAddress;
    }
    
    /**
     * @notice Update Emblem Vault address with validation
     * @param _emblemVaultAddress New Emblem Vault address
     */
    function updateEmblemVaultAddress(address _emblemVaultAddress) 
        external 
        onlyOwner 
        validAddress(_emblemVaultAddress) 
    {
        emblemVaultAddress = _emblemVaultAddress;
    }
    
    // =============================================================================
    // ROUND LIFECYCLE FUNCTIONS
    // =============================================================================
    
    /**
     * @notice Create a new round
     * @dev Only owner can create rounds. Previous round should be completed.
     */
    function createRound() external onlyOwner whenNotPaused whenNotEmergencyPaused {
        // Checks: Ensure previous round is completed (if exists)
        if (currentRoundId > 0) {
            require(
                rounds[currentRoundId].status == RoundStatus.Distributed,
                "Previous round not completed"
            );
        }
        
        // Effects: Update state
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
        
        // Interactions: Emit event
        emit RoundCreated(currentRoundId, startTime, endTime);
    }
    
    /**
     * @notice Open a round for betting
     * @param roundId The round to open
     */
    function openRound(uint256 roundId) 
        external 
        onlyOwner 
        whenNotPaused 
        whenNotEmergencyPaused
        roundExists(roundId) 
        roundInStatus(roundId, RoundStatus.Created) 
    {
        rounds[roundId].status = RoundStatus.Open;
        emit RoundOpened(roundId);
    }
    
    /**
     * @notice Close a round (no more bets/proofs)
     * @param roundId The round to close
     */
    function closeRound(uint256 roundId) 
        external 
        onlyOwner 
        whenNotPaused 
        whenNotEmergencyPaused
        roundExists(roundId) 
        roundInStatus(roundId, RoundStatus.Open) 
    {
        Round storage round = rounds[roundId];
        round.status = RoundStatus.Closed;
        emit RoundClosed(roundId);
    }
    
    /**
     * @notice Take snapshot before VRF request
     * @param roundId The round to snapshot
     */
    function snapshotRound(uint256 roundId) 
        external 
        onlyOwner 
        whenNotPaused 
        whenNotEmergencyPaused
        roundExists(roundId) 
        roundInStatus(roundId, RoundStatus.Closed) 
    {
        Round storage round = rounds[roundId];
        round.status = RoundStatus.Snapshot;
        
        emit RoundSnapshot(roundId, round.totalTickets, round.totalWeight);
    }
    
    // =============================================================================
    // PLACEHOLDER FUNCTIONS (TO BE IMPLEMENTED)
    // =============================================================================
    
    /**
     * @notice Place a bet in the current round
     * @param tickets Number of tickets to purchase (1, 5, or 10)
     */
    function placeBet(uint256 tickets) 
        external 
        payable 
        nonReentrant 
        whenNotPaused 
        whenNotEmergencyPaused 
        notDenylisted(msg.sender)
        validAmount(msg.value)
    {
        // Checks: Validate round is open
        require(currentRoundId > 0, "No active round");
        Round storage round = rounds[currentRoundId];
        require(round.status == RoundStatus.Open, "Round not open for betting");
        
        // Checks: Circuit breaker - max participants
        if (!isParticipant[currentRoundId][msg.sender]) {
            require(
                round.participantCount < MAX_PARTICIPANTS_PER_ROUND,
                "Max participants reached for this round"
            );
        }
        
        // Checks: Validate ticket count and payment
        uint256 expectedAmount;
        if (tickets == 1) {
            expectedAmount = MIN_WAGER;
        } else if (tickets == 5) {
            expectedAmount = BUNDLE_5_PRICE;
        } else if (tickets == 10) {
            expectedAmount = BUNDLE_10_PRICE;
        } else {
            revert("Invalid ticket count (must be 1, 5, or 10)");
        }
        
        require(msg.value == expectedAmount, "Incorrect payment amount");
        
        // Checks: Validate wallet cap
        uint256 newTotal = userWageredInRound[currentRoundId][msg.sender] + msg.value;
        require(newTotal <= WALLET_CAP, "Exceeds wallet cap of 1.0 ETH");
        
        // Checks: Circuit breaker - max total wager per round
        require(
            round.totalWagered + msg.value <= MAX_TOTAL_WAGER_PER_ROUND,
            "Max total wager reached for this round"
        );
        
        // Effects: Update user state
        userWageredInRound[currentRoundId][msg.sender] = newTotal;
        userTicketsInRound[currentRoundId][msg.sender] += tickets;
        
        // Calculate effective weight (base = tickets, modified by proof if exists)
        uint256 effectiveWeight = tickets;
        if (userHasProofInRound[currentRoundId][msg.sender]) {
            effectiveWeight = (tickets * PROOF_MULTIPLIER) / 1000;
        }
        userWeightInRound[currentRoundId][msg.sender] += effectiveWeight;
        
        // Effects: Update round totals
        round.totalTickets += tickets;
        round.totalWeight += effectiveWeight;
        round.totalWagered += msg.value;
        
        // Effects: Add to participants if first bet
        if (!isParticipant[currentRoundId][msg.sender]) {
            roundParticipants[currentRoundId].push(msg.sender);
            isParticipant[currentRoundId][msg.sender] = true;
            round.participantCount++;
        }
        
        // Interactions: Emit event
        emit WagerPlaced(
            msg.sender,
            currentRoundId,
            msg.value,
            tickets,
            effectiveWeight
        );
    }
    
    /**
     * @notice Submit puzzle proof for +40% weight multiplier
     * @param proofHash Hash of the puzzle proof
     */
    function submitProof(bytes32 proofHash) 
        external 
        nonReentrant 
        whenNotPaused 
        whenNotEmergencyPaused 
        notDenylisted(msg.sender) 
    {
        // Checks: Validate round is open
        require(currentRoundId > 0, "No active round");
        Round storage round = rounds[currentRoundId];
        require(round.status == RoundStatus.Open, "Round not open for proofs");
        
        // Checks: User must have placed a wager first
        require(
            userTicketsInRound[currentRoundId][msg.sender] > 0,
            "Must place wager before submitting proof"
        );
        
        // Checks: One proof per wallet per round
        require(
            !userHasProofInRound[currentRoundId][msg.sender],
            "Proof already submitted for this round"
        );
        
        // Checks: Validate proof hash
        require(proofHash != bytes32(0), "Invalid proof hash");
        
        // Additional security check: Prevent common hash patterns
        require(
            proofHash != keccak256(""),
            "Invalid proof: empty hash"
        );
        require(
            proofHash != keccak256(abi.encodePacked(msg.sender)),
            "Invalid proof: trivial hash"
        );
        
        // Effects: Store proof
        userProofInRound[currentRoundId][msg.sender] = PuzzleProof({
            wallet: msg.sender,
            roundId: currentRoundId,
            proofHash: proofHash,
            verified: true, // Basic validation - could be enhanced
            submittedAt: uint64(block.timestamp)
        });
        
        userHasProofInRound[currentRoundId][msg.sender] = true;
        
        // Effects: Recalculate user's effective weight with +40% multiplier
        uint256 userTickets = userTicketsInRound[currentRoundId][msg.sender];
        uint256 oldWeight = userWeightInRound[currentRoundId][msg.sender];
        uint256 newWeight = (userTickets * PROOF_MULTIPLIER) / 1000;
        
        userWeightInRound[currentRoundId][msg.sender] = newWeight;
        
        // Effects: Update round total weight
        round.totalWeight = round.totalWeight - oldWeight + newWeight;
        
        // Interactions: Emit event
        emit ProofSubmitted(
            msg.sender,
            currentRoundId,
            proofHash,
            newWeight
        );
    }
    
    /**
     * @notice Request VRF randomness for winner selection
     * @param roundId The round to request VRF for
     */
    function requestVRF(uint256 roundId) 
        external 
        onlyOwner 
        whenNotPaused 
        whenNotEmergencyPaused
        roundExists(roundId) 
        roundInStatus(roundId, RoundStatus.Snapshot) 
    {
        // Checks: Ensure round has participants
        require(rounds[roundId].totalTickets > 0, "No participants in round");
        
        // Security check: Prevent too frequent VRF requests
        require(
            block.timestamp >= lastVRFRequestTime + 1 minutes,
            "VRF request too frequent"
        );
        
        // Security check: Validate VRF coordinator is still valid
        require(
            address(vrfConfig.coordinator) != address(0),
            "Invalid VRF coordinator"
        );
        
        // Effects: Update round status and timing
        rounds[roundId].status = RoundStatus.VRFRequested;
        rounds[roundId].vrfRequestedAt = uint64(block.timestamp);
        lastVRFRequestTime = block.timestamp;
        
        // Interactions: Request randomness from Chainlink VRF
        uint256 requestId = vrfConfig.coordinator.requestRandomWords(
            vrfConfig.keyHash,
            vrfConfig.subscriptionId,
            vrfConfig.requestConfirmations,
            vrfConfig.callbackGasLimit,
            1 // Number of random words
        );
        
        // Effects: Store request mapping
        rounds[roundId].vrfRequestId = requestId;
        vrfRequestToRound[requestId] = roundId;
        
        // Interactions: Emit event
        emit VRFRequested(roundId, requestId);
    }
    
    /**
     * @notice Fulfill VRF request and assign winners
     * @param requestId The VRF request ID
     * @param randomWords Array of random words from VRF
     */
    function fulfillRandomWords(uint256 requestId, uint256[] memory randomWords) internal override {
        // Checks: Validate request exists
        uint256 roundId = vrfRequestToRound[requestId];
        require(roundId > 0, "Invalid VRF request");
        require(rounds[roundId].status == RoundStatus.VRFRequested, "Round not awaiting VRF");
        
        // Security check: Validate VRF request timing (timeout protection)
        require(
            block.timestamp <= rounds[roundId].vrfRequestedAt + VRF_REQUEST_TIMEOUT,
            "VRF request timeout exceeded"
        );
        
        // Security check: Validate random words
        require(randomWords.length > 0, "No random words provided");
        require(randomWords[0] != 0, "Invalid random word: zero");
        
        // Security check: Ensure request ID matches stored request
        require(
            rounds[roundId].vrfRequestId == requestId,
            "VRF request ID mismatch"
        );
        
        // Interactions: Emit VRF fulfilled event
        emit VRFFulfilled(roundId, requestId, randomWords);
        
        // Effects & Interactions: Assign winners and distribute prizes
        _assignWinnersAndDistribute(roundId, randomWords[0]);
        
        // Effects: Mark round as completed
        rounds[roundId].status = RoundStatus.Distributed;
    }
    
    /**
     * @notice Assign winners based on VRF randomness and distribute prizes
     * @param roundId The round to process
     * @param randomSeed The random seed from VRF
     */
    function _assignWinnersAndDistribute(uint256 roundId, uint256 randomSeed) internal {
        Round storage round = rounds[roundId];
        address[] memory participants = roundParticipants[roundId];
        
        // Enhanced winner selection algorithm with duplicate prevention
        uint256 totalWeight = round.totalWeight;
        address[] memory winners = new address[](10); // Max possible winners (1 Fake + 1 Kek + 8 Pepe)
        uint8[] memory prizeTiers = new uint8[](10);
        uint256 winnerCount = 0;
        
        // Prize distribution: 1 Fake Pack, 1 Kek Pack, 8 Pepe Packs
        uint8[] memory prizeAllocation = new uint8[](10);
        prizeAllocation[0] = FAKE_PACK_TIER;  // 1 Fake Pack
        prizeAllocation[1] = KEK_PACK_TIER;   // 1 Kek Pack
        for (uint256 i = 2; i < 10; i++) {
            prizeAllocation[i] = PEPE_PACK_TIER; // 8 Pepe Packs
        }
        
        // Select winners using weighted random selection with duplicate prevention
        for (uint256 prizeIndex = 0; prizeIndex < prizeAllocation.length && prizeIndex < participants.length; prizeIndex++) {
            uint256 randomValue = uint256(keccak256(abi.encode(randomSeed, prizeIndex, block.timestamp))) % totalWeight;
            
            uint256 cumulativeWeight = 0;
            bool winnerFound = false;
            
            for (uint256 j = 0; j < participants.length; j++) {
                address participant = participants[j];
                
                // Skip if already selected as winner (duplicate prevention)
                if (_winnerSelected[roundId][participant]) {
                    continue;
                }
                
                uint256 participantWeight = userWeightInRound[roundId][participant];
                cumulativeWeight += participantWeight;
                
                if (randomValue < cumulativeWeight) {
                    winners[winnerCount] = participant;
                    prizeTiers[winnerCount] = prizeAllocation[prizeIndex];
                    
                    // Mark as selected to prevent duplicates
                    _winnerSelected[roundId][participant] = true;
                    
                    // Store winner assignment
                    roundWinners[roundId].push(WinnerAssignment({
                        roundId: roundId,
                        wallet: participant,
                        prizeTier: prizeAllocation[prizeIndex],
                        vrfRequestId: round.vrfRequestId,
                        blockNumber: block.number
                    }));
                    
                    winnerCount++;
                    winnerFound = true;
                    break;
                }
            }
            
            // If no winner found (all participants already selected), break
            if (!winnerFound) {
                break;
            }
        }
        
        // Resize arrays to actual winner count
        address[] memory finalWinners = new address[](winnerCount);
        uint8[] memory finalPrizeTiers = new uint8[](winnerCount);
        for (uint256 i = 0; i < winnerCount; i++) {
            finalWinners[i] = winners[i];
            finalPrizeTiers[i] = prizeTiers[i];
        }
        
        // Emit winners assigned event
        emit WinnersAssigned(roundId, finalWinners, finalPrizeTiers);
        
        // Distribute prizes and fees
        _distributePrizes(roundId, finalWinners, finalPrizeTiers);
        _distributeFees(roundId);
    }
    
    /**
     * @notice Distribute prizes to winners via Emblem Vault integration
     * @param roundId The round ID
     * @param winners Array of winner addresses
     * @param prizeTiers Array of prize tiers for each winner
     */
    function _distributePrizes(uint256 roundId, address[] memory winners, uint8[] memory prizeTiers) internal {
        // Basic Emblem Vault integration for small-scale site
        require(emblemVaultAddress != address(0), "Emblem Vault address not set");
        
        for (uint256 i = 0; i < winners.length; i++) {
            address winner = winners[i];
            uint8 prizeTier = prizeTiers[i];
            
            // Security check: Validate winner address
            require(winner != address(0), "Invalid winner address");
            
            // Map prize tier to asset ID (simplified mapping for 133 assets)
            uint256 assetId = _getPrizeAssetId(prizeTier, roundId, i);
            
            // Basic prize distribution - emit event for Emblem Vault to process
            // In production, this would call Emblem Vault contract directly
            emit PrizeDistributed(
                roundId,
                winner,
                prizeTier,
                assetId
            );
            
            // Additional event for Emblem Vault integration
            emit EmblemVaultPrizeAssigned(
                roundId,
                winner,
                assetId,
                block.timestamp
            );
        }
        
        // Emit summary event for the round
        emit RoundPrizesDistributed(roundId, winners.length, block.timestamp);
    }
    
    /**
     * @notice Get asset ID for prize distribution (simplified for small-scale site)
     * @param prizeTier The prize tier (1=Fake, 2=Kek, 3=Pepe)
     * @param roundId The round ID
     * @param winnerIndex The winner index for uniqueness
     * @return assetId The asset ID to distribute
     */
    function _getPrizeAssetId(uint8 prizeTier, uint256 roundId, uint256 winnerIndex) internal pure returns (uint256) {
        // Simple asset ID mapping for 133 total assets
        // Fake Pack: Assets 1-10
        // Kek Pack: Assets 11-50  
        // Pepe Pack: Assets 51-133
        
        if (prizeTier == FAKE_PACK_TIER) {
            // Fake pack gets premium assets (1-10)
            return 1 + (uint256(keccak256(abi.encode(roundId, winnerIndex, "fake"))) % 10);
        } else if (prizeTier == KEK_PACK_TIER) {
            // Kek pack gets mid-tier assets (11-50)
            return 11 + (uint256(keccak256(abi.encode(roundId, winnerIndex, "kek"))) % 40);
        } else {
            // Pepe pack gets common assets (51-133)
            return 51 + (uint256(keccak256(abi.encode(roundId, winnerIndex, "pepe"))) % 83);
        }
    }
    
    /**
     * @notice Distribute fees (80% creators, 20% next round)
     * @param roundId The round ID
     */
    function _distributeFees(uint256 roundId) internal {
        Round storage round = rounds[roundId];
        
        if (round.feesDistributed) {
            return; // Already distributed
        }
        
        uint256 totalFees = round.totalWagered;
        uint256 creatorsAmount = (totalFees * CREATORS_FEE_PCT) / 100;
        uint256 nextRoundAmount = (totalFees * NEXT_ROUND_FEE_PCT) / 100;
        
        // Security check: Validate amounts
        require(creatorsAmount + nextRoundAmount <= totalFees, "Invalid fee calculation");
        require(creatorsAddress != address(0), "Invalid creators address");
        
        // Effects: Mark fees as distributed and update state BEFORE external call
        round.feesDistributed = true;
        nextRoundFunds += nextRoundAmount;
        
        // Interactions: Transfer to creators (checks-effects-interactions pattern)
        (bool success, ) = creatorsAddress.call{value: creatorsAmount}("");
        require(success, "Creator fee transfer failed");
        
        // Emit fee distribution event
        emit FeesDistributed(roundId, creatorsAddress, creatorsAmount, nextRoundAmount);
    }
    
    // =============================================================================
    // VIEW FUNCTIONS
    // =============================================================================
    
    /**
     * @notice Get round information
     */
    function getRound(uint256 roundId) external view returns (Round memory) {
        return rounds[roundId];
    }
    
    /**
     * @notice Get user's stats for a round
     */
    function getUserStats(uint256 roundId, address user) 
        external 
        view 
        returns (uint256 wagered, uint256 tickets, uint256 weight, bool hasProof) 
    {
        return (
            userWageredInRound[roundId][user],
            userTicketsInRound[roundId][user],
            userWeightInRound[roundId][user],
            userHasProofInRound[roundId][user]
        );
    }
    
    /**
     * @notice Get round participants
     */
    function getRoundParticipants(uint256 roundId) external view returns (address[] memory) {
        return roundParticipants[roundId];
    }
    
    /**
     * @notice Get round winners
     */
    function getRoundWinners(uint256 roundId) external view returns (WinnerAssignment[] memory) {
        return roundWinners[roundId];
    }
}
