# Compiler known-bug review — release BLOCKED
Reviewed 2026-11-05 against the official [version map](https://raw.githubusercontent.com/ethereum/solidity/develop/docs/bugs_by_version.json) and [bug descriptions](https://raw.githubusercontent.com/ethereum/solidity/develop/docs/bugs.json).

The mandated example compiler, Solidity 0.8.28, is not current. Local 0.8.38 is absent and its official binary-manifest download failed (connection reset). Do not mistake local passing tests for removal of known compiler risk.

| Issue listed for 0.8.28 | Scope assessment |
|---|---|
| SOL-2026-7 Yul optimizer stale bookkeeping | **BLOCKED**: optimized IR can be affected even without custom assembly; we cannot prove this bytecode unaffected. Fixed in 0.8.38. No project-specific exploit is claimed. |
| SOL-2026-6 named parameters in require custom errors | No such source construct used; standalone revert is unaffected by this issue. |
| SOL-2026-5 memory bytes element delete | viaIR selected; no such delete used. |
| SOL-2026-4 / SOL-2026-2 mutual recursion spill bugs | No internal mutually recursive call graph in protocol. External callbacks are separate EVM calls, not that compiler mechanism. |
| SOL-2026-1 transient clearing collision (High upstream severity) | Neither transient variables nor transient guard used in protocol; not a demonstrated High finding in this project. |
| SOL-2025-1 lost storage-array write on slot overflow | No user-controlled unbounded storage array index/length; factory only appends pairs. Full formal exclusion not claimed. |

Release alternatives: (1) restore authenticated downloads, lock 0.8.38 or a subsequently reviewed patched version, rebuild and rerun every gate; (2) retain this explicitly local educational baseline with public release blocked. No unverified optimizer workaround is asserted safe.
Existing 0.8.28 gas, coverage and campaign results remain observations about precisely that compiler/configuration.
