import { ethers } from 'ethers';
import { validateNetwork, SECURITY_CONFIG, CONTRACT_CONFIG } from './contract-config.js';

// Initialize UI components
export function initUI() {
  console.log('Initializing UI components...');
  
  // Set up navigation highlighting
  highlightCurrentPage();
  
  // Initialize empty states
  resetUI();
}

// Highlight current page in navigation
function highlightCurrentPage() {
  const currentPath = window.location.pathname;
  const navLinks = document.querySelectorAll('nav a');
  
  navLinks.forEach(link => {
    link.classList.remove('active');
    if (link.getAttribute('href') === currentPath || 
        (currentPath === '/' && link.getAttribute('href') === '/')) {
      link.classList.add('active');
    }
  });
}

// Reset UI to initial state
function resetUI() {
  // Hide wallet info
  const walletInfo = document.getElementById('wallet-info');
  if (walletInfo) {
    walletInfo.style.display = 'none';
  }
  
  // Hide bet summary
  const betSummary = document.getElementById('bet-summary');
  if (betSummary) {
    betSummary.style.display = 'none';
  }
  
  // Reset form states
  resetForms();
}

// Reset form states
function resetForms() {
  const proofInput = document.getElementById('proof-input');
  if (proofInput) {
    proofInput.value = '';
  }
  
  const ticketCards = document.querySelectorAll('.ticket-option-card');
  ticketCards.forEach(card => card.classList.remove('selected'));
}

// Update wallet information display with security validations
export async function updateWalletInfo(address, provider) {
  try {
    const walletInfo = document.getElementById('wallet-info');
    const walletBalance = document.getElementById('wallet-balance');
    const walletAddressDisplay = document.getElementById('wallet-address-display');
    const connectBtn = document.getElementById('connect-wallet');
    
    // Update address display
    if (walletAddressDisplay) {
      walletAddressDisplay.textContent = formatAddress(address);
    }
    
    // Update balance
    if (provider && walletBalance) {
      const balance = await provider.getBalance(address);
      const balanceEth = ethers.formatEther(balance);
      walletBalance.textContent = parseFloat(balanceEth).toFixed(4);
    }
    
    // Validate network (show error if wrong network)
    if (provider) {
      try {
        const network = await provider.getNetwork();
        validateNetwork(network.chainId);
      } catch {
        // Show network switch prompt if on wrong network
        showNetworkSwitchPrompt();
      }
    }
    
    // Show wallet info section and hide connect button
    if (walletInfo) {
      walletInfo.style.display = 'block';
    }
    
    if (connectBtn) {
      connectBtn.style.display = 'none';
    }
    
  } catch (error) {
    console.error('Error updating wallet info:', error);
    showTransactionStatus('Failed to update wallet information', 'error');
  }
}

