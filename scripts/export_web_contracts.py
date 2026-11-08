#!/usr/bin/env python3
from pathlib import Path
import json
root=Path(__file__).resolve().parents[1]
items={"factoryAbi":"Factory","pairAbi":"Pair","routerAbi":"Router","faucetAbi":"TestnetToken"}
lines=["// Generated from the actual Foundry artifacts. Do not edit ABI definitions manually."]
for variable,name in items.items():
    artifact=json.loads((root/"out"/(name+".sol")/(name+".json")).read_text())
    lines.append("export const "+variable+" = "+json.dumps(artifact["abi"],separators=(",",":"))+" as const;")
(root/"apps/web/lib/contracts.ts").write_text(chr(10).join(lines)+chr(10))
print("Exported ABI for",", ".join(items.values()))
