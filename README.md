# Decentralized Stablecoin

[![CI](https://github.com/Gaurang1904/STABLECOIN/actions/workflows/test.yml/badge.svg)](https://github.com/Gaurang1904/STABLECOIN/actions/workflows/test.yml)

This repository contains a Foundry implementation of an overcollateralized, crypto-backed stablecoin system. The protocol lets users deposit approved collateral and mint `DSC`, a dollar-pegged ERC20 token, as long as their position remains safely collateralized.

The design is inspired by MakerDAO/DAI, but intentionally smaller in scope:

- No governance
- No stability fees
- No protocol-owned treasury
- Collateral limited to WETH and WBTC
- Chainlink price feeds for USD valuation

> This project is educational and unaudited. It is not production-ready.

## How It Works

The system has two main contracts:

### `DecentralizedStableCoin`

`DecentralizedStableCoin` is the ERC20 token contract for `DSC`.

- Implements minting and burning.
- Uses ownership to restrict mint and burn permissions.
- Ownership is transferred to the engine during deployment so only the engine can control supply.

### `DSCEngine`

`DSCEngine` contains the protocol logic.

- Accepts approved collateral tokens.
- Tracks collateral deposited by each user.
- Tracks DSC minted by each user.
- Uses Chainlink price feeds to convert collateral amounts into USD value.
- Enforces a minimum health factor before minting, redeeming, or liquidating.
- Allows liquidation of undercollateralized positions.

## Stability Model

The stablecoin is designed around three core assumptions.

### 1. Relative Stability

`DSC` is intended to track 1 USD.

Collateral is priced through Chainlink USD price feeds. The engine uses those prices to determine how much DSC a user can safely mint against their collateral.

### 2. Overcollateralized Minting

Users can only mint DSC after depositing collateral. The protocol requires positions to remain overcollateralized.

The active engine uses:

- `LIQUIDATION_THRESHOLD = 50`
- `LIQUIDATION_PRECISION = 100`
- `MIN_HEALTH_FACTOR = 1e18`
- `LIQUIDATION_BONUS = 10`

In practice, this means a user must keep enough collateral value backing their minted DSC. If the collateral value drops too far, the position can be liquidated.

### 3. Exogenous Collateral

The accepted collateral assets are external crypto assets:

- WETH
- WBTC

The protocol does not use endogenous collateral or algorithmic expansion/contraction to maintain the peg.

## Repository Structure

```text
src/
  DecentralizedStableCoin.sol   ERC20 stablecoin token
  DSCEngine.sol                 Core collateral, mint, redeem, burn, and liquidation logic
  DSCEngine1.sol                Commented reference/older implementation

script/
  DeployDSC.s.sol               Deployment script
  HelperConfig.s.sol            Local and Sepolia network configuration

test/
  unit/                         Unit tests
  fuzz/                         Fuzz/invariant test scaffolding
  mocks/                        Chainlink price feed mock

.github/workflows/
  test.yml                      Foundry CI workflow
```

## Requirements

- [Foundry](https://book.getfoundry.sh/getting-started/installation)
- Git

## Setup

Clone the repository and install submodules:

```bash
git clone https://github.com/Gaurang1904/STABLECOIN.git
cd STABLECOIN
git submodule update --init --recursive
```

Build the contracts:

```bash
forge build
```

Run the test suite:

```bash
forge test
```

Check formatting:

```bash
forge fmt --check
```

## Local Deployment

Start a local Anvil chain:

```bash
anvil
```

Deploy the protocol locally:

```bash
forge script script/DeployDSC.s.sol --rpc-url http://127.0.0.1:8545 --broadcast
```

For local deployments, `HelperConfig` creates mock price feeds and mock ERC20 collateral tokens.

## Sepolia Deployment

Create a `.env` file with your deployer private key:

```bash
PRIVATE_KEY=your_private_key
SEPOLIA_RPC_URL=your_rpc_url
```

Then deploy:

```bash
source .env
forge script script/DeployDSC.s.sol --rpc-url $SEPOLIA_RPC_URL --broadcast --verify
```

Never commit private keys or funded wallet secrets.

## Testing Notes

The current unit tests cover:

- Constructor validation
- USD price conversion
- Token amount conversion from USD
- Collateral deposit behavior
- Minting behavior
- Basic redeem behavior
- Health factor reverts for unsafe minting

The fuzz and invariant test files are currently scaffolds and should be expanded before treating the system as security-reviewed.

## Known Limitations

- The contracts are not audited.
- Oracle staleness checks are not implemented in the active engine.
- Only WETH and WBTC collateral are configured.
- Liquidation and invariant coverage should be expanded.
- This project is intended for learning and experimentation, not production deployment.

## License

This project is licensed under the MIT License.
