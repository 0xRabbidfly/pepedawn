import { ethers } from 'ethers';
import './styles/main.css';
import { 
  initUI, 
  updateWalletInfo, 
  updateRoundStatus, 
  updateLeaderboard, 
  updateProgressIndicator,
  updateUserStats, 
  showTransactionStatus,
  showSecurityStatus,
  validateTransactionParams,
  handleTransactionError,
  populateRoundSelector
} from './ui.js';
import { 
  CONTRACT_CONFIG, 
  validateContractConfig, 
  validateNetwork,
  sanitizeInput,
  checkRateLimit,
  validateSecurityState,
  SECURITY_CONFIG
} from './contract-config.js';
import { displayClaimablePrizes, displayRefundButton } from './components/claims.js';
import { formatAddress } from './utils/formatters.js';

// Suppress harmless MetaMask filter errors
const originalError = console.error;
console.error = (...args) => {
  // Filter out MetaMask "No filter for index" errors
  const errorString = args.join(' ');
  if (errorString.includes('No filter for index') || 
      errorString.includes('eth_getFilterChanges')) {
    return; // Suppress these specific errors
  }
  originalError.apply(console, args);
};

// Global state
let provider = null;
let signer = null;
let contract = null;
let userAddress = null;
let currentRoundStatus = null; // Track current round status for UI updates
let eventListenersSetup = false; // Prevent duplicate event listener setup
const processedEvents = new Set(); // Track processed events to prevent duplicates

// Simple event logging for small-scale site
function logEvent(eventType, eventData) {
  console.log(`🎲 ${eventType}:`, eventData);
}

// formatAddress is now imported from ./utils/formatters.js

// Update button states based on round status and user state
async function updateButtonStates(roundState = null) {
  const submitProofBtn = document.getElementById('submit-proof');
  const buyTicketsBtn = document.getElementById('buy-tickets');
  const ticketCards = document.querySelectorAll('.ticket-option-card');
  const proofInput = document.getElementById('proof-input');
  
  // If contract not available, disable all interactive buttons
  if (!contract) {
    if (submitProofBtn) {
      submitProofBtn.disabled = true;
      submitProofBtn.title = 'Contract not available';
    }
    if (buyTicketsBtn) {
      buyTicketsBtn.disabled = true;
      buyTicketsBtn.title = 'Contract not available';
    }
    ticketCards.forEach(card => {
      card.style.pointerEvents = 'none';
      card.style.opacity = '0.5';
      card.title = 'Contract not available';
    });
    return;
  }
  
  try {
    // Get current round info
    const currentRoundId = await contract.currentRoundId();
    
    if (currentRoundId.toString() === '0') {
      // No active round - disable interactions
      currentRoundStatus = 0;
    } else {
      // Use pre-fetched round state if available
      let roundData;
      if (roundState) {
        roundData = roundState.round;
      } else {
        // Get round data
        roundData = await contract.getRound(currentRoundId);
      }
      currentRoundStatus = Number(roundData.status);
    }
    
    // Check if round is open for betting (status 1 = Open)
    const isRoundOpen = currentRoundStatus === 1;
    
    // Update ticket purchase buttons
    if (buyTicketsBtn) {
      buyTicketsBtn.disabled = !isRoundOpen || !userAddress;
      if (!userAddress) {
        buyTicketsBtn.title = 'Connect wallet to purchase tickets';
      } else if (!isRoundOpen) {
        buyTicketsBtn.title = 'Round is not open for ticket purchases';
      } else {
        buyTicketsBtn.title = '';
      }
    }
    
    ticketCards.forEach(card => {
      if (!isRoundOpen || !userAddress) {
        card.style.pointerEvents = 'none';
        card.style.opacity = '0.5';
        if (!userAddress) {
          card.title = 'Connect wallet to place bets';
        } else if (!isRoundOpen) {
          card.title = 'Round is not open for betting';
        }
      } else {
        card.style.pointerEvents = 'auto';
        card.style.opacity = '1';
        card.title = '';
      }
    });
    
    // Update proof submission button - more complex logic
    if (submitProofBtn && proofInput) {
      let proofDisabled = true;
      let proofTooltip = '';
      
      if (!userAddress) {
        proofDisabled = true;
        proofTooltip = 'Connect wallet to submit proof';
      } else if (!isRoundOpen) {
        proofDisabled = true;
        proofTooltip = 'Round is not open for proof submission';
      } else {
        // Check user stats
        try {
          const userStats = await contract.getUserStats(currentRoundId, userAddress);
          
          if (userStats.tickets.toString() === '0') {
            proofDisabled = true;
            proofTooltip = 'Purchase tickets before submitting proof';
          } else if (userStats.hasProof) {
            proofDisabled = true;
            proofTooltip = 'Proof already submitted for this round';
          } else {
            proofDisabled = false;
            proofTooltip = '';
          }
        } catch {
          // If we can't get user stats, default to basic round check
          proofDisabled = !isRoundOpen;
          proofTooltip = isRoundOpen ? '' : 'Round is not open for proof submission';
        }
      }
      
      submitProofBtn.disabled = proofDisabled;
      submitProofBtn.title = proofTooltip;
      proofInput.disabled = proofDisabled;
      if (proofDisabled && proofTooltip) {
        proofInput.placeholder = proofTooltip;
      } else {
        proofInput.placeholder = 'Paste your puzzle proof here...';
      }
    }
    
  } catch (error) {
    // On error, disable buttons for safety
    console.error('Error updating button states:', error);
    if (submitProofBtn) {
      submitProofBtn.disabled = true;
      submitProofBtn.title = 'Error checking round status';
    }
    if (buyTicketsBtn) {
      buyTicketsBtn.disabled = true;
      buyTicketsBtn.title = 'Error checking round status';
    }
    ticketCards.forEach(card => {
      card.style.pointerEvents = 'none';
      card.style.opacity = '0.5';
      card.title = 'Error checking round status';
    });
  }
}

// Toggle proof section visibility - make it globally accessible
window.toggleProofSection = function() {
  const content = document.getElementById('proof-form');
  const icon = document.querySelector('#proof-section .collapse-icon');
  
  if (content.style.display === 'none') {
    content.style.display = 'block';
    icon.textContent = '▲';
  } else {
    content.style.display = 'none';
    icon.textContent = '▼';
  }
}

// Close ticket office - make it globally accessible
window.closeTicketOffice = function() {
  const ticketOffice = document.getElementById('ticket-office');
  if (ticketOffice) {
    ticketOffice.classList.remove('open');
  }
  document.querySelectorAll('.ticket-option-card').forEach(card => card.classList.remove('selected'));
}

// Detect mobile device
function isMobileDevice() {
  return /Android|webOS|iPhone|iPad|iPod|BlackBerry|IEMobile|Opera Mini/i.test(navigator.userAgent);
}

// EIP-6963: Discover all available wallets (Modern Standard - supports Rabby, Trust, etc.)
let discoveredWallets = new Map();

function initWalletDiscovery() {
  // Listen for EIP-6963 announcements
  window.addEventListener('eip6963:announceProvider', (event) => {
    const { info, provider } = event.detail;
    console.log('🔍 EIP-6963 wallet discovered:', info.name);
    discoveredWallets.set(info.uuid, { info, provider });
  });

  // Request wallets to announce themselves
  window.dispatchEvent(new Event('eip6963:requestProvider'));
}

// Get all available wallet providers (EIP-6963 + legacy)
function getAllProviders() {
  const providers = [];
  
  // Add EIP-6963 discovered wallets
  discoveredWallets.forEach(({ info, provider }) => {
    providers.push({
      name: info.name,
      icon: info.icon,
      provider: provider,
      uuid: info.uuid,
      rdns: info.rdns
    });
  });
  
  // Fallback: Check legacy window.ethereum (for older wallets)
  if (window.ethereum) {
    // Check if already added via EIP-6963
    const alreadyAdded = providers.some(p => p.provider === window.ethereum);
    
    if (!alreadyAdded) {
      // Add window.ethereum with detected name
      let name = 'Browser Wallet';
      if (window.ethereum.isMetaMask) name = 'MetaMask';
      else if (window.ethereum.isCoinbaseWallet) name = 'Coinbase Wallet';
      else if (window.ethereum.isBraveWallet) name = 'Brave Wallet';
      else if (window.ethereum.isRabby) name = 'Rabby Wallet';
      else if (window.ethereum.isTrust) name = 'Trust Wallet';
      
      providers.push({
        name: name,
        provider: window.ethereum,
        uuid: 'legacy-ethereum'
      });
    }
    
    // Check for multiple providers in array (old multi-wallet pattern)
    if (window.ethereum.providers?.length > 0) {
      window.ethereum.providers.forEach((provider, index) => {
        const alreadyAdded = providers.some(p => p.provider === provider);
        if (!alreadyAdded) {
          let name = 'Wallet ' + (index + 1);
          if (provider.isMetaMask) name = 'MetaMask';
          else if (provider.isCoinbaseWallet) name = 'Coinbase Wallet';
          else if (provider.isBraveWallet) name = 'Brave Wallet';
          else if (provider.isRabby) name = 'Rabby Wallet';
          else if (provider.isTrust) name = 'Trust Wallet';
          
          providers.push({
            name: name,
            provider: provider,
            uuid: 'legacy-' + index
          });
        }
      });
    }
  }
  
  console.log(`✅ Found ${providers.length} wallet provider(s):`, providers.map(p => p.name).join(', '));
  return providers;
}

