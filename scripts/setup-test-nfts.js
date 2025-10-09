#!/usr/bin/env node

/**
 * Setup Test NFTs Script
 * 
 * Deploys a test NFT contract, mints 10 NFTs, transfers them to the raffle,
 * and sets them as prizes for the specified round.
 * 
 * Usage:
 *   node scripts/setup-test-nfts.js [roundId]
 * 
 * Example:
 *   node scripts/setup-test-nfts.js 1
 */

const { execSync } = require('child_process');
const fs = require('fs');
const path = require('path');

// Load environment variables
function loadEnv() {
  const envPath = path.join(__dirname, '../contracts/.env');
  if (!fs.existsSync(envPath)) {
    throw new Error('contracts/.env not found');
  }
  
  const envContent = fs.readFileSync(envPath, 'utf8');
  envContent.split('\n').forEach(line => {
    const match = line.match(/^([^=]+)=(.*)$/);
    if (match && !process.env[match[1]]) {
      process.env[match[1]] = match[2].trim();
    }
  });
}

function exec(cmd, options = {}) {
  console.log(`\n💻 ${cmd.substring(0, 100)}${cmd.length > 100 ? '...' : ''}`);
  try {
    const result = execSync(cmd, {
      cwd: path.join(__dirname, '../contracts'),
      encoding: 'utf8',
      stdio: options.silent ? 'pipe' : 'inherit',
      ...options
    });
    return result;
  } catch (error) {
    console.error('❌ Command failed:', error.message);
    throw error;
  }
}

function sleep(ms) {
  return new Promise(resolve => setTimeout(resolve, ms));
}

async function main() {
  try {
    loadEnv();
    
    const roundId = process.argv[2] || '1';
    const raffleAddress = process.env.CONTRACT_ADDRESS;
    
    if (!raffleAddress) {
      throw new Error('CONTRACT_ADDRESS not found in .env');
    }
    
    console.log('\n🎨 ========================================');
    console.log('   SETUP TEST NFTs FOR PEPEDAWN');
    console.log('========================================\n');
    console.log(`Round: ${roundId}`);
    console.log(`Raffle: ${raffleAddress}\n`);
    
    // Step 1: Deploy Test NFT Contract
    console.log('📦 Step 1: Deploying Test NFT Contract...');
    exec(
      `forge script scripts/forge/MintTestNFTs.s.sol:MintTestNFTs --rpc-url ${process.env.SEPOLIA_RPC_URL} --private-key ${process.env.PRIVATE_KEY} --broadcast`
    );
    
    // Extract NFT contract address from broadcast
    const broadcastPath = path.join(__dirname, '../contracts/broadcast/MintTestNFTs.s.sol/11155111/run-latest.json');
    if (!fs.existsSync(broadcastPath)) {
      throw new Error('Broadcast file not found');
    }
    
    const broadcast = JSON.parse(fs.readFileSync(broadcastPath, 'utf8'));
    const nftAddress = broadcast.transactions[0].contractAddress;
    
    if (!nftAddress) {
      throw new Error('Could not extract NFT contract address');
    }
    
    console.log(`\n✅ Test NFT Contract: ${nftAddress}`);
    console.log(`✅ 10 NFTs minted to your wallet (IDs 1-10)`);
    
    await sleep(3000);
    
    // Step 2: Transfer NFTs to Raffle Contract
    console.log('\n🔄 Step 2: Transferring NFTs to Raffle...');
    
    // Get deployer address from private key
    const deployerAddress = exec(
      `cast wallet address ${process.env.PRIVATE_KEY}`,
      { silent: true }
    ).trim();
    
    console.log(`  From: ${deployerAddress}`);
    console.log(`  To: ${raffleAddress}\n`);
    
    for (let tokenId = 1; tokenId <= 10; tokenId++) {
      console.log(`  Transferring NFT #${tokenId}...`);
      
      let retries = 3;
      while (retries > 0) {
        try {
          exec(
            `cast send ${nftAddress} "transferFrom(address,address,uint256)" ${deployerAddress} ${raffleAddress} ${tokenId} --private-key ${process.env.PRIVATE_KEY} --rpc-url ${process.env.SEPOLIA_RPC_URL}`,
            { silent: true }
          );
          break; // Success
        } catch (error) {
          retries--;
          if (retries > 0) {
            console.log(`    ⏳ Retrying... (${retries} left)`);
            await sleep(3000);
          } else {
            throw error;
          }
        }
      }
      
      // Delay between transfers to avoid nonce/rate limit issues
      if (tokenId < 10) {
        await sleep(2000);
      }
    }
    
    console.log('\n✅ All 10 NFTs transferred to raffle contract!');
    
    await sleep(2000);
    
    // Step 3: Set Prizes for Round
    console.log(`\n🎁 Step 3: Setting prizes for Round ${roundId}...`);
    exec(
      `cast send ${raffleAddress} "setPrizesForRound(uint256,uint256[10])" ${roundId} "[1,2,3,4,5,6,7,8,9,10]" --private-key ${process.env.PRIVATE_KEY} --rpc-url ${process.env.SEPOLIA_RPC_URL}`
    );
    
    console.log(`\n✅ Prizes set for Round ${roundId}!`);
    
    // Verify setup
    console.log('\n🔍 Verifying setup...');
    const balance = exec(
      `cast call ${nftAddress} "balanceOf(address)" ${raffleAddress} --rpc-url ${process.env.SEPOLIA_RPC_URL}`,
      { silent: true }
    ).trim();
    
    const balanceNum = parseInt(balance, 16);
    console.log(`✅ Raffle contract NFT balance: ${balanceNum}`);
    
    if (balanceNum !== 10) {
      console.warn('⚠️  Expected 10 NFTs, found:', balanceNum);
    }
    
    console.log('\n🎉 ========================================');
    console.log('   TEST NFTs SETUP COMPLETE!');
    console.log('========================================');
    console.log(`\n📋 Summary:`);
    console.log(`   NFT Contract: ${nftAddress}`);
    console.log(`   NFTs in Raffle: ${balanceNum}`);
    console.log(`   Prizes Set: Round ${roundId}`);
    console.log(`\n🐸 Ready to test full claims flow!`);
    console.log(`   Try claiming prizes at: http://localhost:5173/main.html`);
    
  } catch (error) {
    console.error('\n❌ Setup failed:', error.message);
    process.exit(1);
  }
}

main();

