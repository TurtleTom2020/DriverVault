import json
from pathlib import Path
p=Path("assets/catalog/catalog.json")
d=json.loads(p.read_text(encoding="utf-8"))
bad=set(["fh5:3682","fh5:633","fh5:3518","fh5:1040","fh5:1652","fh5:2177","fh5:289","fh5:3746","fh5:3441","fh5:3109","fh5:1352","fh5:3561","fh5:3714","fh5:3715","fh5:3367","fh5:1319","fh5:1578","fh5:3277","fh5:2400","fh5:1302","fh5:1486","fh5:3523","fh5:3249","fh5:3411","fh5:1394","fh5:2750","fh5:3678","fh5:3457","fh5:2175","fh5:2825","fh5:2068","fh5:3107","fh5:1525","fh5:378","fh5:1381","fh5:3307","fh5:2738","fh5:2270","fh5:1042","fh5:3244","fh5:3687","fh5:2521","fh5:2741","fh5:2743","fh5:461"])
g=next(x for x in d["games"] if x["id"]=="fh5")
for v in g["vehicles"]:
    if v.get("id")=="fh5:2750":
        v["image"]="https://static.wikia.nocookie.net/forzamotorsport/images/3/33/FH5_Hot_Wheels_Twin_Mill_Small.png/revision/latest?cb=20240915171751"
        v["imageSource"]="Forza Wiki FH5 image catalogue"
        v["imageMatch"]="FH5 Hot Wheels Twin Mill"
for v in g["vehicles"]:
    if v.get("id") in bad:
        v["image"]=""
        v.pop("imageSource",None); v.pop("imageMatch",None)
g["imageCoverage"]=sum(bool(str(v.get("image","")).strip()) for v in g["vehicles"])
g["imageVerifiedAt"]="2026-09-28"
p.write_text(json.dumps(d,ensure_ascii=False,indent=2)+"\n",encoding="utf-8")
print("FH5 CLEAN COVERAGE",g["imageCoverage"],"/",len(g["vehicles"]))
