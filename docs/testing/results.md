# Verification results — 2026-11-05
Working development environment: Ubuntu 24.04 under WSL2, Linux filesystem /home/chenhy/projects/b2-amm. A delivery mirror is kept under D:/appspace/web3prepare/b2-amm. Foundry root is the project directory itself.

## Frozen protocol
Protocol files match commit 271b387b90432c72126d0db1f28c36fe83d39126. Source checksums are recorded in evidence/source-freeze.json. Supplementary regression/deployment tooling changes do not alter these protocol files. Final executable-suite and campaign records remain separately identifiable.

## Observed checks
| Gate | Status | Evidence |
|---|---|---|
| WSL / Foundry config / exact 0.8.28 build | PASS | forge-config.txt, test-final.log |
| Frozen baseline suite | PASS | 33 unit/fuzz + 128-vector differential test + one group of 7 invariants = 35 reported passed, 0 failed |
| Optional default fork test | SKIP / NOT RUN | no configured RPC |
| Actual mainnet fork attempt | BLOCKED | fork-attempt.log: connection reset before chain ID retrieval |
| 30-minute changing-seed campaign | PASS | 1806.37 seconds; 77 completed rounds; 2310000 unit fuzz cases; 630784 handler calls |
| Core branch coverage >=90% | PASS | core-coverage.json: 36/37 = 97.30%; 161/163 lines; 23/23 functions |
| Six compiler configurations | PASS comparison / 3 expected build FAIL | optimizer-matrix.json; non-IR stack-too-deep recorded |
| Slither scan + manual dispositions | PASS reviewed / raw alerts present | 18 findings; raw tool exit 255, not a clean scan |
| Aderyn scan | PASS reviewed / low alerts present | 0 High categories, 4 Low categories after SafeCast |
| Local add/swap/full exit transactions | PASS | local-deployment.json: all receipts successful, user LP=0, remaining supply=1000 |
| Python exact reference | PASS | reference-model.json: 10,000 cases, 128 vectors, seed 20261105 |
| Requested OZ 5.0.2 install | BLOCKED | network reset; actual cached 5.4.0 version deviation documented |
| Upstream provenance / machine dependency advisory audit | BLOCKED | content integrity lock is not authenticity proof |
| Patched compiler release gate | BLOCKED | compiler-review.md; 0.8.38 manifest download reset |
| Remote GitHub CI | NOT RUN | workflow supplied, no remote publication |
| Public testnet / frontend swap / source verification | NOT RUN | not included or authorized in current contract milestone |
| Echidna / formal verification / transient comparison | NOT RUN | no claim of execution |

Coverage uses --ir-minimum because the non-IR build exceeds stack limits. Foundry warns this can make source mappings inaccurate; numbers are instrumented evidence with that limitation, not proof of all branch paths. The core gate excludes test helper and deployment script coverage explicitly.

## Commands
forge config; forge test -vv; python3 scripts/campaign.py; forge coverage --ir-minimum --report summary --report lcov; python3 scripts/coverage_gate.py evidence/lcov.info; python3 scripts/optimizer_matrix.py; slither . --filter-paths "lib/|test/|script/" --json evidence/slither-final.json; aderyn . --output evidence/aderyn-final.json; python3 scripts/local_smoke.py; python3 scripts/reference_model.py --check.
Scripts preserve per-command logs and exits. Initial failures are retained rather than overwritten into fictitious successful runs.

## Learning report
Material delivered: economic derivation, architecture/state/attack diagrams, statement-group walkthrough, traces/debug commands, test explanations and interview exercises. **Learning Mastery Gate: NOT RUN** until the user independently explains/executes exercises; AI-generated documentation does not demonstrate mastery.

## Final aggregate
Final default suite: **37 PASS, 0 FAIL, 1 explicit fork SKIP**: 34 unit/fuzz, quote differential, LP differential, one group containing 7 invariant properties. Baseline changing-seed campaign ran the 35-test frozen suite; the extra underpayment and LP-model tests were added separately. The protocol source and compiler configuration are unchanged, verified by source-freeze hashes.
Local CI profile: 36 PASS / 0 FAIL / 1 fork SKIP, 512 runs x depth256 / 131,072 handler calls, seed 0xc120261105. LP reference vectors were additionally executed under default profile. This is local CI-profile execution, not a remote Actions run.
Three targeted mutants killed; independent rebuild full bytes match; gas snapshot generation/check, actual full local flow and internal links verified separately in evidence logs. Public release remains BLOCKED as documented.
