# Source walkthrough
Protocol source frozen at commit 271b387b90432c72126d0db1f28c36fe83d39126. Line references below refer to that commit. Inspect exact statements with git show COMMIT:src/Pair.sol followed by nl -ba.

## Module map and runtime
Factory defines pool identity; Pair defines custody, claims and product enforcement; Router defines user intent and atomic workflows; Handler maintains independent expected flows; Python specifies exact rational pricing. No borrowing or price-feed consumer exists.

## Factory.sol
| Lines | What / why / state / security |
|---|---|
| 8–12 | Errors, bidirectional lookup, list and event. No admin slot or fee setter. |
| 15–18 | Reject identical, zero and code-less token addresses. Code presence does not prove honest ERC20 behavior. |
| 19–21 | Sort once, reject duplicate, CREATE2 deploy with token-derived salt. Address also depends on factory and constructor-bearing initcode. |
| 22–25 | Store both lookup directions, append exactly once, emit after construction. |
| 28–29 | Expose enumeration length without unbounded traversal. |

Tests: testFactory, testPairConstructorValidation, testRouterCreatesPairAndReverseAdd. Alternative owner-approved listings would constrain assets but introduce privileged policy; rejected for this scope.

## Pair.sol: statement groups
| Lines | What / why / how / security |
|---|---|
| 4–10 | Reuse OZ ERC20/permit, transfers, math and storage guard. Inherited correctness is not this project's audit certification. |
| 12–14 | Callback carries original caller and both outputs. Callback implementer must authenticate msg.sender itself. |
| 29–37 | Lock 1000 raw LP units; immutable identities; uint112 reserves; uint32 time and uint256 cumulative prices. |
| 51–55 | Validate sorted deployed tokens; initialize ERC20 name and EIP-712 permit domain. |
| 58–60 | Guard snapshot reads against observing a token-transfer/flash-callback intermediate state. |
| 64–68 | Copy last cumulative values and truncate time deliberately modulo 2^32. No storage is written. |
| 69–75 | Modular elapsed time; skip zero reserves; add floor Q112 ratio times elapsed seconds. unchecked is limited to defined wrapping. |
| 79–84 | Lock; validate recipient; read bounded balances; infer deposited deltas from old reserves; read total LP supply. |
| 85–89 | Initial issuance floor sqrt(a0*a1), require unlocked positive shares, mint permanent minimum. Product fits 224 bits. |
| 90–94 | Later issuance min(floor(a0*S/r0),floor(a1*S/r1)); reject zero, mint to recipient. This prevents overissuance. |
| 95–96 | Accrue old reserve price before replacing reserves; emit funded amounts. |
| 100–104 | Burn LP previously transferred to Pair. Separate transactions are unsafe because burn is public. |
| 105–108 | Floor pro-rata current-balance claims; reject either zero; destroy LP before transfers. Dust rejection is explicit. |
| 109–113 | SafeERC20 optional-return transfer; reread pool balances; update and emit. Nominal transfer is not recipient net receipt. |
| 117–120 | Lock and validate recipient, nonzero outputs, strict reserve bounds. |
| 121–123 | Optimistic transfers then optional callback. Flash composability intentionally requires interaction before final reserve accounting. |
| 124–127 | Reread bounded balances; infer positive input above old reserve minus output; reject no repayment. |
| 128–130 | Enforce (1000*b0-3*in0)*(1000*b1-3*in1)>=10^6*r0*r1. Products fit below 2^244. |
| 131–132 | Store only after invariant enforcement and emit actual flows. Failed checks atomically revert transfers/callback effects. |
| 136–140 | Public skim removes surplus without reserve writes. Donation ownership is not tracked. Negative rebase may underflow/revert. |
| 143–145 | Public sync realizes donation gains or unsupported issuer losses into reserves. |
| 148–155 | Read lock check and recipient restrictions. LP transfers/permits do not mutate reserves and remain callable. |
| 158–161 | Honest external balance reads plus uint112 cap dominate product-sensitive math. |
| 164–172 | Accumulate old prices for elapsed time; intentional time/cumulative wrapping, no persistent transient storage. |
| 173–176 | SafeCast bounded balances; write timestamp; emit Sync. |