// Get the best available provider (handles multiple wallet scenarios)
// Now returns the first available, but can be extended with user selection UI
function detectProvider() {
  const providers = getAllProviders();
  
  if (providers.length === 0) {
    console.log('❌ No Web3 provider detected');
    return null;
  }
  
  // Priority order for auto-selection when multiple wallets exist
  const priorityOrder = [
    'MetaMask',           // Most popular
    'Rabby Wallet',       // Popular for DeFi
    'Coinbase Wallet',    // Major exchange wallet
    'Trust Wallet',       // Mobile-first
    'Rainbow',            // Mobile-friendly
    'Brave Wallet',       // Browser wallet (lower priority)
    'Browser Wallet'      // Generic fallback
  ];
  
  // If MetaMask Mobile Browser, use it
  if (navigator.userAgent.includes('MetaMaskMobile') && providers.length > 0) {
    console.log('✅ MetaMask Mobile Browser detected');
    return providers[0].provider;
  }
  
  // Try to find preferred wallet from priority list
  for (const preferredName of priorityOrder) {
    const wallet = providers.find(p => p.name === preferredName);
    if (wallet) {
      console.log(`✅ Auto-selected: ${wallet.name}`);
      
      // Warn if using Brave Wallet when others available
      if (wallet.name === 'Brave Wallet' && providers.length > 1) {
        console.log('⚠️ Brave Wallet detected. Other wallets available:', 
          providers.filter(p => p.name !== 'Brave Wallet').map(p => p.name).join(', '));
      }
      
      return wallet.provider;
    }
  }
  
  // Fallback: return first provider
  console.log(`✅ Using first available provider: ${providers[0].name}`);
  return providers[0].provider;
}

// Initialize page-specific data (read-only, no wallet required)
async function initializePageData() {
  if (!contract) {
    console.log('⚠️ Contract not available - showing fallback UI');
    
    // Show error message instead of "Loading..." on leaderboard page
    if (window.location.pathname.includes('leaderboard.html')) {
      const winnersSelect = document.getElementById('winners-round-select');
      const roundSelect = document.getElementById('round-select');
      const winnersList = document.getElementById('winners-list');
      const leaderboardList = document.getElementById('leaderboard-list');
      
      if (winnersSelect) {
        winnersSelect.innerHTML = '<option value="">Contract unavailable</option>';
      }
      if (roundSelect) {
        roundSelect.innerHTML = '<option value="">Contract unavailable</option>';
      }
      if (winnersList) {
        winnersList.innerHTML = '<p style="text-align: center; padding: 2rem; color: var(--text-secondary);">Unable to load contract data. Please check your connection and refresh.</p>';
      }
      if (leaderboardList) {
        leaderboardList.innerHTML = '<p style="text-align: center; padding: 2rem; color: var(--text-secondary);">Unable to load contract data. Please check your connection and refresh.</p>';
      }
    }
    
    // Show error message on claim page
    if (window.location.pathname.includes('claim.html')) {
      const claimsSelect = document.getElementById('claims-round-select');
      if (claimsSelect) {
        claimsSelect.innerHTML = '<option value="">Contract unavailable</option>';
      }
    }
    
    return;
  }
  
  try {
    const currentRoundId = await contract.currentRoundId();
    
    // Initialize leaderboard page
    if (window.location.pathname.includes('leaderboard.html')) {
      console.log('📊 Initializing leaderboard page...');
      
      // Populate round selectors
      await populateRoundSelector(contract);
      
      // Display winners and leaderboard for current round
      if (currentRoundId.toString() !== '0') {
        const { displayWinners } = await import('./components/claims.js');
        await displayWinners(contract, Number(currentRoundId));
        await updateLeaderboard(contract);
      }
    }
    
    // Initialize claim page (populate selector, but claims require wallet)
    if (window.location.pathname.includes('claim.html')) {
      console.log('🎁 Initializing claim page...');
      await populateRoundSelector(contract);
      // Note: displayClaimablePrizes will be called in setupWalletConnection() when user connects
    }
    
    // Initialize rules page
    if (window.location.pathname.includes('rules.html')) {
      console.log('📜 Initializing rules page...');
      await updateContractInfo(contract);
    }
    
  } catch (error) {
    console.error('Error initializing page data:', error);
  }
}

// Initialize the application
async function init() {
  console.log('Initializing PEPEDAWN application...');
  
  // Initialize UI components
  initUI();
  
  // Set up event listeners
  setupEventListeners();
  
  // Set up round selectors for leaderboard and claim pages
  if (window.location.pathname.includes('leaderboard.html') || window.location.pathname.includes('claim.html')) {
    setupLeaderboardRoundSelector();
  }
  
  // Detect the best provider
  const detectedProvider = detectProvider();
  
  // Check if wallet is already connected (with conflict protection)
  if (detectedProvider) {
    try {
      const accounts = await detectedProvider.request({ method: 'eth_accounts' });
      if (accounts.length > 0) {
        await connectWalletSilent(); // Silent connection - no toast
      }
    } catch (error) {
      console.log('No wallet auto-connection:', error);
      // Handle wallet extension conflicts gracefully
      if (error.message && error.message.includes('ethereum')) {
        console.log('Wallet extension conflict detected - user should disable conflicting extensions');
      }
    }
  } else if (isMobileDevice()) {
    console.log('📱 Mobile device detected without wallet - loading read-only mode');
  }
  
  // Load contract (will use fallback provider if needed)
  await loadContract();
  
  // Initialize page-specific data (even without wallet connection)
  await initializePageData();
  
  // Start periodic updates
  startPeriodicUpdates();
}

// Set up event listeners
function setupEventListeners() {
  const connectBtn = document.getElementById('connect-wallet');
  if (connectBtn) {
    connectBtn.addEventListener('click', connectWallet);
  }
  
  // Hamburger menu functionality
  const hamburgerMenu = document.getElementById('hamburger-menu');
  const mainNav = document.getElementById('main-nav');
  
  if (hamburgerMenu && mainNav) {
    hamburgerMenu.addEventListener('click', function() {
      hamburgerMenu.classList.toggle('active');
      mainNav.classList.toggle('active');
    });
    
    // Close menu when clicking on nav links
    const navLinks = mainNav.querySelectorAll('a');
    navLinks.forEach(link => {
      link.addEventListener('click', function() {
        hamburgerMenu.classList.remove('active');
        mainNav.classList.remove('active');
      });
    });
    
    // Close menu when clicking outside
    document.addEventListener('click', function(event) {
      if (!hamburgerMenu.contains(event.target) && !mainNav.contains(event.target)) {
        hamburgerMenu.classList.remove('active');
        mainNav.classList.remove('active');
      }
    });
  }
  
  // Use event delegation to handle ticket card clicks
  const bettingForm = document.getElementById('betting-form');
  if (bettingForm) {
    bettingForm.addEventListener('click', function(event) {
      const card = event.target.closest('.ticket-option-card');
      if (card) {
        selectTickets({ currentTarget: card });
      }
    });
  }
  
  const buyTicketsBtn = document.getElementById('buy-tickets');
  if (buyTicketsBtn) {
    buyTicketsBtn.addEventListener('click', buyTickets);
  }
  
  // Mobile purchase button
  const mobileBuyTicketsBtn = document.getElementById('mobile-place-bet');
  if (mobileBuyTicketsBtn) {
    mobileBuyTicketsBtn.addEventListener('click', buyTicketsMobile);
  }
  
  const submitProofBtn = document.getElementById('submit-proof');
  if (submitProofBtn) {
    submitProofBtn.addEventListener('click', submitProof);
  }
}

// Set up leaderboard round selector
function setupLeaderboardRoundSelector() {
  const roundSelect = document.getElementById('round-select');
  if (roundSelect) {
    roundSelect.addEventListener('change', async function() {
      const selectedValue = this.value;
      
      // Update leaderboard with selected round
      if (contract) {
        await updateLeaderboard(contract, selectedValue);
      }
    });
  }
  
  const winnersRoundSelect = document.getElementById('winners-round-select');
  if (winnersRoundSelect) {
    winnersRoundSelect.addEventListener('change', async function() {
      const selectedValue = this.value;
      
      // Update winners with selected round
      if (contract) {
        const { displayWinners } = await import('./components/claims.js');
        await displayWinners(contract, Number(selectedValue));
      }
    });
  }
  
  const claimsRoundSelect = document.getElementById('claims-round-select');
  if (claimsRoundSelect) {
    claimsRoundSelect.addEventListener('change', async function() {
      const selectedValue = this.value;
      
      // Update claims with selected round
      if (contract && userAddress) {
        await displayClaimablePrizes(contract, userAddress, Number(selectedValue));
      }
    });
  }
}

