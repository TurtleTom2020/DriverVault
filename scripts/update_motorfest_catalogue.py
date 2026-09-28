#!/usr/bin/env python3
"""Build Motorfest catalogue: complete launch roster + Ubisoft current additions."""
import html,json,re,urllib.request
from html.parser import HTMLParser
from pathlib import Path
BASE="https://www.onlineracedriver.com/2023/09/01/the-crew-motorfest-full-vehicle-list/"\nBASE2="https://www.thesixthaxis.com/2023/08/02/the-crew-motorfest-all-cars-bikes-boats-planes/"
UBI="https://www.ubisoft.com/en-gb/game/the-crew/motorfest/news-updates/6eTRFZ2OQC9SAC1Psddaqg"
SEASONS=[
("Season 7","https://www.ubisoft.com/en-gb/game/the-crew/motorfest/news-updates/4zdveUCcdcqpIglTtV4iys"),
("Season 9","https://www.ubisoft.com/en-gb/game/the-crew/motorfest/news-updates/4Srr3M0u5VudAA41aIJIfh"),
("Season 10","https://www.ubisoft.com/en-us/game/the-crew/motorfest/news-updates/4TJ7qt604DHgSsCMc5qsKr"),
]
OUT=Path("assets/catalog/catalog.json")
UA={"User-Agent":"Mozilla/5.0 DriverVault catalogue builder"}

def get(u):return urllib.request.urlopen(urllib.request.Request(u,headers=UA),timeout=60).read().decode("utf-8","replace")
def txt(x):return html.unescape(" ".join(re.sub(r"<[^>]+>"," ",x).split()))
def slug(s):return re.sub(r"[^a-z0-9]+","-",html.unescape(s).lower().replace("®","")).strip("-")
def split_name(name):
 makes=("Aston Martin","Alfa Romeo","Land Rover","Mercedes-AMG","Mercedes-Benz","Red Bull","North American","Northrop Grumman","Granville Brothers Aircraft","Waco Aircraft Corp.","Extra Aerobatic Planes","Ivory Tower","Forsberg Racing","Harley-Davidson","Genty Automobile","W Motors","PHAZR RC")
 make=next((x for x in makes if name.casefold().startswith(x.casefold()+" ")),name.split()[0])
 return make,name[len(make):].strip()

vehicles=[];seen=set()
def add(make,model,year,discipline,source):
 if not make or not model:return
 key=(re.sub(r"[^a-z0-9]+","",make.casefold()),re.sub(r"[^a-z0-9]+","",model.casefold()),int(year))
 if key in seen:return
 seen.add(key);vehicles.append({"id":"crew:"+slug(f"{discipline}-{make}-{model}-{year}"),"make":make,"model":model,"year":int(year),"discipline":discipline,"image":"","imageSource":"","imageMatch":"","catalogueSource":source})

# Complete 600+ launch roster: list items under discipline headings.
raw=get(BASE)+"\\n"+get(BASE2); section="Motorfest"
for token in re.split(r'(<h[23][^>]*>.*?</h[23]>|<li[^>]*>.*?</li>)',raw,flags=re.I|re.S):
 if re.match(r"<h[23]",token,re.I):
  h=txt(token)
  if h and "vehicle list" not in h.lower():section=h
 elif re.match(r"<li",token,re.I):
  line=txt(token);m=re.match(r"^(19\d{2}|20\d{2})\s+(.+)$",line)
  if m:
   make,model=split_name(m.group(2));add(make,model,int(m.group(1)),section,"Complete launch roster")

class Tables(HTMLParser):
 def __init__(self):super().__init__();self.rows=[];self.row=None;self.cell=None;self.head=None;self.heading=""
 def handle_starttag(self,t,a):
  if t in ("h1","h2","h3","h4","h5"):self.head=[]
  elif t=="tr":self.row=[]
  elif t in ("td","th") and self.row is not None:self.cell=[]
 def handle_data(self,d):
  if self.head is not None:self.head.append(d)
  if self.cell is not None:self.cell.append(d)
 def handle_endtag(self,t):
  if t in ("h1","h2","h3","h4","h5") and self.head is not None:self.heading=" ".join("".join(self.head).split()) or self.heading;self.head=None
  elif t in ("td","th") and self.cell is not None:self.row.append(" ".join("".join(self.cell).split()));self.cell=None
  elif t=="tr" and self.row is not None:
   if len(self.row)>=3:self.rows.append((self.heading,self.row))
   self.row=None
def overlay(url,source):
 p=Tables();p.feed(get(url));before=len(vehicles)
 for heading,row in p.rows:
  c=[x.strip() for x in row if x.strip()];yi=next((i for i,x in enumerate(c) if re.match(r"^(?:19|20)\d{2}",x)),None)
  if yi is None or yi<2:continue
  make,model=c[yi-2],c[yi-1];ym=re.match(r"((?:19|20)\d{2})",c[yi])
  if not ym or make.lower()=="brand" or not model or "to be revealed" in make.lower():continue
  discipline=re.sub(r"[^A-Za-z0-9 &/-]+","",heading).strip() or "Motorfest"
  add(make.replace("®","").strip(),model,int(ym.group(1)),discipline,source)
 print(source,"NEW VEHICLES",len(vehicles)-before)

launch=len(vehicles);print("COMPLETE LAUNCH ROSTER",launch)
overlay(UBI,"Ubisoft master list")
for name,url in SEASONS:overlay(url,"Ubisoft "+name)
if launch<600:raise SystemExit(f"Refusing incomplete launch roster: {launch}")
if len(vehicles)<600:
 raise SystemExit(f"Refusing incomplete merged roster: {len(vehicles)}")
if len(vehicles)>800:
 raise SystemExit(f"Refusing duplicate-inflated merged roster: {len(vehicles)}")
d=json.loads(OUT.read_text(encoding="utf-8"));g=next(x for x in d["games"] if x["id"]=="crew")
g.update({"source":"Complete launch roster cross-checked and extended with Ubisoft official lists","sourceUrl":UBI,"secondarySourceUrl":BASE,"launchCrossCheckUrl":BASE2,"vehicles":vehicles,"catalogueCount":len(vehicles),"imageCoverage":0,"catalogueVerifiedAt":"2026-09-28"})
OUT.write_text(json.dumps(d,ensure_ascii=False,indent=2)+"\n",encoding="utf-8")
print("MOTORFEST MERGED CATALOGUE",len(vehicles))
