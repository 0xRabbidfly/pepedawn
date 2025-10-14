// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IVRFCoordinatorV2Plus} from "@chainlink/contracts/vrf/dev/interfaces/IVRFCoordinatorV2Plus.sol";
import {VRFConsumerBaseV2Plus} from "@chainlink/contracts/vrf/dev/VRFConsumerBaseV2Plus.sol";
import {VRFV2PlusClient} from "@chainlink/contracts/vrf/dev/libraries/VRFV2PlusClient.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {Pausable} from "@openzeppelin/contracts/utils/Pausable.sol";
import {IERC1155} from "@openzeppelin/contracts/token/ERC1155/IERC1155.sol";
import {ERC1155Holder} from "@openzeppelin/contracts/token/ERC1155/utils/ERC1155Holder.sol";
import {MerkleProof} from "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";

/**
 * @title PepedawnRaffle
 * @notice Skill-weighted decentralized raffle with Chainlink VRF, Emblem Vault prizes, and Merkle-based claims
 * @dev Implements 2-week rounds with ETH wagers, puzzle proofs for +40% weight, and pull-payment claims
 * @dev VRFConsumerBaseV2Plus provides ownership functionality via ConfirmedOwner
 * @dev Merkle trees provide efficient verification and indefinite historical data retention
 * @dev ERC1155Holder enables receiving ERC1155 NFTs (Emblem Vault uses ERC1155)
 */
