# Engineering and learning report
## Delivered module
Factory / Pair / Router, ERC20 LP permit, fixed 30-bps fee, optimistic flash callback, public skim/sync, guarded reserve/current cumulative access, raw cumulative prices. No owner, fee switch, upgrade or rescue. Borrowing is out of scope.
Files: src/*.sol, test/*.t.sol and test/fork, scripts/, script/, documentation, version/content lock and CI workflow.

## Actual engineering evidence
Commands, counts, gas, coverage, blocked gates and initial failures are in testing/results.md and evidence/. Local transactions perform complete add/swap/full-exit workflow. Security report is AI-assisted self-assessment. Public release is explicitly blocked by compiler/provenance/network gates, not implied by local success.

## Learning model
- Business: LPs provide both assets and bear inventory/price risk; swap fees accrue to reserve value, not a separate reward balance.
- Source: Factory identifies pools; Pair owns accounting; Router enforces transaction-level user intent; Handler models sequences and ghost history.
- Math: fee-adjusted product -> floor maximum output; sqrt bootstrap and min-proportional LP issuance; floor redemption and ceil same-asset flash fee.
- Execution: transfer -> infer input -> product validation -> reconcile; atomic EVM revert restores failed external effects.
- Security: locks allow optimistic composition while preventing nested reserve mutation; honest token semantics remain a trust boundary.
- Testing: unit/negative/fuzz -> multi-actor stateful invariants -> independent vectors -> mutations -> local receipts. Fork is blocked, not a pass.

## Important correction to the proposed invariants
LP supply is not numerically equal to total assets across two tokens with independent decimals. Verify complete supply accounting, pro-rata claim solvency and independent asset conservation instead. Global k must not be monotonic across burns; assert it specifically across swaps and include fee-adjusted amounts. Locked minimum/dust means user rights must be expressed in raw-unit and rounding terms.

## Mastery acceptance
Documentation material: delivered. Personal explanation, autonomous debugging, derivation and exercise execution: NOT RUN. Use source walkthrough and interview-defense.md, explain who can break each handler assumption, then independently reproduce traces.
