import { ethers } from 'ethers';
import './styles.css';
import { initUI, updateWalletInfo, updateRoundStatus, updateLeaderboard, updateUserStats, showTransactionStatus } from './ui.js';
import { CONTRACT_CONFIG, validateContractConfig } from './contract-config.js';

// Global state
let provider = null;
let signer = null;
let contract = null;
let userAddress = null;

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

// Connect to wallet
async function connectWallet() {
  try {
    if (!window.ethereum) {
      alert('Please install MetaMask or another Web3 wallet');
      return;
    }
    
    // Request account access
    await window.ethereum.request({ method: 'eth_requestAccounts' });
    
    // Create provider and signer
    provider = new ethers.BrowserProvider(window.ethereum);
    signer = await provider.getSigner();
    userAddress = await signer.getAddress();
    
    console.log('Wallet connected:', userAddress);
    
    // Update UI
    updateWalletInfo(userAddress, provider);
    
    // Load contract with signer
    await loadContract();
    
    // Update user stats
    if (contract) {
      await updateUserStats(contract, userAddress);
    }
    
  } catch (error) {
    console.error('Error connecting wallet:', error);
    alert('Failed to connect wallet: ' + error.message);
  }
}

// Load contract from configuration
async function loadContract() {
  try {
    // Validate contract configuration
    if (!validateContractConfig()) {
      console.log('Contract not configured - working in mock mode');
      return;
    }
    
    // Check if we're on the correct network
    if (provider) {
      const network = await provider.getNetwork();
      if (Number(network.chainId) !== CONTRACT_CONFIG.chainId) {
        console.warn(`⚠️ Wrong network! Expected Sepolia (${CONTRACT_CONFIG.chainId}), got ${network.chainId}`);
        console.log('Please switch to Sepolia testnet in MetaMask');
        return;
      }
    }
    
    // Create contract instance
    if (signer) {
      contract = new ethers.Contract(CONTRACT_CONFIG.address, CONTRACT_CONFIG.abi, signer);
    } else if (provider) {
      contract = new ethers.Contract(CONTRACT_CONFIG.address, CONTRACT_CONFIG.abi, provider);
    }
    
    console.log('✅ Contract loaded:', CONTRACT_CONFIG.address);
    
    // Set up event listeners
    if (contract) {
      setupContractEventListeners();
    }
    
  } catch (error) {
    console.error('Error loading contract:', error);
  }
}

// Set up contract event listeners
function setupContractEventListeners() {
  if (!contract) return;
  
  try {
    // Listen for wager events (Remix version uses 'BetPlaced')
    contract.on('BetPlaced', (roundId, user, amount, tickets, weight, event) => {
      console.log('Bet placed:', { user, roundId: roundId.toString(), amount: ethers.formatEther(amount), tickets: tickets.toString() });
      
      // Update UI if it's the current user
      if (user.toLowerCase() === userAddress?.toLowerCase()) {
        updateUserStats(contract, userAddress);
      }
      
      // Update leaderboard and round status
      updateRoundStatus(contract);
      updateLeaderboard(contract);
    });
    
    // Listen for proof events (Remix version uses 'ProofSubmitted')
    contract.on('ProofSubmitted', (roundId, user, weight, event) => {
      console.log('Proof submitted:', { user, roundId: roundId.toString(), weight: weight.toString() });
      
      // Update UI if it's the current user
      if (user.toLowerCase() === userAddress?.toLowerCase()) {
        updateUserStats(contract, userAddress);
      }
      
      // Update leaderboard
      updateLeaderboard(contract);
    });
    
    // Listen for round events
    contract.on('RoundCreated', (roundId, startTime, endTime, event) => {
      console.log('Round created:', { roundId: roundId.toString(), startTime, endTime });
      updateRoundStatus(contract);
    });
    
    contract.on('RoundOpened', (roundId, event) => {
      console.log('Round opened:', { roundId: roundId.toString() });
      updateRoundStatus(contract);
    });
    
    contract.on('RoundClosed', (roundId, event) => {
      console.log('Round closed:', { roundId: roundId.toString() });
      updateRoundStatus(contract);
    });
    
  } catch (error) {
    console.error('Error setting up contract event listeners:', error);
  }
}

// Select ticket bundle
function selectTickets(event) {
  const btn = event.target;
  const tickets = parseInt(btn.dataset.tickets);
  const amount = parseFloat(btn.dataset.amount);
  
  // Update UI
  document.getElementById('selected-tickets').textContent = tickets;
  document.getElementById('selected-amount').textContent = amount;
  
  // Show bet summary
  document.getElementById('bet-summary').style.display = 'block';
  
  // Highlight selected button
  document.querySelectorAll('.ticket-btn').forEach(b => b.classList.remove('selected'));
  btn.classList.add('selected');
}

