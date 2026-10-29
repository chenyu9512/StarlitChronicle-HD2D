#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""Starlit Chronicle V9: full canonical asset factory + atomic Godot switch.

Generates every registered 2D core slot (9 groups) as verifiable OFFLINE
candidates, and can install them in the exact paths expected by Main2's
GlobalGeneratedArtV3 runtime. Never calls procedural output commercial-grade.

Optional externally rendered, visually reviewed model art may substitute
individual slots; full `--tier refined` installation refuses missing or
unapproved receipts. Rollback restores the prior complete pack and registry.
"""
from __future__ import annotations
import argparse
import hashlib
import json
import math
import os
from pathlib import Path
import random
import re
import shutil
import sys
import tempfile
import time
import uuid
from PIL import Image, ImageDraw, ImageFilter
import numpy as np
from hd2d_studio_v7 import rgb, mix, height_normal
from hd2d_studio_v8 import (
    CAST_ROLES, character_sheet, creature_sheet, optimize_creature,
    color_layers, region_atlas, region_panorama, seed,
    qa_char, qa_creature, visual_embedding, compare_images,
)

VERSION='9.0.0'
GROUPS=('terrain','maps','interiors','props','characters','npcs','monsters','bosses','ui')
ROLES=('tree','cottage','shop','shrine','well','lantern','crate','banner')
SIZES={'terrain':(256,256),'maps':(1152,648),'interiors':(256,256),
       'props':(96,128),'characters':(96,192),'npcs':(96,192),
       'monsters':(512,128),'bosses':(512,128),'ui':(512,128)}
def save_fast(image,path):
    """Atomic, fast PNG for large 451-slot generations; SHA verified later."""
    path=Path(path);path.parent.mkdir(parents=True,exist_ok=True)
    tmp=path.with_name(path.name+'.partial.png')
    image.save(tmp,format='PNG',compress_level=1)
    tmp.replace(path)

ROOT_REL=Path('assets/art/runtime/global_factory_v3')
REGISTRY_REL=Path('data/assets/c_art_runtime_registry_v1.json')
EXTRA=('ground','water')

def input_fingerprint(root):
    """Invalidate cached builds when *any* canonical IDs or room data change."""
    root=Path(root);h=hashlib.sha256()
    paths=[root/'data/assets/av_registry.json',root/'data/content/maps.json',
           Path(__file__),root/'tools/hd2d_studio_v8.py',root/'tools/hd2d_studio_v7.py']
    paths += sorted((root/'data/levels/v4/interiors').glob('*.json'))
    for path in paths:
        if not path.is_file():
            local=Path(__file__).parent/path.name
            path=local if local.is_file() else path
        if not path.is_file():raise FileNotFoundError('Required source missing: '+str(path))
        h.update(path.name.encode('utf-8'))
        h.update(bytes.fromhex(digest(path)))
    return h.hexdigest()

def read(path):
    return json.loads(Path(path).read_text(encoding='utf-8-sig'))

def digest(path):
    h=hashlib.sha256()
    with Path(path).open('rb') as f:
        for b in iter(lambda:f.read(1<<20),b''):h.update(b)
    return h.hexdigest()

def safe(s):
    if not re.fullmatch(r'[A-Za-z][A-Za-z0-9_-]{0,100}',str(s)):
        raise ValueError('unsafe official asset ID: '+str(s))
    return str(s)

def data_index(root):
    av=read(root/'data/assets/av_registry.json')
    maps=read(root/'data/content/maps.json').get('entries',[])
    regions={x['id']:x for x in av['regions']}
    rooms=[]
    for file in sorted((root/'data/levels/v4/interiors').glob('*.json')):
        entry=read(file)
        map_id=entry.get('map_id','')
        building_id=entry.get('building_id','')
        if not map_id or not building_id:
            # Some legacy rooms use other field names. File stem is official
            # identity and must match the formal map__building contract.
            stem=file.stem
            if '__' not in stem:raise ValueError('non-canonical interior ID: '+str(file))
            map_id,building_id=stem.split('__',1)
        cid=safe(map_id+'__'+building_id)
        rooms.append({'id':cid,'name':cid,'region_id':next((m['region_id'] for m in maps if m['id']==map_id),'region_coast'),
                      'source_file':str(file.relative_to(root))})
    queue={
       'terrain': [{'id':r['id'],'name':r['name'],'region_id':r['id']} for r in av['regions']],
       'maps':maps,
       'interiors':rooms,
       'props':[{'id':r['id']+'_'+role,'name':role,'role':role,'region_id':r['id']} for r in av['regions'] for role in ROLES],
       'characters':av['characters'],
       'npcs':av['npcs'],
       'monsters':av['monsters'],
       'bosses':av['bosses'],
       'ui':[{'id':r['id'],'name':r['name'],'region_id':r['id']} for r in av['regions']],
    }
    for group,items in queue.items():
        ids=[safe(x['id']) for x in items]
        if not ids or len(set(ids))!=len(ids):raise ValueError('Missing or duplicate IDs in '+group)
    if len(regions)!=len(av['regions']):raise ValueError('duplicate region')
    return queue, regions

def material_atlas(region,identity,interior=False):
    """Vectorized, 8x8 seam-safe textured atlas (milliseconds, not seconds)."""
    a,b,c=color_layers(region)
    code=seed('v9-material',identity) % 1000000007
    yy,xx=np.indices((256,256),dtype=np.float32)
    local_x=xx%32;local_y=yy%32
    row=(yy//32).astype('int32');col=(xx//32).astype('int32')
    edge=np.clip(np.minimum.reduce([local_x,31-local_x,local_y,31-local_y])/3,0,1)
    # Local grain returns precisely zero at every 32px boundary.
    pattern=(np.sin(local_x*.61+(code%37))*np.cos(local_y*.55+(code%71))+
             .46*np.sin(local_x*.31+local_y*.67))*edge
    value=pattern * (8+((code+row*7+col*13)%8))
    secondary=np.cos(local_x*.32+col)*np.sin(local_y*.41+row)*edge*4
    mixed_a=np.array(a,dtype=np.float32)
    mixed_b=np.array(b if interior else c,dtype=np.float32)
    frac=np.clip(row/10+.15 if interior else row/10+.25,0,.9)
    base=mixed_a[None,None,:]*(1-frac[:,:,None])+mixed_b[None,None,:]*frac[:,:,None]
    out=np.zeros((256,256,4),dtype='uint8')
    out[:,:,:3]=np.clip(base+(value+secondary)[:,:,None],0,255).astype('uint8')
    out[:,:,3]=255
    return Image.fromarray(out,'RGBA')

def prop_image(region,role,id):
    a,b,c=color_layers(region)
    s=3;im=Image.new('RGBA',(96*s,128*s),(0,0,0,0));d=ImageDraw.Draw(im,'RGBA')
    def p(points,color,outline=None,w=2):
        pts=[(int(x*s),int(y*s)) for x,y in points]
        d.polygon(pts,fill=(*color,255))
        if outline:d.line(pts+[pts[0]],fill=(*outline,255),width=w*s)
    def e(box,color,outline=None,w=2):
        d.ellipse(tuple(int(x*s) for x in box),fill=(*color,255),outline=(*outline,255) if outline else None,width=w*s)
    def r(box,color,outline=None,w=2):
        d.rectangle(tuple(int(x*s) for x in box),fill=(*color,255),outline=(*outline,255) if outline else None,width=w*s)
    wood=mix(b,(66,48,43),.65);metal=mix(c,(35,40,50),.45);edge=mix(a,(14,24,37),.55)
    if role=='tree':
        r((41,64,55,118),wood,edge);p([(42,101),(32,78),(44,71),(49,94)],wood)
        for x,y,rr in ((28,65,27),(62,61,26),(46,40,33),(33,28,18),(70,33,19)):
            e((x-rr,y-rr,x+rr,y+rr),mix(a,b,(x%8)*.05),edge)
            e((x-rr//2,y-rr//2,x+rr//3,y),mix(a,(240,232,186),.2))
    elif role in ('cottage','shop','shrine'):
        r((10,48,86,111),mix(b,(241,223,186),.28),edge)
        p([(4,51),(45,11),(92,51)],metal,edge)
        for y in (40,44):d.line((16*s,y*s,79*s,y*s),fill=(*mix(metal,(244,204,133),.25),255),width=2*s)
        r((36,74,61,112),edge,mix(b,(13,26,31),.4))
        for x in (18,68):r((x,62,x+12,78),mix(a,(235,212,150),.35),edge)
        if role=='shop':p([(6,52),(90,52),(82,64),(13,64)],mix(b,c,.45))
        if role=='shrine':e((42,18,54,30),mix(b,(249,229,159),.55));p([(48,15),(58,29),(48,39),(38,29)],mix(a,b,.5))
    elif role=='well':
        e((12,61,84,109),metal,edge);e((21,69,76,99),mix(a,(12,43,54),.35),edge)
        for x in (23,67):r((x,33,x+6,84),wood,edge)
        p([(17,36),(47,19),(80,36)],wood,edge)
    elif role=='lantern':
        r((45,50,51,123),wood,edge);p([(26,46),(48,25),(70,46)],metal,edge)
        r((32,46,64,79),mix(b,(252,231,150),.55),edge)
        r((38,52,58,71),(255,224,138),edge)
        e((35,47,62,78),mix(b,(255,243,194),.38))
    elif role=='crate':
        r((15,58,82,113),wood,edge)
        for y in (65,105):d.line((19*s,y*s,79*s,y*s),fill=(*mix(wood,b,.35),255),width=3*s)
        d.line((22*s,63*s,75*s,109*s),fill=(*edge,255),width=4*s)
        d.line((75*s,63*s,22*s,109*s),fill=(*edge,255),width=4*s)
    elif role=='banner':
        r((44,13,51,119),wood,edge);p([(51,25),(79,29),(79,95),(51,83)],mix(a,c,.34),edge)
        p([(59,37),(70,44),(59,52),(55,45)],mix(b,(249,221,154),.5))
        d.line((27*s,24*s,82*s,24*s),fill=(*metal,255),width=4*s)
    else:raise ValueError(role)
    # Microshadows/noise limited to opaque material, avoiding alpha halos.
    mask=im.getchannel('A')
    finish=im.resize((96,128),Image.Resampling.LANCZOS)
    return finish

def npc_sheet(entry,region):
    """Canonical NPC-specific color/material variation without a reused ID."""
    a,b,c=color_layers(region);id=entry['id'];ix=seed(id,'npc')
    roles=['healer','ranger','smith','bard','scribe','guardian','scholar','sailor']
    gears=['staff','bow','hammer','lyre','book','shield','scroll','anchor']
    hems=['robe','split','apron','tails','cape','armor','coat','jacket']
    chosen=ix%8
    name=str(entry.get('name',''))
    for words,i in [('医药疗祭',0),('猎卫巡守',1),('锻工匠',2),('歌乐吟',3),('书抄记',4),('军队长',5),('学者史',6),('船渔港',7)]:
        if any(c in name for c in words):chosen=i;break
    shade=(ix%27)/100
    p=mix(a,b,.18+shade);accent=mix(b,c,.15+(ix%41)/100);dark=mix(c,(19,29,46),.65)
    from hd2d_studio_v8 import draw_character_tile
    role=(roles[chosen],gears[chosen],hems[chosen],'crest', '#%02x%02x%02x'%p,'#%02x%02x%02x'%accent,'#%02x%02x%02x'%dark)
    out=Image.new('RGBA',(96,192),(0,0,0,0))
    for direction in range(4):
        for pose in range(3):
            sprite=draw_character_tile(role,id,direction,pose)
            out.paste(sprite,(pose*32,direction*48))
    return out

def ui_frame(region):
    a,b,c=color_layers(region);w,h=SIZES['ui'];im=Image.new('RGBA',(w,h),(0,0,0,0));d=ImageDraw.Draw(im,'RGBA')
    dark=mix(c,(12,20,33),.73);gold=mix(b,(245,218,165),.47)
    d.rounded_rectangle((3,3,w-4,h-4),radius=14,fill=(*dark,240),outline=(*gold,255),width=4)
    d.rounded_rectangle((13,11,w-14,h-12),radius=8,outline=(*mix(a,b,.6),255),width=2)
    for x in (18,w-20):
        for y in (18,h-20):
            d.ellipse((x-9,y-9,x+9,y+9),fill=(*mix(a,c,.3),255),outline=(*gold,255),width=2)
            d.polygon([(x,y-8),(x+7,y),(x,y+8),(x-7,y)],fill=(*gold,180))
    for x in range(47,w-46,32):
        d.arc((x,2,x+23,17),0,160,fill=(*gold,120),width=2)
        d.arc((x,h-18,x+23,h-3),200,350,fill=(*gold,120),width=2)
    return im

def map_image(entry,region):
    base=region_panorama(region).convert('RGBA').resize(SIZES['maps'],Image.Resampling.LANCZOS)
    d=ImageDraw.Draw(base,'RGBA');r=random.Random(seed(entry['id'],'map-landmarks'))
    a,b,c=color_layers(region)
    # Named layout identity determines optional visual landmarks; these never
    # become physical walkable geometry or change collision coordinates.
    for i in range(4):
        x=140+i*260+r.randint(-42,40);y=420+r.randint(-36,30)
        height=r.randint(37,96)
        fill=mix(b,a,.34+i*.12)
        d.polygon([(x,y),(x+43,y-height),(x+88,y),(x+92,y+height//3),(x-9,y+height//3)],fill=(*fill,210))
        d.polygon([(x-8,y),(x+44,y-height-18),(x+98,y)],fill=(*mix(c,(35,45,61),.3),235))
        d.rectangle((x+34,y+10,x+56,y+height//3),fill=(*mix(c,(20,27,41),.65),245))
    return base.convert('RGBA')

def verify_one(group,img):
    if img.size!=SIZES[group]:raise ValueError(f'{group} canvas incompatible: {img.size}')
    if group in ('characters','npcs'):qa_char(img)
    if group in ('monsters','bosses'):qa_creature(img)
    if group in ('props','characters','npcs','monsters','bosses'):
        alpha=img.convert('RGBA').getchannel('A')
        if not alpha.getbbox() or alpha.getextrema()[0]==255:
            raise ValueError(group+' invalid alpha content')

def model_candidate(source,group,id,target):
    f=source/group/(id+'.png');receipt=f.with_suffix('.quality.json')
    if not f.is_file() or not receipt.is_file():raise ValueError(f'Refined image/receipt missing: {group}/{id}')
    meta=read(receipt)
    if meta.get('image_sha256')!=digest(f):raise ValueError('Refined image checksum differs from receipt: '+id)
    # Only review is sufficient for a release; generated API success is not.
    if meta.get('visual_approved') is not True or meta.get('identity_approved') is not True:
        raise ValueError('Refined image lacks visual+identity approval: '+id)
    with Image.open(f) as im:
        im.load();im=im.convert('RGBA')
    verify_one(group,im)
    return im

def make_pack(root,out,tier='procedural',model_source=None):
    root=Path(root).resolve();out=Path(out).resolve()
    if not (root/'data/assets/av_registry.json').is_file():raise FileNotFoundError('Main2 registry missing')
    if out==root or out==root/'assets' or out==root/ROOT_REL:raise ValueError('refusing to overwrite project during generation')
    queue,regions=data_index(root)
    counts={k:len(v) for k,v in queue.items()}
    if tier=='refined' and not model_source:raise ValueError('refined release needs --model-source')
    seen={'monsters':[],'bosses':[]};assets={};identity=[]
    for group in GROUPS:
        print("V9 BUILD GROUP",group,"COUNT",len(queue[group]),flush=True)
        for entry in queue[group]:
            id=safe(entry['id'])
            region=regions.get(entry.get('region_id','region_coast'),next(iter(regions.values())))
            if tier=='refined':
                im=model_candidate(model_source,group,id,SIZES[group]);meta={'source':'reviewed_model_asset'}
            elif group=='characters':
                if id not in CAST_ROLES:raise ValueError('Missing V8 identity geometry for '+id)
                im=character_sheet(id);meta={'source':'v8_unique_character'}
            elif group=='npcs':
                im=npc_sheet(entry,region);meta={'source':'v9_semantic_npc'}
            elif group in ('monsters','bosses'):
                if group=='bosses':
                    ordinal=int(re.search(r'\d+',id).group())
                    region=list(regions.values())[((ordinal-1)//9)%len(regions)]
                im,t,embedding=optimize_creature(entry,region,group[:-1],seen[group]);seen[group].append(embedding)
                meta={'archetype':t['kind'],'variant':t['variant'],'source':'v8_visual_optimized'}
                identity.append({'id':id,'group':group,'name':entry['name'],**meta})
            elif group=='terrain':
                im=material_atlas(region,id,False);meta={'source':'v9_seamless_terrain'}
            elif group=='maps':
                im=map_image(entry,region);meta={'source':'v9_unique_map_backdrop'}
            elif group=='interiors':
                im=material_atlas(region,id,True);meta={'source':'v9_unique_interior_atlas'}
            elif group=='props':
                im=prop_image(region,entry['role'],id);meta={'source':'v9_semantic_prop'}
            else:
                im=ui_frame(region);meta={'source':'v9_region_ui'}
            verify_one(group,im)
            target=out/group/(id+'.png');save_fast(im,target)
            assets[group+'.'+id]={'path':'res://'+(ROOT_REL/group/(id+'.png')).as_posix(),
                'sha256':digest(target),'provenance':meta.get('source','v9_refined'),
                'source_quality':'reviewed' if tier=='refined' else 'procedural_candidate',
                'qa':{'width':im.width,'height':im.height}}
            if group in ('characters','npcs'):
                normal=out/group/(id+'_normal.png');save_fast(height_normal(im),normal)
                assets[group+'.'+id]['normal_map_path']='res://'+(ROOT_REL/group/(id+'_normal.png')).as_posix()
                assets[group+'.'+id]['normal_map_sha256']=digest(normal)
    for region in regions.values():
        for kind in EXTRA:
            id=region['id']+'_'+kind
            if tier=='refined':
                # Derived exclusively from the image reviewed as terrain/id.
                # Canonical atlas rows: 6=water, others=ground materials.
                master=Image.open(out/'terrain'/(region['id']+'.png')).convert('RGBA')
                im=Image.new('RGBA',(256,256))
                source_row=6 if kind=='water' else 0
                for target_row in range(8):
                    index=source_row if kind=='water' else (5,0,2,4,1,3,2,7)[target_row]
                    im.paste(master.crop((0,index*32,256,(index+1)*32)),(0,target_row*32))
            else:
                im=region_atlas(region,kind=='water')
            dest=out/'terrain'/(id+'.png');save_fast(im,dest)
    report={'schema':'starlit.global_factory.live.v3','enabled':True,
      'source_fingerprint':input_fingerprint(root),
      'source':'v9_full_roster_'+tier,'visual_acceptance':'approved' if tier=='refined' else 'not_tested',
      'asset_count':len(assets),'counts':counts,'renderer':'v9','normal_map_count':counts['characters']+counts['npcs'],
      'assets':assets}
    if len(assets)!=sum(counts.values()):raise ValueError('Asset count mismatch')
    # Drop failed/retired candidate files, never leaving old names to sneak
    # into Git commits or inflate the next published art pack.
    declared={group:set() for group in GROUPS}
    for slot,record in assets.items():
        group,id=slot.split('.',1)
        declared[group].add(id+'.png')
        if record.get('normal_map_path'):declared[group].add(id+'_normal.png')
    for region in regions:
        declared['terrain'].update((region+'_ground.png',region+'_water.png'))
    for group in GROUPS:
        folder=out/group
        if folder.exists():
            for file in folder.glob('*.png'):
                if file.name not in declared[group]:file.unlink()
    (out/'active.json').write_text(json.dumps(report,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
    (out/'identity_variants.json').write_text(json.dumps(identity,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
    return report

def verify_pack(folder,root):
    folder=Path(folder);meta=read(folder/'active.json');queue,regions=data_index(root)
    expected={(group+'.'+entry['id']) for group in GROUPS for entry in queue[group]}
    if meta.get('schema')!='starlit.global_factory.live.v3' or not meta.get('enabled'):
        raise ValueError('Not a Godot-compatible active manifest')
    if set(meta.get('assets',{}))!=expected or meta.get('asset_count')!=len(expected):
        raise ValueError('Canonical missing/unexpected image slots')
    for name,item in meta['assets'].items():
        group,id=name.split('.',1);p=folder/group/(id+'.png')
        if item['path']!='res://'+(ROOT_REL/group/(id+'.png')).as_posix():raise ValueError('bad runtime path: '+name)
        if not p.is_file() or digest(p)!=item['sha256']:raise ValueError('missing/changed image: '+name)
        with Image.open(p) as image:
            image.load();verify_one(group,image)
        if item.get('normal_map_path'):
            normal=folder/group/(id+'_normal.png')
            if not normal.is_file() or digest(normal)!=item['normal_map_sha256']:
                raise ValueError('normal map missing: '+name)
    allow={group:set() for group in GROUPS}
    for slot,item in meta['assets'].items():
        group,id=slot.split('.',1)
        allow[group].add(id+'.png')
        if item.get('normal_map_path'):allow[group].add(id+'_normal.png')
    for region in regions:allow['terrain'].update((region+'_ground.png',region+'_water.png'))
    for group in GROUPS:
        extra={p.name for p in (folder/group).glob('*.png')}-allow[group]
        if extra:raise ValueError('Unexpected leftover PNG files in '+group+': '+repr(sorted(extra)))
    for region in regions:
        for kind in EXTRA:
            path=folder/'terrain'/f'{region}_{kind}.png'
            with Image.open(path) as im:
                if im.size!=(256,256):raise ValueError('regional atlas bad dimensions: '+str(path))
    return {'slots':len(expected),'extra_terrain':2*len(regions),'status':'成功'}

def patch_registry(root,manifest):
    file=root/REGISTRY_REL
    if not file.is_file():return None
    reg=read(file)
    if reg.get('schema')!='starlit.c.art_runtime_registry.v1':raise ValueError('Invalid official art registry schema')
    generated={}
    for slot,record in manifest['assets'].items():
        group,id=slot.split('.',1)
        generated[slot]={'source':record['path'],'group':group,
                         'manifest_sha256':record['sha256'],
                         'provenance':record.get('provenance','v9_candidate'),
                         'stage':'runtime_reviewed' if manifest['visual_acceptance']=='approved' else 'runtime_candidate_visual_qa_pending'}
    for region in (x['id'] for x in read(root/'data/assets/av_registry.json')['regions']):
        for kind in EXTRA:
            slot=f'terrain.{region}_{kind}'
            generated[slot]={'source':'res://'+(ROOT_REL/'terrain'/(region+'_'+kind+'.png')).as_posix(),
                              'group':'terrain','canvas':[256,256],
                              'provenance':manifest['source'],'stage':manifest['visual_acceptance']}
    reg['generated_assets']=generated
    reg['generated_manifest']={'source':'res://'+(ROOT_REL/'active.json').as_posix(),
          'manifest_images':manifest['asset_count'],'regional_atlases_extra':16,
          'groups':manifest['counts'],'enabled':True,'visual_status':'未测试' if manifest['visual_acceptance']!='approved' else '已审核'}
    for region in read(root/'data/assets/av_registry.json')['regions']:
        id=region['id'];item=reg.get('regions',{}).get(id)
        if isinstance(item,dict):
            item['generated_terrain']={kind:generated['terrain.'+id+'_'+kind]['source'] for kind in EXTRA}
            for role in ROLES:
                props=item.setdefault('scene_props',{})
                props[role]=generated['props.'+id+'_'+role]['source']
    temp=file.with_suffix('.v9-temp.json')
    temp.write_text(json.dumps(reg,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
    temp.replace(file)
    return file

def promote(root,candidate,tier='procedural'):
    """One-click local filesystem replacement; old pack retained as backup.

    Transaction scope = runtime folder + JSON art registry. Does not delete
    original images outside that folder, or change collisions/quests/saves.
    """
    root=Path(root).resolve();candidate=Path(candidate).resolve()
    verify_pack(candidate,root)
    target=root/ROOT_REL;parent=target.parent
    if not parent.exists():parent.mkdir(parents=True)
    if target==candidate or candidate.is_relative_to(target):raise ValueError('Source overlaps destination')
    stamp=str(int(time.time()))+'_'+uuid.uuid4().hex[:8]
    backup_parent=root/'build/starlit_v9_backups'
    backup_parent.mkdir(parents=True,exist_ok=True)
    backup=backup_parent/('global_factory_v3.v9-backup-'+stamp)
    registry=root/REGISTRY_REL
    registry_backup=backup_parent/('global_factory_v3.v9-registry-'+stamp+'.json')
    if registry.exists():shutil.copy2(registry,registry_backup)
    stage=Path(tempfile.mkdtemp(prefix='.v9-stage-',dir=parent))
    moved_old=False;moved_new=False
    try:
        for file in candidate.rglob('*'):
            if file.is_file():
                to=stage/file.relative_to(candidate);to.parent.mkdir(parents=True,exist_ok=True)
                shutil.copy2(file,to)
        verify_pack(stage,root)
        if target.exists():target.rename(backup);moved_old=True
        stage.rename(target);moved_new=True
        patch_registry(root,read(target/'active.json'))
        verify_pack(target,root)
        info={'status':'成功','installed':'res://'+ROOT_REL.as_posix(),
              'core_slots':read(target/'active.json')['asset_count'],
              'tier':tier,'visual_status':'未测试' if tier=='procedural' else '已审核',
              'backup_dir':str(backup) if moved_old else None,
              'registry_backup':str(registry_backup) if registry_backup.exists() else None}
        return info
    except Exception:
        if moved_new and target.exists():shutil.rmtree(target)
        if moved_old and backup.exists():backup.rename(target)
        if registry_backup.exists():shutil.copy2(registry_backup,registry)
        raise
    finally:
        if stage.exists():shutil.rmtree(stage)

def rollback(root,backup_path,registry_backup=None):
    root=Path(root).resolve();target=root/ROOT_REL
    backup=Path(backup_path).resolve();parent=target.parent.resolve()
    backup_parent=(root/'build/starlit_v9_backups').resolve()
    if backup.parent!=backup_parent or not backup.name.startswith('global_factory_v3.v9-backup-'):
        raise ValueError('Rollback path must be a V9-generated backup of the same project')
    if not backup.is_dir():raise FileNotFoundError(backup)
    displaced=parent/('.v9-displaced-'+uuid.uuid4().hex)
    if target.exists():target.rename(displaced)
    try:
        backup.rename(target)
        if registry_backup:
            rb=Path(registry_backup).resolve()
            if rb.parent!=backup_parent or not rb.name.startswith('global_factory_v3.v9-registry-'):
                raise ValueError('Invalid V9 registry backup')
            shutil.copy2(rb,root/REGISTRY_REL)
    except Exception:
        if target.exists():target.rename(backup)
        if displaced.exists():displaced.rename(target)
        raise
    if displaced.exists():shutil.rmtree(displaced)
    return {'status':'成功','restored':str(target)}

def model_jobs(root,output,render=False,quality='xhigh',model=None):
    """Use Main2's canonical 451-prompt image API renderer, not fake AI art.

    --render-model needs a real OPENAI_API_KEY and will incur API charges.
    This never auto-approves an API image for production use.
    """
    import subprocess
    provider=Path(root)/'tools/global_art_ai_provider_v3.py'
    if not provider.is_file():raise FileNotFoundError('Official model provider missing: '+str(provider))
    if render and not os.environ.get('OPENAI_API_KEY'):
        raise ValueError('OPENAI_API_KEY is required to render premium imagery')
    cmd=[sys.executable,str(provider),'--project',str(root),'--output',str(output),
         '--scope','all','--limit','0','--quality',quality,
         '--render' if render else '--jobs-only']
    if model:cmd+=['--model',model]
    if render:
        ref=Path(root)/'build/starlit_hd2d_studio_v9/factory'
        if ref.is_dir():cmd+=['--reference-root',str(ref)]
    result=subprocess.run(cmd,cwd=root,check=False)
    if result.returncode:raise RuntimeError('High quality image model returned error '+str(result.returncode))
    return {'status':'成功','mode':'rendered_model_candidates' if render else 'model_prompts_only',
            'api_called':render,'output':str(output),'expected_full_roster':sum(len(x) for x in data_index(root)[0].values())}

def main(argv=None):
    p=argparse.ArgumentParser(description='V9 all-canonical HD2D production + atomic switch')
    p.add_argument('--project',type=Path,default=Path(__file__).resolve().parents[1])
    p.add_argument('--output',type=Path)
    p.add_argument('--tier',choices=('procedural','refined'),default='procedural')
    p.add_argument('--model-source',type=Path,help='Reviewed group/ID.png + ID.quality.json files')
    p.add_argument('--generate',action='store_true')
    p.add_argument('--one-click',action='store_true',help='Generate, validate and replace official Godot candidate runtime pack')
    p.add_argument('--verify',action='store_true')
    p.add_argument('--rollback',type=Path)
    p.add_argument('--registry-backup',type=Path)
    p.add_argument('--model-jobs',action='store_true',help='Export all 451 official AI image tasks, zero API calls')
    p.add_argument('--render-model',action='store_true',help='Render all 451 with configured image API; costs money')
    p.add_argument('--model-output',type=Path)
    p.add_argument('--model',type=str,default=None,help='Use an image model actually available to your account')
    p.add_argument('--model-quality',choices=['high','xhigh','max','auto'],default='xhigh')
    opts=p.parse_args(argv)
    root=opts.project.resolve()
    out=(opts.output or root/'build/starlit_hd2d_studio_v9/factory').resolve()
    try:
        if opts.model_jobs or opts.render_model:
            result=model_jobs(root,opts.model_output or root/'build/starlit_hd2d_studio_v9/refined_models',opts.render_model,opts.model_quality,opts.model)
        elif opts.rollback:
            result=rollback(root,opts.rollback,opts.registry_backup)
        elif opts.verify:
            result=verify_pack(out,root)
        elif opts.generate or opts.one_click:
            # Reuse a fully checked complete pack; unchanged projects avoid
            # unnecessary expensive 451-image regeneration on every install.
            cached=False
            if opts.one_click and (out/'active.json').is_file():
                try:
                    previous=read(out/'active.json')
                    if (previous.get('source')=='v9_full_roster_'+opts.tier and
                            previous.get('source_fingerprint')==input_fingerprint(root)):
                        verify_pack(out,root)
                        cached=True
                except (OSError,ValueError,KeyError):
                    cached=False
            report=read(out/'active.json') if cached else make_pack(root,out,opts.tier,opts.model_source)
            result=verify_pack(out,root)
            if opts.one_click:result=promote(root,out,opts.tier)
            else:result={'status':'成功','core_slots':len(report['assets']),
                 'counts':report['counts'],'extra_terrain':16,
                 'tier':opts.tier,'runtime_modified':False,'visual_status':'未测试'}
        else:
            queue,_=data_index(root)
            result={'status':'成功','mode':'inventory_only','counts':{g:len(v) for g,v in queue.items()},
              'core_slots':sum(len(v) for v in queue.values()),'extra_terrain':16}
        print(json.dumps(result,ensure_ascii=False,indent=2))
        return 0
    except (ValueError,RuntimeError,OSError,KeyError,IndexError) as error:
        print('V9 ERROR:',error,file=sys.stderr)
        return 2

if __name__=='__main__':
    raise SystemExit(main())