// Check for unclaimed prizes across recent rounds
async function checkUnclaimedPrizes(contract, userAddress) {
  if (!contract || !userAddress) return { count: 0, rounds: [] };
  
  try {
    const currentRoundId = await contract.currentRoundId();
    const currentRoundNum = Number(currentRoundId);
    
    if (currentRoundNum === 0) return { count: 0, rounds: [] };
    
    const unclaimedPrizes = [];
    
    // Check last 5 rounds only
    const startRound = Math.max(1, currentRoundNum - 4);
    
    for (let roundId = startRound; roundId <= currentRoundNum; roundId++) {
      try {
        // Check round status first - only process Distributed rounds
        const roundState = await contract.getRoundState(roundId);
        const status = Number(roundState.round.status);
        if (status !== 6) continue; // Only Distributed rounds
        
        // Get winners CID from contract
        const winnersCID = await contract.winnersCIDs(roundId);
        if (!winnersCID || winnersCID === '') continue;
        
        // Fetch winners file (local, fast)
        const { fetchWinnersFile } = await import('./services/ipfs.js');
        const { getPrizesForAddress } = await import('./services/merkle.js');
        
        const winnersFile = await fetchWinnersFile(winnersCID, roundId);
        if (!winnersFile || !winnersFile.winners) continue;
        
        // Get user's prizes in this round
        const userPrizes = getPrizesForAddress(winnersFile.winners, userAddress);
        if (userPrizes.length === 0) continue;
        
        // Check each prize if claimed (batch this for performance)
        for (const prize of userPrizes) {
          const claimedAddress = roundState.prizeClaimers[prize.prizeIndex];
          const isClaimed = claimedAddress !== ethers.ZeroAddress;
          
          if (!isClaimed) {
            unclaimedPrizes.push({
              roundId,
              prizeIndex: prize.prizeIndex,
              prizeTier: prize.prizeTier
            });
          }
        }
      } catch (error) {
        // Silently skip rounds with errors (file not found, etc.)
        console.log(`Skipping round ${roundId}:`, error.message);
      }
    }
    
    return {
      count: unclaimedPrizes.length,
      rounds: [...new Set(unclaimedPrizes.map(p => p.roundId))],
      prizes: unclaimedPrizes
    };
  } catch (error) {
    console.error('Error checking unclaimed prizes:', error);
    return { count: 0, rounds: [] };
  }
}

// Display unclaimed prizes notification
async function displayUnclaimedPrizesNotification(contract, userAddress) {
  const notificationElement = document.getElementById('unclaimed-prizes-notification');
  if (!notificationElement) return;
  
  try {
    const result = await checkUnclaimedPrizes(contract, userAddress);
    
    if (result.count > 0) {
      notificationElement.innerHTML = `
        <a href="/claim.html" class="unclaimed-link">
          <span class="unclaimed-icon">🎁</span>
          <span class="unclaimed-text">${result.count} unclaimed prize${result.count > 1 ? 's' : ''}!</span>
        </a>
      `;
      notificationElement.style.display = 'block';
    } else {
      notificationElement.style.display = 'none';
    }
  } catch (error) {
    console.error('Error displaying unclaimed prizes notification:', error);
    notificationElement.style.display = 'none';
  }
}

// Contract information functions
async function updateContractInfo(contract) {
  if (!contract) return;
  
  try {
    // Get contract address from config
    const contractAddress = CONTRACT_CONFIG.address;
    document.getElementById('contract-address').textContent = contractAddress;
    
    // Get contract owner
    const owner = await contract.owner();
    document.getElementById('contract-owner').textContent = owner;
    
    // Get contract ETH balance
    const balance = await provider.getBalance(contractAddress);
    const balanceEth = ethers.formatEther(balance);
    document.getElementById('contract-balance').textContent = `${parseFloat(balanceEth).toFixed(4)} ETH`;
    
    // Get current round
    const currentRoundId = await contract.currentRoundId();
    document.getElementById('current-round').textContent = currentRoundId.toString() !== '0' ? `Round ${currentRoundId}` : 'No active rounds';
    
    // Get NFT count (check emblem vault balance)
    try {
      const emblemVaultAddress = await contract.emblemVaultAddress();
      const emblemVault = new ethers.Contract(emblemVaultAddress, ['function balanceOf(address) view returns (uint256)'], provider);
      const nftBalance = await emblemVault.balanceOf(contractAddress);
      document.getElementById('contract-nfts').textContent = `${nftBalance.toString()} NFTs`;
    } catch (error) {
      document.getElementById('contract-nfts').textContent = 'Unable to fetch';
    }
    
    // Check contract verification (simplified check)
    checkContractVerification(contractAddress);
    
  } catch (error) {
    console.error('Error updating contract info:', error);
    // Set error states
    document.getElementById('contract-owner').textContent = 'Error loading';
    document.getElementById('contract-balance').textContent = 'Error loading';
    document.getElementById('contract-nfts').textContent = 'Error loading';
    document.getElementById('current-round').textContent = 'Error loading';
  }
}

async function checkContractVerification(contractAddress) {
  try {
    // Simple verification check - try to get contract code
    const code = await provider.getCode(contractAddress);
    if (code && code !== '0x') {
      document.getElementById('verified-status').style.display = 'none';
      document.getElementById('verified-checkmark').style.display = 'inline';
    } else {
      document.getElementById('verified-status').textContent = 'Not verified';
      document.getElementById('verified-status').style.color = '#f44336';
    }
  } catch (error) {
    document.getElementById('verified-status').textContent = 'Unable to check';
    document.getElementById('verified-status').style.color = '#f44336';
  }
}

// Copy to clipboard function
function copyToClipboard(elementId) {
  const element = document.getElementById(elementId);
  const text = element.textContent;
  
  navigator.clipboard.writeText(text).then(() => {
    // Show feedback
    const button = element.parentElement.querySelector('.copy-btn');
    const originalText = button.textContent;
    button.textContent = '✅';
    button.style.background = 'rgba(76, 175, 80, 0.3)';
    
    setTimeout(() => {
      button.textContent = originalText;
      button.style.background = '';
    }, 1500);
  }).catch(err => {
    console.error('Failed to copy: ', err);
    alert('Failed to copy to clipboard');
  });
}

// Make copyToClipboard globally available
window.copyToClipboard = copyToClipboard;

// Connect to wallet with enhanced security validations
async function connectWallet() {
  try {
    // Detect the best available provider
    const detectedProvider = detectProvider();
    
    if (!detectedProvider) {
      // On mobile, check if we're in a mobile browser (not MetaMask browser)
      if (isMobileDevice()) {
        // Only redirect to MetaMask app if we're NOT already in MetaMask Mobile Browser
        if (!navigator.userAgent.includes('MetaMaskMobile')) {
          const currentUrl = window.location.href;
          const metamaskDeepLink = `https://metamask.app.link/dapp/${currentUrl.replace(/^https?:\/\//, '')}`;
          
          showTransactionStatus('Opening MetaMask app...', 'info');
          
          // Try to open MetaMask app
          setTimeout(() => {
            window.location.href = metamaskDeepLink;
          }, 500);
          
          // Show instructions after a delay
          setTimeout(() => {
            showTransactionStatus('If MetaMask doesn\'t open, please install MetaMask app or use the MetaMask app browser to visit this site', 'warning');
          }, 3000);
          
          return;
        }
      }
      
      showTransactionStatus('Please install MetaMask extension or use MetaMask Mobile Browser', 'error');
      return;
    }
    
    // Warn if using Brave Wallet (suboptimal experience)
    if (detectedProvider.isBraveWallet && !detectedProvider.isMetaMask) {
      showTransactionStatus('Brave Wallet detected. For best experience, install MetaMask extension.', 'warning');
    }
    
    showTransactionStatus('Connecting to wallet...', 'info');
    
    // Request account access using the detected provider
    await detectedProvider.request({ method: 'eth_requestAccounts' });
    
    // Create provider and signer using the detected provider
    provider = new ethers.BrowserProvider(detectedProvider);
    signer = await provider.getSigner();
    userAddress = await signer.getAddress();
    
    console.log('Wallet connected:', userAddress);
    
    await setupWalletConnection(true); // true = show success toast
    
  } catch (error) {
    console.error('Error connecting wallet:', error);
    
    // Handle user rejection
    if (error.code === 4001) {
      showTransactionStatus('Connection cancelled by user', 'warning');
    } else {
      const errorMsg = error.message || 'Unknown error';
      showTransactionStatus('Failed to connect wallet: ' + errorMsg, 'error');
    }
  }
}

