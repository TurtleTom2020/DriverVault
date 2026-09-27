#!/usr/bin/env python3
import json, re, sys, urllib.request, urllib.parse, html, unicodedata, difflib
from concurrent.futures import ThreadPoolExecutor, as_completed
from pathlib import Path
from urllib.parse import quote

CAT=Path("assets/catalog/catalog.json")
data=json.loads(CAT.read_text(encoding="utf-8"))

MAKES=sorted([
"Abarth","Acura","Alfa Romeo","Alpine","Alumi Craft","AMC","AMG Transport Dynamics",
"Apollo","Ariel","Ascari","Aston Martin","ATS","Audi","Austin-Healey","Auto Union",
"Automobili Pininfarina","Autozam","BAC","Bentley","BMW","Brabham","Bugatti","Buick",
"Cadillac","Can-Am","Casey Currie Motorsports","Caterham","Chevrolet","Citroën","CUPRA",
"Czinger","Datsun","DeBerti","DeLorean","Dodge","Donkervoort","DS Automobiles","Eagle",
"Exomotive","Ferrari","FIAT","Ford","Formula Drift","Forsberg Racing","Funco","GMC",
"Hennessey","Holden","Honda","Hoonigan","Hot Wheels","HSV","HUMMER","Hyundai","Infiniti",
"International","Italdesign","Jaguar","Jeep","Koenigsegg","KTM","Lamborghini","Lancia",
"Land Rover","Lexus","Lincoln","Local Motors","Lola","Lotus","Lucid","Lynk & Co","Maserati",
"Mazda","McLaren","Mercedes-AMG","Mercedes-Benz","Mercury","MG","MINI","Mitsubishi",
"Morgan","Morris","Mosler","Napier","NIO","Nissan","Noble","Oldsmobile","Opel","Pagani",
"Peel","Penhall","Peugeot","Plymouth","Polaris","Pontiac","Porsche","RAESR","Radical",
"Renault","Rimac","Rivian","Rossion","RUF","Saleen","Schuppan","Shelby","Sierra Cars",
"Spania GTA","Subaru","Toyota","TVR","Ultima","Vauxhall","Volkswagen","Volvo","W Motors",
"Wuling","Xpeng","Zenvo"
], key=len, reverse=True)

def fetch(url):
    req=urllib.request.Request(url,headers={"User-Agent":"Mozilla/5.0 DriverVault/1.0"})
    with urllib.request.urlopen(req,timeout=45) as r:
        return r.read().decode("utf-8","replace")

def strip_tags(x):
    return re.sub(r"\s+"," ",html.unescape(re.sub(r"<[^>]+>","",x))).strip()

def split_make(name):
    for make in MAKES:
        if name == make or name.startswith(make+" "):
            return make, name[len(make):].strip()
    parts=name.split(" ",1)
    return (parts[0],parts[1] if len(parts)>1 else "")

def game(gid):
    return next(g for g in data["games"] if g["id"]==gid)


FANDOM_API="https://forza.fandom.com/api.php"

def fetch_json_url(url, timeout=45, attempts=5):
    import time
    last=None
    for attempt in range(attempts):
        try:
            req=urllib.request.Request(url,headers={
                "User-Agent":"DriverVault/1.5 (+https://github.com/TurtleTom2020/DriverVault)",
                "Accept":"application/json"
            })
            with urllib.request.urlopen(req,timeout=timeout) as r:
                return json.loads(r.read().decode("utf-8","replace"))
        except Exception as e:
            last=e
            time.sleep(min(2 ** attempt, 12))
    raise last

def norm(s):
    s=unicodedata.normalize('NFKD',str(s)).encode('ascii','ignore').decode().lower()
    s=s.replace('mercedes amg','mercedes-amg').replace('type r','type-r').replace('type s','type-s')
    return re.sub(r'[^a-z0-9]+',' ',s).strip()

def fandom_fh5_images():
    """Fetch the FH5-specific image category in a handful of serial MediaWiki calls.
    This avoids the 902 concurrent generic Commons searches that caused v1.4's 429s.
    """
    pages=[]; cont={}
    while True:
        params={
          'action':'query','generator':'categorymembers',
          'gcmtitle':'Category:Car Images (FH5)','gcmnamespace':'6','gcmtype':'file',
          'gcmlimit':'500','prop':'imageinfo','iiprop':'url|mime','iiurlwidth':'800',
          'format':'json','formatversion':'2','maxlag':'5'
        }
        params.update(cont)
        root=fetch_json_url(FANDOM_API+'?'+urllib.parse.urlencode(params))
        pages.extend(root.get('query',{}).get('pages',[]))
        if 'continue' not in root: break
        cont=root['continue']
    images=[]
    for p in pages:
        title=p.get('title','')
        ii=(p.get('imageinfo') or [{}])[0]
        u=ii.get('thumburl') or ii.get('url') or ''
        mime=ii.get('mime','')
        if title.startswith('File:FH5 ') and u.startswith('https://') and mime.startswith('image/'):
            images.append((title[5:],u))
    print(f'FH5 Fandom image catalogue: {len(images)} direct image files loaded')
    if len(images) < 500:
        raise RuntimeError(f'FH5 IMAGE CATALOGUE FAILED: only {len(images)} files returned')
    return images

