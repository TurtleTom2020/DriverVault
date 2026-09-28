#!/usr/bin/env python3
"""DriverVault v2.0 game-image mapper.
Searches game-specific MediaWiki/Fandom repositories for vehicle artwork, validates
that each URL returns real image bytes, and writes only verified mappings.
Existing FH5 mappings are preserved.
"""
import json,re,time,unicodedata,urllib.parse,urllib.request
from concurrent.futures import ThreadPoolExecutor,as_completed
from pathlib import Path

CAT=Path('assets/catalog/catalog.json')
data=json.loads(CAT.read_text(encoding='utf-8'))
UA='DriverVault/2.0 (+https://github.com/TurtleTom2020/DriverVault)'

SOURCES={
 'fh5':['https://forza.fandom.com/api.php'],
 'carx':['https://carx.fandom.com/api.php'],
 'beamng':['https://beamng.fandom.com/api.php'],
 'ets2':['https://truck-simulator.fandom.com/api.php'],
 'ats':['https://truck-simulator.fandom.com/api.php'],
 'assetto':[],
 'wrc':['https://easportswrc.fandom.com/api.php','https://wrc.fandom.com/api.php'],
 'alaskan':['https://alaskanroadtruckers.wiki.gg/api.php','https://alaskan-road-truckers.fandom.com/api.php'],
 'mudrunner':['https://spintires.fandom.com/api.php'],
 'snowrunner':['https://spintires.fandom.com/api.php'],
 'gt7':['https://gran-turismo.fandom.com/api.php'],
}
GAME_TERMS={'fh5':'Forza Horizon 5','carx':'CarX','beamng':'BeamNG','ets2':'Euro Truck Simulator 2','ats':'American Truck Simulator','assetto':'Assetto Corsa','wrc':'EA SPORTS WRC','alaskan':'Alaskan Road Truckers','mudrunner':'MudRunner','snowrunner':'SnowRunner','gt7':'Gran Turismo 7'}

def norm(s):
 s=unicodedata.normalize('NFKD',str(s)).encode('ascii','ignore').decode().lower()
 return re.sub(r'[^a-z0-9]+',' ',s).strip()

def request_json(url,attempts=4):
 last=None
 for n in range(attempts):
  try:
   req=urllib.request.Request(url,headers={'User-Agent':UA,'Accept':'application/json'})
   with urllib.request.urlopen(req,timeout=25) as r:return json.loads(r.read().decode('utf-8','replace'))
  except Exception as e:last=e;time.sleep(1.5*(n+1))
 raise last

def image_ok(url):
 try:
  req=urllib.request.Request(url,headers={'User-Agent':UA,'Range':'bytes=0-2047'})
  with urllib.request.urlopen(req,timeout=20) as r:
   c=(r.headers.get('Content-Type') or '').lower(); b=r.read(2048)
   return c.startswith('image/') and len(b)>64 and (b.startswith(b'\x89PNG') or b.startswith(b'\xff\xd8') or b[:4] in (b'RIFF',b'GIF8') or b.startswith(b'\x00\x00\x00'))
 except Exception:return False

def vehicle_label(v): return ' '.join(x for x in [str(v.get('make','')).strip(),str(v.get('model','')).strip(),str(v.get('year','')).strip()] if x).strip()

def score(title,label,gid):
 t=norm(title); q=norm(label); qt=set(q.split()); tt=set(t.split())
 if not qt:return -999
 bad=('logo','icon','badge','map','track','livery editor','screenshot ui','manufacturer','flag','helmet','wheel')
 if any(x in t for x in bad):return -500
 sc=40*len(qt&tt)-22*len(qt-tt)-5*len(tt-qt)
 if q in t:sc+=220
 model=norm(label.rsplit(' ',1)[0]);
 if model and model in t:sc+=80
 if norm(GAME_TERMS[gid]) in t:sc+=30
 return sc

