# PEPEDAWN

**Skill-Weighted Decentralized Raffle with Chainlink VRF and Emblem Vault Prizes**

A minimal, fast web experience for placing on-chain wagers in 2-week rounds, submitting puzzle proofs for bonus odds, and winning Emblem Vault prizes through verifiable Chainlink VRF draws.

## 🚀 Quick Start

### Prerequisites
- Node.js 20+
- npm or pnpm
- MetaMask or compatible Web3 wallet
- Foundry (for contract development)

### Frontend Development
```bash
cd frontend
npm install
npm run dev
```

Visit `http://localhost:5173` to access the application.

### Contract Development
```bash
cd contracts
# Install Foundry first: https://book.getfoundry.sh/getting-started/installation
forge install
forge test
```

## 📁 Project Structure

```
pepedawn/
├── frontend/                 # Vite MPA + vanilla JS frontend
│   ├── index.html           # Title page with animation
│   ├── main.html            # Betting interface + leaderboard
│   ├── rules.html           # Rules and about page
│   └── src/
│       ├── main.js          # Wallet connection + contract interaction
│       ├── ui.js            # DOM helpers and UI updates
│       └── styles.css       # Minimal modern styling
├── contracts/               # Solidity contracts + tests
│   ├── src/
│   │   └── PepedawnRaffle.sol  # Main raffle contract
│   └── test/                # Foundry unit + invariant tests
└── deploy/artifacts/        # Deployment artifacts
    ├── addresses.json       # Contract addresses by network
    ├── vrf-config.json      # Chainlink VRF configuration
    ├── abis/                # Contract ABIs
    └── events/              # Event schemas for monitoring
```

## 🎮 How It Works

### 1. Round Lifecycle
- **Duration**: 2 weeks per round
- **Phases**: Created → Open → Closed → Snapshot → VRF → Distributed
- **Management**: Owner-controlled round state transitions

### 2. Betting System
- **Minimum**: 0.005 ETH (1 ticket)
- **Bundles**: 5 tickets = 0.0225 ETH (10% discount), 10 tickets = 0.04 ETH (20% discount)
- **Cap**: 1.0 ETH maximum per wallet per round
- **Network**: Ethereum mainnet/testnet

### 3. Skill-Weighted Odds
- **Puzzle Proofs**: Submit one proof per round for +40% weight multiplier
- **Hard Cap**: Maximum 1.4x multiplier, no stacking
- **Verification**: On-chain proof hash storage

### 4. Verifiable Randomness
- **Provider**: Chainlink VRF v2/v2.5
- **Process**: Snapshot → VRF Request → Fulfillment → Winner Assignment
- **Fairness**: All randomness derived from VRF output, no manipulation possible

### 5. Prize Distribution
- **Tiers**: Fake Packs (common), Kek Packs (rare), Pepe Packs (legendary)
- **Source**: Emblem Vault preloaded assets
- **Distribution**: Automatic post-VRF fulfillment
- **Fees**: 80% to creators, 20% to next round

## 🔧 Technical Details

### Frontend
- **Framework**: Vite MPA with vanilla JavaScript
- **Web3**: ethers.js v6 for wallet connection
- **Bundle Size**: ≤100KB JS (currently 99.26KB gzipped)
- **Performance**: Fast wallet connect, minimal dependencies

### Smart Contracts
- **Language**: Solidity 0.8.19
- **Testing**: Foundry unit, invariant, and scenario tests
- **Architecture**: Single contract with modular functions
- **Security**: Checks-effects-interactions pattern, reentrancy protection

### VRF Configuration
Current network configurations in `deploy/artifacts/vrf-config.json`:

- **Sepolia Testnet**: For development and testing
- **Ethereum Mainnet**: For production deployment

### Event Monitoring
All contract events are structured with round IDs and correlation IDs for efficient monitoring:

- **Wager Events**: Track betting activity and amounts
- **Proof Events**: Monitor puzzle proof submissions
- **VRF Events**: Track randomness requests and fulfillment
- **Distribution Events**: Monitor prize and fee distribution

## 🚀 Deployment

### 1. Deploy Contracts
```bash
cd contracts
forge script script/Deploy.s.sol --rpc-url $RPC_URL --private-key $PRIVATE_KEY --broadcast
```

### 2. Update Artifacts
Update `deploy/artifacts/addresses.json` with deployed contract addresses.

### 3. Configure VRF
Set up Chainlink VRF subscription and update `deploy/artifacts/vrf-config.json`.

### 4. Deploy Frontend
```bash
cd frontend
npm run build
# Deploy dist/ to your hosting provider
```

## 🧪 Testing

### Contract Tests
```bash
cd contracts
forge test                    # Run all tests
forge test --match-test testCompleteRoundScenario  # Run specific test
forge test --gas-report      # Generate gas report
```

### Frontend Testing
The frontend includes real-time integration with deployed contracts and falls back to mock data when contracts are unavailable.

## 📊 Performance Metrics

- **Bundle Size**: 99.26KB gzipped (target: ≤100KB)
- **Load Time**: <2s on 3G connection
- **Wallet Connect**: <1s response time
- **Contract Calls**: Optimized for minimal gas usage

## 🔐 Security Features

- **Wallet Cap Enforcement**: 1.0 ETH maximum per wallet per round
- **Proof Verification**: One proof per wallet per round, hash-based validation
- **VRF Security**: Chainlink VRF prevents manipulation of randomness
- **Access Control**: Owner-only functions for round management
- **Reentrancy Protection**: All external calls protected

## 📈 Monitoring & Analytics

Event schemas in `deploy/artifacts/events/` enable monitoring of:
- Round participation and betting patterns
- Proof submission rates and timing
- VRF request/fulfillment latency
- Prize distribution success rates
- Fee collection and distribution

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch
3. Run tests: `forge test` and `npm run build`
4. Submit a pull request

## 📄 License

This project is aligned with the project constitution in `.specify/memory/constitution.md`.

## 🔗 Links

- **Chainlink VRF**: [Documentation](https://docs.chain.link/vrf/v2/introduction)
- **Emblem Vault**: [Platform](https://emblem.finance/)
- **Foundry**: [Book](https://book.getfoundry.sh/)
- **ethers.js**: [Documentation](https://docs.ethers.org/v6/)