// Silent wallet connection for auto-connection on page load
async function connectWalletSilent() {
  try {
    const detectedProvider = detectProvider();
    if (!detectedProvider) return;
    
    // Create provider and signer without requesting permission
    provider = new ethers.BrowserProvider(detectedProvider);
    signer = await provider.getSigner();
    userAddress = await signer.getAddress();
    
    console.log('Wallet auto-connected:', userAddress);
    
    await setupWalletConnection(false); // false = no success toast
    
  } catch (error) {
    console.log('Silent wallet connection failed:', error.message);
    // Don't show error toast for silent connection failures
  }
}

// Common wallet setup logic
async function setupWalletConnection(showSuccessToast = true) {
  // Validate network
  try {
    const network = await provider.getNetwork();
    validateNetwork(network.chainId);
    console.log('✅ Network validated:', SECURITY_CONFIG.NETWORK_NAMES[Number(network.chainId)]);
  } catch (networkError) {
    console.warn('⚠️ Network validation failed:', networkError.message);
    showTransactionStatus(networkError.message, 'warning');
  }
  
  // Set up network change listener with detected provider
  const detectedProvider = detectProvider();
  if (detectedProvider && detectedProvider.on) {
    detectedProvider.on('chainChanged', handleNetworkChange);
    detectedProvider.on('accountsChanged', handleAccountChange);
  }
  
  // Update UI
  await updateWalletInfo(userAddress, provider);
  
  // Load contract with signer
  await loadContract();
  
  // Update user stats and security status
  if (contract) {
    // Get current round ID and state
    const currentRoundId = await contract.currentRoundId();
    let roundState = null;
    if (currentRoundId.toString() !== '0') {
      roundState = await contract.getRoundState(currentRoundId);
    }
    
    await updateUserStats(contract, userAddress, roundState);
    showSecurityStatus(contract, userAddress);
    await updateButtonStates(roundState); // Update button states after connecting
    
    // Update refunds and unclaimed prizes (only on main page)
    console.log('🔍 Current page:', window.location.pathname);
    console.log('🔍 Current round ID:', currentRoundId.toString());
    if (currentRoundId.toString() !== '0') {
      if (window.location.pathname.includes('main.html')) {
        await displayRefundButton(contract, userAddress);
        await displayUnclaimedPrizesNotification(contract, userAddress);
      }
    }
    
    // Show user's claimable prizes if on claim page
    // (Round selector already populated in initializePageData)
    if (window.location.pathname.includes('claim.html')) {
      if (currentRoundId.toString() !== '0') {
        await displayClaimablePrizes(contract, userAddress, Number(currentRoundId));
      }
    }
    
    // Note: Leaderboard and rules pages are initialized in initializePageData()
    // (they work without wallet, so no need to reinitialize on wallet connect)
  }
  
  if (showSuccessToast) {
    showTransactionStatus('Wallet connected successfully', 'success');
  }
}

// Handle network changes
function handleNetworkChange(chainId) {
  console.log('Network changed to:', chainId);
  
  try {
    validateNetwork(chainId);
    console.log('✅ Network change validated');
    
    // Reset event listeners flag on network change
    eventListenersSetup = false;
    processedEvents.clear(); // Clear processed events
    
    // Reload contract and update UI
    loadContract().then(async () => {
      if (userAddress && contract) {
        // Fetch round state once
        const currentRoundId = await contract.currentRoundId();
        let roundState = null;
        if (currentRoundId.toString() !== '0') {
          roundState = await contract.getRoundState(currentRoundId);
        }
        
        updateWalletInfo(userAddress, provider);
        updateUserStats(contract, userAddress, roundState);
        showSecurityStatus(contract, userAddress);
        updateButtonStates(roundState);
      }
    });
    
  } catch (error) {
    console.warn('⚠️ Network change validation failed:', error.message);
    showTransactionStatus(error.message, 'warning');
  }
}

// Handle account changes
function handleAccountChange(accounts) {
  console.log('Account changed:', accounts);
  
  if (accounts.length === 0) {
    // User disconnected wallet
    userAddress = null;
    signer = null;
    contract = null;
    eventListenersSetup = false; // Reset listener flag
    processedEvents.clear(); // Clear processed events
    
    // Reset UI
    const walletInfo = document.getElementById('wallet-info');
    if (walletInfo) walletInfo.style.display = 'none';
    
    const connectBtn = document.getElementById('connect-wallet');
    if (connectBtn) {
      connectBtn.textContent = 'Connect Wallet';
      connectBtn.disabled = false;
      connectBtn.style.display = 'inline-block';
    }
    
    showTransactionStatus('Wallet disconnected', 'info');
  } else {
    // Account switched - reconnect without requesting permission again
    reconnectWallet(accounts[0]);
  }
}

// Reconnect wallet when account changes
async function reconnectWallet(newAddress) {
  try {
    console.log('Reconnecting wallet for account:', newAddress);
    showTransactionStatus('Switching wallet...', 'info');
    
    // Update global state
    userAddress = newAddress;
    
    // Detect provider and create new provider and signer
    const detectedProvider = detectProvider();
    if (!detectedProvider) {
      console.error('No provider detected during reconnection');
      return;
    }
    
    provider = new ethers.BrowserProvider(detectedProvider);
    signer = await provider.getSigner();
    
    // Reset event listeners flag
    eventListenersSetup = false;
    processedEvents.clear();
    
    // Update UI with new wallet info
    await updateWalletInfo(userAddress, provider);
    
    // Load contract with new signer
    await loadContract();
    
    // Update all UI components
    if (contract) {
      // Fetch round state once
      const currentRoundId = await contract.currentRoundId();
      let roundState = null;
      if (currentRoundId.toString() !== '0') {
        roundState = await contract.getRoundState(currentRoundId);
      }
      
      await updateUserStats(contract, userAddress, roundState);
      showSecurityStatus(contract, userAddress);
      await updateButtonStates(roundState);
      await updateRoundStatus(contract, provider, roundState);
      await updateProgressIndicator(contract, roundState);
      await updateLeaderboard(contract);
      
      if (currentRoundId.toString() !== '0') {
        if (window.location.pathname.includes('main.html')) {
          await displayRefundButton(contract, userAddress);
          await displayUnclaimedPrizesNotification(contract, userAddress);
        }
        if (window.location.pathname.includes('claim.html')) {
          await displayClaimablePrizes(contract, userAddress, Number(currentRoundId));
        }
      }
    }
    
    showTransactionStatus('Wallet switched successfully', 'success');
    
  } catch (error) {
    console.error('Error reconnecting wallet:', error);
    showTransactionStatus('Failed to switch wallet: ' + error.message, 'error');
  }
}

// Create fallback public provider for read-only access
async function createFallbackProvider() {
  // Try multiple public RPC endpoints in order (in case of rate limiting)
  const rpcEndpoints = [
    'https://rpc.sepolia.org',
    'https://ethereum-sepolia.publicnode.com',
    'https://1rpc.io/sepolia'
  ];
  
  for (const rpcUrl of rpcEndpoints) {
    try {
      console.log('📡 Trying fallback provider:', rpcUrl);
      const fallbackProvider = new ethers.JsonRpcProvider(rpcUrl);
      
      // Test the connection with a timeout
      const timeoutPromise = new Promise((_, reject) => 
        setTimeout(() => reject(new Error('Connection timeout')), 5000)
      );
      
      const blockPromise = fallbackProvider.getBlockNumber();
      
      await Promise.race([blockPromise, timeoutPromise]);
      console.log('✅ Fallback provider connected successfully:', rpcUrl);
      return fallbackProvider;
      
    } catch (error) {
      console.warn(`⚠️ Failed to connect to ${rpcUrl}:`, error.message);
      // Continue to next RPC endpoint
    }
  }
  
  console.error('❌ All fallback providers failed');
  return null;
}

