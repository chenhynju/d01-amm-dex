# Economic security assessment
**AI-Assisted Self-Assessment.** Scope: fixed-fee constant-product AMM under honest supported token semantics; no lending/debt/interest/liquidation.

PASS within measured bounds: exact fee-adjusted product enforcement, independent rational quote comparison, floor issuance/redemption, callback repayment rejection, asset/supply ghost accounting, bounded quote monotonicity, net-receipt slippage and atomic user LP exit. See actual results and seed/campaign records.

These are executable bounded properties, not universally proven invariants for arbitrary tokens or external markets. Algebra derives the quote from the product constraint; uint112 bounds contain intermediate arithmetic. The Python model gives exact integer/rational checks, not market simulation.

Assumptions: honest ERC20 balances; no rebase, sender-extra fee or issuer freeze; correct caller-supplied minima/deadline; users understand raw units; no downstream reliance on spot prices. Inclusive transfer fees are tested with a deterministic mock, not every real token implementation.
Residual economic risks: impermanent loss, external market jumps, low-liquidity manipulation, sandwiches, donation/front-running griefing, initial LP price setting, dust lock and arbitrary token behavior. Locked minimum raises inflation cost, not a blanket protection proof.
No rewards/issuance budgets, debt solvency, liquidation safety, interest monotonicity or L2 oracle fallback applies (N/A). The seven AMM properties replace inappropriate lending-specific invariants rather than pretending to verify them.

Public release remains BLOCKED by compiler and dependency provenance gates and unexecuted network validation; this does not erase locally observed properties.
