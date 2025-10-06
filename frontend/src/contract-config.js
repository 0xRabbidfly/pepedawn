// Contract configuration for PepedawnRaffle-Remix deployment
// Update this with your actual contract address from Remix

export const CONTRACT_CONFIG = {
  // Your deployed contract address from Remix
  address: "0x5d13Dfbb0ab256C0A82575bD8D242B0BB68A592e",
  
  // Sepolia testnet configuration
  network: 'sepolia',
  chainId: 11155111,
  
  // ABI for PepedawnRaffle-Remix contract (simplified version)
  abi: [
    // Constructor (for reference)
    "constructor(address _vrfCoordinator, uint64 _subscriptionId, bytes32 _keyHash, address _creatorsAddress, address _emblemVaultAddress)",
    
    // View functions
    "function getRound(uint256 _roundId) external view returns (uint256 id, uint64 startTime, uint64 endTime, uint8 status, uint256 totalWagered, uint256 totalTickets, uint256 totalWeight, uint256 vrfRequestId)",
    "function getUserStats(uint256 _roundId, address _user) external view returns (uint256 wagered, uint256 tickets, uint256 weight, bool hasProof)",
    "function currentRoundId() external view returns (uint256)",
    
    // Owner functions
    "function createRound() external",
    "function openRound(uint256 _roundId) external", 
    "function closeRound(uint256 _roundId) external",
    "function requestVRF(uint256 _roundId) external",
    
    // User functions
    "function placeBet(uint256 _roundId) external payable",
    "function submitProof(uint256 _roundId, bytes32 _proof) external",
    
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
    "event BetPlaced(uint256 indexed roundId, address indexed user, uint256 amount, uint256 tickets, uint256 weight)",
    "event ProofSubmitted(uint256 indexed roundId, address indexed user, uint256 weight)",
    "event VRFRequested(uint256 indexed roundId, uint256 indexed requestId)",
    "event PrizesDistributed(uint256 indexed roundId, uint256[] randomWords)"
  ]
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