// Load contract from configuration with enhanced security
async function loadContract() {
  try {
    console.log('📝 Loading contract...');
    
    // Validate contract configuration
    if (!validateContractConfig()) {
      console.log('Contract not configured - working in mock mode');
      return;
    }
    
    let providerToUse = null;
    let isReadOnly = false;
    
    // Determine which provider to use
    if (signer) {
      // User has signed in - use signer for write operations
      providerToUse = signer;
      console.log('✅ Using signer for read/write access');
      
      // Log network info on mobile for debugging (but don't block - let validateNetwork handle it)
      if (isMobileDevice()) {
        try {
          const network = await provider.getNetwork();
          console.log('📱 Mobile network detected:', network.chainId.toString(), network.name);
          console.log('📱 Expected network:', CONTRACT_CONFIG.chainId, CONTRACT_CONFIG.network);
        } catch (networkError) {
          console.warn('⚠️ Could not check network:', networkError.message);
        }
      }
    } else if (provider) {
      // Provider available but no signer - use provider for read-only
      providerToUse = provider;
      isReadOnly = true;
      console.log('✅ Using provider for read-only access');
      
      // Check if we're on the correct network
      try {
        const network = await provider.getNetwork();
        validateNetwork(network.chainId);
        console.log('✅ Network validated for contract loading');
      } catch (networkError) {
        console.warn('⚠️ Network validation failed:', networkError.message);
        showTransactionStatus(networkError.message, 'warning');
        
        // Fall back to public provider
        console.log('📡 Falling back to public RPC provider');
        providerToUse = await createFallbackProvider();
        isReadOnly = true;
      }
    } else {
      // No wallet provider - use fallback public provider for read-only access
      console.log('📱 No wallet detected - using fallback public provider for read-only access');
      providerToUse = await createFallbackProvider();
      isReadOnly = true;
    }
    
    if (!providerToUse) {
      console.error('❌ No provider available');
      showTransactionStatus('Unable to connect to blockchain. Please try again.', 'error');
      return;
    }
    
    // Create contract instance
    contract = new ethers.Contract(CONTRACT_CONFIG.address, CONTRACT_CONFIG.abi, providerToUse);
    
    console.log('✅ Contract instance created:', CONTRACT_CONFIG.address, isReadOnly ? '(read-only)' : '(read/write)');
    
    // Verify contract is accessible (more retries on mobile due to network issues)
    const isMobile = isMobileDevice();
    const maxRetries = isMobile ? 3 : (isReadOnly ? 2 : 1);
    let retryCount = 0;
    let contractAccessible = false;
    
    if (isMobile) {
      console.log('📱 Mobile device detected - using extended retry logic for contract verification');
    }
    
    while (retryCount < maxRetries && !contractAccessible) {
      try {
        console.log(`🔍 Verifying contract accessibility (attempt ${retryCount + 1}/${maxRetries})...`);
        console.log('🔍 Contract address:', CONTRACT_CONFIG.address);
        console.log('🔍 Provider type:', isReadOnly ? 'read-only' : 'wallet signer');
        
        // Add timeout for mobile (mobile networks can be slow)
        const timeoutMs = isMobile ? 10000 : 5000;
        const timeoutPromise = new Promise((_, reject) => 
          setTimeout(() => reject(new Error('Contract call timeout')), timeoutMs)
        );
        
        const roundIdPromise = contract.currentRoundId();
        const roundId = await Promise.race([roundIdPromise, timeoutPromise]);
        
        console.log('✅ Contract accessibility verified. Current round:', roundId.toString());
        contractAccessible = true;
      } catch (contractError) {
        retryCount++;
        console.error(`❌ Contract check failed (attempt ${retryCount}/${maxRetries}):`, contractError);
        console.error('❌ Error details:', {
          message: contractError.message,
          code: contractError.code,
          data: contractError.data
        });
        
        if (retryCount < maxRetries) {
          // Wait before retrying (longer wait on mobile due to network issues)
          const retryDelay = isMobile ? 3000 : 1500;
          console.log(`⏳ Waiting ${retryDelay}ms before retry...`);
          await new Promise(resolve => setTimeout(resolve, retryDelay));
        } else {
          console.error('❌ Contract not accessible after all retries');
          
          // If this was a wallet connection, show warning but DON'T reset wallet state
          // User's wallet should stay connected even if contract isn't accessible
          if (!isReadOnly) {
            showTransactionStatus('Unable to verify contract. Contract may not be deployed or network may be wrong.', 'error');
            contract = null; // Clear contract but keep wallet connected
            return;
          }
          
          showTransactionStatus('Unable to load contract data. Please check your connection.', 'error');
          contract = null;
          return;
        }
      }
    }
    
    // Set up event listeners (only if we have a wallet connection)
    if (contract && !isReadOnly) {
      setupContractEventListeners();
    }
    
  } catch (error) {
    console.error('Error loading contract:', error);
    showTransactionStatus('Failed to load contract: ' + error.message, 'error');
  }
}

