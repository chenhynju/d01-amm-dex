#!/usr/bin/env python3
"""Real local transactions through the production static UI; synthetic EIP-1193 wallet only."""
from pathlib import Path
import subprocess,tempfile,shutil,json,urllib.request,time,os,socket
root=Path(__file__).resolve().parents[1];evidence=root/'evidence/browser-current';evidence.mkdir(parents=True,exist_ok=True)
rpc_url='http://127.0.0.1:18565';web_url='http://127.0.0.1:18065'
# Unlocked local RPC must never be sent through an external HTTP proxy.
for proxy_key in ['NO_PROXY','no_proxy']:
 os.environ[proxy_key]=','.join(filter(None,[os.environ.get(proxy_key,''),'127.0.0.1','localhost']))
local_opener=urllib.request.build_opener(urllib.request.ProxyHandler({}))
def rpc(method,params):
 request=urllib.request.Request(rpc_url,data=json.dumps({'jsonrpc':'2.0','id':1,'method':method,'params':params}).encode(),headers={'Content-Type':'application/json'})
 value=json.load(local_opener.open(request,timeout=10))
 if 'error' in value:raise RuntimeError(value['error'])
 return value['result']
for port in [18565,18065]:
 with socket.socket() as probe:
  try:probe.bind(('127.0.0.1',port))
  except OSError:raise SystemExit(f'Port {port} is occupied; refusing to replace another service')
with tempfile.TemporaryDirectory(prefix='d01-browser-') as td:
 work=Path(td);shutil.copytree(root/'apps/web',work/'web',ignore=shutil.ignore_patterns('node_modules','.next','out','.vercel','*.tsbuildinfo'));(work/'web/node_modules').symlink_to(root/'apps/web/node_modules',target_is_directory=True)
 with (evidence/'anvil.log').open('w') as log:
  anvil=subprocess.Popen(['anvil','--host','127.0.0.1','--port','18565','--chain-id','31337','--hardfork','cancun','--silent'],stdout=log,stderr=log)
  server=None
  try:
   for _ in range(100):
    if anvil.poll() is not None:raise RuntimeError('Owned Anvil exited')
    try:
     if rpc('eth_chainId',[])=='0x7a69':break
    except Exception:time.sleep(.1)
   else:raise RuntimeError('Owned Anvil did not become ready')
   accounts=rpc('eth_accounts',[]);deployer=accounts[0];actor=accounts[1]
   env={**os.environ,'DEPLOYER_ADDRESS':deployer}
   with (evidence/'deployment.log').open('w') as output:
    subprocess.run(['forge','script','script/DeployTestnet.s.sol:DeployTestnet','--rpc-url',rpc_url,'--sender',deployer,'--unlocked','--broadcast','--slow','--gas-estimate-multiplier','200'],cwd=root,env=env,stdout=output,stderr=subprocess.STDOUT,check=True)
   run=json.loads((root/'broadcast/DeployTestnet.s.sol/31337/run-latest.json').read_text());txs=run['transactions']
   address=lambda name:next(t['contractAddress'] for t in txs if t.get('contractName')==name and t.get('transactionType')=='CREATE')
   tokens=[t['contractAddress'] for t in txs if t.get('contractName')=='TestnetToken' and t.get('transactionType')=='CREATE']
   factory=address('Factory');router=address('Router');pair=subprocess.check_output(['cast','call',factory,'getPair(address,address)(address)',*tokens,'--rpc-url',rpc_url],text=True).strip()
   contracts={'factory':factory,'router':router,'pair':pair,'tokenA':tokens[0],'tokenB':tokens[1]}
   hashes={key:subprocess.check_output(['cast','keccak',rpc('eth_getCode',[a,'latest'])],text=True).strip() for key,a in contracts.items()}
   config={'status':'verified','chainId':31337,'rpcUrl':rpc_url,'explorerUrl':'','auditedCommit':None,'contracts':contracts,'runtimeHashes':hashes}
   (work/'web/deployment.json').write_text(json.dumps(config,indent=2)+'\n');(evidence/'fixture.json').write_text(json.dumps(config,indent=2)+'\n')
   with (evidence/'build.log').open('w') as output:subprocess.run(['npm','run','build'],cwd=work/'web',stdout=output,stderr=subprocess.STDOUT,check=True)
   server=subprocess.Popen(['python3','-m','http.server','18065','--bind','127.0.0.1','--directory',str(work/'web/out')],stdout=log,stderr=log)
   for _ in range(80):
    try:local_opener.open(web_url,timeout=2).close();break
    except Exception:time.sleep(.1)
   env={**os.environ,'AMM_BROWSER_RPC':rpc_url,'AMM_BROWSER_URL':web_url,'AMM_BROWSER_ACTOR':actor,'AMM_BROWSER_EVIDENCE':str(evidence),'AMM_BROWSER_FIXTURE':json.dumps(config)}
   subprocess.run(['node',str(root/'scripts/browser_smoke.cjs')],cwd=root,env=env,check=True)
  finally:
   if server:server.terminate();server.wait(timeout=10)
   anvil.terminate();anvil.wait(timeout=10)