// Update round status display
export async function updateRoundStatus(contract, provider = null) {
  try {
    if (!contract) {
      // Show mock data when contract not available
      const timeRemaining = document.getElementById('time-remaining');
      const totalTickets = document.getElementById('total-tickets');
      
      // Highlight "Open" status for mock
      const statusItems = document.querySelectorAll('.status-item');
      statusItems.forEach(item => {
        item.classList.remove('active');
        const dataStatus = item.dataset.status;
        // Handle both single status and collapsed statuses
        if (dataStatus === '1' || (dataStatus.includes(',') && dataStatus.split(',').includes('1'))) {
          item.classList.add('active');
        }
      });
      
      if (timeRemaining) timeRemaining.textContent = '7d 0h 0m 0s (Mock)';
      if (totalTickets) totalTickets.textContent = '1,234 (Mock)';
      return;
    }
    
    // Get current round ID
    const currentRoundId = await contract.currentRoundId();
    
    if (currentRoundId.toString() === '0') {
      // No rounds opened yet
      const currentRoundTitle = document.getElementById('current-round-title');
      if (currentRoundTitle) {
        currentRoundTitle.textContent = 'Current Round: Being Created...';
      }
      
      const timeRemaining = document.getElementById('time-remaining');
      if (timeRemaining) timeRemaining.textContent = 'Coming Soon';
      
      const totalTickets = document.getElementById('total-tickets');
      if (totalTickets) totalTickets.textContent = '0';
      
      // Clear all status highlights
      const statusItems = document.querySelectorAll('.status-item');
      statusItems.forEach(item => {
        item.classList.remove('active');
      });
      
      return;
    }
    
    // Get round data (Remix version returns tuple)
    const roundData = await contract.getRound(currentRoundId);
    
    // Update round title
    const currentRoundTitle = document.getElementById('current-round-title');
    if (currentRoundTitle) {
      currentRoundTitle.textContent = `Current Round: ${currentRoundId}`;
    }
    
    // Update status highlighting (collapsed statuses 2-5 into "Drawing Winners")
    const statusItems = document.querySelectorAll('.status-item');
    const currentStatus = Number(roundData.status);
    
    statusItems.forEach(item => {
      item.classList.remove('active');
      
      const dataStatus = item.dataset.status;
      
      // Handle collapsed statuses (2,3,4,5 = Drawing Winners)
      if (dataStatus.includes(',')) {
        const statuses = dataStatus.split(',').map(s => Number(s.trim()));
        if (statuses.includes(currentStatus)) {
          item.classList.add('active');
        }
      }
      // Handle single status
      else if (Number(dataStatus) === currentStatus) {
        item.classList.add('active');
      }
    });
    
    // Show Merkle badge when winners are drawn (status 2+)
    const merkleBadge = document.getElementById('merkle-badge');
    if (merkleBadge) {
      if (currentStatus >= 2) {
        merkleBadge.classList.add('visible');
      } else {
        merkleBadge.classList.remove('visible');
      }
    }
    
    // Update countdown
    const timeRemaining = document.getElementById('time-remaining');
    if (timeRemaining) {
      const endTime = Number(roundData.endTime) * 1000; // Convert to milliseconds
      updateCountdown(timeRemaining, endTime);
    }
    
    // Update total tickets
    const totalTickets = document.getElementById('total-tickets');
    if (totalTickets) {
      totalTickets.textContent = roundData.totalTickets.toString();
    }
    
    // Update vaulted ETH (contract balance)
    const vaultedEth = document.getElementById('vaulted-eth');
    if (vaultedEth && provider) {
      try {
        const balance = await provider.getBalance(CONTRACT_CONFIG.address);
        const balanceEth = ethers.formatEther(balance);
        vaultedEth.textContent = parseFloat(balanceEth).toFixed(4);
      } catch (balanceError) {
        vaultedEth.textContent = '--';
      }
    }
    
  } catch (error) {
    console.error('Error updating round status:', error);
    
    // Show error state
    const roundStatusText = document.getElementById('round-status-text');
    if (roundStatusText) roundStatusText.textContent = 'Error Loading';
  }
}

// Update dispenser progress indicator showing ticket count toward 10-ticket minimum
export async function updateProgressIndicator(contract) {
  try {
    const dispenserText = document.getElementById('dispenser-text');
    const dispenserBadge = document.getElementById('dispenser-badge');
    const ticketIcons = document.querySelectorAll('.ticket-icon');
    
    if (!contract) {
      if (dispenserText) dispenserText.textContent = 'minimum 10 tickets required';
      ticketIcons.forEach(icon => icon.classList.remove('purchased'));
      return;
    }
    
    // Get current round ID
    const currentRoundId = await contract.currentRoundId();
    
    if (currentRoundId.toString() === '0') {
      if (dispenserText) dispenserText.textContent = 'minimum 10 tickets required';
      ticketIcons.forEach(icon => icon.classList.remove('purchased'));
      return;
    }
    
    // Get round data
    const roundData = await contract.getRound(currentRoundId);
    const totalTickets = Number(roundData.totalTickets);
    
    // Update ticket icons (fill in purchased tickets)
    ticketIcons.forEach((icon, index) => {
      if (index < totalTickets) {
        icon.classList.add('purchased');
      } else {
        icon.classList.remove('purchased');
      }
    });
    
    // Update dispenser badge text
    if (dispenserText && dispenserBadge) {
      if (totalTickets >= 10) {
        dispenserText.textContent = '🐸 PEPEDAWN will be dispensed';
        dispenserBadge.classList.add('dispensing');
        dispenserBadge.classList.remove('waiting');
      } else {
        dispenserText.textContent = 'minimum 10 tickets required';
        dispenserBadge.classList.add('waiting');
        dispenserBadge.classList.remove('dispensing');
      }
    }
    
  } catch (error) {
    console.error('Error updating dispenser progress:', error);
  }
}