// Set up comprehensive contract event listeners with error handling
function setupContractEventListeners() {
  if (!contract) return;
  
  // Prevent duplicate listener setup
  if (eventListenersSetup) {
    console.log('⏭️ Event listeners already set up, skipping...');
    return;
  }
  
  try {
    console.log('🎧 Setting up enhanced contract event listeners...');
    
    // Remove any existing listeners to prevent duplicates
    contract.removeAllListeners();
    
    // Mark as set up
    eventListenersSetup = true;
    
    // Note: Using contract.on() only listens to NEW events (from current block forward)
    // Historical events are not replayed automatically in ethers v6
    
    // Round lifecycle events
    contract.on('RoundCreated', (...args) => {
      const event = args[args.length - 1]; // Event is always the last parameter
      const [roundId, startTime, endTime] = args;
      
      // Deduplicate events
      const eventId = `RoundCreated-${roundId.toString()}-${event?.transactionHash || 'unknown'}`;
      if (processedEvents.has(eventId)) return;
      processedEvents.add(eventId);
      
      const eventData = { 
        roundId: roundId.toString(), 
        startTime: Number(startTime), 
        endTime: Number(endTime),
        blockNumber: event?.blockNumber,
        transactionHash: event?.transactionHash
      };
      console.log('🆕 Round created:', eventData);
      logEvent('RoundCreated', eventData);
      
      showTransactionStatus(`New round #${eventData.roundId} created!`, 'success');
      updateRoundStatus(contract, provider);
      updateButtonStates();
    });
    
    contract.on('RoundOpened', (...args) => {
      const event = args[args.length - 1]; // Event is always the last parameter
      const [roundId] = args;
      
      // Deduplicate events
      const eventId = `RoundOpened-${roundId.toString()}-${event?.transactionHash || 'unknown'}`;
      if (processedEvents.has(eventId)) return;
      processedEvents.add(eventId);
      
      const eventData = { 
        roundId: roundId.toString(),
        blockNumber: event?.blockNumber,
        transactionHash: event?.transactionHash
      };
      console.log('🟢 Round opened:', eventData);
      logEvent('RoundOpened', eventData);
      
      showTransactionStatus(`Round #${eventData.roundId} is now open for betting!`, 'success');
      updateRoundStatus(contract, provider);
      updateButtonStates();
    });
    
    contract.on('RoundClosed', (...args) => {
      const event = args[args.length - 1]; // Event is always the last parameter
      const [roundId] = args;
      
      // Deduplicate events using transaction hash
      const eventId = `RoundClosed-${roundId.toString()}-${event?.transactionHash || 'unknown'}`;
      if (processedEvents.has(eventId)) {
        return; // Already processed this event
      }
      processedEvents.add(eventId);
      
      const eventData = { 
        roundId: roundId.toString(),
        blockNumber: event?.blockNumber,
        transactionHash: event?.transactionHash
      };
      console.log('🔴 Round closed:', eventData);
      logEvent('RoundClosed', eventData);
      
      showTransactionStatus(`Round #${eventData.roundId} closed. No more bets accepted.`, 'info');
      updateRoundStatus(contract, provider);
      updateButtonStates();
    });
    
    contract.on('RoundSnapshot', (...args) => {
      const event = args[args.length - 1]; // Event is always the last parameter
      const [roundId, totalTickets, totalWeight] = args;
      
      // Deduplicate events
      const eventId = `RoundSnapshot-${roundId.toString()}-${event?.transactionHash || 'unknown'}`;
      if (processedEvents.has(eventId)) return;
      processedEvents.add(eventId);
      
      const eventData = { 
        roundId: roundId.toString(),
        totalTickets: totalTickets.toString(),
        totalWeight: totalWeight.toString(),
        blockNumber: event?.blockNumber,
        transactionHash: event?.transactionHash
      };
      console.log('📸 Round snapshot:', eventData);
      logEvent('RoundSnapshot', eventData);
      
      showTransactionStatus(`Round #${eventData.roundId} snapshot taken. Preparing for draw...`, 'info');
      updateRoundStatus(contract, provider);
    });
    
    // User interaction events
    contract.on('WagerPlaced', (...args) => {
      const event = args[args.length - 1]; // Event is always the last parameter
      const [roundId, user, amount, tickets, weight] = args;
      
      // Deduplicate events
      const eventId = `WagerPlaced-${user}-${roundId.toString()}-${event?.transactionHash || 'unknown'}`;
      if (processedEvents.has(eventId)) return;
      processedEvents.add(eventId);
      
      const eventData = {
        roundId: roundId.toString(),
        user: user.toLowerCase(),
        amount: ethers.formatEther(amount),
        tickets: tickets.toString(),
        weight: weight.toString(),
        blockNumber: event?.blockNumber,
        transactionHash: event?.transactionHash
      };
      console.log('🎲 Bet placed:', eventData);
      logEvent('WagerPlaced', eventData);
      
      // Update UI if it's the current user
      if (eventData.user === userAddress?.toLowerCase()) {
        showTransactionStatus(`✅ Your bet confirmed! ${eventData.tickets} tickets for ${eventData.amount} ETH`, 'success');
        updateUserStats(contract, userAddress);
        updateButtonStates(); // User can now submit proof
      } else {
        showTransactionStatus(`New bet: ${eventData.tickets} tickets by ${formatAddress(eventData.user)}`, 'info');
      }
      
      // Update leaderboard, progress, and round status
      updateRoundStatus(contract, provider);
      updateProgressIndicator(contract);
      updateLeaderboard(contract);
    });
    
    contract.on('ProofSubmitted', (roundId, user, weight, event) => {
      // Deduplicate events
      const eventId = `ProofSubmitted-${user}-${roundId.toString()}-${event?.transactionHash || 'unknown'}`;
      if (processedEvents.has(eventId)) return;
      processedEvents.add(eventId);
      
      const eventData = {
        roundId: roundId.toString(),
        user: user.toLowerCase(),
        weight: weight.toString(),
        blockNumber: event.blockNumber,
        transactionHash: event.transactionHash
      };
      console.log('🧩 Proof submitted:', eventData);
      logEvent('ProofSubmitted', eventData);
      
      // Update UI if it's the current user
      if (eventData.user === userAddress?.toLowerCase()) {
        showTransactionStatus(`✅ Puzzle proof confirmed! Weight bonus applied.`, 'success');
        
        // Update proof status element
        const proofStatus = document.getElementById('proof-status');
        if (proofStatus) {
          proofStatus.textContent = '✅ Puzzle proof confirmed! Weight bonus applied.';
          proofStatus.className = 'success';
          proofStatus.style.display = 'block';
        }
        
        updateUserStats(contract, userAddress);
        updateButtonStates(); // Proof button should now be disabled
      } else {
        showTransactionStatus(`Puzzle solved by ${formatAddress(eventData.user)}!`, 'info');
      }
      
      // Update leaderboard
      updateLeaderboard(contract);
    });
    
    contract.on('ProofRejected', (user, roundId, proofHash, event) => {
      // Deduplicate events
      const eventId = `ProofRejected-${user}-${roundId.toString()}-${event?.transactionHash || 'unknown'}`;
      if (processedEvents.has(eventId)) return;
      processedEvents.add(eventId);
      
      const eventData = {
        roundId: roundId.toString(),
        user: user.toLowerCase(),
        proofHash: proofHash,
        blockNumber: event.blockNumber,
        transactionHash: event.transactionHash
      };
      console.log('❌ Proof rejected:', eventData);
      logEvent('ProofRejected', eventData);
      
      // Update UI if it's the current user
      if (eventData.user === userAddress?.toLowerCase()) {
        showTransactionStatus(`❌ Puzzle proof incorrect. No weight bonus applied.`, 'warning');
        
        // Update proof status element
        const proofStatus = document.getElementById('proof-status');
        if (proofStatus) {
          proofStatus.textContent = '❌ Puzzle proof incorrect. No weight bonus applied.';
          proofStatus.className = 'error';
          proofStatus.style.display = 'block';
        }
        
        updateUserStats(contract, userAddress);
        updateButtonStates(); // Proof button should now be disabled
      }
      
      // Update leaderboard (even for rejected proofs, user stats may change)
      updateLeaderboard(contract);
    });
    
    // VRF and prize distribution events
    contract.on('VRFRequested', (roundId, requestId, event) => {
      // Deduplicate events
      const eventId = `VRFRequested-${roundId.toString()}-${event?.transactionHash || 'unknown'}`;
      if (processedEvents.has(eventId)) return;
      processedEvents.add(eventId);
      
      const eventData = {
        roundId: roundId.toString(),
        requestId: requestId.toString(),
        blockNumber: event.blockNumber,
        transactionHash: event.transactionHash
      };
      console.log('🎰 VRF requested:', eventData);
      logEvent('VRFRequested', eventData);
      
      showTransactionStatus(`🎰 Random number requested for round #${eventData.roundId}. Drawing winners...`, 'info');
      updateRoundStatus(contract, provider);
    });
    
    // Note: RoundPrizesDistributed listener removed - duplicate of listener at line 813
    
    // Emblem Vault integration events
    contract.on('EmblemVaultPrizeAssigned', (...args) => {
      const event = args[args.length - 1]; // Event is always the last parameter
      const [roundId, winner, assetId, timestamp] = args;
      
      // Deduplicate events
      const eventId = `EmblemVaultPrizeAssigned-${roundId.toString()}-${winner.toLowerCase()}-${assetId.toString()}-${event?.transactionHash || 'unknown'}`;
      if (processedEvents.has(eventId)) return;
      processedEvents.add(eventId);
      
      const eventData = {
        roundId: roundId.toString(),
        winner: winner.toLowerCase(),
        assetId: assetId.toString(),
        timestamp: Number(timestamp),
        blockNumber: event?.blockNumber,
        transactionHash: event?.transactionHash
      };
      console.log('🎁 Emblem Vault prize assigned:', eventData);
      logEvent('EmblemVaultPrizeAssigned', eventData);
      
      // Show notification if it's the current user
      if (eventData.winner === userAddress?.toLowerCase()) {
        showTransactionStatus(`🎁 Congratulations! You won asset #${eventData.assetId}!`, 'success');
      }
    });
    
    contract.on('RoundPrizesDistributed', (...args) => {
      const event = args[args.length - 1]; // Event is always the last parameter
      const [roundId, winnerCount, timestamp] = args;
      
      // Deduplicate events
      const eventId = `RoundPrizesDistributed-${roundId.toString()}-${event?.transactionHash || 'unknown'}`;
      if (processedEvents.has(eventId)) return;
      processedEvents.add(eventId);
      
      const eventData = {
        roundId: roundId.toString(),
        winnerCount: Number(winnerCount),
        timestamp: Number(timestamp),
        blockNumber: event?.blockNumber,
        transactionHash: event?.transactionHash
      };
      console.log('🏆 Round prizes distribution completed:', eventData);
      logEvent('RoundPrizesDistributed', eventData);
      
      showTransactionStatus(`🏆 Round #${eventData.roundId} completed! ${eventData.winnerCount} prizes distributed.`, 'success');
      updateRoundStatus(contract, provider);
    });
    
    contract.on('FeesDistributed', (roundId, creatorsAmount, nextRoundAmount, event) => {
      // Deduplicate events
      const eventId = `FeesDistributed-${roundId.toString()}-${event?.transactionHash || 'unknown'}`;
      if (processedEvents.has(eventId)) return;
      processedEvents.add(eventId);
      
      const eventData = {
        roundId: roundId.toString(),
        creatorsAmount: ethers.formatEther(creatorsAmount),
        nextRoundAmount: ethers.formatEther(nextRoundAmount),
        blockNumber: event.blockNumber,
        transactionHash: event.transactionHash
      };
      console.log('💰 Fees distributed:', eventData);
      logEvent('FeesDistributed', eventData);
    });
    
    // Security events
    contract.on('AddressDenylisted', (user, status, event) => {
      // Deduplicate events
      const eventId = `AddressDenylisted-${user}-${event?.transactionHash || 'unknown'}`;
      if (processedEvents.has(eventId)) return;
      processedEvents.add(eventId);
      
      const eventData = {
        user: user.toLowerCase(),
        status: status,
        blockNumber: event.blockNumber,
        transactionHash: event.transactionHash
      };
      console.log('🚫 Address denylist status changed:', eventData);
      logEvent('AddressDenylisted', eventData);
      
      if (eventData.user === userAddress?.toLowerCase()) {
        const message = status ? 'Your address has been denylisted' : 'Your address has been removed from denylist';
        showTransactionStatus(message, status ? 'error' : 'success');
        showSecurityStatus(contract, userAddress);
      }
    });
    
    contract.on('EmergencyPauseToggled', (paused, event) => {
      // Deduplicate events
      const eventId = `EmergencyPauseToggled-${paused}-${event?.transactionHash || 'unknown'}`;
      if (processedEvents.has(eventId)) return;
      processedEvents.add(eventId);
      
      const eventData = {
        paused: paused,
        blockNumber: event.blockNumber,
        transactionHash: event.transactionHash
      };
      console.log('⚠️ Emergency pause toggled:', eventData);
      logEvent('EmergencyPauseToggled', eventData);
      
      const message = paused ? 'Emergency pause activated' : 'Emergency pause deactivated';
      showTransactionStatus(message, paused ? 'warning' : 'success');
      
      if (userAddress) {
        showSecurityStatus(contract, userAddress);
      }
    });
    
    contract.on('CircuitBreakerTriggered', (roundId, reason, event) => {
      // Deduplicate events
      const eventId = `CircuitBreakerTriggered-${roundId.toString()}-${event?.transactionHash || 'unknown'}`;
      if (processedEvents.has(eventId)) return;
      processedEvents.add(eventId);
      
      const eventData = {
        roundId: roundId.toString(),
        reason: reason,
        blockNumber: event.blockNumber,
        transactionHash: event.transactionHash
      };
      console.log('🔒 Circuit breaker triggered:', eventData);
      logEvent('CircuitBreakerTriggered', eventData);
      
      showTransactionStatus(`⚠️ Circuit breaker: ${eventData.reason}`, 'warning');
    });
    
    contract.on('SecurityValidationFailed', (user, reason, event) => {
      // Deduplicate events
      const eventId = `SecurityValidationFailed-${user}-${event?.transactionHash || 'unknown'}`;
      if (processedEvents.has(eventId)) return;
      processedEvents.add(eventId);
      
      const eventData = {
        user: user.toLowerCase(),
        reason: reason,
        blockNumber: event.blockNumber,
        transactionHash: event.transactionHash
      };
      console.log('❌ Security validation failed:', eventData);
      logEvent('SecurityValidationFailed', eventData);
      
      if (eventData.user === userAddress?.toLowerCase()) {
        showTransactionStatus(`Security validation failed: ${eventData.reason}`, 'error');
      }
    });
    
    // VRF security events
    contract.on('VRFTimeoutDetected', (roundId, requestTime, event) => {
      // Deduplicate events
      const eventId = `VRFTimeoutDetected-${roundId.toString()}-${event?.transactionHash || 'unknown'}`;
      if (processedEvents.has(eventId)) return;
      processedEvents.add(eventId);
      
      const eventData = {
        roundId: roundId.toString(),
        requestTime: requestTime.toString(),
        blockNumber: event.blockNumber,
        transactionHash: event.transactionHash
      };
      console.log('⏰ VRF timeout detected:', eventData);
      logEvent('VRFTimeoutDetected', eventData);
      
      showTransactionStatus(`⏰ VRF timeout detected for round #${eventData.roundId}`, 'warning');
    });
    
    console.log('✅ Contract event listeners set up successfully');
    
  } catch (error) {
    console.error('❌ Error setting up contract event listeners:', error);
    showTransactionStatus('Failed to set up event listeners', 'error');
  }
}

