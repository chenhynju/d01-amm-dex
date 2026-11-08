#!/usr/bin/env python3
import sys,json
from pathlib import Path
rows={}
for record in Path(sys.argv[1]).read_text().split("end_of_record"):
    lines=record.strip().splitlines()
    sf=next((x[3:] for x in lines if x.startswith("SF:")),"")
    if sf not in ["src/Factory.sol","src/Pair.sol","src/Router.sol","src/TestnetToken.sol"]:continue
    counts={k:int(next(x.split(":")[1] for x in lines if x.startswith(k+":"))) for k in ["LF","LH","FNF","FNH","BRF","BRH"]}
    rows[sf]=counts
assert len(rows)==4,"Missing core files"
total={k:sum(v[k] for v in rows.values()) for k in ["LF","LH","FNF","FNH","BRF","BRH"]}
assert total["BRF"]>0 and total["BRH"]*100>=total["BRF"]*90,"Core branch coverage below 90%"
print(json.dumps({"status":"PASS","files":rows,"total":total,"branch_percent":100*total["BRH"]/total["BRF"]},indent=2))
