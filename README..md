# FairShare: Decentralized Content Royalty Distribution Platform

FairShare is a blockchain-based smart contract platform that revolutionizes how content creators manage and distribute royalties among collaborators. Built on the Stacks blockchain, it provides a transparent, automated, and secure system for handling content ownership and revenue sharing.

## Features

### 🔐 Secure Content Registration
- Register content with unique identifiers and verifiable ownership
- Immutable record of content metadata and stakeholder information
- Support for various content types (music, art, writing, etc.)

### 💰 Automated Royalty Distribution
- Trustless distribution of earnings based on predefined shares
- Configurable platform fee (currently 2%)
- Minimum deposit threshold to optimize gas costs
- Real-time balance tracking and claiming system

### 👥 Multi-Signature Governance
- Collaborative decision-making for royalty structure changes
- Required minimum approvals for modifications (default: 2 approvals)
- Time-bound proposals (24-hour expiry)
- Protection against duplicate approvals

### 📊 Transparent Tracking
- On-chain recording of all transactions and changes
- Real-time visibility of earnings and distributions
- Complete audit trail of stakeholder modifications

## Technical Architecture

### Constants
```clarity
MIN-DEPOSIT: u1000
MAX-STAKEHOLDERS: u10
REQUIRED-APPROVALS: u2
PLATFORM-FEE: 2%
```

### Data Structures
- Content Registry: Stores content metadata and status
- Stakeholder Shares: Manages ownership percentages and claims
- Earnings Pool: Tracks revenue and distributions
- Proposal System: Handles multi-signature requests

## Getting Started

### Prerequisites
- [Clarinet](https://github.com/hirosystems/clarinet) for local development
- [Stacks Wallet](https://www.hiro.so/wallet) for deployment and interaction
- STX tokens for contract deployment and transactions

### Installation

1. Clone the repository
```bash
git clone https://github.com/your-org/fairshare
cd fairshare
```

2. Install dependencies
```bash
clarinet requirements
```

3. Run tests
```bash
clarinet test
```

### Contract Deployment

1. Build the contract
```bash
clarinet build
```

2. Deploy using Clarinet console
```bash
clarinet console
```

## Usage Guide

### Registering Content
```clarity
(contract-call? .fairshare register-content 
    u1 
    "My Amazing Song"
)
```

### Adding Stakeholders
```clarity
(contract-call? .fairshare propose-share-change
    u1                  ;; content-id
    'ST1PQHQKV0RJXZFY1DGX8MNSNYVE3VGZJSRTPGZGM  ;; stakeholder
    u25                 ;; 25% share
)
```

### Depositing Earnings
```clarity
(contract-call? .fairshare deposit-earnings
    u1                  ;; content-id
    u1000000           ;; amount in µSTX
)
```

### Claiming Earnings
```clarity
(contract-call? .fairshare claim-earnings
    u1                  ;; content-id
)
```

## Security Considerations

- All functions include input validation
- Multi-signature requirement for critical changes
- Time-locked proposals
- Protected against common attack vectors
- Arithmetic overflow protection

## Error Codes

| Code | Description |
|------|-------------|
| u100 | Not authorized |
| u101 | Invalid percentage |
| u102 | Already registered |
| u103 | Not found |
| u104 | Too many stakeholders |
| u105 | Invalid amount |
| u106 | Total share exceeded |
| u107 | Zero amount |
| u108 | Duplicate stakeholder |
| u109 | Already approved |
| u110 | Insufficient approvals |
| u111 | Proposal expired |
| u112 | Invalid title |
| u113 | Invalid content ID |

## Contributing

1. Fork the repository
2. Create your feature branch (`git checkout -b feature/AmazingFeature`)
3. Commit your changes (`git commit -m 'Add some AmazingFeature'`)
4. Push to the branch (`git push origin feature/AmazingFeature`)
5. Open a Pull Request


## Future Roadmap

- [ ] NFT integration for content ownership
- [ ] Oracle integration for external revenue data
- [ ] Enhanced governance features
- [ ] Multiple currency support
- [ ] Advanced analytics dashboard
- [ ] Cross-chain compatibility


## Acknowledgements

- Stacks Foundation
- Clarity Language Team
- Open source contributors

---

*Built with ❤️ for content creators worldwide*