def candidates(api,label,gid):
 # Search file namespace directly. A second shorter query helps names containing years/quotes.
 queries=[label, re.sub(r"[‘’']?\d{2,4}$",'',label).strip()]
 out=[]; seen=set()
 for q in queries:
  params={'action':'query','generator':'search','gsrsearch':q,'gsrnamespace':'6','gsrlimit':'12','prop':'imageinfo','iiprop':'url|mime|size','iiurlwidth':'1000','format':'json','formatversion':'2'}
  root=request_json(api+'?'+urllib.parse.urlencode(params))
  for p in root.get('query',{}).get('pages',[]):
   ii=(p.get('imageinfo') or [{}])[0]; u=ii.get('thumburl') or ii.get('url') or ''
   if not u.startswith('https://') or not str(ii.get('mime','')).startswith('image/'):continue
   if u in seen:continue
   seen.add(u);out.append((score(p.get('title',''),label,gid),p.get('title',''),u,ii.get('width',0),ii.get('height',0)))
 return sorted(out,reverse=True)

def page_candidates(api,label,gid):
 # Many game wikis keep the useful vehicle image on the article page rather than
 # in a filename containing the vehicle name. Search articles, then request their
 # lead/page image. This fixes sources where namespace-6 file search returns zero.
 out=[]; seen=set()
 queries=[label, re.sub(r"[‘’']?\d{2,4}$",'',label).strip()]
 for q in queries:
  try:
   params={'action':'query','generator':'search','gsrsearch':q,'gsrnamespace':'0','gsrlimit':'8',
           'prop':'pageimages','piprop':'thumbnail|original|name','pithumbsize':'1200',
           'format':'json','formatversion':'2'}
   root=request_json(api+'?'+urllib.parse.urlencode(params),attempts=2)
   for page in root.get('query',{}).get('pages',[]):
    u=((page.get('thumbnail') or {}).get('source') or (page.get('original') or {}).get('source') or '')
    if not u.startswith('https://') or u in seen: continue
    seen.add(u)
    sc=score(page.get('title',''),label,gid)+90
    out.append((sc,page.get('title',''),u,0,0))
  except Exception: pass
 return sorted(out,reverse=True)

def direct_pageimage(api,label,gid):
 # Exact-title pass catches short MudRunner/SnowRunner names such as C-255.
 try:
  params={'action':'query','titles':label,'prop':'pageimages','piprop':'thumbnail|original|name',
          'pithumbsize':'1200','format':'json','formatversion':'2'}
  root=request_json(api+'?'+urllib.parse.urlencode(params),attempts=2)
  for page in root.get('query',{}).get('pages',[]):
   u=((page.get('thumbnail') or {}).get('source') or (page.get('original') or {}).get('source') or '')
   if u.startswith('https://') and image_ok(u): return u,api,page.get('title',''),999
 except Exception: pass
 return None


def slugify(s):
 s=unicodedata.normalize('NFKD',str(s)).encode('ascii','ignore').decode().lower()
 s=s.replace('&',' and ')
 return re.sub(r'[^a-z0-9]+','-',s).strip('-')

def request_html(url,attempts=3):
 for n in range(attempts):
  try:
   req=urllib.request.Request(url,headers={'User-Agent':'Mozilla/5.0 (DriverVault catalogue validator)','Accept':'text/html,application/xhtml+xml'})
   with urllib.request.urlopen(req,timeout=30) as r:return r.read(4000000).decode('utf-8','replace')
  except Exception:
   if n+1==attempts:return ''
   time.sleep(1.5*(n+1))
 return ''

def abs_url(base,u):
 u=(u or '').replace('&amp;','&').strip()
 if u.startswith('//'):return 'https:'+u
 return urllib.parse.urljoin(base,u)

