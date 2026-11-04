# Attack scenarios
- Flash swap without repayment: local actor receives output and returns without input; transaction reverts. Fee-paying flash swap succeeds; composition is legitimate.
- Cross-function reentry: callback tries sync while swap lock is active; must fail. Read-only reserve access also fails.
- Donation theft: surplus sent in a separate transaction can be skimmed by anyone. Intentional API semantics, not a private deposit. Router transfers and uses funds atomically.
- First LP/donation inflation: lock minimum supply and floor issuance. High manipulated prices or tiny deposits can revert/donate dust; user sets amount minima and uses trusted market context.
- Sandwich/MEV: minOut and deadline bound acceptance, not ordering fairness. No claim of MEV resistance.
- Taxed tokens: swaps measure actual receipt; liquidity deposit rejects transfer tax; exit minima check recipient receipt.
- Negative rebase: stored balances can exceed actual balances, skim reverts until sync; sync realizes LP loss. Not a supported asset model.
- Reserve overflow: syncing balances above uint112 reverts; public skim may remove surplus. Arbitrary token minting can still cause denial of service.
- Stale/manipulated cumulative prices: only primitives supplied; downstream lending integration must not treat them as a safe oracle.
