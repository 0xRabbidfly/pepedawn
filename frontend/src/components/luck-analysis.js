/**
 * Luck Analysis Component
 * Shows users how lucky/unlucky they were in a round based on their odds vs actual wins
 */

/**
 * Calculate binomial probability
 * P(X = k) = C(n,k) * p^k * (1-p)^(n-k)
 */
function binomialProbability(n, k, p) {
  if (k > n) return 0;
  if (p === 0) return k === 0 ? 1 : 0;
  if (p === 1) return k === n ? 1 : 0;
  
  // Calculate combination C(n,k)
  let combination = 1;
  for (let i = 0; i < k; i++) {
    combination *= (n - i) / (i + 1);
  }
  
  return combination * Math.pow(p, k) * Math.pow(1 - p, n - k);
}

/**
 * Get luck tier information based on luck percentage
 */
function getLuckTier(luckPercent) {
  const tiers = [
    { min: 0, max: 0, name: 'Blanked', emoji: '😢', color: '#6B7280', message: 'Better luck next time!' },
    { min: 1, max: 49, name: 'Unlucky', emoji: '😕', color: '#F97316', message: 'Below odds, but there\'s always next round!' },
    { min: 50, max: 99, name: 'Close', emoji: '😐', color: '#EAB308', message: 'Almost expected - not bad!' },
    { min: 100, max: 149, name: 'On Track', emoji: '🙂', color: '#10B981', message: 'Right on target!' },
    { min: 150, max: 199, name: 'Lucky', emoji: '🍀', color: '#22C55E', message: 'You beat the odds!' },
    { min: 200, max: 299, name: 'Very Lucky', emoji: '✨', color: '#F59E0B', message: 'Exceptionally lucky!' },
    { min: 300, max: Infinity, name: 'Jackpot', emoji: '🎰', color: '#A855F7', message: 'Defied the odds!' }
  ];
  
  for (const tier of tiers) {
    if (luckPercent >= tier.min && luckPercent <= tier.max) {
      return tier;
    }
  }
  
  return tiers[0]; // Default to Blanked
}

/**
 * Calculate luck statistics for a user in a specific round
 */
export async function calculateLuckStats(contract, roundId, userAddress, winnersFile = null) {
  try {
    // Get user stats
    const [, tickets, weight, hasProof] = await contract.getUserStats(roundId, userAddress);
    
    // Get round data
    const round = await contract.getRound(roundId);
    const totalWeight = round.totalWeight;
    
    // Count how many prizes the user won (from winners file, not claimers)
    let actualWins = 0;
    if (winnersFile && winnersFile.winners) {
      // Count from winners file (who WON, not who claimed)
      for (const winner of winnersFile.winners) {
        if (winner.address.toLowerCase() === userAddress.toLowerCase()) {
          actualWins++;
        }
      }
    } else {
      // Fallback to prizeClaimers if no winners file (will be inaccurate before claims)
      const roundState = await contract.getRoundState(roundId);
      const prizeClaimers = roundState.prizeClaimers;
      for (const claimer of prizeClaimers) {
        if (claimer.toLowerCase() === userAddress.toLowerCase()) {
          actualWins++;
        }
      }
    }
    
    // Calculate expected wins
    const weightBigInt = BigInt(weight.toString());
    const totalWeightBigInt = BigInt(totalWeight.toString());
    const weightPercent = totalWeightBigInt > 0n 
      ? Number(weightBigInt * 10000n / totalWeightBigInt) / 100
      : 0;
    
    const totalPrizes = 10;
    const expectedWins = (weightPercent / 100) * totalPrizes;
    
    // Calculate luck percentage
    const luckPercent = expectedWins > 0 
      ? Math.round((actualWins / expectedWins) * 100)
      : (actualWins > 0 ? 999 : 0); // If you had 0 chance but won, that's maximum luck!
    
    // Calculate probability distribution (0, 1, 2, 3, 4+)
    const probabilities = [];
    for (let k = 0; k <= 3; k++) {
      const prob = binomialProbability(totalPrizes, k, weightPercent / 100);
      probabilities.push({
        wins: k,
        probability: prob * 100,
        achieved: k === actualWins
      });
    }
    
    // Add "4+" category (sum of all k >= 4)
    let prob4Plus = 0;
    for (let k = 4; k <= totalPrizes; k++) {
      prob4Plus += binomialProbability(totalPrizes, k, weightPercent / 100);
    }
    probabilities.push({
      wins: '4+',
      probability: prob4Plus * 100,
      achieved: actualWins >= 4
    });
    
    return {
      tickets: Number(tickets),
      weight: Number(weight),
      hasProof,
      weightPercent,
      expectedWins,
      actualWins,
      luckPercent,
      probabilities,
      totalPrizes,
      totalWeight: Number(totalWeight)
    };
  } catch (error) {
    console.error('Error calculating luck stats:', error);
    throw error;
  }
}

/**
 * Display luck analysis in the UI
 */
