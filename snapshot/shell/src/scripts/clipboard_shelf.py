#!/usr/bin/env python3
"""Private clipboard shelf using the existing cliphist store."""
import hashlib, io, json, os, re, subprocess, sys, tempfile
from pathlib import Path
from PIL import Image

state = Path(os.environ.get('XDG_STATE_HOME', Path.home()/'.local/state'))/'serpantinum/clipboard-shelf'
run = Path(os.environ.get('XDG_RUNTIME_DIR', '/tmp'))/'serpantinum-clipboard-previews'
for p in (state, run):
    p.mkdir(mode=0o700, parents=True, exist_ok=True)
    os.chmod(p, 0o700)
meta = state/'pins.json'

def load():
    try:
        x=json.loads(meta.read_text()); return x if isinstance(x,list) else []
    except (OSError, ValueError): return []

def save(pins):
    fd, name=tempfile.mkstemp(dir=state, prefix='.pins-')
    with os.fdopen(fd,'w') as f: json.dump(pins, f, ensure_ascii=False)
    os.replace(name, meta); os.chmod(meta,0o600)

def decode_line(line):
    return subprocess.run(['cliphist','decode'], input=line+b'\n', stdout=subprocess.PIPE, stderr=subprocess.DEVNULL, check=True, timeout=8).stdout

def decode(ident):
    if not re.fullmatch(r'\d+', ident): raise ValueError('Invalid clipboard entry')
    raw = subprocess.run(['cliphist','list'], stdout=subprocess.PIPE, stderr=subprocess.DEVNULL, check=True, timeout=8).stdout
    line = next((line for line in raw.splitlines() if line.split(b'\t', 1)[0] == ident.encode()), None)
    if line is None: raise ValueError('Clipboard item is no longer available')
    return decode_line(line)

def kind(data):
    if data.startswith(b'\x89PNG\r\n\x1a\n'): return 'image/png'
    if data.startswith(b'\xff\xd8\xff'): return 'image/jpeg'
    if data.startswith((b'GIF87a',b'GIF89a')): return 'image/gif'
    if data[:4]==b'RIFF' and data[8:12]==b'WEBP': return 'image/webp'
    return 'text/plain;charset=utf-8'

def preview(data, key):
    try:
        out=run/(key+'.png')
        if not out.exists():
            with Image.open(io.BytesIO(data)) as im:
                im.thumbnail((240,140)); im.convert('RGB').save(out,format='PNG')
            os.chmod(out,0o600)
        return out.as_uri()
    except Exception: return ''

def listing(query=''):
    query=query.casefold().strip()
    pins=load(); result=[]; generated_previews=0
    for p in pins:
        path=state/(p['hash']+'.data')
        if not path.is_file(): continue
        row=dict(p, pinned=True, key='pin:'+p['hash'])
        if query and query not in row.get('label','').casefold():
            if row.get('image') or query not in path.read_bytes().decode('utf-8','replace').casefold(): continue
        if row.get('image'): row['thumbnail']=preview(path.read_bytes(),p['hash'])
        result.append(row)
    raw=subprocess.run(['cliphist','list'],stdout=subprocess.PIPE,stderr=subprocess.DEVNULL,check=True,timeout=8).stdout.decode('utf-8','replace')
    for line in raw.splitlines()[:10]:
        ident, sep, label=line.partition('\t')
        if not sep or not ident.isdigit(): continue
        image=label.startswith('[[ binary data') and any(s in label.lower() for s in (' png',' jpeg',' jpg',' webp',' gif'))
        if label.startswith('[[ binary data') and not image: continue
        shown = 'Image' if image else label
        if query and query not in shown.casefold():
            if image or label.startswith('[[ binary data'): continue
            try:
                if query not in decode_line(line.encode('utf-8')).decode('utf-8','replace').casefold(): continue
            except Exception: continue
        row={'key':'clip:'+ident,'id':ident,'label':shown,'image':image,'pinned':False,'thumbnail':''}
        if image:
            cached = run/('clip-'+ident+'.png')
            if cached.exists(): row['thumbnail'] = cached.as_uri()
            elif generated_previews < 12:
                try:
                    row['thumbnail']=preview(decode_line(line.encode('utf-8')),'clip-'+ident)
                    generated_previews += 1
                except Exception: pass
        result.append(row)
    print(json.dumps(result,ensure_ascii=False))

def main():
    op=sys.argv[1]
    if op=='list': listing(sys.argv[2] if len(sys.argv)>2 else ''); return
    if op=='pin':
        data=decode(sys.argv[2]); h=hashlib.sha256(data).hexdigest(); mime=kind(data)
        label='Image' if mime.startswith('image/') else ' '.join(data.decode('utf-8','replace').split())[:180]
        path=state/(h+'.data'); path.write_bytes(data); os.chmod(path,0o600)
        pins=load(); pins=[p for p in pins if p.get('hash')!=h]; pins.insert(0,{'hash':h,'label':label,'image':mime.startswith('image/'),'mime':mime}); save(pins); return
    if op=='unpin':
        h=sys.argv[2]
        if not re.fullmatch('[0-9a-f]{64}',h): raise ValueError('Invalid pin')
        save([p for p in load() if p.get('hash')!=h]); (state/(h+'.data')).unlink(missing_ok=True); return
    if op=='copy':
        typ, ident=sys.argv[2:4]
        if typ=='pin' and re.fullmatch('[0-9a-f]{64}',ident): data=(state/(ident+'.data')).read_bytes()
        elif typ=='clip': data=decode(ident)
        else: raise ValueError('Invalid clipboard entry')
        subprocess.run(['wl-copy','--type',kind(data)],input=data,check=True,timeout=8); return
    raise ValueError('Unknown action')
if __name__=='__main__':
    try: main()
    except Exception as e:
        print(json.dumps({'error':str(e)})); sys.exit(1)
