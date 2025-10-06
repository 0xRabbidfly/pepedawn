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
│       ├── contract-config.js # Contract address & ABI configuration
│       ├── styles.css       # Main application styles
│       └── style.css        # Vite template styles (legacy)
├── contracts/               # Solidity contracts + tests
│   ├── src/
│   │   └── PepedawnRaffle.sol  # Main raffle contract
│   ├── test/                # Foundry unit + invariant tests
│   ├── script/              # Deployment scripts
│   └── scripts/             # Interaction utilities
├── deploy/artifacts/        # Deployment artifacts
│   ├── addresses.json       # Contract addresses by network
│   └── vrf-config.json      # Chainlink VRF configuration
└── specs/                   # Project specifications & planning
```

## 🎯 Core Features

### Smart Contract (Solidity + Foundry)
- **Skill-weighted betting**: Puzzle proofs multiply your odds by 2x
- **Chainlink VRF integration**: Verifiable random winner selection
- **Security-first design**: Reentrancy protection, access controls, circuit breakers
- **Comprehensive testing**: 16 test suites covering all scenarios

### Frontend (Vanilla JS + Vite)
- **Multi-page application**: Title page, betting interface, rules
- **Web3 wallet integration**: MetaMask support with network validation
- **Real-time updates**: Live round status and leaderboard
- **Security features**: Input validation, rate limiting, error handling

## 🔧 Development Workflow

### Contract Development
```bash
cd contracts

# Run tests
forge test                    # All tests
forge test --match-path "test/BasicDeployment.t.sol" # Specific test

# Deploy to Sepolia
forge script script/Deploy.s.sol --rpc-url $SEPOLIA_RPC_URL --broadcast

# Interact with deployed contract
.\scripts\interact-sepolia.ps1 check        # Check contract state
.\scripts\interact-sepolia.ps1 quick-start  # Create and open round
```

### Frontend Development
```bash
cd frontend

# Development
npm run dev          # Development server
npm run build        # Production build
npm run preview      # Preview production build

# Code quality
npm run lint         # ESLint
npm run type-check   # TypeScript checking
```

## 🚀 Deployment

### Contract Deployment
1. **Set environment variables**:
   ```bash
   export PRIVATE_KEY="your_private_key"
   export SEPOLIA_RPC_URL="your_sepolia_rpc_url"
   export VRF_COORDINATOR="0x8103B0A8A00be2DDC778e6e7eaa21791Cd364625"
   export VRF_SUBSCRIPTION_ID="your_subscription_id"
   export VRF_KEY_HASH="0x474e34a077df58807dbe9c96d3c009b23b3c6d0cce433e59bbf5b34f823bc56c"
   export CREATORS_ADDRESS="your_creators_address"
   export EMBLEM_VAULT_ADDRESS="your_emblem_vault_address"
   ```

2. **Deploy contract**:
   ```bash
   cd contracts
   forge script script/Deploy.s.sol --rpc-url $SEPOLIA_RPC_URL --broadcast --verify
   ```

3. **Update frontend configuration**:
   - Copy deployed contract address
   - Update `frontend/src/contract-config.js` with new address
   - Update `deploy/artifacts/addresses.json`

### Frontend Deployment
The project uses GitHub Actions for automated deployment to pepedawn.art:

1. **Local build** (when npm/Rollup works):
   ```bash
   cd frontend
   npm run build
   git add dist/
   git commit -m "Update build for deployment"
   git push
   ```

2. **GitHub Actions** automatically:
   - Lints and type-checks code
   - Builds the application
   - Deploys to pepedawn.art via FTP

**Required GitHub Secrets**:
- `FTP_SERVER`: Your FTP hostname
- `FTP_USERNAME`: Your FTP username  
- `FTP_PASSWORD`: Your FTP password

## 🧪 Testing

### Contract Testing
See `contracts/TESTING.md` for detailed testing guide.

**Quick commands**:
```bash
cd contracts

# Unit tests (fast)
forge test --match-path "test/{BasicDeployment,AccessControl,InputValidation}.t.sol"

# Integration tests
forge test --match-path "test/{Round,Security,ScenarioFullRound}.t.sol"

# Security tests (extensive fuzzing)
forge test --profile security
```

### Frontend Testing
```bash
cd frontend

# Linting
npm run lint

# Type checking (TypeScript config available)
npm run type-check

# Build verification
npm run build

# Manual testing with local development server
npm run dev
```

## 🛡️ Security

The project implements comprehensive security measures:

- **Reentrancy Protection**: OpenZeppelin's `ReentrancyGuard`
- **Access Control**: `Ownable2Step` with custom modifiers
- **Input Validation**: Comprehensive parameter checking
- **Circuit Breakers**: Emergency pause functionality
- **Rate Limiting**: Frontend transaction throttling
- **Network Validation**: Ensures correct blockchain network

See `SECURITY_VALIDATION_REPORT.md` for detailed security analysis.

## 🔗 Contract Interaction

### Using Remix IDE
1. **Compile contract** in Remix with Solidity 0.8.20+ (project uses 0.8.20)
2. **Connect to deployed contract** using address: `0xBa8E7795682A6d0A05F805aD45258E3d4641BFFc`
3. **Create and open round**:
   ```solidity
   createRound()    // Create new round
   openRound(1)     // Open round 1 for betting
   ```

### Using Cast (Command Line)
```bash
# Check contract state
cast call 0xBa8E7795682A6d0A05F805aD45258E3d4641BFFc "currentRoundId()" --rpc-url $SEPOLIA_RPC_URL

# Create round (owner only)
cast send 0xBa8E7795682A6d0A05F805aD45258E3d4641BFFc "createRound()" --private-key $PRIVATE_KEY --rpc-url $SEPOLIA_RPC_URL
```

### Using PowerShell Script
```powershell
# Windows users can use the provided script
.\contracts\scripts\interact-sepolia.ps1 check        # Check status
.\contracts\scripts\interact-sepolia.ps1 quick-start  # Create & open round
.\contracts\scripts\interact-sepolia.ps1 bet 1 0.01   # Place bet
```

## 📋 Current Deployment

**Sepolia Testnet**:
- **Contract Address**: `0xBa8E7795682A6d0A05F805aD45258E3d4641BFFc`
- **Network**: Sepolia (Chain ID: 11155111)
- **Frontend**: pepedawn.art (deployment configured via GitHub Actions)

## 🤝 Contributing

1. **Fork the repository**
2. **Create feature branch**: `git checkout -b feature/amazing-feature`
3. **Run tests**: `cd contracts && forge test`
4. **Commit changes**: `git commit -m 'Add amazing feature'`
5. **Push to branch**: `git push origin feature/amazing-feature`
6. **Open Pull Request**

## 📄 License

This project is licensed under the MIT License - see the LICENSE file for details.

## 🔗 Links

- **Live Application**: pepedawn.art
- **Contract on Etherscan**: [View on Sepolia Etherscan](https://sepolia.etherscan.io/address/0xBa8E7795682A6d0A05F805aD45258E3d4641BFFc)
- **Chainlink VRF**: [Sepolia VRF Coordinator](https://sepolia.etherscan.io/address/0x8103B0A8A00be2DDC778e6e7eaa21791Cd364625)

---

**Built with ❤️ for the Pepedawn community**