#!/usr/bin/env python3
"""Offline resource integrity and map reachability checks (not a Godot runtime test)."""
from pathlib import Path
from PIL import Image
from collections import deque
import re, json, yaml

ROOT=Path(__file__).resolve().parents[1]
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
  assert (ROOT/f'assets/props/{sprite["kind"]}.png').exists(),sprite
  assert 1<int(sprite['x'])<w-1 and 1<int(sprite['y'])<h-1
 texture=Image.open(ROOT/f'assets/maps/{map_name}.png')
 assert texture.size==(w*32,h*32)
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
 assert Image.open(ROOT/f'assets/characters/{name}.png').size==(96,192)
for name in ('slime','bat','golem','boss'):
 assert Image.open(ROOT/f'assets/enemies/{name}.png').size==(128,128)
print('OK: paths, JSON, PNG dimensions, YAML, reachability and references validated')

# Validate the expanded canonical catalog without disturbing legacy prototype resources.
import runpy
runpy.run_path(str(ROOT/'tools'/'validate_content.py'))
