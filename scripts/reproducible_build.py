#!/usr/bin/env python3
from pathlib import Path
import subprocess,hashlib,json,shutil,tempfile
root=Path(__file__).resolve().parents[1]
work=Path(tempfile.mkdtemp(prefix="b2-repro-"))
for name in ["src","lib","foundry.toml"]:
    src=root/name;dst=work/name
    if src.is_dir():shutil.copytree(src,dst)
    else:shutil.copy2(src,dst)
with (root/"evidence/reproducible-build.log").open("w") as log:
    subprocess.run(["forge","build","--root",str(work),"--sizes","--force"],stdout=log,stderr=subprocess.STDOUT,check=True)
rows={}
for name in ["Factory","Pair","Router"]:
    baseline=json.loads((root/"out"/(name+".sol")/(name+".json")).read_text())
    rebuilt=json.loads((work/"out"/(name+".sol")/(name+".json")).read_text())
    row={}
    for field in ["bytecode","deployedBytecode"]:
        a=baseline[field]["object"].removeprefix("0x");b=rebuilt[field]["object"].removeprefix("0x")
        assert a==b,name+" "+field+" differs between Linux roots"
        row[field]={"bytes":len(a)//2,"sha256":hashlib.sha256(bytes.fromhex(a)).hexdigest()}
    rows[name]=row
report={"status":"PASS","comparison":"full init/runtime bytes including metadata across two Linux paths","contracts":rows}
(root/"evidence/reproducible-build.json").write_text(json.dumps(report,indent=2))
print(json.dumps(report,indent=2))
