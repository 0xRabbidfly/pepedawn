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
│   ├── vrf-config.json     # Chainlink VRF configuration
│   └── abis/               # Contract ABIs
├── scripts/                # Automation scripts
│   ├── post-commit-check.js # Post-commit validation
│   ├── update-docs.js      # Documentation updater
│   └── update-configs.js   # Configuration synchronizer
└── specs/                  # Project specifications & planning
    └── 001-build-a-simple/
        ├── spec.md         # Business requirements
        ├── plan.md         # Technical implementation
        ├── research.md     # Technology decisions
        ├── data-model.md   # Entity definitions
        ├── quickstart.md   # Development setup
        └── contracts/      # API specifications
```

## 🎯 Core Features

### Smart Contract (Solidity + Foundry)
- **Skill-weighted betting**: Puzzle proofs multiply your odds by 1.4x (+40%)
- **Chainlink VRF integration**: Verifiable random winner selection
- **Dynamic gas estimation**: Automatic VRF callback gas calculation
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

## 🤖 Automation System

The project includes automated scripts to ensure consistency across contracts, documentation, and configuration files.

### Available Scripts
```bash
# Run all checks
npm run check-all

# Run individual checks
npm run post-commit    # Validation checks
npm run update-docs    # Update documentation
npm run update-configs # Update configurations
```

### What Gets Automated

#### Post-Commit Checks
- **Contract changes detection** using file hashing
- **Documentation consistency** validation
- **Configuration synchronization** verification
- **Spec compliance** checking
- **Security compliance** validation

#### Documentation Updates
- **Interface documentation** (`specs/001-build-a-simple/contracts/interface-documentation.md`)
- **Quickstart guide** (`specs/001-build-a-simple/quickstart.md`)
- **README.md** updates
- **Removes deprecated functions** from docs
- **Adds new features** documentation

#### Configuration Synchronization
- **Contract ABIs** in frontend and deployment artifacts
- **Contract addresses** across all config files
- **VRF configuration** updates
- **Network settings** synchronization

### Git Hooks
- **Post-commit hook**: Runs validation after every commit
- **Pre-commit hook**: Runs tests before allowing commits (via husky)

### Manual Usage
```bash
# Run post-commit checks manually
node scripts/post-commit-check.js

# Update documentation after contract changes
node scripts/update-docs.js

# Synchronize configurations
node scripts/update-configs.js
```

## 🚀 Deployment

### Manual Deploy + Post-commit Sync
This workflow outlines the steps for deploying a new contract version and ensuring all related configurations and documentation are synchronized.

1. **Build New Contract**:
   ```bash
   forge build
   ```

2. **Deploy New Contract**:
   ```bash
    cd contracts
    set -a; source .env; set +a
    forge script script/Deploy.s.sol --rpc-url $SEPOLIA_RPC_URL --broadcast --verify
   ```

3. **Update Source-of-Truth Addresses File**:
   - Manually edit `deploy/artifacts/addresses.json` with the new contract address under the correct `chainId` (e.g., `11155111` for Sepolia).
   - MANUALLY UPDATE 'contracts/.env'
   - MANUALLY ADD CONSUMER to subscription on vrf.chain.link
   - Example structure:
     ```json
     {
       "11155111": {
         "PepedawnRaffle": "0xNEW_CONTRACT_ADDRESS"
       }
     }
     ```

4. **Synchronize Configurations and Documentation**:
   - Run the automation script to update all dependent files:
     ```bash
     cd ..
     npm run update-configs
     npm run update-docs
     ```
   - manually update .env file if not done above

5. **Commit Changes (Triggers Post-Commit Validation)**:
   - Stage the updated files:
     ```bash
     git add deploy/artifacts/addresses.json frontend/public/deploy/artifacts/addresses.json frontend/src/contract-config.js README.md
     ```
   - Commit with a descriptive message:
     ```bash
     git commit -m "Deploy PepedawnRaffle vX.Y on Sepolia and sync configs/docs"
     ```
   - The post-commit hook will then automatically validate:
     - `deploy/artifacts/addresses.json` is present and contains a non-placeholder address.
     - `frontend/public/deploy/artifacts/addresses.json` is synchronized.
     - `frontend/src/contract-config.js` has the correct address and ABI.
     - Documentation and spec consistency checks pass.

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
- **Dynamic Gas Estimation**: Prevents VRF callback failures

## 🔗 Contract Interaction

### Using Remix IDE
1. **Compile contract** in Remix with Solidity 0.8.20+ (project uses 0.8.20)
2. **Connect to deployed contract** using address: `0x3b8cB41b97a4F736F95D1b7d62D101F7a0cd251A`
3. **Create and open round**:
   ```solidity
   createRound()    // Create new round
   openRound(1)     // Open round 1 for betting
   ```

### Using Cast (Command Line)
```bash
# Check contract state
cast call 0x3b8cB41b97a4F736F95D1b7d62D101F7a0cd251A "currentRoundId()" --rpc-url $SEPOLIA_RPC_URL

# Create round (owner only)
cast send 0x3b8cB41b97a4F736F95D1b7d62D101F7a0cd251A "createRound()" --private-key $PRIVATE_KEY --rpc-url $SEPOLIA_RPC_URL
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
- **Contract Address**: `0x3b8cB41b97a4F736F95D1b7d62D101F7a0cd251A` (VRF v2.5)
- **Network**: Sepolia (Chain ID: 11155111)
- **Frontend**: pepedawn.art (deployment configured via GitHub Actions)

## 📚 Project Specifications

The project follows comprehensive specifications in `specs/001-build-a-simple/`:

- **spec.md**: Business requirements and user stories
- **plan.md**: Technical implementation plan
- **research.md**: Technology decisions and rationale
- **data-model.md**: Entity definitions and relationships
- **contracts/**: API specifications and interfaces
- **quickstart.md**: Development setup guide

### Key Features from Specs
- **2-week betting rounds** with ETH wagers
- **Puzzle proof submissions** for +40% weight multiplier
- **Chainlink VRF v2.5** for verifiable randomness
- **Emblem Vault integration** for prize distribution
- **Dynamic gas estimation** for VRF callbacks
- **Comprehensive security** following Constitution v1.1.0

## 🤝 Contributing

1. **Fork the repository**
2. **Create feature branch**: `git checkout -b feature/amazing-feature`
3. **Run tests**: `cd contracts && forge test`
4. **Commit changes**: `git commit -m 'Add amazing feature'`
5. **Push to branch**: `git push origin feature/amazing-feature`
6. **Open Pull Request**

## 🔗 Links

- **Live Application**: pepedawn.art
- **Contract on Etherscan**: [View on Sepolia Etherscan](https://sepolia.etherscan.io/address/0x3b8cB41b97a4F736F95D1b7d62D101F7a0cd251A)
- **Chainlink VRF**: [Sepolia VRF Coordinator](https://sepolia.etherscan.io/address/0x8103B0A8A00be2DDC778e6e7eaa21791Cd364625)

## 📄 License

This project is licensed under the MIT License - see the LICENSE file for details.

---

**Built with ❤️ for the Pepedawn community**