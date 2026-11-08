# Private beta to public portfolio

## User decision — 2026-11-05
Keep the demonstration website owner-private first. Refine it for approximately two to three months before considering public access. This is an intended development window, not a scheduled automatic publication. Public testnet contracts, balances, events and transactions remain observable. Private hosting does not make blockchain activity private.

## Stage 1: establish a reproducible private demonstration
- Complete local contract and economic security checks against the release source.
- Obtain test ETH through a genuinely available faucet; no paid subscription is required by the AMM.
- Deploy and verify contracts on Base Sepolia after release preflight passes.
- Deploy the web application with owner-only access and verify wallet connection, claims, liquidity provision, swap and liquidity withdrawal.
- Record addresses, receipts, compiler configuration and source verification without storing signing secrets.

## Stage 2: refine for two to three months
- First month: complete transaction failure handling, precision and approval UX, responsive browser acceptance, current static/manual review and protocol walkthroughs.
- Second month: repeat economic attack simulations, stateful invariant campaigns, fork compatibility checks and deployment/recovery rehearsals; link each finding to its regression evidence.
- Optional third month: improve interview explanations and independent review coverage, resolve material findings, reproduce the project from a clean checkout and run the complete acceptance flow.

These are review milestones, not evidence of completed work. Record PASS, FAIL, BLOCKED, NOT RUN or N/A per gate.

## Public-release decision
Public access requires a fresh review of engineering and economic security evidence, known limitations, wallet flows, explorer links and documentation. Do not change hosting access automatically when the time window elapses. No mainnet deployment or real-value asset use is included.
