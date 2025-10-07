// Contract configuration for PepedawnRaffle deployment
// Update this with your actual contract address from deployment

export const CONTRACT_CONFIG = {
  // Your deployed contract address (update after deployment)
  address: "0x359220DbD1E7f2Fcb93f0A16776069e5a48bff79", // Main contract deployed on Sepolia testnet (VRF v2.5)
  
  // Sepolia testnet configuration
  network: 'sepolia',
  chainId: 11155111,
  
  // Enhanced ABI for PepedawnRaffle contract with security features
  abi: [
    // Constructor (for reference)
    "constructor(address _vrfCoordinator, uint64 _subscriptionId, bytes32 _keyHash, address _creatorsAddress, address _emblemVaultAddress)",
    
    // View functions
    "function getRound(uint256 roundId) external view returns (tuple(uint256 id, uint64 startTime, uint64 endTime, uint8 status, uint256 totalTickets, uint256 totalWeight, uint256 totalWagered, uint256 vrfRequestId, uint64 vrfRequestedAt, bool feesDistributed, uint256 participantCount))",
    "function getUserStats(uint256 roundId, address user) external view returns (uint256 wagered, uint256 tickets, uint256 weight, bool hasProof)",
    "function getRoundParticipants(uint256 roundId) external view returns (address[])",
    "function getRoundWinners(uint256 roundId) external view returns (tuple(uint256 roundId, address wallet, uint8 prizeTier, uint256 vrfRequestId, uint256 blockNumber)[])",
    "function currentRoundId() external view returns (uint256)",
    "function nextRoundFunds() external view returns (uint256)",
    "function creatorsAddress() external view returns (address)",
    "function emblemVaultAddress() external view returns (address)",
    "function vrfConfig() external view returns (tuple(address coordinator, uint64 subscriptionId, bytes32 keyHash, uint32 callbackGasLimit, uint16 requestConfirmations))",
    "function userProofInRound(uint256, address) external view returns (tuple(address wallet, uint256 roundId, bytes32 proofHash, bool verified, uint64 submittedAt))",
    
    // Security view functions
    "function paused() external view returns (bool)",
    "function emergencyPaused() external view returns (bool)",
    "function denylisted(address user) external view returns (bool)",
    "function lastVRFRequestTime() external view returns (uint256)",
    
    // Owner functions
    "function createRound() external",
    "function openRound(uint256 roundId) external", 
    "function closeRound(uint256 roundId) external",
    "function snapshotRound(uint256 roundId) external",
    "function requestVRF(uint256 roundId) external",
    "function setValidProof(uint256 roundId, bytes32 proofHash) external",
    
    // Security management functions (owner only)
    "function setDenylistStatus(address user, bool status) external",
    "function setEmergencyPause(bool paused) external",
    "function pause() external",
    "function unpause() external",
    "function updateVRFConfig(address coordinator, uint64 subscriptionId, bytes32 keyHash) external",
    "function updateCreatorsAddress(address newAddress) external",
    "function updateEmblemVaultAddress(address newAddress) external",
    
    // User functions
    "function placeBet(uint256 tickets) external payable",
    "function submitProof(bytes32 proofHash) external",
    
    // Constants
    "function MIN_WAGER() external view returns (uint256)",
    "function BUNDLE_5_PRICE() external view returns (uint256)",
    "function BUNDLE_10_PRICE() external view returns (uint256)",
    "function WALLET_CAP() external view returns (uint256)",
    "function PROOF_MULTIPLIER() external view returns (uint256)",
    
    // Events
    "event RoundCreated(uint256 indexed roundId, uint64 startTime, uint64 endTime)",
    "event RoundOpened(uint256 indexed roundId)",
    "event RoundClosed(uint256 indexed roundId)",
    "event RoundSnapshot(uint256 indexed roundId, uint256 totalTickets, uint256 totalWeight)",
    "event BetPlaced(uint256 indexed roundId, address indexed user, uint256 amount, uint256 tickets, uint256 weight)",
    "event ProofSubmitted(address indexed wallet, uint256 indexed roundId, bytes32 proofHash, uint256 newWeight)",
    "event ProofRejected(address indexed wallet, uint256 indexed roundId, bytes32 proofHash)",
    "event ValidProofSet(uint256 indexed roundId, bytes32 validProofHash)",
    "event VRFRequested(uint256 indexed roundId, uint256 indexed requestId)",
    "event PrizesDistributed(uint256 indexed roundId, uint256[] randomWords)",
    "event EmblemVaultPrizeAssigned(uint256 indexed roundId, address indexed winner, uint256 indexed assetId, uint256 timestamp)",
    "event RoundPrizesDistributed(uint256 indexed roundId, uint256 winnerCount, uint256 timestamp)",
    "event FeesDistributed(uint256 indexed roundId, uint256 creatorsAmount, uint256 nextRoundAmount)",
    
    // Security events
    "event AddressDenylisted(address indexed user, bool status)",
    "event EmergencyPauseToggled(bool paused)",
    "event VRFTimeoutDetected(uint256 indexed roundId, uint256 requestTime)",
    "event CircuitBreakerTriggered(uint256 indexed roundId, string reason)",
    "event SecurityValidationFailed(address indexed user, string reason)"
  ]
};

// Security configuration
export const SECURITY_CONFIG = {
  // Network validation
  SUPPORTED_NETWORKS: [11155111], // Sepolia testnet
  NETWORK_NAMES: {
    11155111: 'Sepolia Testnet'
  },
  
  // Input validation
  MAX_PROOF_LENGTH: 1000,
  MIN_PROOF_LENGTH: 1,
  
  // Rate limiting
  MIN_TX_INTERVAL: 5000, // 5 seconds between transactions
  
  // Security checks
  ENABLE_DENYLIST_CHECK: true,
  ENABLE_PAUSE_CHECK: true,
  ENABLE_NETWORK_VALIDATION: true
};