// Get winners data for a distributed round
async function getWinnersData(contract, roundId) {
  try {
    // This would need to be implemented in the contract
    // For now, we'll simulate the winners based on sorted participants
    const participants = await contract.getRoundParticipants(roundId);
    const roundData = await contract.getRound(roundId);
    
    // Sort participants by weight (descending) to determine winners
    const participantsWithStats = [];
    for (let i = 0; i < participants.length; i++) {
      const participant = participants[i];
      try {
        const stats = await contract.getUserStats(roundId, participant);
        participantsWithStats.push({
          address: participant,
          weight: Number(stats.weight)
        });
      } catch (error) {
        console.warn(`Could not get stats for participant ${participant}:`, error.message);
      }
    }
    
    participantsWithStats.sort((a, b) => b.weight - a.weight);
    
    return {
      fakePackWinner: participantsWithStats[0]?.address || null,
      kekPackWinner: participantsWithStats[1]?.address || null,
      pepePackWinners: participantsWithStats.slice(2, 10).map(p => p.address) // 8 winners
    };
  } catch (error) {
    console.error('Error getting winners data:', error);
    return null;
  }
}

// Populate round selector dropdown
export async function populateRoundSelector(contract) {
  try {
    const roundSelect = document.getElementById('round-select');
    const winnersRoundSelect = document.getElementById('winners-round-select');
    if (!contract) return;
    
    // Get current round ID
    const currentRoundId = await contract.currentRoundId();
    const currentRoundNum = Number(currentRoundId);
    
    // Populate leaderboard selector
    if (roundSelect) {
      // Clear existing options
      roundSelect.innerHTML = '';
      
      // Add options for previous rounds (if any)
      for (let i = Math.max(1, currentRoundNum - 5); i <= currentRoundNum; i++) {
        const option = document.createElement('option');
        option.value = i.toString();
        option.textContent = `Round ${i}`;
        if (i === currentRoundNum) {
          option.textContent += ' (Current)';
          option.selected = true;
        }
        roundSelect.appendChild(option);
      }
      
      // Add future round option
      const futureOption = document.createElement('option');
      futureOption.value = (currentRoundNum + 1).toString();
      futureOption.textContent = `Round ${currentRoundNum + 1} (Future)`;
      roundSelect.appendChild(futureOption);
    }
    
    // Populate winners selector
    if (winnersRoundSelect) {
      // Clear existing options
      winnersRoundSelect.innerHTML = '';
      
      // Add options for all rounds (winners can be viewed for any round)
      for (let i = Math.max(1, currentRoundNum - 5); i <= currentRoundNum; i++) {
        const option = document.createElement('option');
        option.value = i.toString();
        option.textContent = `Round ${i}`;
        if (i === currentRoundNum) {
          option.textContent += ' (Current)';
          option.selected = true;
        }
        winnersRoundSelect.appendChild(option);
      }
    }
    
  } catch (error) {
    console.error('Error populating round selector:', error);
  }
}

