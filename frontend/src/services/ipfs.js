// IPFS Service for fetching Participants and Winners files
// Implements gateway fallback strategy with timeout handling

const IPFS_GATEWAYS = [
  'https://gateway.pinata.cloud/ipfs',
  'https://ipfs.io/ipfs',
  'https://cloudflare-ipfs.com/ipfs',
  'https://dweb.link/ipfs'
];

const DEFAULT_TIMEOUT = 60000; // 60 seconds as per spec

/**
 * Fetch a file from IPFS with gateway fallback
 * @param {string} cid - IPFS CID
 * @param {number} timeout - Timeout in milliseconds
 * @returns {Promise<Object>} - Parsed JSON object
 */
export async function fetchFromIPFS(cid, timeout = DEFAULT_TIMEOUT) {
  if (!cid || cid.trim() === '') {
    throw new Error('Invalid CID provided');
  }

  const errors = [];
  
  // Try each gateway in sequence
  for (const gateway of IPFS_GATEWAYS) {
    try {
      console.log(`Attempting to fetch from ${gateway}...`);
      const url = `${gateway}/${cid}`;
      
      const controller = new AbortController();
      const timeoutId = setTimeout(() => controller.abort(), timeout);
      
      const response = await fetch(url, {
        signal: controller.signal,
        headers: {
          'Accept': 'application/json'
        }
      });
      
      clearTimeout(timeoutId);
      
      if (!response.ok) {
        throw new Error(`HTTP ${response.status}: ${response.statusText}`);
      }
      
      const data = await response.json();
      console.log(`✅ Successfully fetched from ${gateway}`);
      return data;
      
    } catch (error) {
      const errorMsg = error.name === 'AbortError' 
        ? `Timeout after ${timeout}ms` 
        : error.message;
      console.warn(`❌ Failed to fetch from ${gateway}: ${errorMsg}`);
      errors.push({ gateway, error: errorMsg });
    }
  }
  
  // All gateways failed
  throw new Error(
    `Failed to fetch CID ${cid} from all gateways. Errors: ${
      errors.map(e => `${e.gateway}: ${e.error}`).join('; ')
    }`
  );
}

/**
 * Fetch Participants File for a round
 * @param {string} cid - IPFS CID from contract
 * @param {number} roundId - Round ID for validation
 * @returns {Promise<Object>} - Participants file data
 */
export async function fetchParticipantsFile(cid, roundId) {
  const data = await fetchFromIPFS(cid);
  
  // Validate file structure
  if (data.version !== '1.0') {
    throw new Error(`Unsupported Participants File version: ${data.version}`);
  }
  
  if (data.roundId !== roundId) {
    throw new Error(`Round ID mismatch: expected ${roundId}, got ${data.roundId}`);
  }
  
  if (!data.participants || !Array.isArray(data.participants)) {
    throw new Error('Invalid Participants File: missing participants array');
  }
  
  if (!data.merkle || !data.merkle.root) {
    throw new Error('Invalid Participants File: missing merkle root');
  }
  
  console.log(`✅ Participants File validated for round ${roundId}`);
  return data;
}

/**
 * Fetch Winners File for a round
 * @param {string} cid - IPFS CID from contract
 * @param {number} roundId - Round ID for validation
 * @returns {Promise<Object>} - Winners file data
 */
export async function fetchWinnersFile(cid, roundId) {
  const data = await fetchFromIPFS(cid);
  
  // Validate file structure
  if (data.version !== '1.0') {
    throw new Error(`Unsupported Winners File version: ${data.version}`);
  }
  
  if (data.roundId !== roundId) {
    throw new Error(`Round ID mismatch: expected ${roundId}, got ${data.roundId}`);
  }
  
  if (!data.winners || !Array.isArray(data.winners)) {
    throw new Error('Invalid Winners File: missing winners array');
  }
  
  if (data.winners.length !== 10) {
    throw new Error(`Invalid Winners File: expected 10 winners, got ${data.winners.length}`);
  }
  
  if (!data.merkle || !data.merkle.root) {
    throw new Error('Invalid Winners File: missing merkle root');
  }
  
  console.log(`✅ Winners File validated for round ${roundId}`);
  return data;
}

/**
 * Check if IPFS is accessible (health check)
 * @returns {Promise<boolean>} - True if at least one gateway is accessible
 */
export async function checkIPFSHealth() {
  // Try to fetch a known CID (IPFS project README)
  const testCid = 'QmQPeNsJPyVWPFDVHb77w8G42Fvo15z4bG2X8D2GhfbSXc';
  
  try {
    await fetchFromIPFS(testCid, 10000); // 10 second timeout for health check
    return true;
  } catch (error) {
    console.error('IPFS health check failed:', error.message);
    return false;
  }
}
