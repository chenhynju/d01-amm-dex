#!/usr/bin/env python3
"""Compare every static finding to a reviewed baseline; never silently drop detectors."""
import json,subprocess,collections
from pathlib import Path
root=Path(__file__).resolve().parents[1]
subprocess.run(["slither",".","--filter-paths","lib/|test/|script/","--json","evidence/slither-ci.json"],cwd=root,check=False)
result=json.loads((root/"evidence/slither-ci.json").read_text())
assert result["success"],result.get("error")
def slither_counts(data):
    return dict(collections.Counter(x["check"]+"|"+x["impact"] for x in data["results"]["detectors"]))
baseline=json.loads((root/"docs/audit/static-baseline.json").read_text())
assert slither_counts(result)==baseline["slither"],"Slither finding set changed: review required"
subprocess.run(["aderyn",".","--output","evidence/aderyn-ci.json"],cwd=root,check=True)
d=json.loads((root/"evidence/aderyn-ci.json").read_text())
assert d["high_issues"]["issues"]==[],"Unreviewed high Aderyn issue"
assert {x["detector_name"]:len(x["instances"]) for x in d["low_issues"]["issues"]}==baseline["aderyn"],"Aderyn finding set changed"
print("PASS: all detector output matches reviewed baseline; not zero findings")