def igcd_assetto_entries():
 """Read IGCD's Assetto Corsa playable-car catalogue once.
    We never import its roster: DriverVault's 178 cars remain the whitelist."""
 base='https://www.igcd.net/'
 out=[]; seen=set()
 for page in (1,2,3):
  url=f'https://www.igcd.net/game.php?id=1000009050&l=en&page={page}&resultsStyle=jouable'
  html=request_html(url)
  if not html: continue
  # IGCD layouts have changed over time, so collect every vehicle.php link and
  # use a generous surrounding card fragment for title + thumbnail extraction.
  for m in re.finditer(r'href=["\']([^"\']*vehicle\.php\?id=\d+[^"\']*)["\']',html,re.I):
   href=abs_url(base,m.group(1)); key=re.search(r'id=(\d+)',href)
   if not key or key.group(1) in seen:continue
   seen.add(key.group(1)); frag=html[max(0,m.start()-1800):min(len(html),m.end()+1800)]
   text=re.sub(r'<script.*?</script>|<style.*?</style>',' ',frag,flags=re.I|re.S)
   text=re.sub(r'<[^>]+>',' ',text); text=re.sub(r'&[^;]+;',' ',text); text=re.sub(r'\s+',' ',text).strip()
   imgs=[abs_url(base,x) for x in re.findall(r'<img[^>]+(?:src|data-src)=["\']([^"\']+)',frag,re.I)]
   imgs=[x for x in imgs if x.startswith('http') and not any(b in x.lower() for b in ('logo','flag','icon','avatar','star'))]
   out.append({'page':href,'text':text,'imgs':imgs})
 return out

IGCD_ASSETTO=None
IGCD_WRC=None

def igcd_game_entries(game_id):
 base='https://www.igcd.net/'
 out=[]; seen=set()
 for page in (1,2,3):
  url=f'https://www.igcd.net/game.php?id={game_id}&l=en&page={page}&resultsStyle=jouable'
  html=request_html(url)
  if not html: continue
  for m in re.finditer(r'href=[\"\']([^\"\']*vehicle\.php\?id=\d+[^\"\']*)[\"\']',html,re.I):
   href=abs_url(base,m.group(1)); key=re.search(r'id=(\d+)',href)
   if not key or key.group(1) in seen: continue
   seen.add(key.group(1)); frag=html[max(0,m.start()-1800):min(len(html),m.end()+1800)]
   text=re.sub(r'<[^>]+>',' ',frag); text=re.sub(r'&[^;]+;',' ',text); text=re.sub(r'\s+',' ',text).strip()
   imgs=[abs_url(base,x) for x in re.findall(r'<img[^>]+(?:src|data-src)=[\"\']([^\"\']+)',frag,re.I)]
   imgs=[x for x in imgs if x.startswith('http') and not any(b in x.lower() for b in ('logo','flag','icon','avatar','star'))]
   out.append({'page':href,'text':text,'imgs':imgs})
 return out

def igcd_image_for(v, entries, gid, aliases=()):
 labels=[vehicle_label(v)]+list(aliases)
 ranked=[]
 for e in entries:
  best=-999
  for label in labels:
   sc=score(e['text'],label,gid); q=set(norm(label).split()); t=set(norm(e['text']).split())
   sc+=35*len(q&t)-25*len(q-t); best=max(best,sc)
  ranked.append((best,e))
 ranked.sort(key=lambda x:x[0],reverse=True)
 for sc,e in ranked[:12]:
  if sc<40: continue
  html=request_html(e['page'],attempts=2); urls=[]
  if html:
   for pat in (r'<meta[^>]+(?:property|name)=[\"\'](?:og:image|twitter:image)[\"\'][^>]+content=[\"\']([^\"\']+)',r'<img[^>]+(?:src|data-src)=[\"\']([^\"\']+)'):
    urls += [abs_url(e['page'],x) for x in re.findall(pat,html,re.I)]
  urls += e['imgs']
  for u in dict.fromkeys(urls):
   if u.startswith('http') and not any(x in u.lower() for x in ('logo','flag','icon','avatar','favicon','banner')) and image_ok(u):
    return u,e['page'],e['text'][:180],sc
 return None

