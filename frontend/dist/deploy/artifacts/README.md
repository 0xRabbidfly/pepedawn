# PEPEDAWN Deployment Artifacts

This directory contains deployment artifacts for the PEPEDAWN raffle system.

## Structure

```
deploy/artifacts/
├── README.md                 # This file
├── addresses.json           # Contract addresses by network
├── abis/                    # Contract ABIs
│   └── PepedawnRaffle.json
├── vrf-config.json         # Chainlink VRF configuration
└── events/                 # Event schemas and references
    ├── wager-events.json
    ├── proof-events.json
    └── draw-events.json
```

## Usage

### Frontend Integration
The frontend loads contract configuration from these artifacts:

```javascript
// Load contract address and ABI
import addresses from './deploy/artifacts/addresses.json';
import abi from './deploy/artifacts/abis/PepedawnRaffle.json';

const contractAddress = addresses[chainId].PepedawnRaffle;
const contract = new ethers.Contract(contractAddress, abi, provider);
```

### VRF Configuration
Chainlink VRF settings are stored in `vrf-config.json`:

```json
{
  "sepolia": {
    "vrfCoordinator": "0x...",
    "subscriptionId": "123",
    "keyHash": "0x...",
    "callbackGasLimit": 100000,
    "requestConfirmations": 3
  }
}
```

## Networks

- **Sepolia Testnet**: Development and testing
- **Ethereum Mainnet**: Production deployment

## Event Schemas

Event schemas in the `events/` directory define the structure of emitted events for:
- Wager placement and validation
- Puzzle proof submission and verification  
- VRF draw requests and fulfillment
- Prize distribution and fee collection

## Security Notes

- All addresses are verified on Etherscan
- ABIs match deployed bytecode
- VRF configuration uses official Chainlink contracts
- Event schemas enable proper indexing and monitoring

## Deployment Process

1. Deploy contracts with Foundry
2. Verify on Etherscan
3. Update `addresses.json` with new addresses
4. Export ABIs to `abis/` directory
5. Configure VRF subscription and update `vrf-config.json`
6. Test event emission and update schemas
7. Update frontend configuration

## Monitoring

Use the event schemas to set up monitoring for:
- Round lifecycle events
- Wager and proof submission
- VRF request/fulfillment
- Prize distribution
- Fee collection and distribution
