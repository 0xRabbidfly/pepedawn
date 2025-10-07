import { ethers } from 'ethers';
import './styles.css';
import { 
  initUI, 
  updateWalletInfo, 
  updateRoundStatus, 
  updateLeaderboard, 
  updateUserStats, 
  showTransactionStatus,
  showSecurityStatus,
  validateTransactionParams,
  handleTransactionError
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

// Global state
let provider = null;
let signer = null;
let contract = null;
let userAddress = null;
let currentRoundStatus = null; // Track current round status for UI updates

// Simple event logging for small-scale site
function logEvent(eventType, eventData) {
  console.log(`🎲 ${eventType}:`, eventData);
}

// Format Ethereum address for display
function formatAddress(address) {
  if (!address) return '';
  return `${address.slice(0, 6)}...${address.slice(-4)}`;
}

// Update button states based on round status and user state
async function updateButtonStates() {
  const submitProofBtn = document.getElementById('submit-proof');
  const placeBetBtn = document.getElementById('place-bet');
  const ticketBtns = document.querySelectorAll('.ticket-btn');
  const proofInput = document.getElementById('proof-input');
  
  // If contract not available, disable all interactive buttons
  if (!contract) {
    if (submitProofBtn) {
      submitProofBtn.disabled = true;
      submitProofBtn.title = 'Contract not available';
    }
    if (placeBetBtn) {
      placeBetBtn.disabled = true;
      placeBetBtn.title = 'Contract not available';
    }
    ticketBtns.forEach(btn => {
      btn.disabled = true;
      btn.title = 'Contract not available';
    });
    return;
  }
  
  try {
    // Get current round info
    const currentRoundId = await contract.currentRoundId();
    
    if (currentRoundId.toString() === '0') {
      // No active round - disable everything
      currentRoundStatus = null;
      if (submitProofBtn) {
        submitProofBtn.disabled = true;
        submitProofBtn.title = 'No active round';
      }
      if (placeBetBtn) {
        placeBetBtn.disabled = true;
        placeBetBtn.title = 'No active round';
      }
      ticketBtns.forEach(btn => {
        btn.disabled = true;
        btn.title = 'No active round';
      });
      return;
    }
    
    // Get round data
    const roundData = await contract.getRound(currentRoundId);
    currentRoundStatus = Number(roundData.status);
    
    // Check if round is open (status = 1)
    const isRoundOpen = currentRoundStatus === 1;
    
    // Update betting buttons
    if (placeBetBtn) {
      placeBetBtn.disabled = !isRoundOpen || !userAddress;
      if (!userAddress) {
        placeBetBtn.title = 'Connect wallet to place bets';
      } else if (!isRoundOpen) {
        placeBetBtn.title = 'Round is not open for betting';
      } else {
        placeBetBtn.title = '';
      }
    }
    
    ticketBtns.forEach(btn => {
      btn.disabled = !isRoundOpen || !userAddress;
      if (!userAddress) {
        btn.title = 'Connect wallet to place bets';
      } else if (!isRoundOpen) {
        btn.title = 'Round is not open for betting';
      } else {
        btn.title = '';
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
            proofTooltip = 'Place a bet before submitting proof';
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
    if (placeBetBtn) {
      placeBetBtn.disabled = true;
      placeBetBtn.title = 'Error checking round status';
    }
    ticketBtns.forEach(btn => {
      btn.disabled = true;
      btn.title = 'Error checking round status';
    });
  }
}

// Initialize the application
async function init() {
  console.log('Initializing PEPEDAWN application...');
  
  // Initialize UI components
  initUI();
  
  // Set up event listeners
  setupEventListeners();
  
  // Check if wallet is already connected
  if (window.ethereum) {
    try {
      const accounts = await window.ethereum.request({ method: 'eth_accounts' });
      if (accounts.length > 0) {
        await connectWallet();
      }
    } catch (error) {
      console.log('No wallet auto-connection:', error);
    }
  }
  
  // Load contract if available
  await loadContract();
  
  // Start periodic updates
  startPeriodicUpdates();
}

// Set up event listeners
function setupEventListeners() {
  const connectBtn = document.getElementById('connect-wallet');
  if (connectBtn) {
    connectBtn.addEventListener('click', connectWallet);
  }
  
  const ticketBtns = document.querySelectorAll('.ticket-btn');
  ticketBtns.forEach(btn => {
    btn.addEventListener('click', selectTickets);
  });
  
  const placeBetBtn = document.getElementById('place-bet');
  if (placeBetBtn) {
    placeBetBtn.addEventListener('click', placeBet);
  }
  
  const submitProofBtn = document.getElementById('submit-proof');
  if (submitProofBtn) {
    submitProofBtn.addEventListener('click', submitProof);
  }
}

// Connect to wallet with enhanced security validations
async function connectWallet() {
  try {
    if (!window.ethereum) {
      showTransactionStatus('Please install MetaMask or another Web3 wallet', 'error');
      return;
    }
    
    showTransactionStatus('Connecting to wallet...', 'info');
    
    // Request account access
    await window.ethereum.request({ method: 'eth_requestAccounts' });
    
    // Create provider and signer
    provider = new ethers.BrowserProvider(window.ethereum);
    signer = await provider.getSigner();
    userAddress = await signer.getAddress();
    
    console.log('Wallet connected:', userAddress);
    
    // Validate network
    try {
      const network = await provider.getNetwork();
      validateNetwork(network.chainId);
      console.log('✅ Network validated:', SECURITY_CONFIG.NETWORK_NAMES[Number(network.chainId)]);
    } catch (networkError) {
      console.warn('⚠️ Network validation failed:', networkError.message);
      showTransactionStatus(networkError.message, 'warning');
    }
    
    // Set up network change listener
    if (window.ethereum.on) {
      window.ethereum.on('chainChanged', handleNetworkChange);
      window.ethereum.on('accountsChanged', handleAccountChange);
    }
    
    // Update UI
    await updateWalletInfo(userAddress, provider);
    
    // Load contract with signer
    await loadContract();
    
    // Update user stats and security status
    if (contract) {
      await updateUserStats(contract, userAddress);
      showSecurityStatus(contract, userAddress);
      await updateButtonStates(); // Update button states after connecting
    }
    
    showTransactionStatus('Wallet connected successfully', 'success');
    
  } catch (error) {
    console.error('Error connecting wallet:', error);
    showTransactionStatus('Failed to connect wallet: ' + error.message, 'error');
  }
}

// Handle network changes
function handleNetworkChange(chainId) {
  console.log('Network changed to:', chainId);
  
  try {
    validateNetwork(chainId);
    console.log('✅ Network change validated');
    
    // Reload contract and update UI
    loadContract().then(() => {
      if (userAddress) {
        updateWalletInfo(userAddress, provider);
        if (contract) {
          updateUserStats(contract, userAddress);
          showSecurityStatus(contract, userAddress);
          updateButtonStates();
        }
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
    
    // Reset UI
    const walletInfo = document.getElementById('wallet-info');
    if (walletInfo) walletInfo.style.display = 'none';
    
    const connectBtn = document.getElementById('connect-wallet');
    if (connectBtn) {
      connectBtn.textContent = 'Connect Wallet';
      connectBtn.disabled = false;
    }
    
    showTransactionStatus('Wallet disconnected', 'info');
  } else {
    // Account switched - reconnect
    connectWallet();
  }
}

// Load contract from configuration with enhanced security
async function loadContract() {
  try {
    // Validate contract configuration
    if (!validateContractConfig()) {
      console.log('Contract not configured - working in mock mode');
      return;
    }
    
    // Check if we're on the correct network
    if (provider) {
      try {
        const network = await provider.getNetwork();
        validateNetwork(network.chainId);
        console.log('✅ Network validated for contract loading');
      } catch (networkError) {
        console.warn('⚠️ Network validation failed:', networkError.message);
        showTransactionStatus(networkError.message, 'warning');
        return;
      }
    }
    
    // Create contract instance
    if (signer) {
      contract = new ethers.Contract(CONTRACT_CONFIG.address, CONTRACT_CONFIG.abi, signer);
    } else if (provider) {
      contract = new ethers.Contract(CONTRACT_CONFIG.address, CONTRACT_CONFIG.abi, provider);
    } else {
      // No provider available yet - wallet not connected
      console.log('⏳ Waiting for wallet connection to load contract');
      return;
    }
    
    console.log('✅ Contract loaded:', CONTRACT_CONFIG.address);
    
    // Verify contract is accessible
    try {
      await contract.currentRoundId();
      console.log('✅ Contract accessibility verified');
    } catch (contractError) {
      console.error('❌ Contract not accessible:', contractError.message);
      showTransactionStatus('Contract not accessible. Please check deployment.', 'error');
      return;
    }
    
    // Set up event listeners
    if (contract) {
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
  
  try {
    console.log('🎧 Setting up enhanced contract event listeners...');
    
    // Remove any existing listeners to prevent duplicates
    contract.removeAllListeners();
    
    // Round lifecycle events
    contract.on('RoundCreated', (...args) => {
      const event = args[args.length - 1]; // Event is always the last parameter
      const [roundId, startTime, endTime] = args;
      
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
      updateRoundStatus(contract);
      updateButtonStates();
    });
    
    contract.on('RoundOpened', (...args) => {
      const event = args[args.length - 1]; // Event is always the last parameter
      const [roundId] = args;
      
      const eventData = { 
        roundId: roundId.toString(),
        blockNumber: event?.blockNumber,
        transactionHash: event?.transactionHash
      };
      console.log('🟢 Round opened:', eventData);
      logEvent('RoundOpened', eventData);
      
      showTransactionStatus(`Round #${eventData.roundId} is now open for betting!`, 'success');
      updateRoundStatus(contract);
      updateButtonStates();
    });
    
    contract.on('RoundClosed', (...args) => {
      const event = args[args.length - 1]; // Event is always the last parameter
      const [roundId] = args;
      
      const eventData = { 
        roundId: roundId.toString(),
        blockNumber: event?.blockNumber,
        transactionHash: event?.transactionHash
      };
      console.log('🔴 Round closed:', eventData);
      logEvent('RoundClosed', eventData);
      
      showTransactionStatus(`Round #${eventData.roundId} closed. No more bets accepted.`, 'info');
      updateRoundStatus(contract);
      updateButtonStates();
    });
    
    contract.on('RoundSnapshot', (...args) => {
      const event = args[args.length - 1]; // Event is always the last parameter
      const [roundId, totalTickets, totalWeight] = args;
      
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
      updateRoundStatus(contract);
    });
    
    // User interaction events
    contract.on('BetPlaced', (...args) => {
      const event = args[args.length - 1]; // Event is always the last parameter
      const [roundId, user, amount, tickets, weight] = args;
      
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
      logEvent('BetPlaced', eventData);
      
      // Update UI if it's the current user
      if (eventData.user === userAddress?.toLowerCase()) {
        showTransactionStatus(`✅ Your bet confirmed! ${eventData.tickets} tickets for ${eventData.amount} ETH`, 'success');
        updateUserStats(contract, userAddress);
        updateButtonStates(); // User can now submit proof
      } else {
        showTransactionStatus(`New bet: ${eventData.tickets} tickets by ${formatAddress(eventData.user)}`, 'info');
      }
      
      // Update leaderboard and round status
      updateRoundStatus(contract);
      updateLeaderboard(contract);
    });
    
    contract.on('ProofSubmitted', (roundId, user, weight, event) => {
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
        updateUserStats(contract, userAddress);
        updateButtonStates(); // Proof button should now be disabled
      } else {
        showTransactionStatus(`Puzzle solved by ${formatAddress(eventData.user)}!`, 'info');
      }
      
      // Update leaderboard
      updateLeaderboard(contract);
    });
    
    // VRF and prize distribution events
    contract.on('VRFRequested', (roundId, requestId, event) => {
      const eventData = {
        roundId: roundId.toString(),
        requestId: requestId.toString(),
        blockNumber: event.blockNumber,
        transactionHash: event.transactionHash
      };
      console.log('🎰 VRF requested:', eventData);
      logEvent('VRFRequested', eventData);
      
      showTransactionStatus(`🎰 Random number requested for round #${eventData.roundId}. Drawing winners...`, 'info');
      updateRoundStatus(contract);
    });
    
    contract.on('PrizesDistributed', (roundId, randomWords, event) => {
      const eventData = {
        roundId: roundId.toString(),
        randomWords: randomWords.map(w => w.toString()),
        blockNumber: event.blockNumber,
        transactionHash: event.transactionHash
      };
      console.log('🏆 Prizes distributed:', eventData);
      logEvent('PrizesDistributed', eventData);
      
      showTransactionStatus(`🏆 Winners selected for round #${eventData.roundId}! Check results.`, 'success');
      updateRoundStatus(contract);
      updateLeaderboard(contract);
    });
    
    // Emblem Vault integration events
    contract.on('EmblemVaultPrizeAssigned', (roundId, winner, assetId, timestamp, event) => {
      const eventData = {
        roundId: roundId.toString(),
        winner: winner.toLowerCase(),
        assetId: assetId.toString(),
        timestamp: Number(timestamp),
        blockNumber: event.blockNumber,
        transactionHash: event.transactionHash
      };
      console.log('🎁 Emblem Vault prize assigned:', eventData);
      logEvent('EmblemVaultPrizeAssigned', eventData);
      
      // Show notification if it's the current user
      if (eventData.winner === userAddress?.toLowerCase()) {
        showTransactionStatus(`🎁 Congratulations! You won asset #${eventData.assetId}!`, 'success');
      }
    });
    
    contract.on('RoundPrizesDistributed', (roundId, winnerCount, timestamp, event) => {
      const eventData = {
        roundId: roundId.toString(),
        winnerCount: Number(winnerCount),
        timestamp: Number(timestamp),
        blockNumber: event.blockNumber,
        transactionHash: event.transactionHash
      };
      console.log('🏆 Round prizes distribution completed:', eventData);
      logEvent('RoundPrizesDistributed', eventData);
      
      showTransactionStatus(`🏆 Round #${eventData.roundId} completed! ${eventData.winnerCount} prizes distributed.`, 'success');
      updateRoundStatus(contract);
    });
    
    contract.on('FeesDistributed', (roundId, creatorsAmount, nextRoundAmount, event) => {
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
  const btn = event.target;
  const tickets = parseInt(btn.dataset.tickets);
  const amount = parseFloat(btn.dataset.amount);
  
  // Update UI
  document.getElementById('selected-tickets').textContent = String(tickets);
  document.getElementById('selected-amount').textContent = String(amount);
  
  // Show bet summary
  document.getElementById('bet-summary').style.display = 'block';
  
  // Highlight selected button
  document.querySelectorAll('.ticket-btn').forEach(b => b.classList.remove('selected'));
  btn.classList.add('selected');
}

// Place bet with enhanced security validations
async function placeBet() {
  try {
    if (!contract || !signer || !userAddress) {
      showTransactionStatus('Please connect your wallet first', 'error');
      return;
    }
    
    const tickets = parseInt(document.getElementById('selected-tickets').textContent);
    const amount = parseFloat(document.getElementById('selected-amount').textContent);
    
    if (!tickets || !amount) {
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
      if (roundData.status !== 1) { // 1 = Open
        throw new Error('Round is not currently open for betting');
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
      
      // Reset form
      document.getElementById('bet-summary').style.display = 'none';
      document.querySelectorAll('.ticket-btn').forEach(btn => btn.classList.remove('selected'));
      
      // Update user stats and security status
      await updateUserStats(contract, userAddress);
      showSecurityStatus(contract, userAddress);
      await updateButtonStates(); // Update button states after placing bet
      
    } catch (contractError) {
      console.error('Contract error:', contractError);
      handleTransactionError(contractError, 'Place Bet');
    }
    
  } catch (error) {
    console.error('Error placing bet:', error);
    showTransactionStatus('Failed to place bet: ' + error.message, 'error');
  }
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
      if (roundData.status !== 1) { // 1 = Open
        throw new Error('Round is not currently open for proof submission');
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
      
      console.log('Proof submitted successfully:', receipt);
      showTransactionStatus('✅ Puzzle proof submitted successfully! +40% weight bonus applied.', 'success');
      
      // Clear input and show success status
      proofInput.value = '';
      const proofStatus = document.getElementById('proof-status');
      if (proofStatus) {
        proofStatus.textContent = '✅ Proof submitted successfully! +40% weight bonus applied.';
        proofStatus.className = 'success';
        proofStatus.style.display = 'block';
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
        await updateRoundStatus(contract);
        await updateLeaderboard(contract);
        
        if (userAddress) {
          await updateUserStats(contract, userAddress);
        }
        
        await updateButtonStates(); // Update button states periodically
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
    updateRoundStatus(contract);
    updateLeaderboard(contract);
    
    if (userAddress) {
      showSecurityStatus(contract, userAddress);
    }
    
    updateButtonStates(); // Initial button state update
  }
}

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
  placeBet,
  submitProof
};