// Select ticket bundle
function selectTickets(event) {
  const card = event.currentTarget;
  const isMobile = window.innerWidth <= 768;
  
  // If this card is already selected, unselect it
  if (card.classList.contains('selected') || card.classList.contains('mobile-selected')) {
    card.classList.remove('selected', 'mobile-selected');
    
    if (isMobile) {
      // Hide mobile slide-out
      const mobileSlideout = document.getElementById('mobile-purchase-slideout');
      if (mobileSlideout) {
        mobileSlideout.classList.remove('open');
      }
    } else {
      // Hide desktop ticket office
      const ticketOffice = document.getElementById('ticket-office');
      if (ticketOffice) {
        ticketOffice.classList.remove('open');
      }
    }
    return;
  }
  
  const tickets = parseInt(card.dataset.tickets);
  const amount = parseFloat(card.dataset.amount);
  
  if (isMobile) {
    // Mobile: Update mobile slide-out and show it
    const mobileTicketsEl = document.getElementById('mobile-selected-tickets');
    const mobileAmountEl = document.getElementById('mobile-selected-amount');
    
    if (mobileTicketsEl) mobileTicketsEl.textContent = String(tickets);
    if (mobileAmountEl) mobileAmountEl.textContent = String(amount);
    
    // Highlight selected card and remove selection from others
    document.querySelectorAll('.ticket-option-card').forEach(c => c.classList.remove('mobile-selected'));
    card.classList.add('mobile-selected');
    
    // Show mobile slide-out
    const mobileSlideout = document.getElementById('mobile-purchase-slideout');
    if (mobileSlideout) {
      mobileSlideout.classList.add('open');
    }
  } else {
    // Desktop: Update desktop UI and show ticket office (simple show/hide like mobile)
    const desktopTicketsEl = document.getElementById('selected-tickets');
    const desktopAmountEl = document.getElementById('selected-amount');
    
    if (desktopTicketsEl) desktopTicketsEl.textContent = String(tickets);
    if (desktopAmountEl) desktopAmountEl.textContent = String(amount);
    
    // Highlight selected card and remove selection from others
    document.querySelectorAll('.ticket-option-card').forEach(c => c.classList.remove('selected'));
    card.classList.add('selected');
    
    // Show ticket office with simple open class (no animations)
    const ticketOffice = document.getElementById('ticket-office');
    if (ticketOffice) {
      ticketOffice.classList.add('open');
    }
  }
}

// Draw animated connector between card and ticket office
function drawTicketConnector(card, office) {
  const svg = document.getElementById('ticket-connector');
  const path = document.getElementById('connector-path');
  const particles = document.querySelectorAll('.particle-ticket');
  
  if (!svg || !path || !card || !office) return;
  
  // Get bounding boxes relative to the betting section
  const section = document.getElementById('betting-section');
  const sectionRect = section.getBoundingClientRect();
  const cardRect = card.getBoundingClientRect();
  const officeRect = office.getBoundingClientRect();
  
  // Calculate start point (right-center of card)
  const startX = cardRect.right - sectionRect.left;
  const startY = cardRect.top + cardRect.height / 2 - sectionRect.top;
  
  // Calculate end point (left-center of office)
  const endX = officeRect.left - sectionRect.left;
  const endY = officeRect.top + officeRect.height / 2 - sectionRect.top;
  
  // Create a smooth curved path (cubic bezier)
  const controlX1 = startX + (endX - startX) * 0.3;
  const controlY1 = startY - 30; // Curve upward
  const controlX2 = startX + (endX - startX) * 0.7;
  const controlY2 = endY + 30; // Curve downward
  
  const pathData = `M ${startX} ${startY} C ${controlX1} ${controlY1}, ${controlX2} ${controlY2}, ${endX} ${endY}`;
  path.setAttribute('d', pathData);
  
  // Show and animate the SVG
  svg.classList.add('active');
  path.classList.add('animated');
  
  // Particle animations removed - keeping only the beam
}

// Hide ticket connector
function hideTicketConnector() {
  const svg = document.getElementById('ticket-connector');
  const path = document.getElementById('connector-path');
  
  if (!svg || !path) return;
  
  // Hide animations
  svg.classList.remove('active');
  path.classList.remove('animated');
}

// Buy tickets with enhanced security validations (unified for desktop & mobile)
async function buyTickets() {
  try {
    if (!contract || !signer || !userAddress) {
      showTransactionStatus('Please connect your wallet first', 'error');
      return;
    }
    
    // Detect mobile/desktop based on window width (same as selectTickets)
    const isMobile = window.innerWidth <= 768;
    
    // Get ticket/amount data from appropriate source (desktop or mobile)
    const ticketsElementId = isMobile ? 'mobile-selected-tickets' : 'selected-tickets';
    const amountElementId = isMobile ? 'mobile-selected-amount' : 'selected-amount';
    
    const ticketsElement = document.getElementById(ticketsElementId);
    const amountElement = document.getElementById(amountElementId);
    
    const tickets = parseInt(ticketsElement?.textContent || '0');
    const amount = parseFloat(amountElement?.textContent || '0');
    
    if (!tickets || tickets <= 0 || !amount || amount <= 0) {
      showTransactionStatus('Please select a ticket bundle first', 'error');
      return;
    }
    
    // Validate transaction parameters
    try {
      validateTransactionParams({ amount, tickets, userAddress });
    } catch (validationError) {
      showTransactionStatus(validationError.message, 'error');
      return;
    }
    
    // Check rate limiting
    try {
      checkRateLimit(userAddress);
    } catch (rateLimitError) {
      showTransactionStatus(rateLimitError.message, 'warning');
      return;
    }
    
    // Validate security state
    try {
      await validateSecurityState(contract, userAddress);
    } catch (securityError) {
      showTransactionStatus(securityError.message, 'error');
      return;
    }
    
    // Convert amount to wei
    const amountWei = ethers.parseEther(amount.toString());
    
    console.log(`Placing bet: ${tickets} tickets for ${amount} ETH`);
    
    try {
      // Show transaction status
      showTransactionStatus('Validating bet parameters...', 'info');
      
      // Get current round ID for the transaction
      const currentRoundId = await contract.currentRoundId();
      if (currentRoundId.toString() === '0') {
        throw new Error('No active round available');
      }
      
      // Get round status to ensure it's open
      const roundData = await contract.getRound(currentRoundId);
      const status = Number(roundData.status);
      console.log('Round status check:', { status, roundData });
      if (status !== 1) { // 1 = Open
        throw new Error(`Round is not currently open for betting (status: ${status})`);
      }
      
      showTransactionStatus('Submitting bet transaction...', 'info');
      
      // Call contract method (enhanced version uses tickets parameter)
      const tx = await contract.placeBet(tickets, { value: amountWei });
      
      showTransactionStatus('Transaction submitted, waiting for confirmation...', 'info');
      console.log('Transaction hash:', tx.hash);
      
      // Wait for transaction confirmation
      const receipt = await tx.wait();
      
      console.log('Bet placed successfully:', receipt);
      showTransactionStatus(`✅ Bet placed successfully! ${tickets} tickets for ${amount} ETH`, 'success');
      
      // Reset UI (clear both mobile and desktop selections to be safe)
      const mobileSlideout = document.getElementById('mobile-purchase-slideout');
      if (mobileSlideout) {
        mobileSlideout.classList.remove('open');
      }
      
      const ticketOffice = document.getElementById('ticket-office');
      if (ticketOffice) {
        ticketOffice.classList.remove('open');
      }
      
      document.querySelectorAll('.ticket-option-card').forEach(card => {
        card.classList.remove('selected', 'mobile-selected');
      });
      
      // Update user stats and security status
      await updateUserStats(contract, userAddress);
      showSecurityStatus(contract, userAddress);
      await updateButtonStates(); // Update button states after placing bet
      
    } catch (contractError) {
      console.error('Contract error:', contractError);
      handleTransactionError(contractError, 'Buy Tickets');
    }
    
  } catch (error) {
    console.error('Error placing bet:', error);
    showTransactionStatus('Failed to place bet: ' + error.message, 'error');
  }
}

