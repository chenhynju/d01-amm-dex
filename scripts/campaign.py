#!/usr/bin/env python3
"""Run complete randomized campaigns for >=30 minutes; never mask command failures."""
import subprocess,time,json,os
from pathlib import Path
root=Path(__file__).resolve().parents[1]
start=time.monotonic();rounds=[]
while time.monotonic()-start < 1800:
    seed=202611050000+len(rounds)
    env=os.environ.copy()
    env["FOUNDRY_FUZZ_SEED"]=hex(seed)
    log=root/"evidence"/("campaign-%03d.log"%len(rounds))
    before=time.monotonic()
    with log.open("w") as out:
        result=subprocess.run(["forge","test","--no-match-contract","MainnetForkTest","--fuzz-runs","10000"],cwd=root,env=env,stdout=out,stderr=subprocess.STDOUT)
    rounds.append({"seed":hex(seed),"exit":result.returncode,"seconds":time.monotonic()-before,"log":log.name})
    report={"status":"RUNNING" if result.returncode==0 else "FAIL","seconds":time.monotonic()-start,"rounds":rounds}
    (root/"evidence/campaign.json").write_text(json.dumps(report,indent=2))
    if result.returncode:raise SystemExit(result.returncode)
report["status"]="PASS";report["seconds"]=time.monotonic()-start
(root/"evidence/campaign.json").write_text(json.dumps(report,indent=2))
print(json.dumps(report))
