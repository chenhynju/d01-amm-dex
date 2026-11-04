#!/usr/bin/env python3
"""Read-only release gate; passing local tests never implies public deployment authorization."""
from pathlib import Path
import json,hashlib
root=Path(__file__).resolve().parents[1]
freeze=json.loads((root/"evidence/source-freeze.json").read_text())
match=all(hashlib.sha256((root/f).read_bytes()).hexdigest()==digest for f,digest in freeze["files"].items())
gates={"frozen_protocol_source":"PASS" if match else "FAIL",
       "patched_compiler_known_bug_review":"BLOCKED",
       "authenticated_dependency_baseline":"BLOCKED",
       "mainnet_fork_execution":"BLOCKED",
       "public_network_authorization":"NOT RUN"}
report={"status":"BLOCKED","gates":gates,"explanation":"See compiler-review.md and dependency-review.md. No transaction is sent."}
print(json.dumps(report,indent=2))
raise SystemExit(1)
