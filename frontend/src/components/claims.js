// Claims Component - Handles prize claiming UI and Merkle proof generation
import { ethers } from 'ethers';
import { fetchWinnersFile } from '../services/ipfs.js';
import { generateWinnerProof, getPrizesForAddress, getPrizeTierName, verifyWinnersFile } from '../services/merkle.js';
import { showTransactionStatus } from '../ui.js';

/**
 * Display claimable prizes for current user
 * @param {ethers.Contract} contract - Contract instance
 * @param {string} userAddress - User's Ethereum address
 * @param {number} roundId - Round ID
 */
export async function displayClaimablePrizes(contract, userAddress, roundId) {
  console.log('🎯 displayClaimablePrizes called:', { userAddress, roundId });
  const claimsContainer = document.getElementById('claims-container');
  if (!claimsContainer) {
    console.error('❌ claims-container not found in DOM');
    return;
  }
  
  try {
    // Get round data
    const roundData = await contract.getRound(roundId);
    const status = Number(roundData.status);
    
    // Only show claims if round is Distributed (5) or Closed
    if (status !== 5 && status !== 6) {
      claimsContainer.style.display = 'none';
      return;
    }
    
    // Check if winners root is set
    if (!roundData.winnersRoot || roundData.winnersRoot === ethers.ZeroHash) {
      claimsContainer.style.display = 'none';
      return;
    }
    
    // Get winners CID
    const winnersCID = await contract.winnersCIDs(roundId);
    if (!winnersCID || winnersCID === '') {
      claimsContainer.innerHTML = '<p class="info">Winners file not yet published</p>';
      claimsContainer.style.display = 'block';
      return;
    }
    
    // Show loading state
    claimsContainer.innerHTML = '<p class="info">Loading winners data from IPFS...</p>';
    claimsContainer.style.display = 'block';
    
    // Fetch winners file from IPFS
    const winnersFile = await fetchWinnersFile(winnersCID, roundId);
    
    // Verify winners file
    const vrfSeed = roundData.vrfSeed || ethers.ZeroHash;
    const isValid = verifyWinnersFile(winnersFile, roundData.winnersRoot, vrfSeed);
    if (!isValid) {
      claimsContainer.innerHTML = '<p class="error">⚠️ Winners file verification failed</p>';
      return;
    }
    
    // Find prizes for this user
    const userPrizes = getPrizesForAddress(winnersFile.winners, userAddress);
    console.log('🎁 User prizes found:', userPrizes.length, userPrizes);
    
    if (userPrizes.length === 0) {
      claimsContainer.innerHTML = '<p class="info">No prizes won in this round</p>';
      return;
    }
    
    // Display claimable prizes
    console.log('🎨 Building HTML for prizes...');
    let html = '<h3>🎁 Your Prizes</h3>';
    html += '<div class="prizes-grid">';
    
    for (const prize of userPrizes) {
      console.log('🔍 Checking claim status for prize:', prize.prizeIndex);
      // Check if already claimed
      let isClaimed = false;
      try {
        const claimStatus = await contract.claims(roundId, prize.prizeIndex);
        isClaimed = claimStatus !== ethers.ZeroAddress;
        console.log('✅ Claim status:', { prizeIndex: prize.prizeIndex, isClaimed, claimStatus });
      } catch (error) {
        console.error('❌ Error checking claim status:', error);
        isClaimed = false; // Default to not claimed if error
      }
      
      html += `
        <div class="prize-card ${isClaimed ? 'claimed' : ''}">
          <div class="prize-tier">${getPrizeTierName(prize.prizeTier)}</div>
          <div class="prize-index">Prize #${prize.prizeIndex + 1}</div>
          <div class="prize-token">NFT ID: ${prize.emblemVaultTokenId || 'TBD'}</div>
          ${isClaimed 
            ? '<div class="claim-status claimed">✓ Claimed</div>'
            : `<button class="claim-btn" data-round="${roundId}" data-prize-index="${prize.prizeIndex}" data-prize-tier="${prize.prizeTier}">Claim Prize</button>`
          }
        </div>
      `;
    }
    
    html += '</div>';
    console.log('🎨 Setting innerHTML and showing claims...');
    claimsContainer.innerHTML = html;
    
    // Show the claims section
    const claimsSection = document.getElementById('claims-section');
    if (claimsSection) {
      console.log('✅ Showing claims section');
      claimsSection.style.display = 'block';
    } else {
      console.error('❌ claims-section not found');
    }
    
    // Add event listeners to claim buttons
    const claimButtons = claimsContainer.querySelectorAll('.claim-btn');
    claimButtons.forEach(btn => {
      btn.addEventListener('click', async () => {
        const roundId = parseInt(btn.dataset.round);
        const prizeIndex = parseInt(btn.dataset.prizeIndex);
        const prizeTier = parseInt(btn.dataset.prizeTier);
        await claimPrize(contract, userAddress, roundId, prizeIndex, prizeTier, winnersFile);
      });
    });
    
  } catch (error) {
    console.error('Error displaying claimable prizes:', error);
    claimsContainer.innerHTML = `<p class="error">Failed to load prizes: ${error.message}</p>`;
  }
}