Tests: initial/mint/maximum-reserve boundaries, burn-all/LP fuzz exit, dust rollback, both swap directions, fee/product fuzz, flash callback/no repayment, token hook lock, tax/no-return/failure, donation/skim/sync, negative rebase and TWAP wrap. Alternative custom LP/permit adds unnecessary signature risk; alternative concentrated liquidity requires a different state machine.

## Router.sol
| Lines | What / why / state / security |
|---|---|
| 14–28 | Errors, immutable factory and inclusive deadline. Lock precedes external calls. |
| 32–38 | Validate raw input/reserve units; 997 input fee factor; floor mulDiv quote; strictly bounded output. |
| 52–61 | Resolve/create canonical pair, align reserves to caller order, choose proportional desired amounts; reject one-sided synced pools. |
| 63–70 | Require positive amounts and user minima; snapshot and transfer caller-approved assets; reject taxed deposit deltas atomically. |
| 72 | Mint in same transaction so there is no inter-transaction skim window. |
| 85–90 | Resolve Pair; snapshot net recipient holdings; move caller LP atomically; burn. |
| 91–93 | Check actual recipient deltas, deliberately ignoring nominal burn return. Protects minimums with inclusive output taxes. |
| 106–114 | Reject bad recipient, align reserves, transfer input, measure actual pool increase. Existing donation is not credited as caller input. |
| 115–118 | Select correct output side, execute swap, enforce actual minOut. minOut=0 leaves price risk with caller. |
| 121–134 | Reject absent pair; align reserves; reject invalid generic recipients. |

Tests: amount bounds, missing pairs, forward/reverse amounts, ratio selection, unsupported taxed deposit, tax-aware exit minima, deadlines, minOut rollback and token failure. Alternatives exact-output/multihop/native ETH add review surface and are outside current milestone.

## Formula derivation
For one-sided input d and output o, require (1000*x+997*d)*(y-o)>=1000*x*y. Rearrange o<=997*d*y/(1000*x+997*d). Integer floor is maximal safe output; ceil would violate the inequality for some inputs.
For unchanged supply S, fee growth increases sqrt(k)/S. Deposits/withdrawals change both S and k, so global k monotonicity is invalid.
Burn liability l/S of balances uses floor; sum of users' rounded claims cannot exceed assets if sum of LP is bounded by supply.
Flash same-asset repayment is ceil(1000*borrowed/997); the callback test implements numerator+996 before integer division.

## Actual trace and debugging
Run forge test --match-test testSwapAndFee -vvvv. A 10^16 input transfers first; router computes the rational floor; Pair transfers output, infers input, checks adjusted k, stores reserves and emits Sync/Swap.
Run testFlashRepaymentAndLocks at -vvvv: optimistic output -> ammCall -> rejected getReserves and sync -> ceil repayment -> invariant -> update.
Run testFlashNoRepay: callback returns without payment -> InsufficientInput -> output transfer reverted.
Evidence: ../../evidence/test-final.log and campaign logs; deterministic -vvvv reproduction commands are included for interactive inspection.

## Handler and independent model
Handler.swap records pre-k, mints bounded actor input, executes actual swap, updates ghost inflow/outflow and checks both raw and fee-adjusted products. deposit selects two LP recipients; exit selects an actor and uses that actor's approval; donate either reconciles or skims and updates the ledger only for retained assets. Time advance syncs without creating assets.
Properties compare ghost accounting to token balances, complete holder supply to totalSupply and pro-rata claims to reserves. Expected dust outcomes are explicit, not generic catch-and-ignore.
Python Fraction uses arbitrary precision integers to derive 128 Solidity quote vectors and checks 10,000 monotonic/tight-rounding cases. JS floating point is not used.

## Understanding gate
Explain each selector and its easiest adversary, derive the product inequality, trace rollback, and explain why raw spot reserves cannot secure a lending vault. See ../learning/interview-defense.md for exercises and answers. Personal mastery remains NOT RUN until independently demonstrated.

## Supplemental independent LP vectors
LPReference.t.sol compares initial square-root issuance, subsequent min-proportional issuance and pro-rata burn against scripts/lp_reference_model.py (Python arbitrary-precision integers). Sixteen vectors execute real Pair transitions; 10,000 model cases check integer bounds. testFlashPrincipalOnlyRepaymentRejected separately proves that returning principal without the 0.3% fee fails the product constraint. Protocol source remains identical to the frozen commit.
