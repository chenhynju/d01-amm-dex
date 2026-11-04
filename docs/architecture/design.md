# Architecture and state
Factory sorts token addresses, rejects missing code, creates each unique pair with CREATE2 and registers both directions. Pair inherits OZ ERC20, ERC20Permit and storage ReentrancyGuard. Router is stateless apart from an immutable factory, has its own lock and never retains intended user balances.

## State transitions
Mint: observe balances -> compute incremental assets -> floor LP issuance -> lock initial 1000 units -> update cumulative prices using old reserves -> store new reserves.
Swap: lock -> validate outputs -> optimistic transfers -> optional callback -> observe balances -> infer input -> enforce fee-adjusted product -> accumulate/store -> unlock.
Burn: compute floor claims using actual balances -> destroy LP -> transfer assets -> observe/store.
Sync: accumulate old price up to current timestamp -> reconcile balances.
Skim: transfer only excess balances; preserve reserves.

Asset custody and enforcement live in Pair; slippage, deadlines and atomic transfer workflows live in Router. Pair APIs are public building blocks. Never send tokens/LP to pair in a separate transaction: anyone can consume them via mint/burn/swap/skim.

## Trust
Token balanceOf and transfer semantics must be honest. Inclusive transfer-fee swaps are measured, no-return ERC20 calls are wrapped by SafeERC20. Fee-on-transfer liquidity addition is rejected. Rebases, blacklist/freeze, sender-extra fees and malicious tokens are not economically safe assets.
No oracle integration consumes spot reserves. Guarded getReserves/currentCumulativePrices reject reads during asset movement. Public LP supply/balance and raw historical cumulative getters remain readable: downstream protocols must not combine them with transient token balances as an oracle.

Read-only guard boundary: it applies while a Pair entrypoint holds its lock. A Router incoming-token transfer occurs before Pair entry, so a token hook at that point may read old reserves alongside changed external balances. Downstream contracts must not treat this as universal read-only-reentrancy protection or combine arbitrary balance/LP reads into a safe oracle. No downstream lending/pricing consumer is included.