// Update leaderboard display
export async function updateLeaderboard(contract, selectedRoundId = null) {
  try {
    const leaderboardList = document.getElementById('leaderboard-list');
    const leaderboardTitle = document.getElementById('leaderboard-title');
    if (!leaderboardList) return;
    
    // Only update leaderboard if we're on the leaderboard page
    if (!window.location.pathname.includes('leaderboard.html')) return;
    
    if (!contract) {
      // Show mock data when contract not available
      const mockLeaderboard = [
        { address: '0x1234...5678', tickets: 50, weight: 70, fakeOdds: '12.5%', hasVerifiedProof: true },
        { address: '0xabcd...efgh', tickets: 35, weight: 35, fakeOdds: '8.7%', hasVerifiedProof: false },
        { address: '0x9876...4321', tickets: 25, weight: 35, fakeOdds: '8.7%', hasVerifiedProof: true }
      ];
      
      const leaderboardHTML = `
        <div class="leaderboard-header">
          <span>Rank</span>
          <span>Address</span>
          <span>Tickets</span>
          <span>Weight</span>
          <span>Winning Odds</span>
        </div>
        ${mockLeaderboard.map((entry, index) => `
          <div class="leaderboard-entry">
            <span class="rank">#${index + 1}</span>
            <span class="address">${entry.address} (Mock)${entry.hasVerifiedProof ? ' 🧩' : ''}</span>
            <span class="tickets">${entry.tickets}</span>
            <span class="weight">${entry.weight}</span>
            <span class="odds">${entry.fakeOdds}</span>
          </div>
        `).join('')}
      `;
      
      leaderboardList.innerHTML = leaderboardHTML;
      return;
    }
    
    // Determine which round to display
    let displayRoundId;
    let isCurrentRound = false;
    
    if (selectedRoundId) {
      // User selected a specific round
      displayRoundId = selectedRoundId;
      isCurrentRound = false;
    } else {
      // Default to current round
      displayRoundId = await contract.currentRoundId();
      isCurrentRound = true;
    }
    
    // Update title
    if (leaderboardTitle) {
      leaderboardTitle.textContent = `Leaderboard Round: ${displayRoundId}`;
    }
    
    if (displayRoundId.toString() === '0') {
      leaderboardList.innerHTML = '<p>No active round</p>';
      return;
    }
    
    // Check if this is a future round
    const currentRoundId = await contract.currentRoundId();
    if (Number(displayRoundId) > Number(currentRoundId)) {
      leaderboardList.innerHTML = `
        <div style="text-align: center; padding: var(--spacing-xl); color: var(--text-secondary);">
          <h3>🚀 Future Round</h3>
          <p>Round ${displayRoundId} hasn't started yet.</p>
          <p>This round will begin after Round ${currentRoundId} ends.</p>
        </div>
      `;
      return;
    }
    
    // Get round data
    const roundData = await contract.getRound(displayRoundId);
    
    if (roundData.totalTickets.toString() === '0') {
      leaderboardList.innerHTML = '<p>No participants yet</p>';
      return;
    }
    
    // Check if round is distributed (status 5)
    const isDistributed = Number(roundData.status) === 5;
    
    let winnersHTML = '';
    if (isDistributed) {
      const winners = await getWinnersData(contract, displayRoundId);
      if (winners) {
        winnersHTML = `
          <div class="winners-section">
            <div class="winners-title">🎉 Round ${displayRoundId} Winners 🎉</div>
            
            <div class="winner-tier">
              <div class="winner-tier-title fake-pack">🥇 Fake Pack Winner (3x PEPEDAWN)</div>
              <div class="winner-address">${winners.fakePackWinner ? formatAddress(winners.fakePackWinner) : 'No Winner'}</div>
            </div>
            
            <div class="winner-tier">
              <div class="winner-tier-title kek-pack">🥈 Kek Pack Winner (2x PEPEDAWN)</div>
              <div class="winner-address">${winners.kekPackWinner ? formatAddress(winners.kekPackWinner) : 'No Winner'}</div>
            </div>
            
            <div class="winner-tier">
              <div class="winner-tier-title pepe-pack">🥉 Pepe Pack Winners (1x PEPEDAWN)</div>
              <div class="pepe-winners-grid">
                ${winners.pepePackWinners.map(address => 
                  `<div class="winner-address">${formatAddress(address)}</div>`
                ).join('')}
              </div>
            </div>
          </div>
        `;
      }
    }
    
    // Get ALL participants (fixed: was only showing current user)
    const leaderboardData = [];
    try {
      const participants = await contract.getRoundParticipants(displayRoundId);
      
      // Get stats for each participant
      for (let i = 0; i < participants.length; i++) {
        const participant = participants[i];
        try {
          const stats = await contract.getUserStats(displayRoundId, participant);
          const fakeOdds = roundData.totalWeight > 0 
            ? ((Number(stats.weight) / Number(roundData.totalWeight)) * 100).toFixed(1)
            : '0.0';
          
          // Check if user has a verified proof (correct proof)
          let hasVerifiedProof = false;
          if (stats.hasProof) {
            try {
              const proofData = await contract.userProofInRound(displayRoundId, participant);
              hasVerifiedProof = proofData.verified;
            } catch (proofError) {
              // If we can't get proof data, default to false
              hasVerifiedProof = false;
            }
          }
          
          leaderboardData.push({
            address: participant,
            tickets: Number(stats.tickets),
            weight: Number(stats.weight),
            fakeOdds: fakeOdds + '%',
            hasVerifiedProof: hasVerifiedProof
          });
        } catch (error) {
          // Skip participant if stats can't be retrieved
          console.warn(`Could not get stats for participant ${participant}:`, error.message);
        }
      }
    } catch (error) {
      // Silently handle expected errors when no round exists
      if (!error.message.includes('execution reverted') && !error.message.includes('Round not initialized')) {
        console.warn('Error fetching participants for leaderboard:', error);
      }
    }
    
    // Sort by weight (descending)
    leaderboardData.sort((a, b) => b.weight - a.weight);
    
    // Generate leaderboard HTML
    const leaderboardHTML = `
      ${winnersHTML}
      <div class="leaderboard-header">
        <span>Rank</span>
        <span>Address</span>
        <span>Tickets</span>
        <span>Weight</span>
        <span>Winning Odds</span>
      </div>
      ${leaderboardData.map((entry, index) => `
        <div class="leaderboard-entry">
          <span class="rank">#${index + 1}</span>
          <span class="address">${formatAddress(entry.address)}${entry.hasVerifiedProof ? ' 🧩' : ''}</span>
          <span class="tickets">${entry.tickets}</span>
          <span class="weight">${entry.weight}</span>
          <span class="odds">${entry.fakeOdds}</span>
        </div>
      `).join('')}
    `;
    
    leaderboardList.innerHTML = leaderboardHTML;
    
  } catch (error) {
    console.error('Error updating leaderboard:', error);
    
    const leaderboardList = document.getElementById('leaderboard-list');
    if (leaderboardList) {
      leaderboardList.innerHTML = '<p>Error loading leaderboard</p>';
    }
  }
}

