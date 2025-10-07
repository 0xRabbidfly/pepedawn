#!/usr/bin/env node

const fs = require('fs');
const path = require('path');
const { execSync } = require('child_process');

function loadDotEnv(filePath) {
  if (!fs.existsSync(filePath)) return;
  const content = fs.readFileSync(filePath, 'utf8');
  for (const line of content.split(/\r?\n/)) {
    if (!line || line.trim().startsWith('#')) continue;
    const idx = line.indexOf('=');
    if (idx === -1) continue;
    const key = line.slice(0, idx).trim();
    const val = line.slice(idx + 1).trim();
    if (!(key in process.env)) process.env[key] = val;
  }
}

function readJson(p) {
  return JSON.parse(fs.readFileSync(p, 'utf8'));
}

function ensure(value, name) {
  if (!value || String(value).length === 0) {
    throw new Error(`${name} is required`);
  }
  return value;
}

try {
  // Load env from contracts/.env if present
  loadDotEnv(path.join(process.cwd(), 'contracts', '.env'));

  const chainId = '11155111';
  const addressesPath = path.join(process.cwd(), 'deploy', 'artifacts', 'addresses.json');
  const vrfCfgPath = path.join(process.cwd(), 'deploy', 'artifacts', 'vrf-config.json');

  const addresses = readJson(addressesPath);
  const vrf = readJson(vrfCfgPath);

  const contractAddress = ensure(addresses?.[chainId]?.PepedawnRaffle, 'Deployed contract address for chainId 11155111');

  const coordinator = ensure(vrf?.coordinator, 'VRF coordinator');
  const subId = ensure(vrf?.subscriptionId, 'VRF subscriptionId');
  const keyHash = ensure(vrf?.keyHash, 'VRF keyHash');

  const creators = ensure(process.env.CREATORS_ADDRESS, 'CREATORS_ADDRESS');
  const emblem = ensure(process.env.EMBLEM_VAULT_ADDRESS, 'EMBLEM_VAULT_ADDRESS');
  const rpcUrl = ensure(process.env.SEPOLIA_RPC_URL, 'SEPOLIA_RPC_URL');
  const etherscanKey = ensure(process.env.ETHERSCAN_API_KEY, 'ETHERSCAN_API_KEY');

  // Encode constructor args with cast
  const encodeCmd = `cast abi-encode "constructor(address,uint64,bytes32,address,address)" ${coordinator} ${subId} ${keyHash} ${creators} ${emblem}`;
  const argsEncoded = execSync(encodeCmd, { encoding: 'utf8' }).trim();

  // Run verification via Etherscan
  const verifyCmd = [
    'forge verify-contract',
    '--verifier etherscan',
    `--chain-id ${chainId}`,
    `--rpc-url ${rpcUrl}`,
    `--etherscan-api-key ${etherscanKey}`,
    contractAddress,
    'src/PepedawnRaffle.sol:PepedawnRaffle',
    `--constructor-args ${argsEncoded}`,
    '--watch'
  ].join(' ');

  console.log('Verifying with command:\n', verifyCmd, '\n');
  execSync(verifyCmd, { stdio: 'inherit', cwd: path.join(process.cwd(), 'contracts') });

} catch (err) {
  console.error('Verification failed:', err.message);
  process.exit(1);
}


