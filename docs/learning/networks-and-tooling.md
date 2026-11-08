# Networks and tooling learning map

This is a project-specific learning priority, not an industry market-share ranking. DApp describes an application architecture, DeFi financial mechanisms, and DAO governance. They can use the same chain.

| Ecosystem | Mainnet | Application testnet | Project learning priority |
|---|---|---|---|
| Ethereum | Ethereum | Sepolia | EVM baseline, standards, security and real-state fork tests |
| Base | Base (8453) | Base Sepolia (84532) | Current AMM deployment and wallet workflow |
| Arbitrum | Arbitrum One (42161) | Arbitrum Sepolia (421614) | Later EVM portability and rollup assumptions |
| Optimism | OP Mainnet | OP Sepolia | Later OP Stack, sequencer and bridge analysis |
| Solana | Mainnet Beta | Devnet | Separate Rust/Anchor/account-model track |

Ethereum Hoodi targets validator/staking testing. Solana Testnet primarily serves validator/network testing; Devnet is appropriate for applications.

## Current project route
Anvil local chain -> Ethereum mainnet fork compatibility tests -> Base Sepolia deployment -> owner-private web demonstration -> public portfolio after review. Public-testnet transactions remain public even with private web hosting.

A chain, RPC provider, faucet, explorer and web host are separate services. This AMM does not require a Coinbase exchange account, CDP subscription or thirdweb subscription. Faucet eligibility must be checked through the actual authenticated flow.

## Skills to demonstrate
1. Chain ID, RPC methods, explorers and separate network balances.
2. Nonce, gas, approval scope, simulation, signing, reverts and receipts.
3. Reproducible build, runtime bytecode and source verification.
4. Claims, liquidity provision, swaps, withdrawals and event/accounting reconciliation.
5. Sequencer availability, finality, bridge trust and RPC failure handling.
6. Distinguish local tests, real-state forks and public-testnet execution evidence.

## Primary references
- [Ethereum networks](https://ethereum.org/developers/docs/networks/)
- [Base connections](https://docs.base.org/get-started/connect-to-base)
- [Base test funds](https://docs.base.org/get-started/get-funds)
- [Arbitrum network reference](https://docs.arbitrum.io/arbitrum-essentials/reference/node-providers)
- [Optimism RPC providers](https://docs.optimism.io/app-developers/reference/rpc-providers)
- [Solana clusters](https://solana.com/docs/references/clusters)
- [Optimism faucets](https://docs.optimism.io/app-developers/tools-sdks/faucets)
- [Optimism faucet UI](https://console.optimism.io/faucet)

Learning material is not proof of personal mastery.
