#!/usr/bin/env python3
from pathlib import Path
import subprocess,tempfile,json,shutil,os,hashlib,datetime
root=Path(__file__).resolve().parents[1];ev=root/"evidence/release-20261105"
env=os.environ.copy()
env["HTTPS_PROXY"]=env["HTTP_PROXY"]="http://127.0.0.1:18443"
env["https_proxy"]=env["http_proxy"]="http://127.0.0.1:18443"
stage=Path(tempfile.mkdtemp(prefix="b2-auth-dependencies-"))
report={}
for name,repo,tag in [
 ("openzeppelin-contracts","https://github.com/OpenZeppelin/openzeppelin-contracts","v5.0.2"),
 ("forge-std","https://github.com/foundry-rs/forge-std","v1.14.0")]:
    target=stage/name
    subprocess.run(["git","clone","--depth","1","--branch",tag,repo,str(target)],env=env,check=True)
    commit=subprocess.check_output(["git","-C",str(target),"rev-parse","HEAD"],text=True).strip()
    version=json.loads((target/"package.json").read_text())["version"]
    report[name]={"upstream":repo,"tag":tag,"commit":commit,"package_version":version,"acquisition":"official HTTPS git clone"}
    backup=Path.home()/"projects/.b2-amm-backups/20261105"/name
    backup.parent.mkdir(parents=True,exist_ok=True)
    current=root/"lib"/name
    if current.exists():
        assert not backup.exists(),"Existing backup: inspect before replacement"
        current.rename(backup)
    shutil.copytree(target,current,ignore=shutil.ignore_patterns(".git","node_modules","out","cache"))
(ev/"dependency-acquisition.json").write_text(json.dumps(report,indent=2))
print(json.dumps(report,indent=2))
