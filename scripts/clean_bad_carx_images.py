#!/usr/bin/env python3
import json
from pathlib import Path
p=Path("assets/catalog/catalog.json")
d=json.loads(p.read_text(encoding="utf-8"))
g=next(x for x in d["games"] if x["id"]=="carx")
# Audited false positives/placeholders. Never preserve a wrong image merely to
# improve coverage: the app now falls back to CarX game artwork for blanks.
bad={
 "carx:hachi-go",       # Hachi-Roku image
 "carx:syberia-wdc",    # unrelated Miracle_stock / CarX Rally
 "carx:burner-jdm",     # Stub_image placeholder
 "carx:grace-gt",       # unrelated Miracle_stock / CarX Rally
 "carx:sensei",         # Carrot II image
 "carx:interstate",     # WIP logo
 "carx:midnight",       # unrelated Miracle_stock / CarX Rally
}
for v in g["vehicles"]:
 if v.get("id") in bad:
  v["image"]=""
  v.pop("imageSource",None); v.pop("imageMatch",None)
g["imageCoverage"]=sum(bool(str(v.get("image","")).strip()) for v in g["vehicles"])
g["imageVerifiedAt"]="2026-09-28"
p.write_text(json.dumps(d,ensure_ascii=False,indent=2)+"\n",encoding="utf-8")
print("CARX CLEAN COVERAGE",g["imageCoverage"],"/",len(g["vehicles"]))
