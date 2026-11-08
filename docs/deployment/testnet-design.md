# Public testnet design
Target chain is Base Sepolia 84532. Bootstrap also runs on local 31337; mainnet deployment of the faucet/initializer is rejected in code.
Factory/Pair/Router keep their existing permissionless design. The deployer has no administrative privilege over them.
Two synthetic 18-decimal faucet tokens B2A/B2B are deployed, each permitting 1000 units per address per hour with a one-billion-unit cap. The cap and interval are immutable, no mint admin exists, and Sybil resistance is not claimed. These are valueless test assets, not representations of ETH/USD.
The deployer claims the same allotment as everyone else, approves exactly 100 units of each token and creates a 100:100 initial pool. The initial price is a demonstration ratio, not a financial quote.
Post-deployment acceptance uses a distinct user flow to add/swap/remove user LP while bootstrap liquidity remains available. An independent full-exit test is retained locally.
Public deployment must use an authenticated patched compiler and a new audit/test freeze. The previous 0.8.28 evidence cannot approve the new release.
