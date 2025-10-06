# CarbonX

**CarbonX** is a decentralized platform built on the VeChainThor blockchain that facilitates the issuance, trading, and retirement of carbon credits. The platform leverages blockchain technology to ensure transparency, traceability, and trust in carbon credit management.

## Overview

This platform allows users and companies to:

* **Issue** carbon credits on-chain backed by verified certifications
* **Trade** carbon credits through a secure peer-to-peer marketplace
* **Retire** carbon credits with immutable proof of offset
* **Verify** complete credit history and metadata transparency

All carbon credit data and transactions are recorded immutably on the VeChainThor blockchain.

## Features

*  On-chain carbon credit issuance with validator signature verification (ERC-191)
*  Tokenized carbon credits as NFTs (ERC721-based)
*  Secure retirement (burning) of credits with permanent proof
*  Transparent credit metadata including project details, methodology, vintage, and expiry
*  Decentralized marketplace with escrow-based trading
*  Multi-standard support (Verra, Gold Standard, CDM, ACR, CAR)

## Deployed Contracts (VeChainThor Testnet)

| Contract | Address |
|----------|---------|
| **Registrar** | `0xfC7B85607799cD66539Ee0B6Db698832c50315A5` |
| **CarbonX Token** | `0x1441069D3738Ca796d89151d669601c9c9279368` |
| **Marketplace** | `0x49247328bd0b3293E7b04f96F00F66Fa699FCACd` |

**Testnet Validator:** `0xccce847Adf23167A61aF51f6cd793a8e1cB98C9B`

## Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                    REGISTRAR CONTRACT                        │
│  Central authority for credit lifecycle management          │
│                                                              │
│  ✓ Issues credits with validator signatures                 │
│  ✓ Manages validator whitelist (owner-controlled)           │
│  ✓ Stores comprehensive on-chain metadata                   │
│  ✓ Handles credit retirement (burning)                      │
│  ✓ Expiry tracking and validation                           │
│  ✓ ERC-191 signature verification                           │
│  ✓ Replay attack protection (consumed digest mapping)       │
└────────────────┬────────────────────────────────────────────┘
                 │ owns & controls
                 ▼
┌─────────────────────────────────────────────────────────────┐
│                    CARBONX TOKEN (ERC721)                    │
│  NFT representation of carbon credits                       │
│                                                              │
│  ✓ Standard-compliant ERC721 implementation                 │
│  ✓ Transferable, tradeable tokens                           │
│  ✓ Access-controlled minting (Registrar only)               │
│  ✓ Access-controlled burning (Registrar only)               │
│  ✓ Dynamic tokenURI with base64-encoded metadata            │
│  ✓ Full ownership and approval functionality                │
└─────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────┐
│                    MARKETPLACE CONTRACT                      │
│  Decentralized exchange for peer-to-peer trading            │
│                                                              │
│  ✓ Escrow-based listing system                              │
│  ✓ VET-denominated pricing                                  │
│  ✓ Expiry timestamps for time-limited offers                │
│  ✓ Update listing parameters                                │
│  ✓ Cancel and refund mechanisms                             │
│  ✓ Overpayment refund handling                              │
│  ✓ Reentrancy protection                                    │
└─────────────────────────────────────────────────────────────┘
```

## Smart Contract Overview

### Registrar
Central registry managing the complete lifecycle of carbon credits.

**Key Functions:**
- `issue()` - Mint new credits with validator signature
- `retire()` - Burn credits with permanent retirement proof
- `getMetadata()` - Retrieve full credit information
- `addValidator()` / `removeValidator()` - Manage validator whitelist

### CarbonX Token (ERC721)
Standard NFT implementation with custom metadata.

**Key Functions:**
- `mint()` / `burn()` - Controlled by Registrar only
- `transferFrom()` - Standard ERC721 transfers
- `tokenURI()` - Returns base64-encoded metadata

### Marketplace
Decentralized exchange with escrow mechanism.

**Key Functions:**
- `list()` - Create listings with price and expiry
- `fulfill()` - Purchase listed credits
- `update()` - Modify listing parameters
- `cancel()` - Remove listing and return credit

## Getting Started

### Prerequisites

- [Foundry](https://book.getfoundry.sh/getting-started/installation)

### Installation

```bash
# Clone repository
git clone https://github.com/traverne/CarbonX-MVP.git
cd CarbonX-MVP

# Install Foundry dependencies
cd contracts
forge install

# Run tests
forge test

# Run with verbosity
forge test -vvv

# Generate gas report
forge test --gas-report

# Check coverage
forge coverage
```

### Test Coverage

See detailed coverage report: [`.coverage`](./.coverage)

**Summary:**
- **Registrar.sol**: Comprehensive coverage of issuance, retirement, and validator management
- **CarbonX.sol**: Full ERC721 functionality tested
- **Marketplace.sol**: Listing, fulfillment, and cancellation flows covered

### Gas Snapshot

See gas consumption metrics: [`.snapshot`](./.gas-snapshot)

**Optimized for:**
- Efficient struct packing
- Minimal storage operations
- Gas-efficient ERC721 (Solmate library)

## Project Structure

```
CarbonX/
│   ├── src/
│   │   ├── Registrar.sol      # Core credit registry
│   │   ├── CarbonX.sol         # ERC721 token
│   │   └── Marketplace.sol     # Trading platform
│   ├── test/
│   │   ├── Registrar.t.sol     # 60+ tests
│   │   ├── CarbonX.t.sol       # 50+ tests
│   │   └── Marketplace.t.sol   # 80+ tests
```

## Development

### Running Tests

```bash
# All tests
forge test

# Specific contract
forge test --match-contract RegistrarTest

# Specific test
forge test --match-test test_Issue

# With gas reporting
forge test --gas-report

# With coverage
forge coverage --report lcov
```

## Security

- Reentrancy guards on all state-changing functions
- ERC-191 signature verification with replay protection
- Access control (Owned pattern)
- Comprehensive test coverage (100+ tests)
- Gas optimization audits

## Roadmap

- [x] Core smart contracts
- [x] Unit tests & coverage
- [x] Testnet deployment
- [x] Validator service
- [x] Basic frontend (issuance + dashboard)
- [ ] Marketplace UI integration
- [ ] Credit retirement interface
- [ ] Real-world certificate verification
- [ ] Mainnet launch
- [ ] B3TR rewards integration (For future versions)
- [ ] Integrate AI (For future versions)

## License

MIT License - see [LICENSE](LICENSE) file for details

## Contact

- **Website**: [carbonx-vechain.vercel.app]

**Built on VeChainThor for a sustainable future**
