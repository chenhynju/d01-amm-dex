#!/usr/bin/env python3
"""Manual targeted mutations in disposable workspaces; success requires each mutant be killed."""
from pathlib import Path
import shutil,tempfile,subprocess,json
root=Path(__file__).resolve().parents[1]
# This runner uses the strengthened deterministic flash PoC supplied alongside this script.
results=[]
for name,file,old,new,test in [
    ("remove-flash-fee","src/Pair.sol","a0In * 3","a0In * 0","testFlashPrincipalOnlyRepaymentRejected"),
    ("remove-swap-lock","src/Pair.sol","external nonReentrant {","external {","testFlashRepaymentAndLocks"),
    ("no-quote-fee","src/Router.sol","input * 997","input * 1000","testSwapAndFee")
]:
    work=Path(tempfile.mkdtemp(prefix="b2-mutant-"))
    for item in ["src","lib","foundry.toml"]:
        src=root/item;dst=work/item
        if src.is_dir():shutil.copytree(src,dst)
        else:shutil.copy2(src,dst)
    (work/"test").mkdir();shutil.copy2(root/"test/AMM.t.sol",work/"test/AMM.t.sol")
    target=work/file;text=target.read_text()
    assert old in text,"Mutation target drifted"
    # Only first matching occurrence: the first nonReentrant void function is swap.
    target.write_text(text.replace(old,new,1))
    log=root/"evidence"/("mutation-"+name+".log")
    with log.open("w") as out:
        result=subprocess.run(["forge","test","--root",str(work),"--match-contract","AMMTest","--match-test",test,"-vvvv"],stdout=out,stderr=subprocess.STDOUT)
    contents=log.read_text()
    assert result.returncode!=0 and "[FAIL" in contents and "Compiler run successful" in contents,"Mutant not killed by an executed test"
    results.append({"mutation":name,"status":"KILLED","exit":result.returncode,"test":test,"log":log.name})
    (root/"evidence/mutations.json").write_text(json.dumps(results,indent=2))
print(json.dumps(results,indent=2))
