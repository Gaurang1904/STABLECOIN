# Decentralized Stablecoin Design

## 1. Relative Stability
- Target: Anchored/Pegged ≈ **$1.00**
- Price Oracle: **Chainlink price feed**
- Conversion Function:  
  - Exchange **ETH & BTC → USD equivalent**

## 2. Stability Mechanism (Minting)
- Type: **Algorithmic & Decentralized**
- Rules:
  - Users can only mint stablecoins if they provide **sufficient collateral**
  - Collateralization ratio enforced via smart contracts

## 3. Collateral
- **Exogenous (Crypto-based)**
- Accepted assets:
  - `wETH` (Wrapped Ether)  
  - `wBTC` (Wrapped Bitcoin)

---

### Summary
This stablecoin is designed to maintain relative price stability around $1 using on-chain oracles and over-collateralized crypto assets. Minting is algorithmically controlled, ensuring only properly collateralized positions can issue new tokens.
