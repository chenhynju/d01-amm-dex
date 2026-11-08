# B2 AMM
A reviewable constant-product exchange demonstrating how assets, LP shares and adversarial callbacks move through a protocol state machine.
Current testnet release: Base Sepolia contracts are deployed and Sourcify exact-match verified. [Addresses, receipts and runtime checks](deployments/base-sepolia-20261108.json). Hosted acceptance remains pending.

[Current self-assessment and release gates](docs/audit/review-2026-11-08.md) · [WSL source policy](docs/deployment/workspace-workflow.md)

This milestone implements the AMM portion of B2: factory, pair, ERC20 router, permit-enabled LP token, skim/sync, flash swaps and cumulative prices. Lending is separate. Security review is an **AI-Assisted Self-Assessment**, not an independent audit or production assurance.

**Release acceptance: PARTIAL.** The current WSL implementation uses Solidity 0.8.38 and an authenticated OZ 5.0.2 dependency snapshot, and includes a Next.js wallet UI. Historical compiler warnings and measurements below belong to the earlier baseline; the dated review distinguishes current results from unexecuted deployment gates. See [workspace workflow](docs/deployment/workspace-workflow.md).

## Quick start
Use Ubuntu/WSL2, Python 3 and the recorded Foundry 1.8.1 / Solidity 0.8.38 toolchain. Vendored dependencies make source checkout self-contained; the exact compiler must already be installed or downloadable. Run from this directory, the Foundry root.

~~~bash
forge --version
python3 scripts/dependencies.py
forge test
forge test --match-contract AMMInvariant -vv
python3 scripts/reference_model.py --check
~~~

The latest measured aggregate is [evidence/summary.json](evidence/summary.json); the security release gate remains separate.

The repository archive is `chenhynju/d01-amm-dex`; visibility and remote CI status are tracked separately. The commands above require no signing secrets. The optional fork test explicitly skips unless MAINNET_RPC_URL is set.

~~~bash
python3 scripts/campaign.py
forge coverage --ir-minimum --report summary --report lcov
forge snapshot --match-contract AMMTest --check
python3 scripts/local_smoke.py
~~~

The campaign runs for at least 30 minutes after compilation, with changing recorded seeds. Local smoke broadcasts actual transactions to ephemeral Anvil and checks receipts and balances. [Measured results and gates](docs/testing/results.md) distinguish PASS from blocked/not-run checks.

## Architecture
~~~mermaid
flowchart LR
    U[User and ERC20 approvals] --> R[Router: deadlines and receipt minima]
    R --> F[Factory: unique CREATE2 registry]
    F --> P[Pair: reserves and LP ERC20 permit]
    R --> P
    P --> T0[Token 0]
    P --> T1[Token 1]
    P --> C[Optional flash callback]
    C --> P
    P --> O[Guarded cumulative-price primitives]
~~~

[Architecture / HLD / LLD](docs/architecture/design.md) · [Factory](src/Factory.sol) · [Pair](src/Pair.sol) · [Router](src/Router.sol)

## Protocol mechanics and state
A swap charges 3/1000 of inferred input and enforces the fee-adjusted product. Fees stay with LPs; no protocol fee or administrator exists. Initial supply is floor(sqrt(amount0 * amount1)); 1000 raw LP units are permanently locked. Later mint/burn round down. All formulas operate in raw token units.

The router supports single-hop exact-input ERC20 swaps and proportional liquidity operations. Inclusive transfer-fee swaps and no-return ERC20 transfers are supported. Taxed deposits revert; exit minima check actual user receipt. Rebasing, issuer freezes, dishonest balances and sender-extra fees are outside the supported asset model.

~~~mermaid
stateDiagram-v2
    [*] --> Empty
    Empty --> Active: first mint and minimum LP lock
    Active --> Locked: mint / burn / swap / skim / sync
    Locked --> Callback: optimistic flash output
    Callback --> Locked: repayment
    Locked --> Active: validate and reconcile
    Locked --> Active: revert restores prior state
    Active --> Active: LP transfer / approve / permit
~~~

## Security model and attack surface
Pair and Router use OZ storage locks. Guarded reserve/current-cumulative reads reject transient callback reads. Historical cumulative getters and LP balances remain readable; consumers must not combine these with transient external token balances as an oracle.

~~~mermaid
flowchart TD
    A[Adversary] --> X[Flash output and callback]
    A --> T[Tax / rebase / token hooks]
    A --> D[Donation / initial LP / rounding]
    A --> M[Ordering / sandwich]
    X --> K[Adjusted product and locks]
    T --> B[SafeERC20 and actual deltas]
    D --> L[Minimum liquidity and floor accounting]
    M --> S[Minima and deadline]
    K --> R[Residual risks and integration assumptions]
    B --> R
    L --> R
    S --> R
~~~

Seven stateful properties cover fee-adjusted k, ghost assets, reconciled reserves, complete LP supply, locked minimum, claim solvency and quote monotonicity. End-of-campaign exits distinguish redeemable claims from sub-unit dust. Direct transfers are public surplus; funding and mint/burn/swap must be atomic.

## Evidence navigation
- [Requirements](docs/requirements/scope.md), [architecture and design](docs/architecture/design.md)
- [Unit / negative / fuzz / attack tests](test/AMM.t.sol), [handler and invariants](test/Invariant.t.sol)
- [Python rational reference](scripts/reference_model.py), [quote vectors](test/Differential.t.sol), [LP integer model](scripts/lp_reference_model.py) and [LP vectors](test/LPReference.t.sol)
- [Economic model](docs/economics/economic-model.md), [properties](docs/economics/invariants.md), [attack scenarios](docs/economics/attack-scenarios.md), [simulation report](docs/economics/simulation-report.md), [economic assessment](docs/economics/economic-security-assessment.md)
- [Security assessment and dispositions](docs/audit/final-report.md)
- [Compiler / gas benchmarks](docs/testing/benchmarks.md), [deployment records](docs/deployment/README.md)
- [Source walkthrough](docs/code-walkthrough/README.md), [interview defense](docs/learning/interview-defense.md), [ADRs](docs/adr/0001-mechanics.md)

## Limitations
The current WSL source includes a static-exported Next.js wallet UI and a chain-locked Base Sepolia deployment script with synthetic faucet assets. This does not imply that a public deployment or browser business acceptance has completed. Archive-fork execution requires reachable historical RPC. Vendored OpenZeppelin 5.0.2 and forge-std are locked by file hashes; run the dependency checker from this checkout. Historical tool outputs are preserved and must not be interpreted as acceptance of later source changes.

Minimum LP is permanent; dust may not redeem until both outputs are positive. Slippage limits bound accepted execution but do not prevent MEV or attest a fair initial price. Cumulative prices are not a complete oracle. No upgrade/rescue authority exists to recover unsupported/frozen token assets.

## Engineering contributions
Protocol-specific contracts, tests, mathematical model and documents were authored with AI assistance. OZ supplies ERC20, signatures, math and guard primitives; Foundry supplies execution/testing. The constant-product design follows [Uniswap V2 mechanics](https://docs.uniswap.org/whitepaper.pdf); this project does not claim to invent that model or reimplement the underlying signature libraries.

Remaining release work: current end-to-end browser and chain settlement, reachable archive-fork execution, funded Base Sepolia deployment, source verification and hosted acceptance. Lending is maintained separately as D02. Personal mastery requires independent explanation and exercises.