def image_key(filename):
    x=re.sub(r'\.[A-Za-z0-9]+$','',filename)
    x=re.sub(r'^FH5\s+','',x,flags=re.I)
    # Down-rank non-card artwork. Small thumbnails are preferred where available.
    x=re.sub(r'\b(Small|Large)\b','',x,flags=re.I)
    return norm(x)

def score_image(v, filename):
    key=image_key(filename)
    target=norm(f"{v.get('make','')} {v.get('model','')}")
    model=norm(v.get('model',''))
    make=norm(v.get('make',''))
    toks=set(target.split()); kt=set(key.split())
    if not model or not make: return -999
    # Never use obvious gallery/promotional/interior shots for catalogue cards.
    bad=(' promo',' front',' rear',' interior',' dashboard',' engine',' cabin',' trunk',' xbox livery',' cars promo')
    kl=' '+key
    if any(b in kl for b in bad): return -999
    score=0
    if key==target: score+=1000
    if target in key: score+=700
    if model in key: score+=350
    if make in key: score+=180
    score+=25*len(toks & kt)-18*len(toks-kt)-8*len(kt-toks)
    if ' small' in filename.lower(): score+=120
    if str(v.get('year','')) and str(v.get('year')) in key: score+=35
    return score

def add_verified_images():
    fh=game('fh5')['vehicles']
    images=fandom_fh5_images()
    mapped=0
    for v in fh:
        ranked=sorted(((score_image(v,f),f,u) for f,u in images), reverse=True)
        best=ranked[0] if ranked else (-999,'','')
        if best[0] >= 500:
            v['image']=best[2]; v['imageSource']='Forza Wiki FH5 image catalogue'; mapped+=1
    print(f'FH5 image mapping: {mapped}/902 matched to FH5-specific artwork')

    # Exact cars from the user's blank-card screenshot must all map.
    expected=[
      ('Abarth','124 Spider'),('Abarth','695 Biposto'),('Abarth','Fiat 131'),
      ('Abarth','595 esseesse'),('Acura','NSX'),('Acura','RSX Type-S')
    ]
    for make,model in expected:
        matches=[v for v in fh if v.get('make')==make and v.get('model')==model]
        if not matches or not matches[0].get('image'):
            raise RuntimeError(f'IMAGE MATCH GATE FAILED: {make} {model}')
        print('Image mapped:',make,model)
    if mapped < 600:
        raise RuntimeError(f'IMAGE COVERAGE GATE FAILED: only {mapped}/902 mapped')
    print(f'FH5 image gate passed: {mapped}/902 mapped; screenshot cars 6/6')

def update_fh5():
    raw=fetch("https://forza.net/fh5cars")
    rows=re.findall(r"<tr[^>]*>(.*?)</tr>",raw,re.I|re.S)
    out=[]
    for row in rows:
        cells=[strip_tags(x) for x in re.findall(r"<td[^>]*>(.*?)</td>",row,re.I|re.S)]
        if len(cells)<6 or not re.match(r"^\d{4}\s",cells[0]): continue
        year,name=cells[0].split(" ",1)
        make,model=split_make(name)
        car_id=re.sub(r"\D","",cells[5])
        if not car_id: continue
        out.append({
          "id":f"fh5:{car_id}","year":year,"make":make,"model":model,
          "class":cells[1],"drive":"","collect":cells[2],"added":cells[3],
          "nickname":cells[4],"image":""
        })
    if len(out)!=902:
        raise RuntimeError(f"FH5 validation FAILED: expected 902, parsed {len(out)}")
    g=game("fh5"); g["vehicles"]=out; g["official_total"]=902
    g["source"]="https://forza.net/fh5cars"; g["verifiedAt"]="2026-09-27"
    print("FH5: 902/902 validated")

def update_gt7():
    raw=fetch("https://raw.githubusercontent.com/jbhoorasingh/gt7-datalogger/main/backend/app/data/cars.json")
    root=json.loads(raw); cars=root["cars"]; out=[]
    for cid,c in cars.items():
        name=(c.get("name") or "").strip()
        full=(c.get("full_name") or "").strip()
        make=(c.get("manufacturer") or "").strip()
        model=name or full
        # Official Gran Turismo car-list detail route uses the numeric vehicle id.
        image=f"https://www.gran-turismo.com/images/c/i1QHdbil7nGQk.jpg" if False else ""
        out.append({
          "id":f"gt7:{cid}","year":str(c.get("year") or ""),
          "make":make,"model":model,"class":str(c.get("category") or ""),
          "drive":str(c.get("drivetrain") or ""),"image":image
        })
    if len(out)<570:
        raise RuntimeError(f"GT7 validation FAILED: parsed only {len(out)}")
    g=game("gt7"); g["vehicles"]=out; g["official_total"]=len(out)
    g["source"]=root.get("meta",{}).get("source","Gran Turismo official car list")
    g["verifiedAt"]=root.get("meta",{}).get("generated","2026-09-27")
    print(f"GT7: {len(out)} vehicles validated")

update_fh5()
update_gt7()
add_verified_images()

# Hard validation for catalogues we have completed locally.
expected={"assetto":178,"snowrunner":116,"alaskan":19,"mudrunner":35}
for gid,n in expected.items():
    actual=len(game(gid)["vehicles"])
    if actual!=n: raise RuntimeError(f"{gid}: expected {n}, got {actual}")
    print(f"{gid}: {actual}/{n} validated")

data["version"]="1.5.0"
CAT.write_text(json.dumps(data,ensure_ascii=False,indent=2),encoding="utf-8")
print("Catalogue validation complete.")
