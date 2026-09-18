"""Bundle first-party UI and pinned CDN resources for deterministic cold offline start."""
from pathlib import Path
import hashlib, json, re, shutil, urllib.request, time
from urllib.parse import urlsplit
root=Path(__file__).resolve().parents[2]
out=root/'firemap-android/app/src/main/assets/www'
if out.exists():shutil.rmtree(out)
out.mkdir(parents=True)
for pattern in ('*.html','*.js','*.css','*.json','*.png','*.svg'):
 for p in root.glob(pattern):shutil.copyfile(p,out/p.name)
# CDN versions are pinned in this build, also for scripts injected by JS modules.
pins={'https://cdn.jsdelivr.net/npm/@supabase/supabase-js@2':'https://cdn.jsdelivr.net/npm/@supabase/supabase-js@2.57.4/dist/umd/supabase.js',
'https://cdn.jsdelivr.net/npm/@tomickigrzegorz/leaflet-rotate/dist/leaflet-rotate.umd.min.js':'https://cdn.jsdelivr.net/npm/@tomickigrzegorz/leaflet-rotate@0.2.4/dist/leaflet-rotate.umd.min.js',
'https://cdn.jsdelivr.net/npm/@tomickigrzegorz/leaflet-rotate/dist/leaflet-rotate.css':'https://cdn.jsdelivr.net/npm/@tomickigrzegorz/leaflet-rotate@0.2.4/dist/leaflet-rotate.css'}
manifest={}
def vendor(url):
 if url in manifest:return manifest[url]['path']
 actual=pins.get(url,url)
 print("Bundling",actual,flush=True)
 suffix=Path(urlsplit(actual).path).suffix
 if suffix not in ('.css','.js','.png','.gif','.svg','.woff2'):suffix='.js'
 name='vendor/'+hashlib.sha256(actual.encode()).hexdigest()[:20]+suffix
 for attempt in range(3):
  try:
   with urllib.request.urlopen(actual,timeout=40) as r:data=r.read()
   break
  except Exception:
   if attempt==2:raise
   time.sleep(2)
 dest=out/name;dest.parent.mkdir(exist_ok=True);dest.write_bytes(data)
 manifest[url]={'url':actual,'path':name,'sha256':hashlib.sha256(data).hexdigest()}
 if name.endswith('.css'):
  from urllib.parse import urljoin
  css=data.decode()
  for item in re.findall(r'url\([\"\x27]?([^\)\"\x27]+)',css):
   if not item.startswith(('data:','#')):
    child=vendor(urljoin(actual,item));css=css.replace(item,Path(child).name)
  dest.write_text(css)
 return name
for p in list(out.glob('*.html')):
 s=p.read_text()
 for url in re.findall(r'(?:src|href)=[\"\x27](https://cdn.jsdelivr.net/[^\"\x27]+)',s):s=s.replace(url,vendor(url))
 p.write_text(s)
(out/'bundle-manifest.json').write_text(json.dumps(manifest,indent=2))
print('Bundled',len(list(out.rglob('*'))),'files and',len(manifest),'CDN resources')