// Update user statistics
export async function updateUserStats(contract, userAddress) {
  try {
    const userTickets = document.getElementById('user-tickets');
    const userWeight = document.getElementById('user-weight');
    const userProofStatus = document.getElementById('user-proof-status');
    const userFakeOdds = document.getElementById('user-fake-odds');
    const capRemaining = document.getElementById('cap-remaining');
    
    if (!contract || !userAddress) {
      // Show default/mock data when contract not available
      if (userTickets) userTickets.textContent = '0 (No Contract)';
      if (userWeight) userWeight.textContent = '0 (No Contract)';
      if (userProofStatus) userProofStatus.textContent = 'No (No Contract)';
      if (userFakeOdds) userFakeOdds.textContent = '0% (No Contract)';
      if (capRemaining) capRemaining.textContent = '1.0 (No Contract)';
      return;
    }
    
    // Get current round ID
    const currentRoundId = await contract.currentRoundId();
    
    if (currentRoundId.toString() === '0') {
      // No active round - update UI and return early
      if (userTickets) userTickets.textContent = '0';
      if (userWeight) userWeight.textContent = '0';
      if (userProofStatus) userProofStatus.textContent = 'No Active Round';
      if (userFakeOdds) userFakeOdds.textContent = '0%';
      if (capRemaining) capRemaining.textContent = '1.0';
      return;
    }
    
    // Get user stats for current round
    let stats, roundData;
    try {
      // First check if the round exists by getting round data
      roundData = await contract.getRound(currentRoundId);
      
      // Check if round is properly initialized (has a valid status)
      if (!roundData || roundData.status === undefined) {
        throw new Error('Round not initialized');
      }
      
      // Now safely get user stats
      stats = await contract.getUserStats(currentRoundId, userAddress);
    } catch (error) {
      // Completely silence expected contract errors to prevent console spam
      const isExpectedError = error.message.includes('execution reverted') || 
                             error.message.includes('Round not initialized') ||
                             error.message.includes('call revert exception') ||
                             error.code === 'CALL_EXCEPTION';
      
      if (!isExpectedError) {
        console.warn('Unexpected error fetching round data:', error);
      }
      
      // Show "no round" state
      if (userTickets) userTickets.textContent = '0';
      if (userWeight) userWeight.textContent = '0';
      if (userProofStatus) userProofStatus.textContent = 'Round Not Available';
      if (userFakeOdds) userFakeOdds.textContent = '0%';
      if (capRemaining) capRemaining.textContent = '1.0';
      return;
    }
    
    // Update tickets
    if (userTickets) {
      userTickets.textContent = stats.tickets.toString();
    }
    
    // Update weight
    if (userWeight) {
      userWeight.textContent = stats.weight.toString();
    }
    
    // Update proof status
    if (userProofStatus) {
      if (stats.hasProof) {
        // Check if proof was verified (correct) or just submitted (failed)
        try {
          const proofData = await contract.userProofInRound(currentRoundId, userAddress);
          
          if (proofData.verified) {
            userProofStatus.textContent = 'Yes (+40%)';
            userProofStatus.className = 'proof-success';
          } else {
            userProofStatus.innerHTML = 'Yes (<span style="color: red;">failed</span>)';
            userProofStatus.className = 'proof-failed';
          }
        } catch (error) {
          // Fallback if we can't get proof data
          userProofStatus.textContent = 'Yes';
        }
      } else {
        userProofStatus.textContent = 'No';
        userProofStatus.className = '';
      }
    }
    
    // Update fake pack odds (percentage of total weight)
    if (userFakeOdds) {
      if (Number(roundData.totalWeight) > 0 && Number(stats.weight) > 0) {
        const odds = ((Number(stats.weight) / Number(roundData.totalWeight)) * 100).toFixed(1);
        userFakeOdds.textContent = odds + '%';
      } else {
        userFakeOdds.textContent = '0%';
      }
    }
    
    // Update cap remaining
    if (capRemaining) {
      const wagered = Number(ethers.formatEther(stats.wagered || '0'));
      const remaining = (1.0 - wagered).toFixed(3);
      capRemaining.textContent = remaining;
    }
    
  } catch (error) {
    console.error('Error updating user stats:', error);
    
    // Show error state
    const userTickets = document.getElementById('user-tickets');
    if (userTickets) userTickets.textContent = 'Error';
  }
}

