# Bonded NFT Escrow System

A comprehensive smart contract system for bonded NFT escrow with staking, governance, and adjudication mechanisms built on Polygon.

## Overview

This system enables content creators to issue bonds that fans can post against, creating a trustless escrow mechanism with built-in leak detection and adjudication. The system includes:

- **Bond Issuance**: Content creators define bond terms (asset type, amount, duration, quantity)
- **Bond Posting**: Users post bonds and receive NFT certificates
- **Escrow & Staking**: Posted assets are held in escrow and automatically staked for rewards
- **Governance**: Multi-signature governance wallet for adjudication decisions
- **Leak Detection**: Watermark-based leak detection with adjudication process
- **Affiliate Program**: Referral rewards for bond posting

## Architecture

### Core Contracts

1. **BondEscrow.sol** - Main escrow contract coordinating all operations
2. **BondedNFT.sol** - ERC721 NFT contract for bond certificates
3. **StakingPool.sol** - Staking mechanism for escrowed assets
4. **GovernanceWallet.sol** - Multi-signature governance for adjudication
5. **MockERC20.sol** - Test token for development

### Workflow

1. **Bond Issuance**: Creator specifies bond terms
2. **Bond Posting**: User posts bond amount, receives NFT
3. **Escrow & Staking**: Assets held in escrow, automatically staked
4. **Adjudication**: Governance can adjudicate leaks and redistribute funds
5. **Expiry**: If no leak, assets return to NFT holder

## Features

- ✅ Multi-contract architecture with clear separation of concerns
- ✅ ERC721 NFT certificates for bond ownership
- ✅ Automatic staking with configurable reward rates
- ✅ Multi-signature governance for adjudication
- ✅ Affiliate/referral program
- ✅ Time-based bond expiry
- ✅ Comprehensive test suite
- ✅ Gas-optimized for Polygon deployment

## Installation

```bash
npm install
```

## Configuration

1. Copy `.env.example` to `.env`
2. Fill in your private key and RPC URLs
3. Get API keys for block explorers

## Compilation

```bash
npm run compile
```

## Testing

```bash
npm run test
```

## Deployment

### Local Development
```bash
# Start local node
npm run node

# Deploy to local network
npm run deploy-local
```

### Polygon Mainnet
```bash
npm run deploy
```

## Contract Addresses

After deployment, contract addresses will be displayed in the console and can be used for frontend integration.

## Usage Examples

### Issue a Bond
```javascript
await bondEscrow.issueBond(
  "video",              // asset type
  ethers.parseEther("100"), // bond amount
  86400,                // duration (1 day)
  10                    // quantity
);
```

### Post a Bond
```javascript
await mockToken.approve(bondEscrowAddress, ethers.parseEther("100"));
await bondEscrow.postBond(0, affiliateAddress);
```

### Create Adjudication Proposal
```javascript
await governanceWallet.createAdjudicationProposal(
  0,                    // bond ID
  "Leak evidence: watermark detected"
);
```

## Security Features

- **ReentrancyGuard**: Protection against reentrancy attacks
- **Access Control**: Role-based permissions for governance
- **Time Locks**: Voting periods for governance decisions
- **Safe Transfers**: Proper ERC20 transfer handling

## Fee Structure

- **Governance Fee**: 5% of staking rewards (configurable)
- **Affiliate Fee**: 2% of bond amount (configurable)
- **Maximum Limits**: Built-in caps to prevent excessive fees

## Testing Coverage

The test suite covers:
- Bond issuance and posting
- NFT minting and transfers
- Staking and reward calculations
- Governance voting and execution
- Affiliate fee distribution
- Bond expiry and claims
- Leak adjudication process

## Gas Optimization

- Efficient storage patterns
- Batch operations where possible
- Optimized for Polygon's low gas costs
- Minimal external calls

## Future Enhancements

- Cross-chain functionality
- Advanced staking strategies
- Automated leak detection integration
- Enhanced governance mechanisms
- Mobile-friendly interfaces

## License

MIT License - see LICENSE file for details.