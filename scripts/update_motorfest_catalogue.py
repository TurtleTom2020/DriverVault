#!/usr/bin/env python3
"""Build DriverVault's Crew Motorfest catalogue from Ubisoft's official roster."""
import html, json, re, urllib.request
from html.parser import HTMLParser
from pathlib import Path

URL="https://www.ubisoft.com/en-gb/game/the-crew/motorfest/news-updates/6eTRFZ2OQC9SAC1Psddaqg"
OUT=Path("assets/catalog/catalog.json")

class Tables(HTMLParser):
 def __init__(self):
  super().__init__(); self.rows=[]; self.row=None; self.cell=None; self.heading=None; self.current_heading=""
 def handle_starttag(self,tag,attrs):
  if tag in ("h1","h2","h3","h4","h5"): self.heading=[]
  elif tag=="tr": self.row=[]
  elif tag in ("td","th") and self.row is not None:self.cell=[]
 def handle_data(self,data):
  if self.heading is not None:self.heading.append(data)
  if self.cell is not None:self.cell.append(data)
 def handle_endtag(self,tag):
  if tag in ("h1","h2","h3","h4","h5") and self.heading is not None:
   x=" ".join("".join(self.heading).split())
   if x:self.current_heading=x
   self.heading=None
  elif tag in ("td","th") and self.cell is not None:
   self.row.append(" ".join("".join(self.cell).split()));self.cell=None
  elif tag=="tr" and self.row is not None:
   if len(self.row)>=3:self.rows.append((self.current_heading,self.row))
   self.row=None

def slug(s):
 s=html.unescape(s).lower().replace("®","")
 return re.sub(r"[^a-z0-9]+","-",s).strip("-")

req=urllib.request.Request(URL,headers={"User-Agent":"Mozilla/5.0 DriverVault catalogue builder"})
raw=urllib.request.urlopen(req,timeout=60).read().decode("utf-8","replace")
p=Tables();p.feed(raw)
vehicles=[];seen=set()
for heading,row in p.rows:
 clean=[x.strip() for x in row if x.strip()]
 yi=next((i for i,x in enumerate(clean) if re.fullmatch(r"(?:19|20)\d{2}",x)),None)
 if yi is None or yi<2:continue
 brand,model,year=clean[yi-2],clean[yi-1],clean[yi]
 if brand.upper() in {"BRAND","MAKE"} or model.upper()=="MODEL":continue
 yr=int(year)
 discipline=re.sub(r"[^A-Za-z0-9 &/-]+","",heading).strip() or "Motorfest"
 key=(brand.casefold(),model.casefold(),yr,discipline.casefold())
 if key in seen:continue
 seen.add(key)
 vehicles.append({"id":"crew:"+slug(f"{discipline}-{brand}-{model}-{yr}"),
  "make":brand.replace("®","").strip(),"model":model.strip(),"year":yr,
  "discipline":discipline,"image":"","imageSource":"","imageMatch":"","catalogueSource":"Ubisoft official"})

print("UBISOFT TABLE ROWS",len(p.rows),"UNIQUE VEHICLES",len(vehicles))
if len(vehicles)<500:
 raise SystemExit(f"Refusing suspicious Ubisoft parse: only {len(vehicles)} vehicles")

d=json.loads(OUT.read_text(encoding="utf-8"))
g=next(x for x in d["games"] if x["id"]=="crew")
g["source"]="Ubisoft official The Crew Motorfest vehicle list"
g["sourceUrl"]=URL
g["vehicles"]=vehicles
g["catalogueCount"]=len(vehicles)
g["imageCoverage"]=0
g["catalogueVerifiedAt"]="2026-09-28"
OUT.write_text(json.dumps(d,ensure_ascii=False,indent=2)+"\n",encoding="utf-8")
print("MOTORFEST OFFICIAL CATALOGUE",len(vehicles),"vehicles")
