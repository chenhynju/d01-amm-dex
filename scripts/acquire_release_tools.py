#!/usr/bin/env python3
"""Authenticate exact compiler/tool artifacts from official HTTPS manifests and stage project-local tools."""
from pathlib import Path
import urllib.request,json,hashlib,tarfile,os,subprocess,shutil,datetime
root=Path(__file__).resolve().parents[1];ev=root/"evidence/release-20261105"
proxy="http://127.0.0.1:18443"
opener=urllib.request.build_opener(urllib.request.ProxyHandler({"http":proxy,"https":proxy}))
def get(url):
    request=urllib.request.Request(url,headers={"User-Agent":"B2AMM-release","Accept":"application/json"})
    with opener.open(request,timeout=90) as r:return r.read()
report={}
manifest=json.loads(get("https://binaries.soliditylang.org/linux-amd64/list.json"))
version="0.8.38"
build=next(b for b in manifest["builds"] if b["path"]==manifest["releases"][version])
binary=get("https://binaries.soliditylang.org/linux-amd64/"+build["path"])
digest=hashlib.sha256(binary).hexdigest()
assert digest==build["sha256"].removeprefix("0x"),"Compiler digest mismatch"
target=Path.home()/".local/share/svm"/version/("solc-"+version)
target.parent.mkdir(parents=True,exist_ok=True)
target.write_bytes(binary);target.chmod(0o755)
report["solc"]={"version":version,"sha256":digest,"official_path":build["path"],"status":"VERIFIED"}
bugs=json.loads(get("https://raw.githubusercontent.com/ethereum/solidity/develop/docs/bugs_by_version.json"))
assert bugs[version]["bugs"]==[],"Review current compiler bug list before release"
report["compiler_known_bugs"]={"version":version,"bugs":bugs[version]["bugs"],"checked_at":datetime.datetime.now(datetime.timezone.utc).isoformat()}
release=json.loads(get("https://api.github.com/repos/foundry-rs/foundry/releases/tags/v1.8.7"))
asset=next(a for a in release["assets"] if a["name"]=="foundry_v1.8.7_linux_amd64.tar.gz")
archive=get(asset["browser_download_url"])
expected=asset.get("digest","")
assert expected.startswith("sha256:"),"Official release has no digest; do not install unverified archive"
actual=hashlib.sha256(archive).hexdigest()
assert actual==expected.split(":",1)[1],"Foundry archive digest mismatch"
folder=root/".tools/foundry-1.8.7";folder.mkdir(parents=True,exist_ok=True)
tarpath=folder/"release.tar.gz";tarpath.write_bytes(archive)
with tarfile.open(tarpath) as tar:
    tar.extractall(folder,filter="data")
for name in ["forge","cast","anvil"]:(folder/name).chmod(0o755)
report["foundry"]={"version":"1.8.7","archive_sha256":actual,"release_url":release["html_url"],"status":"VERIFIED","local_directory":str(folder)}
for name in ["forge","cast","anvil"]:
    report["foundry"][name+"_sha256"]=hashlib.sha256((folder/name).read_bytes()).hexdigest()
report["foundry"]["version_output"]=subprocess.check_output([str(folder/"forge"),"--version"],text=True)
(ev/"toolchain-acquisition.json").write_text(json.dumps(report,indent=2))
print(json.dumps(report,indent=2))
