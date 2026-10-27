#!/usr/bin/env python3
"""Offline resource integrity and map reachability checks (not a Godot runtime test)."""
from pathlib import Path
from PIL import Image
from collections import deque
import re, json, yaml

ROOT=Path(__file__).resolve().parents[1]

# Main2 deliberately removed legacy authored artwork. The old prototype
# filename is a logical slot, not a physical PNG path on this branch.
MIGRATION_FILE=ROOT/'data/assets/c_third_party_only_migration_v1.json'
MIGRATION={}
if MIGRATION_FILE.exists():
 migration=json.loads(MIGRATION_FILE.read_text(encoding='utf8'))
 for row in migration.get('mappings',[]):
  old=row.get('old_path','')
  new=row.get('new_source','')
  if old and new:
   assert old not in MIGRATION,(old,'duplicate migration target')
   assert new.startswith('assets/art/external/cc0_named_v1/') and '..' not in Path(new).parts,(old,new)
   MIGRATION[old]=new

def art_source(logical):
 """Return real image used by a legacy path, without recreating deleted art."""
 direct=ROOT/logical
 if direct.is_file():return direct,False
 source=MIGRATION.get(logical,'')
 assert source,(logical,'missing physical file and explicit third-party mapping')
 physical=ROOT/source
 assert physical.is_file(),(logical,'mapped source missing',source)
 assert physical.suffix.lower() in ('.png','.jpg','.jpeg','.webp'),(logical,source)
 return physical,True

def decoded_texture(logical,old_size=None):
 path,migrated=art_source(logical)
 with Image.open(path) as image:
  image.verify()
 with Image.open(path) as image:
  w,h=image.size
  assert w>=16 and h>=16,(logical,path,'image too small')
  if old_size is not None and not migrated:
   assert (w,h)==old_size,(logical,'unmigrated artwork dimension drift',(w,h))
 return migrated

assert (ROOT/'project.godot').exists()
assert (ROOT/'scenes/main.tscn').exists()
assert len(list((ROOT/'scripts').glob('*.gd')))>=7
settings=(ROOT/'project.godot').read_text(encoding='utf8')
assert 'renderer/rendering_method.mobile="gl_compatibility"' in settings
assert 'autoload' in settings.lower()
for filename in (ROOT/'scripts').glob('*.gd'):
 content=filename.read_text(encoding='utf8')
 for kind,path in re.findall(r'(preload|load)\(\s*"(res://[^"%]+)"\s*\)',content):
  assert (ROOT/path.removeprefix('res://')).exists(),(filename,path)
 for index,line in enumerate(content.splitlines(),start=1):
  assert not ('\t' in line and line.startswith('\t')), (filename, index, 'Tab indentation')

config=yaml.safe_load((ROOT/'codemagic.yaml').read_text(encoding='utf8'))
assert 'ios-unsigned' in config['workflows']
assert len(config['workflows']['ios-unsigned']['scripts']) >= 4

for map_name in ('village','ruins'):
 data=json.loads((ROOT/f'data/{map_name}.json').read_text(encoding='utf8'))
 w,h=data['width'],data['height']
 assert w==44 and h==28 and len(data['tiles'])==h
 assert all(len(row)==w for row in data['tiles'])
 for sprite in data['props']:
  decoded_texture(f'assets/props/{sprite["kind"]}.png')
  assert 1<int(sprite['x'])<w-1 and 1<int(sprite['y'])<h-1
 # The original 44x28 raster is not the live V3 TileMapLayer renderer.
 # A third-party atlas can be shared by both prototype map IDs.
 decoded_texture(f'assets/maps/{map_name}.png',(w*32,h*32))
 blocked={(x,y) for y,row in enumerate(data['tiles']) for x,c in enumerate(row) if c in 'Ww'}
 for p in data['props']:
  size=p.get('solid',[])
  if size:
   for dy in range(size[1]):
    for dx in range(size[0]): blocked.add((p['x']+dx,p['y']+dy))
 start=(12,17) if map_name=='village' else (4,14)
 assert start not in blocked
 queue=deque([start]); seen={start}
 while queue:
  x,y=queue.popleft()
  for pt in ((x+1,y),(x-1,y),(x,y+1),(x,y-1)):
   if pt not in seen and pt not in blocked and 1<=pt[0]<w-1 and 1<=pt[1]<h-1:
    seen.add(pt);queue.append(pt)
 for p in data['props']:
  if 'interact' not in p:continue
  target=(p['x'],p['y'])
  # interaction checks strictly < 64 screen units (2 tile centers)
  reachable=any(((x-target[0])**2+(y-target[1])**2)**.5<2 for x,y in seen)
  assert reachable, f'{map_name} cannot reach {p["id"]}'
 print(f'{map_name}: {len(seen)} reachable cells, {len(data["props"])} props, verified interactions')

for name in ('hero','companion'):
 decoded_texture(f'assets/characters/{name}.png',(96,192))
for name in ('slime','bat','golem','boss'):
 decoded_texture(f'assets/enemies/{name}.png',(128,128))
print('OK: real or migrated paths, decoded images, legacy dimensions, YAML and reachability validated (not an art-quality release gate)')

# Validate the expanded canonical catalog without disturbing legacy prototype resources.
import runpy
runpy.run_path(str(ROOT/'tools'/'validate_content.py'))
