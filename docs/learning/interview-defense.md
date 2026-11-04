# Interview defense and exercises
1. Why does k not stay constant? The 0.3% fee remains in pool; rounding can also increase k. Burns reduce k, so a global monotonic invariant would be wrong.
2. Who breaks the handler invariant most easily? A malicious/rebasing token invalidates the honest-balance model; an exit breaks naive global k monotonicity. A donation breaks reserve=balance until reconciled.
3. Why ghost variables? Recomputing expected balances from current reserves merely restates implementation. Ghost inflow/outflow ledgers model historical accounting.
4. Why round against caller? Mint/output/burn floor protects existing LPs from cumulative overissuance/overpayment. Flash repayment ceil ensures sufficient fee.
5. Why lock LP? Raises the cost of donation inflation; does not guarantee fairness at arbitrary manipulated prices.
6. Is cumulative price a safe oracle? No: needs observation window, liquidity, freshness, timestamp wrap discipline and sequencer/deviation policy.
7. What can flash loans attack? Reserve-based spot consumers, unguarded callbacks and external accounting. The AMM accepts temporary output only if fee-adjusted k is restored.
8. Why permit tests? Replay domain includes chain/contract and incrementing nonce; reuse must fail.
9. How debug? Run forge test --match-test testFlashRepaymentAndLocks -vvvv, inspect token transfer -> callback -> rejected nested sync -> repayment -> Sync.
10. Exercise: deliberately replace 997 with 1000; predict which differential tests fail. Deliberately remove callback repayment; explain revert.
11. Exercise: explain each handler selector, the ghost update and boundary assumptions without reading this answer.
Learning mastery remains NOT RUN until the user independently explains/runs exercises. AI-generated material is not evidence of personal mastery.
