// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@chainlink/contracts/src/v0.8/interfaces/VRFCoordinatorV2Interface.sol";
import "@chainlink/contracts/src/v0.8/VRFConsumerBaseV2.sol";

/**
 * @title PepedawnRaffle
 * @notice Skill-weighted decentralized raffle with Chainlink VRF and Emblem Vault prizes
 * @dev Implements 2-week rounds with ETH wagers, puzzle proofs for +40% weight, and automatic distribution
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
        uint256 totalTickets;
        uint256 totalWeight;
        uint256 totalWagered;
        uint256 vrfRequestId;
        bool feesDistributed;
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
    
    address public owner;
    address public creatorsAddress;
    address public emblemVaultAddress;
    
    uint256 public currentRoundId;
    uint256 public nextRoundFunds;
    
    VRFConfig public vrfConfig;
    
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
    
    // =============================================================================
    // MODIFIERS
    // =============================================================================
    
    modifier onlyOwner() {
        require(msg.sender == owner, "Only owner");
        _;
    }
    
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
        owner = msg.sender;
        creatorsAddress = _creatorsAddress;
        emblemVaultAddress = _emblemVaultAddress;
        
        vrfConfig = VRFConfig({
            coordinator: VRFCoordinatorV2Interface(_vrfCoordinator),
            subscriptionId: _subscriptionId,
            keyHash: _keyHash,
            callbackGasLimit: 100000,
            requestConfirmations: 3
        });
    }
    
    // =============================================================================
    // ROUND LIFECYCLE FUNCTIONS
    // =============================================================================
    
    /**
     * @notice Create a new round
     * @dev Only owner can create rounds. Previous round should be completed.
     */
    function createRound() external onlyOwner {
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
            feesDistributed: false
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
        roundExists(roundId) 
        roundInStatus(roundId, RoundStatus.Open) 
    {
        rounds[roundId].status = RoundStatus.Closed;
        emit RoundClosed(roundId);
    }
    
    /**
     * @notice Take snapshot before VRF request
     * @param roundId The round to snapshot
     */
    function snapshotRound(uint256 roundId) 
        external 
        onlyOwner 
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
    function placeBet(uint256 tickets) external payable {
        // Checks: Validate round is open
        require(currentRoundId > 0, "No active round");
        Round storage round = rounds[currentRoundId];
        require(round.status == RoundStatus.Open, "Round not open for betting");
        
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
    function submitProof(bytes32 proofHash) external {
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
        roundExists(roundId) 
        roundInStatus(roundId, RoundStatus.Snapshot) 
    {
        // Checks: Ensure round has participants
        require(rounds[roundId].totalTickets > 0, "No participants in round");
        
        // Effects: Update round status
        rounds[roundId].status = RoundStatus.VRFRequested;
        
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
        
        // Effects: Store random words and update status
        rounds[roundId].status = RoundStatus.Distributed; // Will be set properly after distribution
        
        // Interactions: Emit VRF fulfilled event
        emit VRFFulfilled(roundId, requestId, randomWords);
        
        // Effects & Interactions: Assign winners and distribute prizes
        _assignWinnersAndDistribute(roundId, randomWords[0]);
    }
    
    /**
     * @notice Assign winners based on VRF randomness and distribute prizes
     * @param roundId The round to process
     * @param randomSeed The random seed from VRF
     */
    function _assignWinnersAndDistribute(uint256 roundId, uint256 randomSeed) internal {
        Round storage round = rounds[roundId];
        address[] memory participants = roundParticipants[roundId];
        
        // Simple winner selection algorithm (can be enhanced)
        // For now, select up to 3 winners based on weighted probability
        
        uint256 totalWeight = round.totalWeight;
        address[] memory winners = new address[](3);
        uint8[] memory prizeTiers = new uint8[](3);
        uint256 winnerCount = 0;
        
        // Select winners using weighted random selection
        for (uint256 i = 0; i < 3 && i < participants.length; i++) {
            uint256 randomValue = uint256(keccak256(abi.encode(randomSeed, i))) % totalWeight;
            
            uint256 cumulativeWeight = 0;
            for (uint256 j = 0; j < participants.length; j++) {
                address participant = participants[j];
                uint256 participantWeight = userWeightInRound[roundId][participant];
                cumulativeWeight += participantWeight;
                
                if (randomValue < cumulativeWeight) {
                    winners[winnerCount] = participant;
                    prizeTiers[winnerCount] = uint8(i + 1); // Prize tiers 1, 2, 3
                    
                    // Store winner assignment
                    roundWinners[roundId].push(WinnerAssignment({
                        roundId: roundId,
                        wallet: participant,
                        prizeTier: uint8(i + 1),
                        vrfRequestId: round.vrfRequestId,
                        blockNumber: block.number
                    }));
                    
                    winnerCount++;
                    break;
                }
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
        
        // Mark round as completed
        round.status = RoundStatus.Distributed;
    }
    
    /**
     * @notice Distribute prizes to winners (placeholder for Emblem Vault integration)
     * @param roundId The round ID
     * @param winners Array of winner addresses
     * @param prizeTiers Array of prize tiers for each winner
     */
    function _distributePrizes(uint256 roundId, address[] memory winners, uint8[] memory prizeTiers) internal {
        // TODO: Integrate with actual Emblem Vault contracts
        // For now, emit events to track prize distribution
        
        for (uint256 i = 0; i < winners.length; i++) {
            // Mock asset ID based on prize tier
            uint256 assetId = 1000 + prizeTiers[i];
            
            emit PrizeDistributed(
                roundId,
                winners[i],
                prizeTiers[i],
                assetId
            );
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
        
        // Effects: Mark fees as distributed
        round.feesDistributed = true;
        nextRoundFunds += nextRoundAmount;
        
        // Interactions: Transfer to creators
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