export function displayLuckAnalysis(stats, containerSelector) {
  const container = document.querySelector(containerSelector);
  if (!container) {
    return; // Silent fail if container not found
  }
  
  const tier = getLuckTier(stats.luckPercent);
  
  // Build probability breakdown HTML
  const probabilityHTML = stats.probabilities.map(p => {
    const isActual = p.achieved;
    const winsLabel = p.wins === '4+' ? '4+' : p.wins;
    const icon = isActual ? '⭐' : '';
    const style = isActual ? 'font-weight: bold; color: #F59E0B;' : '';
    
    return `
      <div class="luck-probability-row" style="${style}">
        <span class="luck-prob-wins">Winning ${winsLabel}:</span>
        <span class="luck-prob-percent">${p.probability.toFixed(1)}%</span>
        <span class="luck-prob-icon">${icon}</span>
        ${isActual ? '<span class="luck-prob-label">You did this!</span>' : ''}
      </div>
    `;
  }).join('');
  
  // Calculate luck bar width with proper scaling
  // Scale: 0% = 0%, 100% = 33%, 200% = 66%, 300%+ = 100%
  // This way "Expected" marker at 33% represents 100% luck
  const maxDisplayPercent = 300;
  const scaledWidth = Math.min((stats.luckPercent / maxDisplayPercent) * 100, 100);
  const expectedMarkerPosition = (100 / maxDisplayPercent) * 100; // 33.33%
  
  // Build the HTML
  const html = `
    <div class="luck-analysis-card">
      <h3 class="luck-title">🎲 Your Luck Analysis</h3>
      
      <div class="luck-stats-summary">
        <div class="luck-stat-item">
          <span class="luck-stat-label">Tickets:</span>
          <span class="luck-stat-value">${stats.tickets || 0}</span>
        </div>
        <div class="luck-stat-item">
          <span class="luck-stat-label">Weight:</span>
          <span class="luck-stat-value">${stats.weight || 0} (${(stats.weightPercent || 0).toFixed(2)}% of pool)${stats.hasProof ? ' 🧩' : ''}</span>
        </div>
        <div class="luck-stat-item">
          <span class="luck-stat-label">Expected Wins:</span>
          <span class="luck-stat-value">${(stats.expectedWins || 0).toFixed(2)} prizes</span>
        </div>
      </div>
      
      <div class="luck-result-box" style="border-color: ${tier.color};">
        <div class="luck-tier-header">
          <span class="luck-tier-emoji">${tier.emoji}</span>
          <span class="luck-tier-name" style="color: ${tier.color};">${tier.name}!</span>
          <span class="luck-tier-emoji">${tier.emoji}</span>
        </div>
        
        <div class="luck-main-result">
          Won <strong>${stats.actualWins || 0}</strong> prize${stats.actualWins !== 1 ? 's' : ''} 
          (<strong style="color: ${tier.color};">${stats.luckPercent || 0}% luck</strong>)
        </div>
        
        <div class="luck-bar-container">
          <div class="luck-bar-fill" style="width: ${scaledWidth}%; background-color: ${tier.color};"></div>
          <div class="luck-bar-marker" style="left: ${expectedMarkerPosition}%;">
            <div class="luck-bar-marker-line"></div>
            <div class="luck-bar-marker-label">Expected</div>
          </div>
        </div>
        
        <div class="luck-message" style="color: ${tier.color};">
          ${tier.message}
        </div>
        
        ${(stats.luckPercent || 0) > 100 ? `
          <div class="luck-beat-odds">
            You beat the odds by <strong>${(stats.luckPercent || 0) - 100}%</strong>!
          </div>
        ` : (stats.luckPercent || 0) < 100 && (stats.expectedWins || 0) > 0 ? `
          <div class="luck-below-odds">
            ${Math.round(100 - (stats.luckPercent || 0))}% below expected
          </div>
        ` : ''}
      </div>
      
      <div class="luck-probability-breakdown">
        <h4 class="luck-breakdown-title">Probability Breakdown:</h4>
        ${probabilityHTML}
      </div>
    </div>
  `;
  
  container.innerHTML = html;
}

/**
 * Show luck analysis modal for a specific round
 */
export async function showLuckAnalysisModal(contract, roundId, userAddress) {
  try {
    // Calculate luck stats
    const stats = await calculateLuckStats(contract, roundId, userAddress);
    
    // Create modal
    const modal = document.createElement('div');
    modal.className = 'luck-modal-overlay';
    modal.innerHTML = `
      <div class="luck-modal-content">
        <button class="luck-modal-close" aria-label="Close">&times;</button>
        <div class="luck-modal-header">
          <h2>Round #${roundId} Luck Analysis</h2>
        </div>
        <div id="luck-modal-body"></div>
      </div>
    `;
    
    document.body.appendChild(modal);
    
    // Display luck analysis in modal
    displayLuckAnalysis(stats, '#luck-modal-body');
    
    // Close button handler
    const closeBtn = modal.querySelector('.luck-modal-close');
    closeBtn.addEventListener('click', () => {
      modal.remove();
    });
    
    // Close on overlay click
    modal.addEventListener('click', (e) => {
      if (e.target === modal) {
        modal.remove();
      }
    });
    
    // Close on escape key
    const escapeHandler = (e) => {
      if (e.key === 'Escape') {
        modal.remove();
        document.removeEventListener('keydown', escapeHandler);
      }
    };
    document.addEventListener('keydown', escapeHandler);
    
  } catch (error) {
    console.error('Error showing luck analysis:', error);
    alert('Unable to calculate luck analysis. Please try again.');
  }
}