// Place bet
async function placeBet() {
  try {
    if (!contract || !signer) {
      alert('Please connect your wallet first');
      return;
    }
    
    const tickets = parseInt(document.getElementById('selected-tickets').textContent);
    const amount = parseFloat(document.getElementById('selected-amount').textContent);
    
    if (!tickets || !amount) {
      alert('Please select a ticket bundle first');
      return;
    }
    
    // Convert amount to wei
    const amountWei = ethers.parseEther(amount.toString());
    
    console.log(`Placing bet: ${tickets} tickets for ${amount} ETH`);
    
    try {
      // Show transaction status
      showTransactionStatus('Placing bet...', 'info');
      
      // Get current round ID for the transaction
      const currentRoundId = await contract.currentRoundId();
      if (currentRoundId.toString() === '0') {
        throw new Error('No active round available');
      }
      
      // Call contract method (Remix version uses roundId parameter)
      const tx = await contract.placeBet(currentRoundId, { value: amountWei });
      
      showTransactionStatus('Transaction submitted, waiting for confirmation...', 'info');
      console.log('Transaction hash:', tx.hash);
      
      // Wait for transaction confirmation
      const receipt = await tx.wait();
      
      console.log('Bet placed successfully:', receipt);
      showTransactionStatus(`Bet placed successfully! ${tickets} tickets for ${amount} ETH`, 'success');
      
      // Reset form
      document.getElementById('bet-summary').style.display = 'none';
      document.querySelectorAll('.ticket-btn').forEach(btn => btn.classList.remove('selected'));
      
      // Update user stats
      await updateUserStats(contract, userAddress);
      
    } catch (contractError) {
      console.error('Contract error:', contractError);
      
      // Handle specific contract errors
      let errorMessage = 'Failed to place bet';
      if (contractError.message.includes('Round not open')) {
        errorMessage = 'Round is not currently open for betting';
      } else if (contractError.message.includes('Exceeds wallet cap')) {
        errorMessage = 'This bet would exceed your 1.0 ETH wallet cap';
      } else if (contractError.message.includes('Incorrect payment')) {
        errorMessage = 'Incorrect payment amount for selected tickets';
      } else if (contractError.message.includes('user rejected')) {
        errorMessage = 'Transaction was cancelled';
      }
      
      showTransactionStatus(errorMessage, 'error');
    }
    
  } catch (error) {
    console.error('Error placing bet:', error);
    showTransactionStatus('Failed to place bet: ' + error.message, 'error');
  }
}

// Submit puzzle proof
async function submitProof() {
  try {
    if (!contract || !signer) {
      alert('Please connect your wallet first');
      return;
    }
    
    const proofInput = document.getElementById('proof-input');
    const proof = proofInput.value.trim();
    
    if (!proof) {
      alert('Please enter your puzzle proof');
      return;
    }
    
    console.log('Submitting proof:', proof);
    
    try {
      // Show transaction status
      showTransactionStatus('Submitting puzzle proof...', 'info');
      
      // Hash the proof for on-chain storage
      const proofHash = ethers.keccak256(ethers.toUtf8Bytes(proof));
      
      // Get current round ID for the transaction
      const currentRoundId = await contract.currentRoundId();
      if (currentRoundId.toString() === '0') {
        throw new Error('No active round available');
      }
      
      // Call contract method (Remix version uses roundId parameter)
      const tx = await contract.submitProof(currentRoundId, proofHash);
      
      showTransactionStatus('Transaction submitted, waiting for confirmation...', 'info');
      console.log('Transaction hash:', tx.hash);
      
      // Wait for transaction confirmation
      const receipt = await tx.wait();
      
      console.log('Proof submitted successfully:', receipt);
      showTransactionStatus('Puzzle proof submitted successfully! +40% weight bonus applied.', 'success');
      
      // Clear input and show success status
      proofInput.value = '';
      const proofStatus = document.getElementById('proof-status');
      if (proofStatus) {
        proofStatus.textContent = 'Proof submitted successfully! +40% weight bonus applied.';
        proofStatus.className = 'success';
        proofStatus.style.display = 'block';
      }
      
      // Update user stats
      await updateUserStats(contract, userAddress);
      
    } catch (contractError) {
      console.error('Contract error:', contractError);
      
      // Handle specific contract errors
      let errorMessage = 'Failed to submit proof';
      if (contractError.message.includes('Round not open')) {
        errorMessage = 'Round is not currently open for proof submission';
      } else if (contractError.message.includes('Must place wager')) {
        errorMessage = 'You must place a wager before submitting a proof';
      } else if (contractError.message.includes('Proof already submitted')) {
        errorMessage = 'You have already submitted a proof for this round';
      } else if (contractError.message.includes('user rejected')) {
        errorMessage = 'Transaction was cancelled';
      }
      
      showTransactionStatus(errorMessage, 'error');
      
      // Show error in proof status
      const proofStatus = document.getElementById('proof-status');
      if (proofStatus) {
        proofStatus.textContent = errorMessage;
        proofStatus.className = 'error';
        proofStatus.style.display = 'block';
      }
    }
    
  } catch (error) {
    console.error('Error submitting proof:', error);
    showTransactionStatus('Failed to submit proof: ' + error.message, 'error');
  }
}

// Start periodic updates
function startPeriodicUpdates() {
  // Update round status every 30 seconds
  setInterval(async () => {
    if (contract) {
      await updateRoundStatus(contract);
      await updateLeaderboard(contract);
      
      if (userAddress) {
        await updateUserStats(contract, userAddress);
      }
    }
  }, 30000);
  
  // Initial update
  if (contract) {
    updateRoundStatus(contract);
    updateLeaderboard(contract);
  }
}

// Initialize when DOM is loaded
if (document.readyState === 'loading') {
  document.addEventListener('DOMContentLoaded', init);
} else {
  init();
}

// Export for debugging
window.pepedawn = {
  provider,
  signer,
  contract,
  userAddress,
  connectWallet,
  placeBet,
  submitProof
};
