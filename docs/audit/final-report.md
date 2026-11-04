# AI-Assisted Self-Assessment — B2 AMM
## Scope freeze
Protocol source and baseline executable tests are frozen at commit 271b387b90432c72126d0db1f28c36fe83d39126. Later documentation/evidence commits do not alter the protocol source tree.
In scope: src/Factory.sol, src/Pair.sol, src/Router.sol and executable reproduction tests. Out of scope: lending, frontend, public infrastructure and a full third-party library audit.
Compiler 0.8.28 / Cancun / optimizer 1000 / viaIR true; OZ 5.4.0 and forge-std 1.14.0 are content-locked. No privileged protocol roles exist; honest token balances and supported transfer semantics remain assumptions.

## Method
Manual review of protocol functions, arithmetic, permissions, token flow, lock coverage, inherited permit and event paths; deterministic attacks; fuzz; two-actor handler/ghost ledger; independent rational model; Slither 0.11.6 and Aderyn 0.6.8. Raw results: evidence/slither-final.json, evidence/aderyn-final.json. See testing/results.md for executed gates. Bounded tests are not a formal proof.

## Findings
| ID | Severity / classification | Decision |
|---|---|---|
| B2-L01 | Low: dust exit liveness | Accepted and documented; zero rounded output reverts atomically with LP ownership preserved. |
| B2-I01 | Informational: dependency provenance | 5.0.2 download blocked; cached 5.4.0 integrity locked, upstream authenticity unverified. Public release gate blocked. |
| B2-Q01 | Test-model defect | Unconditional end-of-campaign exit was an invalid dust assumption; explicit regression and model boundary added. |

### B2-L01 — tiny positions cannot redeem under a skewed reserve ratio
Affected: Pair.burn / Router.removeLiquidity. Preconditions: LP claim rounds to zero in at least one asset. Root cause: intentional floor rounding and rejection of either zero output. Impact: temporary/indefinite illiquidity of dust; no demonstrated extraction from another user.
PoC: forge test --match-test testDustLPExitIsAtomic -vvvv. It skews reserves, transfers one raw LP unit to a second account, attempts exit, and checks rollback preserves LP and no LP is stranded at Pair.
Recommendation: document minimum economic size; aggregate LP or wait for a redeemable ratio. Fix review: regression and afterInvariant handle the explicit boundary; burn semantics retained. Residual risk: dust is illiquid.

### B2-Q01 chronology and uncertainty
The first unseeded run emitted InsufficientLiquidity while testing invariant_claimsAreSolvent. It was interrupted during expensive shrinking; its exact failing seed/sequence was not recovered. A seeded diagnostic passed. The deterministic dust PoC demonstrates an unsound unconditional exit assumption and motivated explicit dust handling plus positive-mint preconditions.
This is not a claim to have reproduced the exact original unseeded failure. Initial logs are preserved. Acceptance runs record fixed/changing seeds; failures were not removed to obtain a pass.

## Every static category reviewed — no detectors disabled
- Slither reentrancy-balance (High): router compares actual receipt deltas intentionally. Router lock prevents nested workflows and Pair lock prevents nested reserve mutators. Token-hook test demonstrates both write/read locks. Dishonest/rebasing token behavior remains excluded.
- reentrancy-no-eth / benign: swap deliberately calls before reserve storage updates. All five asset/reserve mutators share the lock; guarded snapshots reject transient reads. Flash repayment/non-repayment and cross-function reentry have executable tests.
- divide-before-multiply: Q112 quantization precedes time weighting by definition; error <1 Q112 unit per second per term. Multiplying before division may exceed 256-bit bounds.
- incorrect-equality: zero amount/supply/reserve checks are validity/state predicates, not assumptions about externally donated ETH.
- unused-return: nominal burn amounts are deliberately replaced by actual recipient deltas; router does not use timestamp because its quote is not an oracle freshness attestation.
- timestamp: elapsed seconds are the accumulator's unit. Intentional uint32 modulo wrap is tested; consumer intervals must remain <2^32 seconds.
- Initial Aderyn unsafe-casting High: explicit balance bounds already dominated writes; SafeCast added as defense in depth. Final scan shows zero High issue categories; this was not a demonstrated exploitable High finding.
- Aderyn low numeric/literal issues: immutable fee/Q112 formula terms. State-change/event issues: skim has token Transfer events without reserve writes; router warnings concern inherited guard state, while Pair emits business events. Unchecked burn return is intentionally ignored.

## Decision and residual risk
No unresolved real Critical/High exploit was identified within the stated local scope. This is not production release approval. Fork, public deployment, upstream provenance and actual remote CI remain separate gates. Echidna and transient-guard fork parity are NOT RUN. Three targeted mutations were subsequently executed and killed; see evidence/mutations.json. Public donation capture, first-LP manipulation, MEV, token issuer controls and downstream oracle misuse remain documented risks.

## Compiler release risk found during final review
See compiler-review.md: SOL-2026-7 cannot be excluded for optimized IR in 0.8.28. No project-specific exploit is asserted; public deployment is BLOCKED until a patched compiler is authenticated and all gates rerun. The High transient-clearing compiler issue does not apply to our storage-only guard design.

Read-only guard boundary: it applies while a Pair entrypoint holds its lock. A Router incoming-token transfer occurs before Pair entry, so a token hook at that point may read old reserves alongside changed external balances. Downstream contracts must not treat this as universal read-only-reentrancy protection or combine arbitrary balance/LP reads into a safe oracle. No downstream lending/pricing consumer is included.
