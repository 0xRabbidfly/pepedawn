// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/**
 * PepedawnRaffle (refactor)
 *
 * Design decisions locked with the user:
 * - One VRF word (seed-only) per round. Minimal callback.
 * - Off-chain deterministic expansion of winners using the on-chain seed + snapshotted participants.
 * - Commit Merkle roots on-chain for (participants) at snapshot and (winners) after expansion.
 * - Winners claim prizes with Merkle proofs. Refunds/fees use pull-payments.
 * - Denylist allowed any time (owner governance as chosen by user).
 * - Simple owner model (no timelock), non-upgradeable deployment.
 * - NonReentrant on ETH-moving functions. Struct packing & smaller ints for gas.
 * - Direct chain reads for frontend (no subgraph requirement baked-in).
 * - Number of winners fixed at 10 per round; prize tiers deterministically derived from the seed.
 * - Sampling policy: address may win multiple times up to the number of tickets they hold (ticket-level without replacement).
 *
 * NOTE: This file is self-contained for illustration. In production, import OpenZeppelin libraries
 * (Ownable, ReentrancyGuard, MerkleProof, SafeCast, etc.) and Chainlink VRF v2.5 consumer base.
 */

/* =========================
 * Minimal safe utilities
 * ========================= */
abstract contract Ownable {
    address public owner;
    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);
    modifier onlyOwner() { require(msg.sender == owner, "NOT_OWNER"); _; }
    constructor() { owner = msg.sender; emit OwnershipTransferred(address(0), msg.sender); }
    function transferOwnership(address newOwner) external onlyOwner { require(newOwner != address(0), "0"); emit OwnershipTransferred(owner, newOwner); owner = newOwner; }
}

abstract contract ReentrancyGuard {
    uint256 private _status = 1; // 1=NOT_ENTERED,2=ENTERED
    modifier nonReentrant() {
        require(_status == 1, "REENTRANT");
        _status = 2; _; _status = 1;
    }
}

library Merkle {
    function verify(bytes32[] memory proof, bytes32 root, bytes32 leaf) internal pure returns (bool ok) {
        bytes32 computed = leaf;
        for (uint256 i = 0; i < proof.length; i++) {
            bytes32 p = proof[i];
            computed = computed < p ? keccak256(abi.encodePacked(computed, p)) : keccak256(abi.encodePacked(p, computed));
        }
        return computed == root;
    }
}

/* =========================
 * Minimal Chainlink VRF v2.5 interface shims
 * (Replace with official imports in production.)
 * ========================= */
interface IVRFCoordinatorV2Plus {
    function requestRandomWords(
        bytes32 keyHash,
        uint256 subId,
        uint16 minimumRequestConfirmations,
        uint32 callbackGasLimit,
        uint32 numWords
    ) external returns (uint256 requestId);
}

abstract contract VRFConsumerBaseV2Plus {
    function fulfillRandomWords(uint256 requestId, uint256[] memory randomWords) internal virtual;
}

/* =========================
 * Main contract
 * ========================= */
