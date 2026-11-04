#!/usr/bin/env python3
"""Content lock for vendored, offline dependencies. This is integrity, not CVE attestation."""
import hashlib,json,argparse
from pathlib import Path
root=Path(__file__).resolve().parents[1]
parser=argparse.ArgumentParser();parser.add_argument("--write",action="store_true");args=parser.parse_args()
report={}
for name in ["openzeppelin-contracts","forge-std"]:
    dep=root/"lib"/name
    manifest={str(p.relative_to(dep)):hashlib.sha256(p.read_bytes()).hexdigest() for p in sorted(dep.rglob("*")) if p.is_file()}
    report[name]={"version":json.loads((dep/"package.json").read_text())["version"],"files":manifest}
lock=root/"dependencies.lock.json"
if args.write:lock.write_text(json.dumps(report,indent=2))
else:assert json.loads(lock.read_text())==report,"Dependency content changed"
print(json.dumps({k:{"version":v["version"],"files":len(v["files"])} for k,v in report.items()}))
