#!/usr/bin/env python3
from pathlib import Path
import subprocess,json,os,concurrent.futures
root=Path(__file__).resolve().parents[1];web=root/"apps/web"
env=os.environ.copy();env["PATH"]=str(Path.home()/".local/share/fnm/node-versions/v22.23.2/installation/bin")+":"+env["PATH"]
env["HTTPS_PROXY"]=env["HTTP_PROXY"]="http://127.0.0.1:18443"
env["https_proxy"]=env["http_proxy"]="http://127.0.0.1:18443"
specs={
"next":"15.5.29","react":"19","react-dom":"19","wagmi":"2","viem":"2","@tanstack/react-query":"5",
"tailwindcss":"3","postcss":"8","autoprefixer":"10","typescript":"5","@types/react":"19","@types/react-dom":"19","@types/node":"22",
"eslint":"9","eslint-config-next":"15.5.29","@eslint/eslintrc":"3"}
def resolve(item):
    name,version=item
    raw=subprocess.check_output(["npm","view",name+"@"+version,"version","--json","--registry=https://registry.npmjs.org"],env=env,text=True)
    data=json.loads(raw)
    return name,data[-1] if isinstance(data,list) else data
with concurrent.futures.ThreadPoolExecutor(max_workers=4) as pool:versions=dict(pool.map(resolve,specs.items()))
runtime=["next","react","react-dom","wagmi","viem","@tanstack/react-query"]
manifest={"name":"b2-amm-web","version":"1.0.0","private":True,"type":"module","packageManager":"npm@10.9.8",
"engines":{"node":"22.23.2"},
"scripts":{"dev":"next dev --hostname 0.0.0.0","build":"next build","typecheck":"tsc --noEmit","lint":"eslint . --max-warnings 0","test":"node --experimental-strip-types --test tests/*.test.ts"},
"dependencies":{k:versions[k] for k in runtime},"devDependencies":{k:v for k,v in versions.items() if k not in runtime}}
(web/"package.json").write_text(json.dumps(manifest,indent=2))
(web/"versions.lock.json").write_text(json.dumps({"registry":"https://registry.npmjs.org","resolved":versions,"node":"22.23.2","npm":"10.9.8"},indent=2))
print(json.dumps(versions,indent=2))
