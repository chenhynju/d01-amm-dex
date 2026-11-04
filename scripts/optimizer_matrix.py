#!/usr/bin/env python3
import subprocess,os,json,shutil,tempfile
from pathlib import Path
root=Path(__file__).resolve().parents[1]
work=Path(tempfile.mkdtemp(prefix="b2-optimizer-"))
for name in ["src","test","lib","foundry.toml"]:
    src=root/name;dst=work/name
    if src.is_dir():shutil.copytree(src,dst)
    else:shutil.copy2(src,dst)
results=[]
for ir in [False,True]:
    for runs in [200,1000,10000]:
        tag=f"ir-{str(ir).lower()}-runs-{runs}"
        env=os.environ.copy();env["FOUNDRY_VIA_IR"]=str(ir).lower();env["FOUNDRY_OPTIMIZER_RUNS"]=str(runs)
        cmd=["forge","test","--root",str(work),"--match-contract","AMMTest","--skip","Invariant.t.sol","--skip","Differential.t.sol","--skip","MainnetFork.t.sol","--gas-report","--fuzz-runs","1024"]
        log=root/"evidence"/f"optimizer-{tag}.log"
        with log.open("w") as out:
            result=subprocess.run(cmd,env=env,stdout=out,stderr=subprocess.STDOUT)
        row={"via_ir":ir,"optimizer_runs":runs,"exit":result.returncode,"log":log.name,"contracts":{}}
        if result.returncode==0:
            for contract in ["Pair","Router","Factory"]:
                artifact=json.loads((work/"out"/f"{contract}.sol"/f"{contract}.json").read_text())
                row["contracts"][contract]={k:len(artifact[field]["object"].removeprefix("0x"))//2 for k,field in [("runtime_bytes","deployedBytecode"),("initcode_bytes","bytecode")]}
                # Constructor args for Pair and Router are reported separately from artifact initcode.
        results.append(row)
        (root/"evidence/optimizer-matrix.json").write_text(json.dumps(results,indent=2))
print(json.dumps(results,indent=2))
