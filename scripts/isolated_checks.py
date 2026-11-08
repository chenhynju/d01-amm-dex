#!/usr/bin/env python3
"""Run destructive build-tool checks in an isolated Linux workspace."""
import subprocess,shutil,tempfile,json,os
from pathlib import Path
root=Path(__file__).resolve().parents[1]
evidence=root/os.environ.get("B2_EVIDENCE_DIR","evidence")
evidence.mkdir(parents=True,exist_ok=True)
work=Path(tempfile.mkdtemp(prefix="b2-checks-"))
for name in ["src","test","script","scripts","lib","foundry.toml","dependencies.lock.json"]:
    src=root/name;dst=work/name
    if src.is_dir():shutil.copytree(src,dst,ignore=shutil.ignore_patterns("__pycache__"))
    else:shutil.copy2(src,dst)
(work/"evidence").mkdir()
results={}
def run(tag,cmd,expected=0):
    with (evidence/(tag+".log")).open("w") as out:
        rc=subprocess.run(cmd,cwd=work,stdout=out,stderr=subprocess.STDOUT).returncode
    results[tag]={"exit":rc,"expected":expected,"log":tag+".log"}
    (evidence/"isolated-checks.json").write_text(json.dumps(results,indent=2))
run("slither-final",["slither",".","--filter-paths","lib/|test/|script/","--json",str(evidence/"slither-final.json")],255)
run("aderyn-final",["aderyn",".","--output",str(evidence/"aderyn-final.json")])
run("coverage",["forge","coverage","--ir-minimum","--report","summary","--report","lcov","--no-match-contract","MainnetForkTest"])
if (work/"lcov.info").exists():shutil.copy2(work/"lcov.info",evidence/"lcov.info")
run("local-smoke-runner",["python3","scripts/local_smoke.py"])
for name in ["anvil.log","local-deploy.log","local-deployment.json"]:
    f=work/"evidence"/name
    if f.exists():shutil.copy2(f,evidence/name)
print(json.dumps({"workspace":str(work),"results":results},indent=2))
