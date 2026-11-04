# Executable economic properties
1. Swap-only product never decreases: recorded pre/post k per handler swap; ghost sticky failure flag. Liquidity burns are allowed to decrease k.
2. Fee-adjusted product: Pair swap check and rational reference vectors enforce the exact 997/1000 inequality.
3. Ghost asset conservation: independently update inflow/outflow ledgers; compare to actual pool token balances after every handler action.
4. Reserve reconciliation: stored reserves equal balances at completed handler transaction boundaries. Direct donations between actions are an explicit exception.
5. LP supply: equals initial holder + handler + permanently locked holder; only these holders exist in campaign.
6. Locked minimum: balance(address(1))=1000; supply>=1000.
7. Solvency: aggregate floor-rounded user claims never exceed reserves.
8. Quote monotonicity/bounded output: higher input cannot reduce output, output<reserve.
9. Exit liveness: afterInvariant burns every remaining handler LP; dedicated fuzz checks proportional deposit/exit round trip.

These are bounded executable checks, not a formal proof. Adversarial reentrancy, malicious token failures and flash repayment are separately tested. Lending collateral/health factor/liquidation/rate properties are N/A.