// Helper function to validate contract configuration
export function validateContractConfig() {
  if (CONTRACT_CONFIG.address === "0x0000000000000000000000000000000000000000") {
    console.warn("⚠️ Contract address not set! Please update CONTRACT_CONFIG.address with your deployed contract address.");
    return false;
  }
  
  if (!CONTRACT_CONFIG.address.startsWith('0x') || CONTRACT_CONFIG.address.length !== 42) {
    console.error("❌ Invalid contract address format!");
    return false;
  }
  
  console.log("✅ Contract configuration valid:", CONTRACT_CONFIG.address);
  return true;
}

// Validate network compatibility
export function validateNetwork(chainId) {
  const numericChainId = Number(chainId);
  
  if (!SECURITY_CONFIG.SUPPORTED_NETWORKS.includes(numericChainId)) {
    const networkName = SECURITY_CONFIG.NETWORK_NAMES[numericChainId] || `Chain ID ${numericChainId}`;
    const supportedNames = SECURITY_CONFIG.SUPPORTED_NETWORKS
      .map(id => SECURITY_CONFIG.NETWORK_NAMES[id] || `Chain ID ${id}`)
      .join(', ');
    
    throw new Error(`Unsupported network: ${networkName}. Please switch to: ${supportedNames}`);
  }
  
  return true;
}

// Sanitize user input
export function sanitizeInput(input, type = 'string') {
  if (typeof input !== 'string') {
    throw new Error('Input must be a string');
  }
  
  // Remove null bytes and control characters
  const sanitized = input.replace(/[\x00-\x1f\x7f-\x9f]/g, '');
  
  switch (type) {
    case 'proof':
      if (sanitized.length < SECURITY_CONFIG.MIN_PROOF_LENGTH) {
        throw new Error(`Proof too short (minimum ${SECURITY_CONFIG.MIN_PROOF_LENGTH} characters)`);
      }
      if (sanitized.length > SECURITY_CONFIG.MAX_PROOF_LENGTH) {
        throw new Error(`Proof too long (maximum ${SECURITY_CONFIG.MAX_PROOF_LENGTH} characters)`);
      }
      return sanitized.trim();
    
    case 'address':
      if (!/^0x[a-fA-F0-9]{40}$/.test(sanitized)) {
        throw new Error('Invalid Ethereum address format');
      }
      return sanitized.toLowerCase();
    
    default:
      return sanitized.trim();
  }
}

// Rate limiting helper
const lastTransactionTimes = new Map();

export function checkRateLimit(userAddress) {
  const now = Date.now();
  const lastTx = lastTransactionTimes.get(userAddress?.toLowerCase());
  
  if (lastTx && (now - lastTx) < SECURITY_CONFIG.MIN_TX_INTERVAL) {
    const remaining = Math.ceil((SECURITY_CONFIG.MIN_TX_INTERVAL - (now - lastTx)) / 1000);
    throw new Error(`Please wait ${remaining} seconds before submitting another transaction`);
  }
  
  lastTransactionTimes.set(userAddress?.toLowerCase(), now);
  return true;
}

// Security validation for contract interactions
export async function validateSecurityState(contract, userAddress) {
  if (!contract || !userAddress) {
    throw new Error('Contract and user address required for security validation');
  }
  
  const checks = [];
  
  // Check if contract is paused
  if (SECURITY_CONFIG.ENABLE_PAUSE_CHECK) {
    checks.push(
      contract.paused().then(paused => {
        if (paused) throw new Error('Contract is currently paused');
      }),
      contract.emergencyPaused().then(emergencyPaused => {
        if (emergencyPaused) throw new Error('Contract is in emergency pause mode');
      })
    );
  }
  
  // Check if user is denylisted
  if (SECURITY_CONFIG.ENABLE_DENYLIST_CHECK) {
    checks.push(
      contract.denylisted(userAddress).then(denylisted => {
        if (denylisted) throw new Error('Address is denylisted and cannot interact with the contract');
      })
    );
  }
  
  await Promise.all(checks);
  return true;
}

// Basic read-only data functions for small-scale site
export async function getBasicRoundData(contract) {
  if (!contract) return null;
  
  try {
    const currentRoundId = await contract.currentRoundId();
    if (currentRoundId.toString() === '0') {
      return { hasActiveRound: false };
    }
    
    const roundData = await contract.getRound(currentRoundId);
    
    return {
      hasActiveRound: true,
      roundId: currentRoundId.toString(),
      status: Number(roundData.status),
      totalTickets: roundData.totalTickets.toString(),
      totalWeight: roundData.totalWeight.toString(),
      totalWagered: roundData.totalWagered.toString(),
      participantCount: roundData.participantCount.toString(),
      endTime: Number(roundData.endTime)
    };
  } catch (error) {
    console.error('Error fetching basic round data:', error);
    return null;
  }
}

export async function getUserBasicStats(contract, userAddress, roundId) {
  if (!contract || !userAddress || !roundId) return null;
  
  try {
    const stats = await contract.getUserStats(roundId, userAddress);
    const roundData = await getBasicRoundData(contract);
    
    // Calculate basic odds
    let odds = '0%';
    if (roundData && Number(roundData.totalWeight) > 0 && Number(stats.weight) > 0) {
      odds = ((Number(stats.weight) / Number(roundData.totalWeight)) * 100).toFixed(1) + '%';
    }
    
    return {
      tickets: stats.tickets.toString(),
      weight: stats.weight.toString(),
      wagered: stats.wagered.toString(),
      hasProof: stats.hasProof,
      odds: odds
    };
  } catch (error) {
    console.error('Error fetching user stats:', error);
    return null;
  }
}
