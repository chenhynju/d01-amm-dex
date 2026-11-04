# AMM scope
The current request is the AMM subset of B2. Lending, liquidation, interest indices and debt are out of scope. Deliver a permissionless factory, constant-product pair, ERC20 LP with EIP-2612 permit, ERC20 router, public skim/sync, flash callbacks and cumulative prices. Fixed 0.3% LP fee. No admin or protocol fee.

Single-hop exact-input token swaps, liquidity deposits and exits are supported. Native ETH wrapping, multihop routing, exact-output swaps and a production frontend are outside this contract-first milestone. Public Base Sepolia broadcasting is blocked pending explicit authorization and funding; no chain evidence is implied.

The user's later request to finish implementation and audit supersedes the first-session skeleton stop in root AGENTS.md. The root instructions continue to govern testing, evidence and public actions.

Initial requested OpenZeppelin 5.0.2 install failed due network connection resets. Temporarily vendored 5.4.0 from local cache; dependencies are content locked. This is a declared baseline deviation, not evidence of the requested install succeeding.