def assetto_igcd_image(v):
 global IGCD_ASSETTO
 label=vehicle_label(v)
 if IGCD_ASSETTO is None: IGCD_ASSETTO=igcd_assetto_entries()
 ranked=[]
 for e in IGCD_ASSETTO:
  sc=score(e['text'],label,'assetto')
  # score() sees the whole card fragment; add a token-overlap score that is
  # deliberately tolerant of IGCD placing year before make/model.
  q=set(norm(label).split()); t=set(norm(e['text']).split())
  sc+=35*len(q&t)-25*len(q-t)
  ranked.append((sc,e))
 ranked.sort(key=lambda x:x[0],reverse=True)
 for sc,e in ranked[:10]:
  if sc<40:continue
  # Individual page usually exposes the larger screenshot. If it does not,
  # the catalogue thumbnail is still an actual in-game capture and is valid.
  html=request_html(e['page'],attempts=2)
  urls=[]
  if html:
   for pat in (r'<meta[^>]+(?:property|name)=["\'](?:og:image|twitter:image)["\'][^>]+content=["\']([^"\']+)',
               r'<img[^>]+(?:src|data-src)=["\']([^"\']+)'):
    urls += [abs_url(e['page'],x) for x in re.findall(pat,html,re.I)]
  urls += e['imgs']
  done=set()
  for u in urls:
   if not u.startswith('http') or u in done:continue
   done.add(u); low=u.lower()
   if any(x in low for x in ('logo','flag','icon','avatar','favicon','banner')):continue
   if image_ok(u):return u,e['page'],e['text'][:180],sc
 return None

def fh5_variant_ok(v,title,url=''):
 # FH5 mappings must be an actual FH5 vehicle asset, never a make icon,
 # an older/newer Forza render, or a vaguely related donor car.
 need=norm(vehicle_label(v)); got=norm(title); low=(title+' '+url).lower()
 if any(x in low for x in ('icon make','icon_make','logo','badge','fh6_','fh6 ','fm4_','fm4 ','mot_')):
  return False
 # Make alone is never enough. Require at least two meaningful model tokens.
 stop={'the','and','forza','edition','welcome','pack','movie','studios','racing','motorsports','motorsport'}
 make=set(norm(str(v.get('make',''))).split())
 model=[x for x in norm(str(v.get('model',''))).split() if x not in stop and x not in make and len(x)>1]
 overlap=sum(1 for x in set(model) if x in set(got.split()))
 if len(set(model))>=2 and overlap<2:return False
 if len(set(model))==1 and overlap<1:return False
 checks=[]
 if 'forza edition' in need: checks.append(('forza edition' in got) or re.search(r'\\bfe\\b',got))
 if 'welcome pack' in need: checks.append(('welcome pack' in got) or re.search(r'\\bwp\\b',got))
 if 'oreo edition' in need: checks.append('oreo' in got)
 if 'barbie movie' in need: checks.append('barbie' in got)
 if 'fast x' in need: checks.append(('fast x' in got) or ('fast and furious' in got))
 if 'jurassic park' in need: checks.append('jurassic' in got)
 if 'back to the future' in need: checks.append(('back to the future' in got) or ('bttf' in got))
 if 'k i t t' in need: checks.append(('k i t t' in got) or ('kitt' in got))
 return all(checks)

