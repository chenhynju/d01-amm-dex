#!/usr/bin/env python3
"""Check internal Markdown targets without accessing remote URLs."""
from pathlib import Path
import re,json
root=Path(__file__).resolve().parents[1]
broken=[];count=0
for doc in [root/"README.md",*sorted((root/"docs").rglob("*.md"))]:
    for target in re.findall(r"\[[^\]]*\]\(([^)]+)\)",doc.read_text()):
        if "://" in target or target.startswith("#"):continue
        path=target.split("#")[0]
        if not path:continue
        count+=1
        if not (doc.parent/path).exists():broken.append({"file":str(doc.relative_to(root)),"target":target})
assert count>=20,"Suspiciously few Markdown links parsed"
assert not broken,json.dumps(broken)
print(json.dumps({"status":"PASS","internal_links_checked":count}))