/**
 * Claim a prize
 * @param {ethers.Contract} contract - Contract instance
 * @param {string} userAddress - User's address
 * @param {number} roundId - Round ID
 * @param {number} prizeIndex - Prize index (0-9)
 * @param {number} prizeTier - Prize tier
 * @param {Object} winnersFile - Winners file data
 */
async function claimPrize(contract, userAddress, roundId, prizeIndex, prizeTier, winnersFile) {
  try {
    showTransactionStatus('Generating Merkle proof...', 'info');
    
    // Generate Merkle proof
    const proof = generateWinnerProof(winnersFile.winners, userAddress, prizeIndex);
    
    showTransactionStatus('Submitting claim transaction...', 'info');
    
    // Call contract claim function
    const tx = await contract.claim(roundId, prizeIndex, prizeTier, proof);
    
    showTransactionStatus('Waiting for confirmation...', 'info');
    
    const receipt = await tx.wait();
    
    console.log('Prize claimed successfully:', receipt);
    showTransactionStatus(`✅ Prize claimed successfully! NFT transferred to your wallet.`, 'success');
    
    // Refresh claims display
    setTimeout(() => {
      displayClaimablePrizes(contract, userAddress, roundId);
    }, 2000);
    
  } catch (error) {
    console.error('Error claiming prize:', error);
    let errorMsg = 'Failed to claim prize';
    
    if (error.message.includes('user rejected')) {
      errorMsg = 'Transaction cancelled by user';
    } else if (error.message.includes('already claimed')) {
      errorMsg = 'This prize has already been claimed';
    } else if (error.message.includes('invalid proof')) {
      errorMsg = 'Invalid Merkle proof - verification failed';
    } else if (error.message.includes('Claim limit')) {
      errorMsg = 'You have reached your claim limit for this round';
    } else {
      errorMsg = `Failed to claim: ${error.message}`;
    }
    
    showTransactionStatus(errorMsg, 'error');
  }
}

/**
 * Display refund button if user has refund available
 * @param {ethers.Contract} contract - Contract instance
 * @param {string} userAddress - User's address
 */
export async function displayRefundButton(contract, userAddress) {
  const refundContainer = document.getElementById('refund-container');
  if (!refundContainer) return;
  
  try {
    // Check refund balance
    const refundBalance = await contract.refunds(userAddress);
    
    if (refundBalance === 0n) {
      refundContainer.style.display = 'none';
      return;
    }
    
    // Display refund button
    const refundEth = ethers.formatEther(refundBalance);
    refundContainer.innerHTML = `
      <div class="refund-card">
        <h3>💰 Refund Available</h3>
        <p class="refund-amount">${refundEth} ETH</p>
        <p class="refund-info">This round didn't meet the minimum ticket threshold.</p>
        <button id="withdraw-refund-btn" class="btn btn-primary">Withdraw Refund</button>
      </div>
    `;
    refundContainer.style.display = 'block';
    
    // Add event listener
    const withdrawBtn = document.getElementById('withdraw-refund-btn');
    withdrawBtn.addEventListener('click', () => withdrawRefund(contract, userAddress));
    
  } catch (error) {
    console.error('Error checking refund:', error);
  }
}

/**
 * Withdraw refund
 * @param {ethers.Contract} contract - Contract instance
 * @param {string} userAddress - User's address
 */
async function withdrawRefund(contract, userAddress) {
  try {
    showTransactionStatus('Withdrawing refund...', 'info');
    
    const tx = await contract.withdrawRefund();
    
    showTransactionStatus('Waiting for confirmation...', 'info');
    
    const receipt = await tx.wait();
    
    console.log('Refund withdrawn successfully:', receipt);
    showTransactionStatus('✅ Refund withdrawn successfully!', 'success');
    
    // Refresh refund display
    setTimeout(() => {
      displayRefundButton(contract, userAddress);
    }, 2000);
    
  } catch (error) {
    console.error('Error withdrawing refund:', error);
    let errorMsg = 'Failed to withdraw refund';
    
    if (error.message.includes('user rejected')) {
      errorMsg = 'Transaction cancelled by user';
    } else if (error.message.includes('No refund')) {
      errorMsg = 'No refund available';
    } else {
      errorMsg = `Failed to withdraw: ${error.message}`;
    }
    
    showTransactionStatus(errorMsg, 'error');
  }
}