contract PepedawnRaffle is VRFConsumerBaseV2Plus, ReentrancyGuard, Pausable, ERC1155Holder {
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
    uint256 public constant MAX_PARTICIPANTS_PER_ROUND = 100; // Circuit breaker
    uint256 public constant MAX_TOTAL_WAGER_PER_ROUND = 100 ether; // Circuit breaker - start conservative
    uint256 public constant VRF_REQUEST_TIMEOUT = 1 hours; // VRF timeout protection
    
    // VRF Gas Configuration Constants (Optimized for simple callback architecture)
    uint32 public constant VRF_MIN_CALLBACK_GAS = 75_000; // Conservative floor for simple VRF callback
    uint32 public constant VRF_MAX_CALLBACK_GAS = 500_000; // Maximum gas limit (reduced from 2.5M)
    uint256 public maxGasPrice = 100 gwei; // Maximum gas price for VRF requests (owner-updatable)
    
    // Version tracking
    string public constant VERSION = "0.5.1";
    uint256 public immutable DEPLOYMENT_TIMESTAMP;
    
    // =============================================================================
    // ENUMS
    // =============================================================================
    
    enum RoundStatus {
        Created,    // Round created but not open for ticket purchases
        Open,       // Round open for ticket purchases and proofs
        Closed,     // Round closed, no more ticket purchases/proofs
        Snapshot,   // Snapshot taken, ready for VRF
        VRFRequested, // VRF requested, waiting for fulfillment
        WinnersReady, // VRF fulfilled, Merkle root ready for submission
        Distributed, // Merkle root submitted, prizes available for claiming
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
        bytes32 participantsRoot; // Merkle root of participants (for verification)
        bytes32 winnersRoot; // Merkle root of winners (for claims)
        bytes32 vrfSeed; // VRF seed for reproducibility
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
    IERC1155 public immutable emblemVault; // Emblem Vault ERC1155 NFT contract for prize custody
    
    uint256 public currentRoundId;
    uint256 public nextRoundFunds;
    
    // Pull-payment balances for creators
    mapping(address => uint256) public creatorBalances;
    
    VrfConfig public vrfConfig;
    
    // Security state variables
    mapping(address => bool) public denylisted; // Denylist for blocked addresses
    bool public emergencyPaused; // Additional emergency pause state
    uint256 public lastVrfRequestTime; // Track VRF request timing
    string public pauseReason; // Reason for contract pause (for transparency)
    
    // Merkle & Claims state variables (NEW)
    mapping(uint256 => string) public participantsCIDs; // roundId => IPFS CID for participants file
    mapping(uint256 => string) public winnersCIDs; // roundId => IPFS CID for winners file
    mapping(uint256 => mapping(uint8 => address)) public claims; // roundId => prizeIndex => claimer
    mapping(uint256 => mapping(address => uint8)) public claimCounts; // roundId => user => claim count
    mapping(uint256 => mapping(uint8 => uint256)) public prizeNFTs; // roundId => prizeIndex => tokenId
    
    // Refunds (pull-payment pattern)
    mapping(address => uint256) public refunds; // user => accumulated refund balance
    
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
    
    // Merkle & Claims events (NEW)
    event ParticipantsRootCommitted(uint256 indexed roundId, bytes32 root, string cid);
    event WinnersCommitted(uint256 indexed roundId, bytes32 root, string cid);
    event PrizeClaimed(
        uint256 indexed roundId,
        address indexed winner,
        uint8 prizeIndex,
        uint8 prizeTier,
        uint256 emblemVaultTokenId
    );
    event RefundWithdrawn(address indexed user, uint256 amount);
    event PrizesSet(uint256 indexed roundId, uint256[] tokenIds);
    
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
    
    event CreatorFeesWithdrawn(
        address indexed creator,
        uint256 amount
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
    event MaxGasPriceUpdated(uint256 oldPrice, uint256 newPrice);
    
    // Emergency & Recovery events
    event EmergencyWithdrawal(address indexed to, uint256 amount, string assetType);
    event DirectETHReceived(address indexed sender, uint256 amount);
    event ContractPausedWithReason(string reason, uint256 timestamp);
    
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
    
    modifier whenEmergencyPaused() {
        require(emergencyPaused, "Emergency pause is not active");
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
        emblemVault = IERC1155(_emblemVaultAddress); // Initialize ERC1155 interface (Emblem Vault)
        
        vrfConfig = VrfConfig({
            coordinator: IVRFCoordinatorV2Plus(_vrfCoordinator),
            subscriptionId: _subscriptionId,
            keyHash: _keyHash,
            callbackGasLimit: 500_000, // Increased from 100_000 for complex callback
            requestConfirmations: 5   // Increased from 3 for better finality
        });
        
        // Initialize security state
        emergencyPaused = false;
        lastVrfRequestTime = 0;
        
        // Set deployment timestamp for version tracking
        DEPLOYMENT_TIMESTAMP = block.timestamp;
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
     * @notice Pause contract with reason (Pausable functionality)
     * @param reason Reason for pausing the contract
     */
    function pause(string calldata reason) external onlyOwner {
        pauseReason = reason;
        _pause();
        emit ContractPausedWithReason(reason, block.timestamp);
    }
    
    /**
     * @notice Unpause contract (Pausable functionality)
     */
    function unpause() external onlyOwner {
        pauseReason = "";
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
     * @dev Note: emblemVault interface is immutable, only the address reference is updated
     * @param _emblemVaultAddress New Emblem Vault address
     */
    function updateEmblemVaultAddress(address _emblemVaultAddress) 
        external 
        onlyOwner 
        validAddress(_emblemVaultAddress) 
    {
        emblemVaultAddress = _emblemVaultAddress;
    }
    
    /**
     * @notice Update maximum gas price for VRF requests (owner-updatable)
     * @dev Allows adjustment for gas price volatility without contract redeployment
     * @param _maxGasPrice New maximum gas price in wei
     */
    function updateMaxGasPrice(uint256 _maxGasPrice) 
        external 
        onlyOwner 
        validAmount(_maxGasPrice)
    {
        require(_maxGasPrice >= 50 gwei, "Max gas price too low (minimum 50 gwei)");
        require(_maxGasPrice <= 500 gwei, "Max gas price too high (maximum 500 gwei)");
        
        uint256 oldPrice = maxGasPrice;
        maxGasPrice = _maxGasPrice;
        
        emit MaxGasPriceUpdated(oldPrice, _maxGasPrice);
    }
    
    /**
     * @notice Internal helper to check if 7-day guard has passed
     * @dev Uses max(deployment timestamp, last VRF request time) as anchor
     * @return true if 7 days have passed since the anchor timestamp
     */
    function _sevenDayGuardPassed() internal view returns (bool) {
        uint256 anchor = lastVrfRequestTime == 0 ? DEPLOYMENT_TIMESTAMP : lastVrfRequestTime;
        return block.timestamp >= anchor + 7 days;
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
                rounds[currentRoundId].status == RoundStatus.Distributed || 
                rounds[currentRoundId].status == RoundStatus.Refunded,
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
            validProofHash: bytes32(0),
            participantsRoot: bytes32(0),
            winnersRoot: bytes32(0),
            vrfSeed: bytes32(0)
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
        roundInStatus(roundId, RoundStatus.Created)
    {
        require(proofHash != bytes32(0), "Invalid proof hash");
        rounds[roundId].validProofHash = proofHash;
        emit ValidProofSet(roundId, proofHash);
    }
    
    /**
     * @notice Open a round for ticket purchases
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
     * @notice Close a round (no more ticket purchases/proofs)
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
     * @notice Refund all participants of a round (pull-payment pattern)
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
                
                // Accrue refund (pull-payment pattern - no immediate transfer)
                refunds[participant] += refundAmount;
                
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
    
    /**
     * @notice Commit Merkle root and IPFS CID for participants
     * @param roundId The round to commit participants for
     * @param root Merkle root of participants tree
     * @param cid IPFS CID of participants file
     */
    function commitParticipantsRoot(
        uint256 roundId,
        bytes32 root,
        string calldata cid
    ) external onlyOwner roundExists(roundId) roundInStatus(roundId, RoundStatus.Snapshot) {
        require(root != bytes32(0), "Invalid root: zero");
        
        rounds[roundId].participantsRoot = root;
        participantsCIDs[roundId] = cid;
        
        emit ParticipantsRootCommitted(roundId, root, cid);
    }
    
    /**
     * @notice Set prize NFTs for a round (must be called before round opens)
     * @param roundId The round to set prizes for
     * @param tokenIds Array of 10 Emblem Vault token IDs
     */
    function setPrizesForRound(
        uint256 roundId,
        uint256[] calldata tokenIds
    ) external onlyOwner roundExists(roundId) {
        require(tokenIds.length == 10, "Must provide 10 prizes");
        Round storage round = rounds[roundId];
        require(round.status == RoundStatus.Created, "Round already opened");
        
        for (uint8 i = 0; i < 10; i++) {
            require(
                emblemVault.balanceOf(address(this), tokenIds[i]) > 0,
                "Contract must own NFT"
            );
            prizeNFTs[roundId][i] = tokenIds[i];
        }
        
        emit PrizesSet(roundId, tokenIds);
    }
    
    // =============================================================================
    // CLAIMS & REFUNDS (Pull-Payment Pattern)
    // =============================================================================
    
    /**
     * @notice Claim a prize using Merkle proof
     * @param roundId The round to claim from
     * @param prizeIndex Prize slot (0-9)
     * @param prizeTier Prize tier for validation
     * @param proof Merkle proof
     */
    function claim(
        uint256 roundId,
        uint8 prizeIndex,
        uint8 prizeTier,
        bytes32[] calldata proof
    ) external nonReentrant roundExists(roundId) {
        require(prizeIndex < 10, "Invalid prize index");
        
        Round storage round = rounds[roundId];
        require(
            round.status == RoundStatus.Distributed,
            "Round not ready for claims"
        );
        require(round.winnersRoot != bytes32(0), "Winners not committed");
        require(claims[roundId][prizeIndex] == address(0), "Prize already claimed");
        
        // Verify Merkle proof
        bytes32 leaf = keccak256(abi.encodePacked(msg.sender, prizeTier, prizeIndex));
        require(
            MerkleProof.verify(proof, round.winnersRoot, leaf),
            "Invalid Merkle proof"
        );
        
        // Check claim limit (user can claim up to their ticket count)
        uint256 userTickets = userTicketsInRound[roundId][msg.sender];
        require(userTickets > 0, "No tickets in round");
        require(claimCounts[roundId][msg.sender] < userTickets, "Claim limit exceeded");
        
        // Update state before external call
        claims[roundId][prizeIndex] = msg.sender;
        claimCounts[roundId][msg.sender]++;
        
        // Transfer NFT (ERC1155: from, to, id, amount, data)
        uint256 tokenId = prizeNFTs[roundId][prizeIndex];
        require(tokenId != 0, "Prize not set");
        emblemVault.safeTransferFrom(address(this), msg.sender, tokenId, 1, "");
        
        emit PrizeClaimed(roundId, msg.sender, prizeIndex, prizeTier, tokenId);
    }
    
    /**
     * @notice Withdraw accumulated refunds (pull-payment)
     */
    function withdrawRefund() external nonReentrant {
        uint256 amount = refunds[msg.sender];
        require(amount > 0, "No refund available");
        
        // Zero balance before transfer (checks-effects-interactions)
        refunds[msg.sender] = 0;
        
        (bool success, ) = msg.sender.call{value: amount}("");
        require(success, "Refund transfer failed");
        
        emit RefundWithdrawn(msg.sender, amount);
    }
    
    // =============================================================================
    // TICKET PURCHASES & PROOFS
    // =============================================================================
    
    /**
     * @notice Purchase tickets in the current round
     * @param tickets Number of tickets to purchase (1, 5, or 10)
     */
    function buyTickets(uint256 tickets) 
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
        require(round.status == RoundStatus.Open, "Round not open for ticket purchases");
        require(block.timestamp <= round.endTime, "Round ended");
        
        // Additional security: Enforce endTime in buyTickets (clean window closure)
        require(block.timestamp < round.endTime, "Round window closed");
        
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
        
        // Effects: Add to participants if first ticket purchase
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
        require(block.timestamp <= round.endTime, "Round ended");
        
        // Additional security: Enforce endTime in submitProof (clean window closure)
        require(block.timestamp < round.endTime, "Round window closed");
        
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
        
        // Checks: Require participantsRoot to be set before VRF request (fairness + determinism)
        require(rounds[roundId].participantsRoot != bytes32(0), "Participants root must be set before VRF request");
        
        // Security check: Prevent too frequent VRF requests
        // Allow immediate requests if lastVrfRequestTime is 0 (for testing)
        require(
            lastVrfRequestTime == 0 || block.timestamp >= lastVrfRequestTime + 30 seconds,
            "VRF request too frequent"
        );
        
        // Security check: Validate VRF coordinator is still valid
        require(
            address(vrfConfig.coordinator) != address(0),
            "Invalid VRF coordinator"
        );
        
        // Security check: Prevent VRF requests during extreme gas spikes
        require(tx.gasprice <= maxGasPrice, "Gas price too high for VRF request");
        
        // Simple VRF callback gas limit (validation + store seed + update status + emit event)
        uint32 finalGasLimit = 160_000; // Based on actual usage: 154k + small safety margin
        
        // Ensure gas limit is within bounds with higher minimum
        require(finalGasLimit >= VRF_MIN_CALLBACK_GAS, "Estimated gas too low - minimum required");
        require(finalGasLimit <= VRF_MAX_CALLBACK_GAS, "Estimated gas too high");
        
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
        
        // Store VRF seed for reproducibility (for off-chain winner selection)
        rounds[roundId].vrfSeed = bytes32(randomWords[0]);
        
        // Effects: Mark round as ready for Merkle root submission
        rounds[roundId].status = RoundStatus.WinnersReady;
        
        // Interactions: Emit VRF fulfilled event (off-chain bot listens for this)
        emit VRFFulfilled(roundId, requestId, randomWords);
    }
    
    // =============================================================================
    // MERKLE ROOT SUBMISSION & CLAIMS
    // =============================================================================
    
    /**
     * @notice Submit Merkle root of winners after off-chain computation
     * @dev Only callable by owner after VRF has been fulfilled
     * @param roundId Round ID for which winners were computed
     * @param winnersRoot Merkle root of the winners tree
     * @param ipfsHash IPFS hash of the winners file for transparency
     */
    function submitWinnersRoot(
        uint256 roundId,
        bytes32 winnersRoot,
        string calldata ipfsHash
    ) external onlyOwner {
        Round storage round = rounds[roundId];
        
        // Checks: Round must be in WinnersReady status
        require(
            round.status == RoundStatus.WinnersReady,
            "Round not ready for winners submission"
        );
        
        // Checks: Merkle root must not be zero
        require(winnersRoot != bytes32(0), "Invalid Merkle root");
        
        // Checks: Participants root must be set (defensive check)
        require(round.participantsRoot != bytes32(0), "Participants root missing");
        
        // Checks: IPFS hash must not be empty
        require(bytes(ipfsHash).length > 0, "Empty IPFS hash");
        
        // Effects: Store Merkle root and IPFS hash
        round.winnersRoot = winnersRoot;
        winnersCIDs[roundId] = ipfsHash;
        
        // Effects: Update round status to Distributed (ready for claims)
        round.status = RoundStatus.Distributed;
        
        // Effects & Interactions: Distribute fees to creators and next round
        _distributeFees(roundId);
        
        // Interactions: Emit event
        emit WinnersCommitted(roundId, winnersRoot, ipfsHash);
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
        
        // Effects: Mark fees as distributed and update state
        round.feesDistributed = true;
        nextRoundFunds += nextRoundAmount;
        
        // Use pull-payment pattern for creator fees (safer than push)
        creatorBalances[creatorsAddress] += creatorsAmount;
        
        // Emit fee distribution event
        emit FeesDistributed(roundId, creatorsAddress, creatorsAmount, nextRoundAmount);
    }
    
    // =============================================================================
    // VRF RECOVERY FUNCTIONS
    // =============================================================================
    
    /**
     * @notice Reset VRF request if timeout exceeded or for manual recovery
     * @dev Allows recovery from stuck VRF requests by reverting to Snapshot status
     * @param roundId Round to reset VRF for
     */
    function resetVrf(uint256 roundId) 
        external 
        onlyOwner 
        roundExists(roundId) 
    {
        Round storage round = rounds[roundId];
        require(round.status == RoundStatus.VRFRequested, "Round not awaiting VRF");
        
        // Allow reset if timeout exceeded OR manual reset (for emergency recovery)
        require(
            block.timestamp > round.vrfRequestedAt + VRF_REQUEST_TIMEOUT,
            "VRF timeout not exceeded"
        );
        
        // Capture old request ID before clearing
        uint256 oldRequestId = round.vrfRequestId;
        
        // Clear the VRF request mapping first
        vrfRequestToRound[oldRequestId] = 0;
        
        // Effects: Reset round status and clear VRF data
        round.status = RoundStatus.Snapshot;
        round.vrfRequestId = 0;
        round.vrfRequestedAt = 0;
        
        emit VRFTimeoutDetected(roundId, oldRequestId);
    }
    
    /**
     * @notice Reset VRF request if timeout exceeded (legacy function name for compatibility)
     * @dev Allows recovery from stuck VRF requests by reverting to Snapshot status
     * @param roundId Round to reset VRF for
     */
    function resetVrfTimeout(uint256 roundId) 
        external 
        onlyOwner 
        roundExists(roundId) 
    {
        Round storage round = rounds[roundId];
        require(round.status == RoundStatus.VRFRequested, "Round not awaiting VRF");
        
        // Allow reset if timeout exceeded OR manual reset (for emergency recovery)
        require(
            block.timestamp > round.vrfRequestedAt + VRF_REQUEST_TIMEOUT,
            "VRF timeout not exceeded"
        );
        
        // Capture old request ID before clearing
        uint256 oldRequestId = round.vrfRequestId;
        
        // Clear the VRF request mapping first
        vrfRequestToRound[oldRequestId] = 0;
        
        // Effects: Reset round status and clear VRF data
        round.status = RoundStatus.Snapshot;
        round.vrfRequestId = 0;
        round.vrfRequestedAt = 0;
        
        emit VRFTimeoutDetected(roundId, oldRequestId);
    }
    
    /**
     * @notice Auto-close round if end time has passed
     * @dev Anyone can call this to close an expired round
     * @param roundId Round to auto-close
     */
    function autoCloseRound(uint256 roundId) 
        external 
        roundExists(roundId) 
    {
        Round storage round = rounds[roundId];
        require(round.status == RoundStatus.Open, "Round not open");
        require(block.timestamp > round.endTime, "Round not expired");
        
        // Effects: Close the round
        round.status = RoundStatus.Closed;
        
        emit RoundClosed(roundId);
    }
    
    /**
     * @notice Withdraw creator fees (pull-payment pattern)
     * @dev Allows creators to withdraw their accumulated fees safely
     */
    function withdrawCreatorFees() 
        external 
        nonReentrant 
    {
        uint256 amount = creatorBalances[msg.sender];
        require(amount > 0, "No fees to withdraw");
        
        // Effects: Clear balance before transfer
        creatorBalances[msg.sender] = 0;
        
        // Interactions: Transfer fees
        (bool success, ) = msg.sender.call{value: amount}("");
        require(success, "Fee withdrawal failed");
        
        emit CreatorFeesWithdrawn(msg.sender, amount);
    }

    // =============================================================================
    // EMERGENCY & RECOVERY FUNCTIONS
    // =============================================================================
    
    /**
     * @notice Emergency withdrawal of ETH (only when contract is paused)
     * @dev Requires both regular pause AND emergency pause to prevent accidental use
     * @dev This is a last resort function for recovering funds if contract becomes unusable
     * @param to Address to send ETH to (should be multisig or governance contract)
     * @param amount Amount of ETH to withdraw (in wei)
     */
    function emergencyWithdrawETH(address payable to, uint256 amount) 
        external 
        onlyOwner 
        whenPaused 
        whenEmergencyPaused 
        validAddress(to) 
        validAmount(amount) 
    {
        require(amount <= address(this).balance, "Insufficient contract balance");
        require(to != address(this), "Cannot withdraw to self");
        
        // Additional safety: Require contract to be paused for at least 7 days
        // This gives users time to withdraw refunds before emergency action
        require(
            _sevenDayGuardPassed(), 
            "Must wait 7 days after last activity"
        );
        
        (bool success, ) = to.call{value: amount}("");
        require(success, "Emergency ETH transfer failed");
        
        emit EmergencyWithdrawal(to, amount, "ETH");
    }
    
    /**
     * @notice Emergency withdrawal of NFTs (only when contract is paused)
     * @dev For recovering prize NFTs if Emblem Vault integration fails
     * @dev Supports ERC1155 NFTs (Emblem Vault uses ERC1155)
     * @param nftContract The NFT contract address
     * @param tokenId The token ID to withdraw
     * @param amount The amount to withdraw (use 1 for unique NFTs)
     * @param to Address to send NFT to
     */
    function emergencyWithdrawNFT(
        address nftContract, 
        uint256 tokenId,
        uint256 amount,
        address to
    ) 
        external 
        onlyOwner 
        whenPaused 
        whenEmergencyPaused 
        validAddress(nftContract)
        validAddress(to) 
    {
        require(to != address(this), "Cannot withdraw to self");
        require(nftContract != address(0), "Invalid NFT contract");
        require(amount > 0, "Amount must be greater than 0");
        
        // Additional safety check
        require(
            _sevenDayGuardPassed(), 
            "Must wait 7 days after last activity"
        );
        
        // ERC1155 transfer (from, to, id, amount, data)
        IERC1155(nftContract).safeTransferFrom(address(this), to, tokenId, amount, "");
        
        emit EmergencyWithdrawal(to, tokenId, "NFT");
    }
    
    /**
     * @notice Receive function to handle direct ETH transfers
     * @dev Accepts ETH and adds to nextRoundFunds (for legitimate transfers)
     * @dev This prevents ETH from being lost if sent directly to contract
     */
    receive() external payable {
        // Add received ETH to next round funds
        nextRoundFunds += msg.value;
        
        emit DirectETHReceived(msg.sender, msg.value);
    }
    
    /**
     * @notice Fallback function for any other calls
     * @dev Rejects all other function calls to prevent accidental interactions
     */
    fallback() external payable {
        revert("Function not found - use buyTickets() to participate");
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
     * @notice Get comprehensive round state information (optimized for frontend)
     * @param roundId The round to get state for
     * @return round Round struct with all round data
     * @return participantsCount Number of participants in the round
     * @return winnersCount Number of winners selected
     * @return prizesClaimed Number of prizes that have been claimed
     * @return prizeTokenIds Array of 10 NFT token IDs for this round's prizes
     * @return prizeClaimers Array of 10 addresses (address(0) if unclaimed)
     */
    function getRoundState(uint256 roundId) 
        external 
        view 
        roundExists(roundId)
        returns (
            Round memory round,
            uint256 participantsCount,
            uint256 winnersCount,
            uint256 prizesClaimed,
            uint256[10] memory prizeTokenIds,
            address[10] memory prizeClaimers
        ) 
    {
        round = rounds[roundId];
        participantsCount = roundParticipants[roundId].length;
        winnersCount = roundWinners[roundId].length;
        
        // Gather all prize information in one pass
        for (uint8 i = 0; i < 10; i++) {
            prizeTokenIds[i] = prizeNFTs[roundId][i];
            prizeClaimers[i] = claims[roundId][i];
            
            if (prizeClaimers[i] != address(0)) {
                prizesClaimed++;
            }
        }
        
        return (round, participantsCount, winnersCount, prizesClaimed, prizeTokenIds, prizeClaimers);
    }
    
    // =============================================================================
    // MERKLE & CLAIMS VIEW FUNCTIONS
    // =============================================================================
    
    /**
     * @notice Get claim status for a prize
     * @param roundId The round ID
     * @param prizeIndex The prize index (0-9)
     * @return claimer Address that claimed (zero if unclaimed)
     * @return claimed Whether prize has been claimed
     */
    function getClaimStatus(uint256 roundId, uint8 prizeIndex) 
        external 
        view 
        returns (address claimer, bool claimed) 
    {
        claimer = claims[roundId][prizeIndex];
        claimed = claimer != address(0);
    }
    
    /**
     * @notice Get refund balance for a user
     * @param user The user address
     * @return balance The refund balance
     */
    function getRefundBalance(address user) external view returns (uint256 balance) {
        return refunds[user];
    }
    
    /**
     * @notice Get participants root and CID for a round
     * @param roundId The round ID
     * @return root The Merkle root
     * @return cid The IPFS CID
     */
    function getParticipantsData(uint256 roundId) 
        external 
        view 
        returns (bytes32 root, string memory cid) 
    {
        return (rounds[roundId].participantsRoot, participantsCIDs[roundId]);
    }
    
    /**
     * @notice Get winners root and CID for a round
     * @param roundId The round ID
     * @return root The Merkle root
     * @return cid The IPFS CID
     */
    function getWinnersData(uint256 roundId) 
        external 
        view 
        returns (bytes32 root, string memory cid) 
    {
        return (rounds[roundId].winnersRoot, winnersCIDs[roundId]);
    }
    
    /**
     * @notice Verify a Merkle proof for winners (helper for frontend)
     * @param roundId The round ID
     * @param user The user address
     * @param prizeIndex The prize index
     * @param prizeTier The prize tier
     * @param proof The Merkle proof
     * @return valid Whether the proof is valid
     */
    function isWinner(
        uint256 roundId,
        address user,
        uint8 prizeIndex,
        uint8 prizeTier,
        bytes32[] calldata proof
    ) external view returns (bool valid) {
        bytes32 root = rounds[roundId].winnersRoot;
        if (root == bytes32(0)) return false;
        
        bytes32 leaf = keccak256(abi.encodePacked(user, prizeTier, prizeIndex));
        return MerkleProof.verify(proof, root, leaf);
    }
}
