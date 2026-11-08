#!/usr/bin/env python3
import subprocess,time,json,urllib.request,os
from pathlib import Path
root=Path(__file__).resolve().parents[1];url="http://127.0.0.1:18545"
evidence=Path(os.environ.get("AMM_SMOKE_EVIDENCE_DIR",str(root/"evidence")));evidence.mkdir(parents=True,exist_ok=True)
def rpc(method,params):
    body=json.dumps({"jsonrpc":"2.0","id":1,"method":method,"params":params}).encode()
    d=json.load(urllib.request.urlopen(urllib.request.Request(url,body,{"Content-Type":"application/json"})))
    if "error" in d:raise RuntimeError(d["error"])
    return d["result"]
def call(addr,sig,*args):
    return subprocess.check_output(["cast","call","--rpc-url",url,addr,sig,*args],text=True).strip()
with (evidence/"anvil.log").open("w") as log:
    anvil=subprocess.Popen(["anvil","--port","18545","--chain-id","31337","--silent"],stdout=log,stderr=log)
    try:
        for _ in range(100):
            if anvil.poll() is not None:raise RuntimeError("Owned Anvil exited before ready; port may be busy")
            try:
                assert rpc("eth_chainId",[])=="0x7a69";break
            except Exception:time.sleep(.1)
        with (evidence/"local-deploy.log").open("w") as out:
            subprocess.run(["forge","script","script/LocalDemo.s.sol:LocalDemo","--rpc-url",url,"--broadcast","--slow","--gas-estimate-multiplier","200","--unlocked","--sender","0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266"],cwd=root,stdout=out,stderr=subprocess.STDOUT,check=True)
        run=json.loads((root/"broadcast/LocalDemo.s.sol/31337/run-latest.json").read_text())
        txs=run["transactions"]
        factory=next(t["contractAddress"] for t in txs if t.get("contractName")=="Factory")
        router=next(t["contractAddress"] for t in txs if t.get("contractName")=="Router")
        tokens=[t["contractAddress"] for t in txs if t.get("contractName")=="DemoToken" and t.get("transactionType")=="CREATE"]
        pair=call(factory,"getPair(address,address)(address)",*tokens)
        out=int(call(tokens[1],"balanceOf(address)(uint256)","0x0000000000000000000000000000000000000b0b").split()[0])
        assert out>=9*10**15
        assert len(rpc("eth_getCode",[pair,"latest"]))>2
        remainingSupply=int(call(pair,"totalSupply()(uint256)").split()[0])
        assert remainingSupply==1000
        userLP=int(call(pair,"balanceOf(address)(uint256)","0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266").split()[0])
        assert userLP==0
        receipts=[rpc("eth_getTransactionReceipt",[t["hash"]]) for t in txs]
        assert all(v["status"]=="0x1" for v in receipts)
        report={"status":"PASS","network":"local ephemeral Anvil","chainId":31337,"factory":factory,"router":router,"pair":pair,"tokens":tokens,"recipientOutput":str(out),"remainingLockedSupply":remainingSupply,"userLP":userLP,"reserves":call(pair,"getReserves()(uint112,uint112,uint32)"),"transactions":[{k:t.get(k) for k in ["hash","transactionType","contractName","contractAddress","function"]} for t in txs],"receipts":receipts}
        (evidence/"local-deployment.json").write_text(json.dumps(report,indent=2))
        print(json.dumps({k:v for k,v in report.items() if k not in ["receipts","transactions"]},indent=2))
    except Exception:
        diagnostic={"status":"FAIL","transactions":[]}
        runfile=root/"broadcast/LocalDemo.s.sol/31337/run-latest.json"
        if runfile.exists():
            for tx in json.loads(runfile.read_text()).get("transactions",[]):
                h=tx.get("hash")
                if not h:continue
                receipt=rpc("eth_getTransactionReceipt",[h])
                item={"hash":h,"function":tx.get("function"),"gasLimit":tx.get("transaction",{}).get("gas"),"receipt":receipt}
                if receipt and receipt.get("status")=="0x0":
                    item["trace"]=rpc("debug_traceTransaction",[h,{"tracer":"callTracer"}])
                diagnostic["transactions"].append(item)
        (evidence/"failure-diagnostic.json").write_text(json.dumps(diagnostic,indent=2))
        raise
    finally:anvil.terminate();anvil.wait(timeout=10)