contract PepedawnRaffle is Ownable, ReentrancyGuard, VRFConsumerBaseV2Plus {
    using Merkle for bytes32[];

    /* ===== Config ===== */
    uint256 public constant MAX_TICKETS_PER_WALLET = 10; // enforced via pricing choices in UI (1,5,10)
    uint8    public constant WINNERS_PER_ROUND = 10;

    // Pricing tiers (example): 1,5,10 tickets. Update to match your existing economics.
    uint256 public pricePerTicketWei = 0.01 ether; // example; set via owner

    // Chainlink
    IVRFCoordinatorV2Plus public coordinator;
    bytes32 public keyHash;           // gas lane
    uint256 public subscriptionId;    // VRF sub id
    uint32  public callbackGasLimit;  // keep minimal (seed store + event)
    uint16  public requestConfirmations = 3;

    /* ===== Rounds ===== */
    enum RoundStatus { NotOpened, Open, Snapshotted, VRFRequested, VRFFulfilled, WinnersCommitted, Closed }

    struct Round {
        uint128 totalWeight;     // sum of all tickets (packed)
        uint64  openedAt;
        uint64  snapshottedAt;
        uint64  vrfRequestedAt;
        uint64  vrfFulfilledAt;
        uint64  winnersCommittedAt;
        RoundStatus status;
        bytes32 participantsRoot; // Merkle root of (address, uint128 weight)
        bytes32 winnersRoot;      // Merkle root of (address, uint8 prizeTier, uint8 wins, bytes32 salt?)
        bytes32 vrfSeed;          // single seed from VRF fulfillment
        string  participantsCid;  // off-chain reference (ipfs://...)
        string  winnersCid;       // off-chain reference
    }

    uint256 public currentRoundId;
    mapping(uint256 => Round) public rounds;

    // Per round accounting
    mapping(uint256 => mapping(address => uint128)) public weightOf; // tickets per address
    mapping(uint256 => mapping(address => uint128)) public amountPaid; // wei paid (for refunds)

    // Governance: denylist (owner chosen to allow anytime per user decision)
    mapping(address => bool) public denylisted;

    // Pull-payments (refunds & fees)
    mapping(address => uint256) public refunds;        // aggregated across rounds for simplicity
    uint256 public creatorFeesAccrued;
    address public creatorsAddress; // destination for creator fees (can be owner or separate)

    // Claims tracking (winner claims per (round,address,prizeTier,index))
    mapping(uint256 => mapping(address => uint256)) public claimedBitmap; // bitmask per prize index (0..WINNERS_PER_ROUND-1)

    /* ===== Events ===== */
    event RoundOpened(uint256 indexed roundId);
    event BetPlaced(uint256 indexed roundId, address indexed user, uint256 tickets, uint256 amount);
    event SnapshotCommitted(uint256 indexed roundId, bytes32 participantsRoot, uint256 totalWeight, string participantsCid);
    event VRFRequested(uint256 indexed roundId, uint256 requestId);
    event VRFFulfilled(uint256 indexed roundId, bytes32 seed);
    event WinnersCommitted(uint256 indexed roundId, bytes32 winnersRoot, string winnersCid);
    event WinnerClaimed(uint256 indexed roundId, address indexed user, uint8 prizeTier, uint8 prizeIndex);
    event RefundAccrued(uint256 indexed roundId, address indexed user, uint256 amount);
    event RefundWithdrawn(address indexed user, uint256 amount);
    event CreatorFeesWithdrawn(address indexed to, uint256 amount);
    event DenylistUpdated(address indexed user, bool denied);

    /* ===== Constructor / Admin ===== */
    constructor(
        address _coordinator,
        bytes32 _keyHash,
        uint256 _subscriptionId,
        uint32   _callbackGasLimit,
        address _creatorsAddress
    ) {
        coordinator = IVRFCoordinatorV2Plus(_coordinator);
        keyHash = _keyHash;
        subscriptionId = _subscriptionId;
        callbackGasLimit = _callbackGasLimit; // keep small (e.g., <= 200k)
        creatorsAddress = _creatorsAddress;
        _openNewRound();
    }

    function setPricing(uint256 _pricePerTicketWei) external onlyOwner { require(_pricePerTicketWei > 0, "price"); pricePerTicketWei = _pricePerTicketWei; }
    function setVRFConfig(bytes32 _keyHash, uint32 _callbackGasLimit, uint16 _conf) external onlyOwner { keyHash=_keyHash; callbackGasLimit=_callbackGasLimit; requestConfirmations=_conf; }
    function setCreatorsAddress(address a) external onlyOwner { creatorsAddress = a; }
    function updateDenylist(address user, bool denied) external onlyOwner { denylisted[user] = denied; emit DenylistUpdated(user, denied); }

    /* ===== Round lifecycle ===== */
    function _openNewRound() internal {
        currentRoundId += 1;
        Round storage r = rounds[currentRoundId];
        r.openedAt = uint64(block.timestamp);
        r.status = RoundStatus.Open;
        emit RoundOpened(currentRoundId);
    }

    function placeBet(uint256 tickets) external payable nonReentrant {
        require(!denylisted[msg.sender], "denied");
        require(tickets == 1 || tickets == 5 || tickets == 10, "tickets: 1|5|10");
        Round storage r = rounds[currentRoundId];
        require(r.status == RoundStatus.Open, "not open");

        uint256 expected = tickets * pricePerTicketWei;
        require(msg.value == expected, "bad value");

        // Enforce per-wallet cap across this round
        uint256 newWeight = uint256(weightOf[currentRoundId][msg.sender]) + tickets;
        require(newWeight <= MAX_TICKETS_PER_WALLET, ">max per wallet");

        // Update state
        weightOf[currentRoundId][msg.sender] = uint128(newWeight);
        r.totalWeight += uint128(tickets);
        amountPaid[currentRoundId][msg.sender] += uint128(msg.value);

        emit BetPlaced(currentRoundId, msg.sender, tickets, msg.value);
    }

    /// @notice Owner freezes the participant set and commits the Merkle root and off-chain CID.
    function snapshotRound(uint256 roundId, bytes32 participantsRoot, string calldata participantsCid) external onlyOwner {
        Round storage r = rounds[roundId];
        require(r.status == RoundStatus.Open, "bad status");
        require(participantsRoot != bytes32(0), "root");
        r.participantsRoot = participantsRoot;
        r.participantsCid = participantsCid;
        r.snapshottedAt = uint64(block.timestamp);
        r.status = RoundStatus.Snapshotted;
        emit SnapshotCommitted(roundId, participantsRoot, r.totalWeight, participantsCid);
    }

    /// @notice Owner requests VRF. One word only.
    function requestVRF(uint256 roundId) external onlyOwner {
        Round storage r = rounds[roundId];
        require(r.status == RoundStatus.Snapshotted, "bad status");
        uint256 reqId = coordinator.requestRandomWords(keyHash, subscriptionId, requestConfirmations, callbackGasLimit, 1);
        r.vrfRequestedAt = uint64(block.timestamp);
        r.status = RoundStatus.VRFRequested;
        emit VRFRequested(roundId, reqId);
    }

    /// @dev VRF coordinator calls back here. Minimal work: store seed & event.
    function fulfillRandomWords(uint256 /*requestId*/, uint256[] memory randomWords) internal override {
        // For simplicity, we bind seed to the latest round in VRFRequested state.
        // In production, map requestId -> roundId.
        uint256 roundId = currentRoundId; // placeholder; replace with mapping if multiple outstanding
        Round storage r = rounds[roundId];
        require(r.status == RoundStatus.VRFRequested, "bad status");
        bytes32 seed = bytes32(randomWords[0]);
        r.vrfSeed = seed;
        r.vrfFulfilledAt = uint64(block.timestamp);
        r.status = RoundStatus.VRFFulfilled;
        emit VRFFulfilled(roundId, seed);
    }

    /// @notice After off-chain winner expansion, owner commits the winners root + CID.
    function commitWinners(uint256 roundId, bytes32 winnersRoot, string calldata winnersCid) external onlyOwner {
        Round storage r = rounds[roundId];
        require(r.status == RoundStatus.VRFFulfilled, "bad status");
        require(winnersRoot != bytes32(0), "root");
        r.winnersRoot = winnersRoot;
        r.winnersCid = winnersCid;
        r.winnersCommittedAt = uint64(block.timestamp);
        r.status = RoundStatus.WinnersCommitted;
        emit WinnersCommitted(roundId, winnersRoot, winnersCid);
    }

    /// @notice Winner claims a prize. One call per prize index if multiple wins.
    /// @param prizeIndex 0..WINNERS_PER_ROUND-1 identifying the specific prize draw slot
    /// @param prizeTier  1=fake pack, 2=kek pack, 3=pepe pack
    /// @param proof Merkle proof against winnersRoot for leaf = keccak256(abi.encode(user, uint8 prizeTier, uint8 prizeIndex))
    function claim(uint256 roundId, uint8 prizeIndex, uint8 prizeTier, bytes32[] calldata proof) external nonReentrant {
        require(prizeIndex < WINNERS_PER_ROUND, "idx");
        Round storage r = rounds[roundId];
        require(r.status == RoundStatus.WinnersCommitted, "bad status");
        require(!_isClaimed(roundId, msg.sender, prizeIndex), "claimed");

        bytes32 leaf = keccak256(abi.encode(msg.sender, prizeTier, prizeIndex));
        require(Merkle.verify(proof, r.winnersRoot, leaf), "bad proof");

        _setClaimed(roundId, msg.sender, prizeIndex);
        // Integrate with prize distribution (emit event for off-chain EV delivery)
        emit WinnerClaimed(roundId, msg.sender, prizeTier, prizeIndex);
    }

    function _isClaimed(uint256 roundId, address user, uint8 prizeIndex) internal view returns (bool) {
        uint256 mask = (1 << prizeIndex);
        return (claimedBitmap[roundId][user] & mask) != 0;
    }
    function _setClaimed(uint256 roundId, address user, uint8 prizeIndex) internal {
        uint256 mask = (1 << prizeIndex);
        claimedBitmap[roundId][user] |= mask;
    }

    /* ===== Refunds & Fees (pull-payments) ===== */
    /// @notice Accrue refunds per user (owner computes off-chain and posts results once).
    ///         Leaf format for participants snapshot is (address, weight). Use that to compute pro-rata refunds off-chain if needed.
    function accrueRefund(uint256 roundId, address user, uint256 amount) external onlyOwner {
        require(amount > 0, "amt");
        require(rounds[roundId].status >= RoundStatus.Snapshotted, "round");
        refunds[user] += amount;
        emit RefundAccrued(roundId, user, amount);
    }

    function withdrawRefund() external nonReentrant {
        uint256 amt = refunds[msg.sender];
        require(amt > 0, "none");
        refunds[msg.sender] = 0;
        (bool ok, ) = msg.sender.call{value: amt}("");
        require(ok, "xfer");
        emit RefundWithdrawn(msg.sender, amt);
    }

    function accrueCreatorFees(uint256 amount) external onlyOwner { creatorFeesAccrued += amount; }

    function withdrawCreatorFees(address payable to, uint256 amount) external onlyOwner nonReentrant {
        require(to != address(0), "to");
        require(amount > 0 && amount <= creatorFeesAccrued, "amt");
        creatorFeesAccrued -= amount;
        (bool ok, ) = to.call{value: amount}("");
        require(ok, "xfer");
        emit CreatorFeesWithdrawn(to, amount);
    }

    /* ===== Close & Roll ===== */
    function closeAndOpenNextRound(uint256 roundId) external onlyOwner {
        Round storage r = rounds[roundId];
        require(r.status == RoundStatus.WinnersCommitted, "bad status");
        r.status = RoundStatus.Closed;
        _openNewRound();
    }

    /* ===== View helpers ===== */
    function getRound(uint256 roundId) external view returns (
        RoundStatus status,
        uint128 totalWeight,
        bytes32 participantsRoot,
        bytes32 winnersRoot,
        bytes32 vrfSeed,
        string memory participantsCid,
        string memory winnersCid
    ) {
        Round storage r = rounds[roundId];
        return (r.status, r.totalWeight, r.participantsRoot, r.winnersRoot, r.vrfSeed, r.participantsCid, r.winnersCid);
    }

    /* ===== Receive ===== */
    receive() external payable {}
}
