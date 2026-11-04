# Deployment records
Run python3 scripts/local_smoke.py for ephemeral Anvil on port 18545, chain 31337. It broadcasts Factory/Router/demo tokens, adds liquidity, swaps, verifies every receipt status, pair code and recipient balance, then stops its own Anvil. DemoToken is unrestricted local-only support.

Actual evidence: ../../evidence/local-deployment.json and local-deploy.log. These local addresses are not public explorer evidence.

## Public preflight — NOT RUN
No public signature, transaction, paid operation or publishing was authorized or attempted.
Before a separate Base Sepolia release: resolve dependency provenance and all release gates; freeze source; verify chain ID 84532 and current EVM compatibility; review wallet public address, funds, constructors, token identities and code sizes. With explicit authorization, use script/Deploy.s.sol and an external signer, never a raw key in source. Record receipts, blocks, gas, code/source verification and post-deployment add/swap/remove checks.
Frontend, public source verification and public testnet/mainnet success are not implied by local deployment.