def map_one(gid,v):
 label=vehicle_label(v)
 if gid=='assetto':
  hit=assetto_igcd_image(v)
  if hit:return hit
  # AC variants often use a base-model IGCD title; retry without tune suffixes.
  global IGCD_ASSETTO
  if IGCD_ASSETTO is None: IGCD_ASSETTO=igcd_assetto_entries()
  base=re.sub(r'\b(step\s*\d+|drift|tuned|stage\s*\d+|akrapovic edition|roadster|v6 cup|long tail|short tail|time attack|awd|gr\.a\s*92)\b',' ',label,flags=re.I)
  base=re.sub(r'\s+',' ',base).strip()
  if base and base!=label:
   hit=igcd_image_for(v,IGCD_ASSETTO,'assetto',[base])
   if hit:return hit
 if gid=='wrc':
  global IGCD_WRC
  if IGCD_WRC is None: IGCD_WRC=igcd_game_entries('1000016887')
  aliases=[re.sub(r'\s+HYBRID','',label,flags=re.I), re.sub(r'[‘’"\']?2[34][‘’"\']?','',label)]
  hit=igcd_image_for(v,IGCD_WRC,'wrc',aliases)
  if hit:return hit
 if gid=='alaskan':
  # Official wiki spelling is Conveyer. E/P are economy/performance variants
  # of the same family, so try the exact variant article then the base article.
  aliases=[label]
  base=re.sub(r'\s+[EP]$','',label).strip()
  if base not in aliases: aliases.append(base)
  for alias in aliases:
   for api in SOURCES[gid]:
    exact=direct_pageimage(api,alias,gid)
    if exact:return exact
    try:
     for sc,title,u,w,h in sorted(page_candidates(api,alias,gid)+candidates(api,alias,gid),reverse=True)[:12]:
      if sc>=45 and image_ok(u):return u,api,title,sc
    except Exception:pass
 for api in SOURCES[gid]:
  exact=direct_pageimage(api,label,gid)
  if exact:return exact
  try:
   # Article images first, then filename search. Article images are substantially
   # more reliable on Spintires, Assetto and wiki.gg.
   cs=page_candidates(api,label,gid)+candidates(api,label,gid)
   cs=sorted(cs,reverse=True)
   for sc,title,u,w,h in cs[:8]:
    if sc<55:continue
    if gid=='fh5' and not fh5_variant_ok(v,title,u):continue
    if w and h and max(w,h)<300:continue
    if image_ok(u):return u,api,title,sc
  except Exception:continue
 return None

def ensure_ids(g):
 used=set()
 for i,v in enumerate(g.get('vehicles',[])):
  if v.get('id'):used.add(v['id']);continue
  slug=norm(vehicle_label(v)).replace(' ','-') or str(i+1); base=f"{g['id']}:{slug}"; x=base;n=2
  while x in used:x=f'{base}-{n}';n+=1
  v['id']=x;used.add(x)

for g in data['games']:ensure_ids(g)

for g in data['games']:
 gid=g['id']
 if gid not in SOURCES:continue
 vehicles=g.get('vehicles',[])
 todo=[v for v in vehicles if not str(v.get('image','')).strip()]
 print(f'[{gid}] searching {len(todo)} unmapped vehicles...')
 mapped=0
 with ThreadPoolExecutor(max_workers=10) as ex:
  fut={ex.submit(map_one,gid,v):v for v in todo}
  for n,f in enumerate(as_completed(fut),1):
   v=fut[f]
   try:r=f.result()
   except Exception:r=None
   if r:
    u,api,title,sc=r;v['image']=u;v['imageSource']=api;v['imageMatch']=title;mapped+=1
   if n%25==0:print(f'  {n}/{len(todo)} checked, {mapped} new mappings')
 coverage=sum(bool(str(v.get('image','')).strip()) for v in vehicles)
 g['imageCoverage']=coverage;g['imageVerifiedAt']='2026-09-27'
 print(f'[{gid}] VERIFIED IMAGE COVERAGE {coverage}/{len(vehicles)}')
 # Checkpoint after every game so a long run never loses completed mappings.
 CAT.write_text(json.dumps(data,ensure_ascii=False,indent=2),encoding='utf-8')
 print(f'[{gid}] checkpoint saved')

# Never permit the old v1.8 failure (all-zero non-FH5 catalogues) to ship.
fail=[]
for g in data['games']:
 if g['id'] in SOURCES:
  n=len(g.get('vehicles',[])); imgs=sum(bool(str(v.get('image','')).strip()) for v in g.get('vehicles',[]))
  if n and imgs==0:fail.append(g['id'])
fh=next(g for g in data['games'] if g['id']=='fh5')
if sum(bool(v.get('image')) for v in fh['vehicles'])<805:raise SystemExit('FH5 regression: image coverage below 805')
if fail:raise SystemExit('ZERO-IMAGE GATE FAILED: '+', '.join(fail))
data['version']='2.0.0'
CAT.write_text(json.dumps(data,ensure_ascii=False,indent=2),encoding='utf-8')
print('Image mapping complete; zero-image gate passed for every supported game source.')
