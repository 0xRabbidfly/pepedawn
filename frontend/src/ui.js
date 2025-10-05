import { ethers } from 'ethers';

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
  
  const ticketBtns = document.querySelectorAll('.ticket-btn');
  ticketBtns.forEach(btn => btn.classList.remove('selected'));
}

// Update wallet information display
export async function updateWalletInfo(address, provider) {
  try {
    const walletInfo = document.getElementById('wallet-info');
    const walletAddress = document.getElementById('wallet-address');
    const walletBalance = document.getElementById('wallet-balance');
    const connectBtn = document.getElementById('connect-wallet');
    
    if (walletAddress) {
      walletAddress.textContent = formatAddress(address);
    }
    
    if (provider && walletBalance) {
      const balance = await provider.getBalance(address);
      const balanceEth = ethers.formatEther(balance);
      walletBalance.textContent = parseFloat(balanceEth).toFixed(4);
    }
    
    if (walletInfo) {
      walletInfo.style.display = 'block';
    }
    
    if (connectBtn) {
      connectBtn.textContent = 'Connected';
      connectBtn.disabled = true;
    }
    
  } catch (error) {
    console.error('Error updating wallet info:', error);
  }
}

// Update round status display
export async function updateRoundStatus(contract) {
  try {
    if (!contract) {
      // Show mock data when contract not available
      const roundStatusText = document.getElementById('round-status-text');
      const timeRemaining = document.getElementById('time-remaining');
      const totalTickets = document.getElementById('total-tickets');
      
      if (roundStatusText) roundStatusText.textContent = 'No Contract (Mock)';
      if (timeRemaining) timeRemaining.textContent = '7d 0h 0m 0s (Mock)';
      if (totalTickets) totalTickets.textContent = '1,234 (Mock)';
      return;
    }
    
    // Get current round ID
    const currentRoundId = await contract.currentRoundId();
    
    if (currentRoundId.toString() === '0') {
      // No rounds created yet
      const roundStatusText = document.getElementById('round-status-text');
      if (roundStatusText) roundStatusText.textContent = 'No Active Round';
      return;
    }
    
    // Get round data
    const roundData = await contract.getRound(currentRoundId);
    
    // Update status text
    const roundStatusText = document.getElementById('round-status-text');
    if (roundStatusText) {
      const statusNames = ['Created', 'Open', 'Closed', 'Snapshot', 'VRF Requested', 'Distributed'];
      roundStatusText.textContent = statusNames[roundData.status] || 'Unknown';
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
    
  } catch (error) {
    console.error('Error updating round status:', error);
    
    // Show error state
    const roundStatusText = document.getElementById('round-status-text');
    if (roundStatusText) roundStatusText.textContent = 'Error Loading';
  }
}

// Update leaderboard display
export async function updateLeaderboard(contract) {
  try {
    const leaderboardList = document.getElementById('leaderboard-list');
    if (!leaderboardList) return;
    
    if (!contract) {
      // Show mock data when contract not available
      const mockLeaderboard = [
        { address: '0x1234...5678', tickets: 50, weight: 70, fakeOdds: '12.5%' },
        { address: '0xabcd...efgh', tickets: 35, weight: 35, fakeOdds: '8.7%' },
        { address: '0x9876...4321', tickets: 25, weight: 35, fakeOdds: '8.7%' }
      ];
      
      const leaderboardHTML = `
        <div class="leaderboard-header">
          <span>Rank</span>
          <span>Address</span>
          <span>Tickets</span>
          <span>Weight</span>
          <span>Fake Pack Odds</span>
        </div>
        ${mockLeaderboard.map((entry, index) => `
          <div class="leaderboard-entry">
            <span class="rank">#${index + 1}</span>
            <span class="address">${entry.address} (Mock)</span>
            <span class="tickets">${entry.tickets}</span>
            <span class="weight">${entry.weight}</span>
            <span class="odds">${entry.fakeOdds}</span>
          </div>
        `).join('')}
      `;
      
      leaderboardList.innerHTML = leaderboardHTML;
      return;
    }
    
    // Get current round ID
    const currentRoundId = await contract.currentRoundId();
    
    if (currentRoundId.toString() === '0') {
      leaderboardList.innerHTML = '<p>No active round</p>';
      return;
    }
    
    // Get round participants
    const participants = await contract.getRoundParticipants(currentRoundId);
    const roundData = await contract.getRound(currentRoundId);
    
    if (participants.length === 0) {
      leaderboardList.innerHTML = '<p>No participants yet</p>';
      return;
    }
    
    // Fetch stats for each participant
    const leaderboardData = [];
    for (const participant of participants) {
      try {
        const stats = await contract.getUserStats(currentRoundId, participant);
        const fakeOdds = roundData.totalWeight > 0 
          ? ((Number(stats.weight) / Number(roundData.totalWeight)) * 100).toFixed(1)
          : '0.0';
        
        leaderboardData.push({
          address: participant,
          tickets: Number(stats.tickets),
          weight: Number(stats.weight),
          fakeOdds: fakeOdds + '%',
          hasProof: stats.hasProof
        });
      } catch (error) {
        console.error('Error fetching stats for', participant, error);
      }
    }
    
    // Sort by weight (descending)
    leaderboardData.sort((a, b) => b.weight - a.weight);
    
    // Generate leaderboard HTML
    const leaderboardHTML = `
      <div class="leaderboard-header">
        <span>Rank</span>
        <span>Address</span>
        <span>Tickets</span>
        <span>Weight</span>
        <span>Fake Pack Odds</span>
      </div>
      ${leaderboardData.map((entry, index) => `
        <div class="leaderboard-entry">
          <span class="rank">#${index + 1}</span>
          <span class="address">${formatAddress(entry.address)}${entry.hasProof ? ' 🧩' : ''}</span>
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
      // No active round
      if (userTickets) userTickets.textContent = '0';
      if (userWeight) userWeight.textContent = '0';
      if (userProofStatus) userProofStatus.textContent = 'No Active Round';
      if (userFakeOdds) userFakeOdds.textContent = '0%';
      if (capRemaining) capRemaining.textContent = '1.0';
      return;
    }
    
    // Get user stats for current round
    const stats = await contract.getUserStats(currentRoundId, userAddress);
    const roundData = await contract.getRound(currentRoundId);
    
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
        userProofStatus.textContent = 'Yes (+40%)';
      } else {
        userProofStatus.textContent = 'No';
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
  
  // Auto-hide after 5 seconds for success/error messages
  if (type === 'success' || type === 'error') {
    setTimeout(() => {
      statusEl.style.display = 'none';
    }, 5000);
  }
}

// Hide transaction status
export function hideTransactionStatus() {
  const statusEl = document.getElementById('tx-status');
  if (statusEl) {
    statusEl.style.display = 'none';
  }
}
