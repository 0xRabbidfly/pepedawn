# Research: PEPEDAWN betting site with VRF draws and Emblem Vault prizes

**Feature**: 001-build-a-simple  
**Date**: 2025-10-06  
**Status**: Complete

## Research Findings

### Frontend Technology Stack

**Decision**: Vite MPA (Multi-Page Application) with vanilla JavaScript + ethers.js v6  
**Rationale**: 
- Minimal JS bundle size requirement (<= 100KB) favors vanilla JS over frameworks
- Vite provides fast development and optimized builds
- ethers.js v6 is the standard for Ethereum wallet integration
- MPA approach suits the 3-page structure (title, main, rules)

**Alternatives considered**: 
- React/Vue: Rejected due to bundle size overhead
- Web3.js: Rejected in favor of ethers.js for better TypeScript support and smaller size
- SPA: Rejected as MPA better suits distinct page purposes

### Smart Contract Architecture

**Decision**: Single Solidity 0.8.19 contract with Chainlink VRF v2/v2.5 integration  
**Rationale**:
- Solidity 0.8.19 provides built-in overflow protection
- Single contract reduces deployment complexity and gas costs
- Chainlink VRF is the industry standard for verifiable randomness
- Existing codebase already implements this pattern

**Alternatives considered**:
- Multiple contracts: Rejected for simplicity in this phase
- VRF v1: Rejected as v2/v2.5 provides better gas efficiency
- Custom randomness: Rejected due to security and verifiability requirements

### Testing Strategy

**Decision**: Foundry for contract testing, minimal browser testing for frontend  
**Rationale**:
- Foundry provides comprehensive Solidity testing (unit, invariant, scenario)
- Fast execution and gas reporting
- Existing test suite already established
- Browser testing kept minimal due to wallet integration complexity

**Alternatives considered**:
- Hardhat: Rejected as Foundry already established in project
- Extensive E2E testing: Deferred due to wallet connection complexity

### Deployment and Hosting

**Decision**: Static site hosting for frontend, Ethereum mainnet/testnet for contracts  
**Rationale**:
- Frontend is static HTML/JS/CSS, suitable for CDN hosting
- No backend server required (all state on-chain)
- Ethereum provides the required security and decentralization

**Alternatives considered**:
- Full-stack hosting: Unnecessary complexity for static frontend
- L2 networks: Rejected per constitutional requirement (Ethereum-only)

### Audio/Animation Implementation

**Decision**: HTML5 audio with user interaction trigger, CSS animations  
**Rationale**:
- Browser autoplay policies require user interaction
- CSS animations are lightweight and performant
- Graceful degradation when audio assets not provided

**Alternatives considered**:
- WebGL/Three.js: Rejected due to bundle size constraints
- Autoplay audio: Rejected due to browser policies

### Security Considerations

**Decision**: Implement all constitutional security requirements from v1.1.0  
**Rationale**:
- Constitution v1.1.0 mandates specific security patterns
- Recent security audit findings must be addressed
- Reentrancy protection, access control, input validation required

**Key security patterns to implement**:
- Reentrancy guards on external calls
- Checks-effects-interactions pattern
- Secure ownership transfer (2-step process)
- Emergency pause functionality
- Input validation for all external parameters
- Duplicate winner prevention
- VRF manipulation protection

### Performance Targets

**Decision**: 
- Frontend bundle: <= 100KB gzipped
- Wallet connection: < 2 seconds
- Transaction confirmation: Standard Ethereum block times
- Leaderboard updates: Real-time via events

**Rationale**: Based on spec requirements and user experience expectations

## Technical Decisions Summary

| Component | Technology | Rationale |
|-----------|------------|-----------|
| Frontend Framework | Vite MPA + Vanilla JS | Bundle size, simplicity |
| Web3 Library | ethers.js v6 | Standard, lightweight |
| Smart Contracts | Solidity 0.8.19 | Security, existing codebase |
| Randomness | Chainlink VRF v2/v2.5 | Verifiable, constitutional requirement |
| Testing | Foundry | Comprehensive, fast |
| Hosting | Static site hosting | No backend needed |
| Audio | HTML5 with user trigger | Browser policy compliance |
| Security | Constitutional v1.1.0 patterns | Audit compliance |

## Implementation Notes

- Existing codebase structure already aligns with research decisions
- Security patterns need to be added/enhanced per constitution v1.1.0
- Audio assets marked as [TO_BE_PROVIDED] in spec
- VRF configuration already established in deploy/artifacts/
- Frontend bundle currently at 99.26KB (within target)

## Next Steps

Proceed to Phase 1 design artifacts:
- data-model.md: Entity definitions and relationships
- contracts/: API contracts and interfaces  
- quickstart.md: Development setup and testing guide