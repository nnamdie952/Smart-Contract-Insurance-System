# Smart Contract Insurance System

A comprehensive decentralized insurance platform built on Stacks blockchain using Clarity smart contracts.

## System Overview

This insurance system consists of five interconnected smart contracts that automate the entire insurance lifecycle:

### Core Contracts

1. **Policy Customization Contract** (`policy-customization.clar`)
    - Creates tailored coverage terms
    - Manages policy parameters and conditions
    - Handles policy lifecycle management

2. **Risk Assessment Contract** (`risk-assessment.clar`)
    - Calculates premiums based on risk data
    - Automated risk scoring algorithms
    - Dynamic premium adjustments

3. **Claim Validation Contract** (`claim-validation.clar`)
    - Verifies loss events through oracle data
    - Validates claim authenticity
    - Manages claim processing workflow

4. **Automatic Payout Contract** (`automatic-payout.clar`)
    - Triggers payments when conditions are met
    - Handles escrow and fund management
    - Automated settlement processing

5. **Fraud Prevention Contract** (`fraud-prevention.clar`)
    - Detects suspicious claim patterns
    - Implements fraud scoring mechanisms
    - Maintains blacklist and risk indicators

## Features

- **Decentralized**: No central authority required
- **Transparent**: All operations recorded on blockchain
- **Automated**: Smart contract execution reduces manual intervention
- **Customizable**: Flexible policy terms and conditions
- **Secure**: Built-in fraud prevention and validation

## Architecture

The contracts work together in a coordinated fashion:
- Policy creation triggers risk assessment
- Claims are validated before payout processing
- Fraud prevention runs continuously across all operations
- Automatic payouts execute when all conditions are satisfied

## Getting Started

### Prerequisites
- Clarinet CLI installed
- Node.js and npm
- Stacks wallet for testing

### Installation

\`\`\`bash
git clone <repository-url>
cd clarity-insurance-system
npm install
\`\`\`

### Testing

\`\`\`bash
npm test
\`\`\`

### Deployment

\`\`\`bash
clarinet deploy
\`\`\`

## Contract Interactions

### Creating a Policy
1. Call `create-policy` on policy-customization contract
2. System automatically assesses risk and calculates premium
3. Policy becomes active upon premium payment

### Filing a Claim
1. Submit claim through claim-validation contract
2. Oracle data verification occurs automatically
3. Fraud prevention screening runs in parallel
4. Approved claims trigger automatic payout

## Security Considerations

- All contracts include comprehensive error handling
- Input validation prevents malicious data
- Fraud prevention monitors all transactions
- Multi-signature requirements for high-value operations

## Testing

Comprehensive test suite covers:
- Policy creation and management
- Risk assessment calculations
- Claim validation workflows
- Payout mechanisms
- Fraud detection scenarios

## Contributing

Please read our contributing guidelines and submit pull requests for any improvements.

## License

MIT License - see LICENSE file for details.
