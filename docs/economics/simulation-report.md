# Simulation report
This is a local on-chain state-machine simulation with deterministic mock tokens, two active LP recipients and an initial LP holder. It is not an empirical market study or a profitability forecast.

Executed action space: bounded forward/reverse swaps, proportional deposits, partial/full exits, donation->skim, donation->sync, and time advances. A ghost ledger tracks retained asset inflows/outflows; separate properties check supply, reserve reconciliation, solvency, minimum lock, adjusted k and monotonic quotes.

Default bounds: fuzz=1024 cases per fuzz function, invariant=128 runs/depth64; changing-seed campaign uses 10,000 cases per fuzz function. CI profile is 10,000 fuzz and invariant512/depth256. Exact completed counts, seeds and statuses are recorded in evidence/campaign.json, per-round logs and evidence/ci-profile-local.log; see ../testing/results.md for final aggregation.
A deterministic action counter table in each log demonstrates exercised handler selectors. Some deliberately tiny actions return before state change if they cannot mint/redeem a raw unit; this is explicit domain handling, not swallowing arbitrary errors.

Attacks executed: no-repay flash output, principal-only flash repayment, cross-function/write/read callback reentry, taxed inputs/outputs, no-return transfer, failing token, negative rebase behavior, reserve overflow and donation capture. Three deliberate isolated mutations were killed: zero flash fee, no swap lock and zero router fee. Mutation testing is targeted, not an exhaustive mutation score.

Independent models: Python Fraction quote model (10,000 checks/128 Solidity vectors), Python integer LP model (10,000 checks/16 initial-mint, incremental-mint and redemption vectors). Both avoid floating point.

Limitations: no live market/MEV agent, rational-arbitrage equilibrium, real flash-loan provider, archive-fork state or Base deployment. Mock token behavior is not proof for arbitrary ERC20 issuers. Exact initial unseeded failure was not recovered; later explicit boundaries and recorded-seed results are described in the audit report.

## Completed campaign aggregate
1806.37 seconds, 77 completed rounds, 2310000 unit fuzz cases, 630784 handler calls. All rounds exited zero; exact seed range 0x2f2c8f4610 through 0x2f2c8f465c is enumerated in campaign.json. Additional CI profile completed 131,072 calls with zero revert. These are bounded simulation observations, not formal proof.
