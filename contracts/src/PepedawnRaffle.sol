// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IVRFCoordinatorV2Plus} from "@chainlink/contracts/vrf/dev/interfaces/IVRFCoordinatorV2Plus.sol";
import {VRFConsumerBaseV2Plus} from "@chainlink/contracts/vrf/dev/VRFConsumerBaseV2Plus.sol";
import {VRFV2PlusClient} from "@chainlink/contracts/vrf/dev/libraries/VRFV2PlusClient.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {Pausable} from "@openzeppelin/contracts/utils/Pausable.sol";

/**
 * @title PepedawnRaffle
 * @notice Skill-weighted decentralized raffle with Chainlink VRF and Emblem Vault prizes
 * @dev Implements 2-week rounds with ETH wagers, puzzle proofs for +40% weight, and automatic distribution
 * @dev VRFConsumerBaseV2Plus provides ownership functionality via ConfirmedOwner
 */
contract PepedawnRaffle is VRFConsumerBaseV2Plus, ReentrancyGuard, Pausable {
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
    uint256 public constant MIN_TICKETS_FOR_DISTRIBUTION = 10; // Minimum tickets required for prize distribution
    
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
        Distributed, // Prizes distributed, round complete
        Refunded    // Round refunded due to insufficient tickets
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
        bytes32 validProofHash; // Valid proof hash set by owner for this round
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
    
    struct VrfConfig {
        IVRFCoordinatorV2Plus coordinator;
        uint256 subscriptionId;
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
    
    VrfConfig public vrfConfig;
    
    // Security state variables
    mapping(address => bool) public denylisted; // Denylist for blocked addresses
    mapping(uint256 => mapping(address => bool)) private _winnerSelected; // Prevent duplicate winners
    bool public emergencyPaused; // Additional emergency pause state
    uint256 public lastVrfRequestTime; // Track VRF request timing
    
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
    event ProofRejected(
        address indexed wallet,
        uint256 indexed roundId,
        bytes32 proofHash
    );
    event ValidProofSet(
        uint256 indexed roundId,
        bytes32 validProofHash
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
    
    // Refund events
    event ParticipantRefunded(
        uint256 indexed roundId,
        address indexed participant,
        uint256 amount
    );
    event RoundRefunded(
        uint256 indexed roundId,
        uint256 participantCount,
        uint256 totalRefunded
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
    
    modifier onlyVrfCoordinator() {
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
        uint256 _subscriptionId,
        bytes32 _keyHash,
        address _creatorsAddress,
        address _emblemVaultAddress
    ) 
        VRFConsumerBaseV2Plus(_vrfCoordinator)
        validAddress(_vrfCoordinator)
        validAddress(_creatorsAddress)
        validAddress(_emblemVaultAddress)
    {
        // Input validation
        require(_subscriptionId > 0, "Invalid VRF subscription ID");
        require(_keyHash != bytes32(0), "Invalid VRF key hash");
        
        creatorsAddress = _creatorsAddress;
        emblemVaultAddress = _emblemVaultAddress;
        
        vrfConfig = VrfConfig({
            coordinator: IVRFCoordinatorV2Plus(_vrfCoordinator),
            subscriptionId: _subscriptionId,
            keyHash: _keyHash,
            callbackGasLimit: 500000, // Increased from 100000 for complex callback
            requestConfirmations: 5   // Increased from 3 for better finality
        });
        
        // Initialize security state
        emergencyPaused = false;
        lastVrfRequestTime = 0;
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
    function updateVrfConfig(
        address _coordinator,
        uint256 _subscriptionId,
        bytes32 _keyHash
    ) external onlyOwner validAddress(_coordinator) {
        require(_subscriptionId > 0, "Invalid VRF subscription ID");
        require(_keyHash != bytes32(0), "Invalid VRF key hash");
        
        vrfConfig.coordinator = IVRFCoordinatorV2Plus(_coordinator);
        vrfConfig.subscriptionId = _subscriptionId;
        vrfConfig.keyHash = _keyHash;
    }

    /**
     * @notice Reset VRF timing for testing purposes
     * @dev Only available for testing - should be removed in production
     */
    function resetVrfTiming() external onlyOwner {
        lastVrfRequestTime = 0;
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
            participantCount: 0,
            validProofHash: bytes32(0)
        });
        
        // Interactions: Emit event
        emit RoundCreated(currentRoundId, startTime, endTime);
    }
    
    /**
     * @notice Set valid proof hash for a round
     * @param roundId The round to set proof for
     * @param proofHash The valid proof hash
     */
    function setValidProof(uint256 roundId, bytes32 proofHash) 
        external 
        onlyOwner 
        roundExists(roundId) 
    {
        require(proofHash != bytes32(0), "Invalid proof hash");
        rounds[roundId].validProofHash = proofHash;
        emit ValidProofSet(roundId, proofHash);
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
     * @dev If round has fewer than MIN_TICKETS_FOR_DISTRIBUTION, automatically refunds all participants
     * @param roundId The round to close
     */
    function closeRound(uint256 roundId) 
        external 
        onlyOwner 
        whenNotPaused 
        whenNotEmergencyPaused
        roundExists(roundId) 
        roundInStatus(roundId, RoundStatus.Open) 
        nonReentrant
    {
        Round storage round = rounds[roundId];
        
        // Check if minimum tickets met
        if (round.totalTickets < MIN_TICKETS_FOR_DISTRIBUTION) {
            // Insufficient tickets - refund all participants
            _refundParticipants(roundId);
            round.status = RoundStatus.Refunded;
        } else {
            // Sufficient tickets - proceed normally
            round.status = RoundStatus.Closed;
            emit RoundClosed(roundId);
        }
    }
    
    /**
     * @notice Refund all participants of a round
     * @dev Internal function called when round doesn't meet minimum ticket threshold
     * @param roundId The round to refund
     */
    function _refundParticipants(uint256 roundId) internal {
        Round storage round = rounds[roundId];
        address[] memory participants = roundParticipants[roundId];
        
        uint256 totalRefunded = 0;
        
        for (uint256 i = 0; i < participants.length; i++) {
            address participant = participants[i];
            uint256 refundAmount = userWageredInRound[roundId][participant];
            
            if (refundAmount > 0) {
                // Reset user's round data
                userWageredInRound[roundId][participant] = 0;
                userTicketsInRound[roundId][participant] = 0;
                userWeightInRound[roundId][participant] = 0;
                
                // Transfer refund
                (bool success, ) = participant.call{value: refundAmount}("");
                require(success, "Refund transfer failed");
                
                totalRefunded += refundAmount;
                emit ParticipantRefunded(roundId, participant, refundAmount);
            }
        }
        
        // Reset round totals
        round.totalTickets = 0;
        round.totalWeight = 0;
        round.totalWagered = 0;
        
        emit RoundRefunded(roundId, participants.length, totalRefunded);
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
        
        // Checks: Validate against round's valid proof (if set)
        bytes32 validProof = round.validProofHash;
        bool isCorrect = (validProof != bytes32(0) && proofHash == validProof);
        
        // Effects: Store proof with verification status
        userProofInRound[currentRoundId][msg.sender] = PuzzleProof({
            wallet: msg.sender,
            roundId: currentRoundId,
            proofHash: proofHash,
            verified: isCorrect,
            submittedAt: uint64(block.timestamp)
        });
        
        // Mark proof as submitted (regardless of correctness)
        userHasProofInRound[currentRoundId][msg.sender] = true;
        
        // Effects: Only apply weight bonus if proof is correct
        if (isCorrect) {
            // Recalculate user's effective weight with +40% multiplier
            uint256 userTickets = userTicketsInRound[currentRoundId][msg.sender];
            uint256 oldWeight = userWeightInRound[currentRoundId][msg.sender];
            uint256 newWeight = (userTickets * PROOF_MULTIPLIER) / 1000;
            
            userWeightInRound[currentRoundId][msg.sender] = newWeight;
            
            // Update round total weight
            round.totalWeight = round.totalWeight - oldWeight + newWeight;
            
            // Interactions: Emit success event
            emit ProofSubmitted(
                msg.sender,
                currentRoundId,
                proofHash,
                newWeight
            );
        } else {
            // Interactions: Emit rejection event
            emit ProofRejected(
                msg.sender,
                currentRoundId,
                proofHash
            );
        }
    }
    
    /**
     * @notice Request VRF randomness for winner selection with dynamic gas estimation
     * @param roundId The round to request VRF for
     */
    function requestVrf(uint256 roundId) 
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
        // Allow immediate requests if lastVrfRequestTime is 0 (for testing)
        require(
            lastVrfRequestTime == 0 || block.timestamp >= lastVrfRequestTime + 1 minutes,
            "VRF request too frequent"
        );
        
        // Security check: Validate VRF coordinator is still valid
        require(
            address(vrfConfig.coordinator) != address(0),
            "Invalid VRF coordinator"
        );
        
        // Dynamic gas estimation following Chainlink best practices
        uint32 estimatedGas = _estimateCallbackGas(roundId);
        uint32 safetyBuffer = estimatedGas * 30 / 100; // 30% safety buffer
        uint32 finalGasLimit = estimatedGas + safetyBuffer;
        
        // Ensure gas limit is within bounds
        require(finalGasLimit >= 10000, "Estimated gas too low");
        require(finalGasLimit <= 2500000, "Estimated gas too high");
        
        // Update gas limit for this request
        vrfConfig.callbackGasLimit = finalGasLimit;
        
        // Effects: Update round status and timing
        rounds[roundId].status = RoundStatus.VRFRequested;
        rounds[roundId].vrfRequestedAt = uint64(block.timestamp);
        lastVrfRequestTime = block.timestamp;
        
        // Interactions: Request randomness from Chainlink VRF v2.5
        uint256 requestId = vrfConfig.coordinator.requestRandomWords(
            VRFV2PlusClient.RandomWordsRequest({
                keyHash: vrfConfig.keyHash,
                subId: vrfConfig.subscriptionId,
                requestConfirmations: vrfConfig.requestConfirmations,
                callbackGasLimit: finalGasLimit,
                numWords: 1,
                extraArgs: VRFV2PlusClient._argsToBytes(
                    VRFV2PlusClient.ExtraArgsV1({nativePayment: false}) // Use LINK for payment
                )
            })
        );
        
        // Effects: Store request mapping
        rounds[roundId].vrfRequestId = requestId;
        vrfRequestToRound[requestId] = roundId;
        
        // Interactions: Emit event
        emit VRFRequested(roundId, requestId);
    }
    
    /**
     * @notice Estimate callback gas based on round complexity following Chainlink best practices
     * @param roundId The round to estimate gas for
     * @return estimatedGas The estimated gas required for the callback
     */
    function _estimateCallbackGas(uint256 roundId) internal view returns (uint32) {
        Round memory round = rounds[roundId];
        address[] memory participants = roundParticipants[roundId];
        
        // Base gas for fulfillRandomWords function
        uint32 baseGas = 50000; // Function overhead, event emission, basic checks
        
        // Gas for winner selection algorithm
        uint32 winnerSelectionGas = 20000; // Base winner selection logic
        
        // Gas for prize distribution (per winner)
        uint32 prizeDistributionGasPerWinner = 15000; // Per winner distribution
        uint32 totalPrizeDistributionGas = prizeDistributionGasPerWinner * 10; // Max 10 winners
        
        // Gas for fee distribution
        uint32 feeDistributionGas = 25000; // Fee calculation and transfer
        
        // Gas for storage operations (per participant)
        uint32 storageGasPerParticipant = 5000; // Storage updates per participant
        uint32 totalStorageGas = storageGasPerParticipant * uint32(participants.length);
        
        // Gas for event emissions
        uint32 eventGas = 10000; // Multiple event emissions
        
        // Calculate total estimated gas
        uint32 totalEstimatedGas = baseGas + winnerSelectionGas + totalPrizeDistributionGas + 
                                 feeDistributionGas + totalStorageGas + eventGas;
        
        // Apply complexity multipliers based on round size
        if (participants.length > 100) {
            totalEstimatedGas = totalEstimatedGas * 120 / 100; // 20% increase for large rounds
        }
        
        if (round.totalWeight > 1000) {
            totalEstimatedGas = totalEstimatedGas * 110 / 100; // 10% increase for high weight rounds
        }
        
        // Ensure minimum gas limit
        if (totalEstimatedGas < 100000) {
            totalEstimatedGas = 100000; // Minimum safe gas limit
        }
        
        return totalEstimatedGas;
    }
    
    /**
     * @notice Fulfill VRF request and assign winners
     * @param requestId The VRF request ID
     * @param randomWords Array of random words from VRF
     */
    function fulfillRandomWords(uint256 requestId, uint256[] calldata randomWords) internal override {
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
     * @notice Select a weighted winner from participants
     * @param randomSeed The random seed from VRF
     * @param nonce Additional nonce for uniqueness
     * @param totalWeight Total weight of all participants
     * @param participants Array of participant addresses
     * @param roundId The round ID for weight lookup
     * @return winner The selected winner address
     */
    function _selectWeightedWinner(
        uint256 randomSeed,
        uint256 nonce,
        uint256 totalWeight,
        address[] memory participants,
        uint256 roundId
    ) internal view returns (address) {
        // Generate random number in range [0, totalWeight)
        uint256 randomWeight = uint256(keccak256(abi.encode(randomSeed, nonce))) % totalWeight;
        
        // Walk through participants until cumulative weight >= randomWeight
        uint256 cumulativeWeight = 0;
        for (uint256 i = 0; i < participants.length; i++) {
            address participant = participants[i];
            uint256 participantWeight = userWeightInRound[roundId][participant];
            cumulativeWeight += participantWeight;
            
            if (cumulativeWeight > randomWeight) {
                return participant;
            }
        }
        
        // Fallback (should never reach if totalWeight is correct)
        return participants[0];
    }
    
    /**
     * @notice Assign winners based on VRF randomness and distribute prizes using weighted lottery
     * @dev 1st place: Fake Pack, 2nd place: Kek Pack, 3rd-10th place: Pepe Packs
     * @dev Same wallet can win multiple prizes (weighted lottery, not raffle)
     * @param roundId The round to process
     * @param randomSeed The random seed from VRF
     */
    function _assignWinnersAndDistribute(uint256 roundId, uint256 randomSeed) internal {
        Round storage round = rounds[roundId];
        address[] memory participants = roundParticipants[roundId];
        
        uint256 totalWeight = round.totalWeight;
        require(totalWeight > 0, "No weight in round");
        
        // Select 10 winners with weighted randomization
        address[] memory winners = new address[](10);
        uint8[] memory prizeTiers = new uint8[](10);
        uint256 winnerCount = 0;
        
        // Select 10 winners: 1st=Fake, 2nd=Kek, 3rd-10th=Pepe
        for (uint256 i = 0; i < 10 && totalWeight > 0; i++) {
            // Use weighted selection
            address winner = _selectWeightedWinner(randomSeed, i, totalWeight, participants, roundId);
            
            // Assign prize tier based on position
            uint8 prizeTier;
            if (i == 0) {
                prizeTier = FAKE_PACK_TIER;  // 1st place: Fake Pack
            } else if (i == 1) {
                prizeTier = KEK_PACK_TIER;   // 2nd place: Kek Pack
            } else {
                prizeTier = PEPE_PACK_TIER;  // 3rd-10th place: Pepe Packs
            }
            
            winners[winnerCount] = winner;
            prizeTiers[winnerCount] = prizeTier;
            
            // Store winner assignment
            roundWinners[roundId].push(WinnerAssignment({
                roundId: roundId,
                wallet: winner,
                prizeTier: prizeTier,
                vrfRequestId: round.vrfRequestId,
                blockNumber: block.number
            }));
            
            winnerCount++;
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
    
    /**
     * @notice Estimate gas for VRF callback (public function for testing/monitoring)
     * @param roundId The round to estimate gas for
     * @return estimatedGas The estimated gas required for the callback
     */
    function estimateVrfCallbackGas(uint256 roundId) external view returns (uint32) {
        return _estimateCallbackGas(roundId);
    }
}