// Update countdown timer
function updateCountdown(element, endTime) {
  function update() {
    const now = Date.now();
    const remaining = endTime - now;
    
    if (remaining <= 0) {
      element.textContent = 'Round Ended';
      return;
    }
    
    const days = Math.floor(remaining / (24 * 60 * 60 * 1000));
    const hours = Math.floor((remaining % (24 * 60 * 60 * 1000)) / (60 * 60 * 1000));
    const minutes = Math.floor((remaining % (60 * 60 * 1000)) / (60 * 1000));
    const seconds = Math.floor((remaining % (60 * 1000)) / 1000);
    
    element.textContent = `${days}d ${hours}h ${minutes}m ${seconds}s`;
  }
  
  update();
  setInterval(update, 1000);
}

// Format Ethereum address for display
function formatAddress(address) {
  if (!address) return '';
  return `${address.slice(0, 6)}...${address.slice(-4)}`;
}

// Show transaction status
export function showTransactionStatus(message, type = 'info') {
  // Create or update status element
  let statusEl = document.getElementById('tx-status');
  if (!statusEl) {
    statusEl = document.createElement('div');
    statusEl.id = 'tx-status';
    statusEl.className = 'tx-status';
    document.body.appendChild(statusEl);
  }
  
  statusEl.textContent = message;
  statusEl.className = `tx-status ${type}`;
  statusEl.style.display = 'block';
  
  // Auto-hide after timeout (different times based on type)
  let timeout;
  switch(type) {
    case 'success':
      timeout = 5000; // 5 seconds for success
      break;
    case 'error':
      timeout = 8000; // 8 seconds for errors (need more time to read)
      break;
    case 'info':
      timeout = 4000; // 4 seconds for info
      break;
    case 'warning':
      timeout = 6000; // 6 seconds for warnings
      break;
    default:
      timeout = 5000; // 5 seconds default
  }
  
  setTimeout(() => {
    statusEl.style.display = 'none';
  }, timeout);
}

// Hide transaction status
export function hideTransactionStatus() {
  const statusEl = document.getElementById('tx-status');
  if (statusEl) {
    statusEl.style.display = 'none';
  }
}

// Show network switch prompt
export function showNetworkSwitchPrompt() {
  const supportedNetworks = SECURITY_CONFIG.SUPPORTED_NETWORKS
    .map(id => SECURITY_CONFIG.NETWORK_NAMES[id] || `Chain ID ${id}`)
    .join(', ');
  
  const message = `Please switch to a supported network: ${supportedNetworks}`;
  showTransactionStatus(message, 'warning');
  
  // Add switch network button if MetaMask is available
  if (window.ethereum && window.ethereum.request) {
    const switchBtn = document.createElement('button');
    switchBtn.textContent = 'Switch to Sepolia';
    switchBtn.className = 'switch-network-btn';
    switchBtn.onclick = async () => {
      try {
        await switchToSepolia();
        hideTransactionStatus();
      } catch (error) {
        console.error('Failed to switch network:', error);
        showTransactionStatus('Failed to switch network: ' + error.message, 'error');
      }
    };
    
    const statusEl = document.getElementById('tx-status');
    if (statusEl && !statusEl.querySelector('.switch-network-btn')) {
      statusEl.appendChild(switchBtn);
    }
  }
}

