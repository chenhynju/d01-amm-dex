#!/usr/bin/env python3
"""Aggregate only completed, actually observed records; fail closed on missing evidence."""
from pathlib import Path
import json,re,hashlib
root=Path(__file__).resolve().parents[1];ev=root/"evidence"
campaign=json.loads((ev/"campaign.json").read_text())
assert campaign["status"]=="PASS" and campaign["seconds"]>=1800
fuzz=0;calls=0
for row in campaign["rounds"]:
    assert row["exit"]==0
    text=(ev/row["log"]).read_text()
    assert "0 failed, 0 skipped" in text
    for line in text.splitlines():
        if line.startswith("[PASS] testFuzz"):
            fuzz+=int(re.search("runs: ([0-9]+)",line).group(1))
        if "AMMInvariant invariants (runs:" in line:
            calls+=int(re.search("calls: ([0-9]+)",line).group(1))
final=(ev/"test-final.log").read_text()
assert "37 tests passed, 0 failed, 1 skipped" in final
assert "PASS: all detector output matches reviewed baseline" in (ev/"static-gate.log").read_text()
ci=(ev/"ci-profile-local.log").read_text()
assert "36 tests passed, 0 failed, 1 skipped" in ci and "calls: 131072, reverts: 0" in ci
assert json.loads((ev/"local-deployment.json").read_text())["status"]=="PASS"
assert json.loads((ev/"reproducible-build.json").read_text())["status"]=="PASS"
mutations=json.loads((ev/"mutations.json").read_text());assert len(mutations)==3 and all(v["status"]=="KILLED" for v in mutations)
freeze=json.loads((ev/"source-freeze.json").read_text())
assert all(hashlib.sha256((root/f).read_bytes()).hexdigest()==h for f,h in freeze["files"].items())
summary={"status":"PASS_LOCAL_ONLY","public_release":"BLOCKED","final_suite":{"passed":37,"failed":0,"skipped_fork":1},
"campaign":{"seconds":campaign["seconds"],"rounds":len(campaign["rounds"]),"unit_fuzz_cases":fuzz,"handler_calls":calls,"seed_first":campaign["rounds"][0]["seed"],"seed_last":campaign["rounds"][-1]["seed"]},
"ci_profile":{"passed":36,"failed":0,"skipped_fork":1,"runs":512,"depth":256,"handler_calls":131072,"seed":"0xc120261105"},
"core_coverage":json.loads((ev/"core-coverage.json").read_text())["branch_percent"],"mutants_killed":3,"protocol_commit":freeze["protocol_commit"]}
(ev/"summary.json").write_text(json.dumps(summary,indent=2))
report=root/"docs/testing/results.md";text=report.read_text()
text=text.replace("| 30-minute changing-seed campaign | RUNNING | campaign.json and per-round logs; final status replaces this row |",
"| 30-minute changing-seed campaign | PASS | %.2f seconds; %d completed rounds; %d unit fuzz cases; %d handler calls |"%(campaign["seconds"],len(campaign["rounds"]),fuzz,calls))
text=text.replace("| Baseline suite | PASS |","| Frozen baseline suite | PASS |")
text+="""
## Final aggregate
Final default suite: **37 PASS, 0 FAIL, 1 explicit fork SKIP**: 34 unit/fuzz, quote differential, LP differential, one group containing 7 invariant properties. Baseline changing-seed campaign ran the 35-test frozen suite; the extra underpayment and LP-model tests were added separately. The protocol source and compiler configuration are unchanged, verified by source-freeze hashes.
Local CI profile: 36 PASS / 0 FAIL / 1 fork SKIP, 512 runs x depth256 / 131,072 handler calls, seed 0xc120261105. LP reference vectors were additionally executed under default profile. This is local CI-profile execution, not a remote Actions run.
Three targeted mutants killed; independent rebuild full bytes match; gas snapshot generation/check, actual full local flow and internal links verified separately in evidence logs. Public release remains BLOCKED as documented.
"""
report.write_text(text)
simulation=root/"docs/economics/simulation-report.md"
simulation.write_text(simulation.read_text()+"""
## Completed campaign aggregate
%.2f seconds, %d completed rounds, %d unit fuzz cases, %d handler calls. All rounds exited zero; exact seed range %s through %s is enumerated in campaign.json. Additional CI profile completed 131,072 calls with zero revert. These are bounded simulation observations, not formal proof.
"""%(campaign["seconds"],len(campaign["rounds"]),fuzz,calls,summary["campaign"]["seed_first"],summary["campaign"]["seed_last"]))
print(json.dumps(summary,indent=2))