// Buy tickets from mobile slide-out (same function works for both)
async function buyTicketsMobile() {
  return buyTickets(); // Window width detection handles mobile/desktop
}

// Submit puzzle proof with enhanced security validations
async function submitProof() {
  try {
    if (!contract || !signer || !userAddress) {
      showTransactionStatus('Please connect your wallet first', 'error');
      return;
    }
    
    const proofInput = document.getElementById('proof-input');
    if (!proofInput) return;
    const proof = proofInput.value.trim();
    
    if (!proof) {
      showTransactionStatus('Please enter your puzzle proof', 'error');
      return;
    }
    
    // Sanitize and validate proof input
    let sanitizedProof;
    try {
      sanitizedProof = sanitizeInput(proof, 'proof');
    } catch (sanitizeError) {
      showTransactionStatus(sanitizeError.message, 'error');
      return;
    }
    
    // Check rate limiting
    try {
      checkRateLimit(userAddress);
    } catch (rateLimitError) {
      showTransactionStatus(rateLimitError.message, 'warning');
      return;
    }
    
    // Validate security state
    try {
      await validateSecurityState(contract, userAddress);
    } catch (securityError) {
      showTransactionStatus(securityError.message, 'error');
      return;
    }
    
    console.log('Submitting proof:', sanitizedProof.substring(0, 50) + '...');
    
    try {
      // Show transaction status
      showTransactionStatus('Validating proof submission...', 'info');
      
      // Get current round ID for the transaction
      const currentRoundId = await contract.currentRoundId();
      if (currentRoundId.toString() === '0') {
        throw new Error('No active round available');
      }
      
      // Get round status to ensure it's open
      const roundData = await contract.getRound(currentRoundId);
      const status = Number(roundData.status);
      console.log('Round status check (proof):', { status, roundData });
      if (status !== 1) { // 1 = Open
        throw new Error(`Round is not currently open for proof submission (status: ${status})`);
      }
      
      // Check if user has placed a bet
      const userStats = await contract.getUserStats(currentRoundId, userAddress);
      if (userStats.tickets.toString() === '0') {
        throw new Error('You must place a bet before submitting a proof');
      }
      
      // Check if proof already submitted
      if (userStats.hasProof) {
        throw new Error('You have already submitted a proof for this round');
      }
      
      showTransactionStatus('Submitting puzzle proof...', 'info');
      
      // Hash the proof for on-chain storage
      const proofHash = ethers.keccak256(ethers.toUtf8Bytes(sanitizedProof));
      
      // Call contract method (enhanced version uses proofHash parameter)
      const tx = await contract.submitProof(proofHash);
      
      showTransactionStatus('Transaction submitted, waiting for confirmation...', 'info');
      console.log('Transaction hash:', tx.hash);
      
      // Wait for transaction confirmation
      const receipt = await tx.wait();
      
      console.log('Proof transaction confirmed:', receipt);
      showTransactionStatus('Proof submitted, validating...', 'info');
      
      // Clear input
      proofInput.value = '';
      
      // Clear any existing proof status - we'll wait for contract events
      const proofStatus = document.getElementById('proof-status');
      if (proofStatus) {
        proofStatus.style.display = 'none';
      }
      
      // Update user stats and security status
      await updateUserStats(contract, userAddress);
      showSecurityStatus(contract, userAddress);
      await updateButtonStates(); // Update button states after submitting proof
      
    } catch (contractError) {
      console.error('Contract error:', contractError);
      const errorInfo = handleTransactionError(contractError, 'Submit Proof');
      
      // Show error in proof status
      const proofStatus = document.getElementById('proof-status');
      if (proofStatus) {
        proofStatus.textContent = errorInfo.message;
        proofStatus.className = 'error';
        proofStatus.style.display = 'block';
      }
    }
    
  } catch (error) {
    console.error('Error submitting proof:', error);
    showTransactionStatus('Failed to submit proof: ' + error.message, 'error');
  }
}

// Start periodic updates with security monitoring
function startPeriodicUpdates() {
  // Update round status every 60 seconds (reduced frequency)
  setInterval(async () => {
    if (contract) {
      try {
        // Get current round ID first
        const currentRoundId = await contract.currentRoundId();
        
        // If we have an active round, fetch ALL data in one optimized call
        let roundState = null;
        if (currentRoundId.toString() !== '0') {
          roundState = await contract.getRoundState(currentRoundId);
        }
        
        // Update all UI components with the pre-fetched data
        await updateRoundStatus(contract, provider, roundState);
        await updateProgressIndicator(contract, roundState);
        await updateLeaderboard(contract);
        
        if (userAddress) {
          await updateUserStats(contract, userAddress, roundState);
          
          // Update refunds and unclaimed prizes on main page
          if (currentRoundId.toString() !== '0' && window.location.pathname.includes('main.html')) {
            await displayRefundButton(contract, userAddress);
            await displayUnclaimedPrizesNotification(contract, userAddress);
          }
        }
        
        await updateButtonStates(roundState); // Update button states periodically
      } catch (error) {
        // Completely silence expected contract errors to prevent console spam
        const isExpectedError = error.message.includes('execution reverted') || 
                               error.message.includes('call revert exception') ||
                               error.code === 'CALL_EXCEPTION' ||
                               error.code === 3; // MetaMask execution reverted code
        
        if (!isExpectedError) {
          console.error('Periodic update error:', error);
        }
      }
    }
  }, 60000);
  
  // Security status check every 30 seconds (reduced frequency)
  setInterval(async () => {
    if (contract && userAddress) {
      try {
        showSecurityStatus(contract, userAddress);
      } catch (error) {
        // Completely silence expected contract errors to prevent console spam
        const isExpectedError = error.message.includes('execution reverted') || 
                               error.message.includes('call revert exception') ||
                               error.code === 'CALL_EXCEPTION' ||
                               error.code === 3; // MetaMask execution reverted code
        
        if (!isExpectedError) {
          console.error('Security status error:', error);
        }
      }
    }
  }, 30000);
  
  // Initial update
  if (contract) {
    // Get current round ID and fetch state once
    contract.currentRoundId().then(async (currentRoundId) => {
      let roundState = null;
      if (currentRoundId.toString() !== '0') {
        roundState = await contract.getRoundState(currentRoundId);
      }
      
      updateRoundStatus(contract, provider, roundState);
      updateProgressIndicator(contract, roundState);
      updateLeaderboard(contract);
      
      if (userAddress) {
        showSecurityStatus(contract, userAddress);
        updateUserStats(contract, userAddress, roundState);
      }
      
      updateButtonStates(roundState); // Initial button state update
    }).catch(error => {
      console.error('Initial update error:', error);
    });
  }
}

// Initialize wallet discovery (EIP-6963) as early as possible
initWalletDiscovery();

// Initialize when DOM is loaded
if (document.readyState === 'loading') {
  document.addEventListener('DOMContentLoaded', init);
} else {
  init();
}

// Test comment to trigger new build hash

// Export for debugging (simplified for small-scale site)
window.pepedawn = {
  provider,
  signer,
  contract,
  userAddress,
  connectWallet,
  buyTickets,
  submitProof
};