// Switch to Sepolia testnet
export async function switchToSepolia() {
  if (!window.ethereum) {
    throw new Error('MetaMask not detected');
  }
  
  try {
    // Try to switch to Sepolia
    await window.ethereum.request({
      method: 'wallet_switchEthereumChain',
      params: [{ chainId: '0xaa36a7' }], // Sepolia chainId in hex
    });
  } catch (switchError) {
    // If Sepolia is not added, add it
    if (switchError.code === 4902) {
      await window.ethereum.request({
        method: 'wallet_addEthereumChain',
        params: [{
          chainId: '0xaa36a7',
          chainName: 'Sepolia Testnet',
          nativeCurrency: {
            name: 'SepoliaETH',
            symbol: 'ETH',
            decimals: 18,
          },
          rpcUrls: ['https://sepolia.infura.io/v3/'],
          blockExplorerUrls: ['https://sepolia.etherscan.io/'],
        }],
      });
    } else {
      throw switchError;
    }
  }
}

// Enhanced security status display
export function showSecurityStatus(contract, userAddress) {
  if (!contract || !userAddress) return;
  
  const securityEl = document.getElementById('security-status');
  if (!securityEl) return;
  
  // Check security status
  Promise.all([
    contract.paused().catch(() => false),
    contract.emergencyPaused().catch(() => false),
    contract.denylisted(userAddress).catch(() => false)
  ]).then(([paused, emergencyPaused, denylisted]) => {
    let status = '✅ All systems operational';
    let className = 'security-status normal';
    
    if (denylisted) {
      status = '🚫 Address is denylisted';
      className = 'security-status error';
    } else if (emergencyPaused) {
      status = '⚠️ Emergency pause active';
      className = 'security-status warning';
    } else if (paused) {
      status = '⏸️ Contract paused';
      className = 'security-status warning';
    }
    
    securityEl.textContent = status;
    securityEl.className = className;
  }).catch(error => {
    console.error('Error checking security status:', error);
    securityEl.textContent = '❓ Security status unknown';
    securityEl.className = 'security-status unknown';
  });
}

// Validate transaction parameters
export function validateTransactionParams(params) {
  const { amount, tickets, userAddress } = params;
  
  // Validate amount
  if (!amount || isNaN(amount) || amount <= 0) {
    throw new Error('Invalid bet amount');
  }
  
  // Validate tickets
  if (!tickets || !Number.isInteger(tickets) || tickets <= 0) {
    throw new Error('Invalid ticket count');
  }
  
  // Validate user address
  if (!userAddress || !/^0x[a-fA-F0-9]{40}$/.test(userAddress)) {
    throw new Error('Invalid user address');
  }
  
  return true;
}

// Simple transaction monitoring for small-scale site
export function monitorTransaction(txHash, type) {
  console.log(`📡 ${type} transaction: ${txHash}`);
  return { hash: txHash, type: type };
}

// Simple transaction status update
export function updateTransactionStatus(txHash, status) {
  console.log(`📊 Transaction ${txHash}: ${status}`);
}

// Enhanced error handling with user feedback
export function handleTransactionError(error, txType) {
  console.error(`Transaction error (${txType}):`, error);
  
  let userMessage = 'Transaction failed';
  let errorType = 'error';
  
  // Parse common error types
  if (error.message.includes('user rejected')) {
    userMessage = 'Transaction cancelled by user';
    errorType = 'info';
  } else if (error.message.includes('insufficient funds')) {
    userMessage = 'Insufficient ETH balance for transaction';
  } else if (error.message.includes('gas')) {
    userMessage = 'Transaction failed due to gas issues';
  } else if (error.message.includes('nonce')) {
    userMessage = 'Transaction nonce error - please try again';
  } else if (error.message.includes('network')) {
    userMessage = 'Network error - please check connection';
  } else if (error.code === 'CALL_EXCEPTION') {
    userMessage = 'Contract call failed - check requirements';
  }
  
  showTransactionStatus(userMessage, errorType);
  
  return {
    message: userMessage,
    type: errorType,
    originalError: error
  };
}
