#!/usr/bin/env python3
"""Global 2D art candidate factory for Starlit Chronicle / Main2.

Data-driven coverage: maps, V4 interiors, regions, cast, NPCs, monsters,
bosses and UI. This tool NEVER overwrites live game art or gameplay data.
Its procedural outputs are candidates, not approved character/Boss identity art.
"""
from __future__ import annotations
import argparse
import hashlib
import json
import math
import random
import re
import sys
from pathlib import Path
from PIL import Image, ImageDraw

VERSION = "3.0.0"
SCOPES = ("terrain", "maps", "interiors", "props", "characters", "npcs", "monsters", "bosses", "ui")
SIZES = {"terrain": (256,256), "maps": (1152,648), "interiors": (256,256),
         "props": (96,128), "characters": (96,192), "npcs": (96,192),
         "monsters": (512,128), "bosses": (512,128), "ui": (512,128)}

def read(path):
    obj = json.loads(path.read_text(encoding="utf-8-sig"))
    if not isinstance(obj, dict):
        raise ValueError("Invalid JSON object: " + str(path))
    return obj

def safe(value):
    value = str(value)
    if not re.fullmatch(r"[A-Za-z0-9][A-Za-z0-9_-]{0,95}", value):
        raise ValueError("Unsafe asset ID: " + value)
    return value

def seeded(*values):
    return int.from_bytes(hashlib.sha256("|".join(map(str,values)).encode()).digest()[:8],"big")

def blend(a,b,t):
    return tuple(round(x*(1-t)+y*t) for x,y in zip(a,b))

def shade(c,t):
    return blend(c,(255,248,229) if t>=0 else (22,27,44),abs(t))

def colors(region):
    vals = region.get("style",{}).get("palette",["#83B9C4","#D7C59D","#386A82"])
    if len(vals)<3:
        vals=["#83B9C4","#D7C59D","#386A82"]
    return tuple(tuple(int(x[j:j+2],16) for j in (1,3,5)) for x in vals[:3])

def tile(d,x,y,c,kind,seed):
    rng=random.Random(seed)
    d.rectangle((x,y,x+31,y+31),fill=c)
    if kind=="water":
        for k in range(4):
            v=y+4+k*7+rng.randrange(3)
            d.arc((x-8,v-2,x+40,v+4),5,135,fill=shade(c,.22))
    elif kind in ("wood","wall"):
        for k in range(4):
            v=y+k*8
            d.line((x,v,x+31,v),fill=shade(c,-.21))
            dx=x+(15 if (k+seed)%2 else 7)
            d.line((dx,v+1,dx,v+7),fill=shade(c,-.15))
    elif kind in ("stone","cobbles"):
        for v in range(y,y+32,11):
            d.line((x,v,x+31,v),fill=shade(c,-.18))
            for dx in range(x+(12 if v%2 else 0),x+32,19):
                d.line((dx,v,dx,min(y+31,v+10)),fill=shade(c,-.12))
    else:
        for _ in range(13):
            px=x+rng.randrange(32); py=y+rng.randrange(32)
            d.line((px,py,px+rng.randrange(-2,3),py-rng.randrange(1,4)),
                   fill=shade(c,rng.uniform(-.18,.18)))

def atlas(region,room_id=""):
    a,b,c=colors(region)
    kinds=("grass","road","stone","wood","cobbles","sand","water","wall")
    bases=(a,b,shade(c,.15),blend(b,c,.35),shade(b,-.14),shade(b,.25),c,shade(c,-.2))
    if room_id:
        kinds=("wood","wood","cobbles","grass","stone","road","wall","sand")
        bases=(shade(b,.18),b,a,shade(a,.25),c,shade(b,.38),shade(c,-.2),shade(b,.46))
    out=Image.new("RGBA",(256,256),(0,0,0,0)); d=ImageDraw.Draw(out)
    for row,(kind,base) in enumerate(zip(kinds,bases)):
        for col in range(8):
            tile(d,col*32,row*32,shade(base,(col-3)*.016),kind,
                 seeded(region["id"],room_id,row,col))
    return out

def backdrop(entry,region):
    w,h=1152,648; rng=random.Random(seeded(entry["id"],"backdrop"))
    a,b,c=colors(region)
    out=Image.new("RGB",(w,h)); d=ImageDraw.Draw(out)
    for y in range(h):
        d.line((0,y,w,y),fill=blend(shade(c,.48),shade(a,-.16),y/h*.82))
    d=ImageDraw.Draw(out,"RGBA")
    sun_x=rng.randrange(740,970)
    d.ellipse((sun_x,65,sun_x+145,210),fill=(*shade(b,.52),135))
    for layer in range(5):
        baseline=275+layer*63
        tone=shade(blend(a,c,min(1,layer*.19)),-layer*.08)
        points=[(0,h)]
        for x in range(-90,w+180,65):
            points.append((x,baseline+rng.randint(-55,65)+math.sin(x*.006+layer)*15))
        points.append((w,h))
        d.polygon(points,fill=(*tone,255))
    kind=entry.get("type","field")
    count={"town":9,"dungeon":3,"landmark":2,"field":3}.get(kind,5)
    for _ in range(count):
        x=rng.randint(35,w-95); y=rng.randint(430,540); size=rng.randint(30,87)
        if kind in ("town","landmark"):
            d.rectangle((x+8,y-size+14,x+size,y),fill=(*shade(c,-.25),255))
            d.polygon([(x,y-size+14),(x+size//2,y-size-18),(x+size+8,y-size+14)],
                      fill=(*shade(b,-.27),255))
            d.rectangle((x+size//3,y-22,x+size//3+9,y-7),fill=(*shade(b,.4),255))
        else:
            d.ellipse((x,y-size,x+size*.4,y),fill=(*shade(c,-.15),255))
    return out

def prop(region,kind):
    a,b,c=colors(region)
    out=Image.new("RGBA",(96,128),(0,0,0,0)); d=ImageDraw.Draw(out)
    if kind=="tree":
        d.rectangle((40,66,53,118),fill=shade(b,-.4))
        for dx,dy,r in [(-12,43,23),(16,47,27),(0,23,32)]:
            d.ellipse((48+dx-r,dy-r//2,48+dx+r,dy+r),fill=shade(a,(dx%7-3)*.045))
    elif kind in ("cottage","shop","shrine"):
        d.rectangle((10,43,86,111),fill=shade(b,.24),outline=shade(c,-.25),width=2)
        d.polygon([(3,47),(47,6),(92,47)],fill=shade(c,-.15))
        d.rectangle((36,75,59,111),fill=shade(c,-.32))
        for x in (19,68):
            d.rectangle((x,56,x+11,70),fill=shade(a,.46),outline=shade(c,-.25))
        if kind=="shop":
            d.rectangle((12,48,83,56),fill=shade(a,.15))
        if kind=="shrine":
            d.polygon([(47,15),(52,35),(47,44),(42,35)],fill=shade(b,.58))
    elif kind=="well":
        d.ellipse((16,64,82,106),fill=shade(c,-.27))
        d.ellipse((25,71,73,96),fill=shade(a,-.13))
        for x in (20,72):
            d.rectangle((x,34,x+7,83),fill=shade(b,-.4))
        d.polygon([(12,34),(49,14),(87,34)],fill=shade(c,-.1))
    elif kind=="lantern":
        d.rectangle((46,40,51,118),fill=shade(c,-.35))
        d.ellipse((29,20,69,68),fill=(*shade(b,.55),210))
        d.ellipse((36,29,62,60),fill=shade(b,.75))
    elif kind=="crate":
        d.rectangle((18,63,81,112),fill=shade(b,-.22),outline=shade(c,-.3),width=3)
        d.line((19,65,80,111),fill=shade(c,-.26),width=3)
        d.line((80,65,19,111),fill=shade(c,-.26),width=3)
    elif kind=="banner":
        d.rectangle((45,12,51,119),fill=shade(b,-.38))
        d.polygon([(47,19),(82,29),(78,83),(47,73)],fill=shade(a,-.19))
    return out

def walker(asset_id,region):
    a,b,c=colors(region); rng=random.Random(seeded(asset_id))
    jacket=shade(a,rng.uniform(-.15,.22)); hair=shade(c,rng.uniform(-.25,.17))
    out=Image.new("RGBA",(96,192),(0,0,0,0)); d=ImageDraw.Draw(out)
    for direction in range(4):
        for frame in range(3):
            ox,oy=frame*32,direction*48; gait=(-2,0,2)[frame]
            d.rectangle((ox+9,oy+25,ox+22,oy+37),
                        fill=jacket if direction!=2 else shade(jacket,-.23))
            for px,dx in ((11,gait),(20,-gait)):
                d.line((ox+px,oy+37,ox+px+dx,oy+45),fill=shade(c,-.3),width=4)
            skin=(222,173,137)
            d.ellipse((ox+10,oy+8,ox+23,oy+26),fill=skin)
            d.rectangle((ox+9,oy+7,ox+23,oy+13),fill=hair)
            if direction==0:
                for x in (13,20):
                    d.rectangle((ox+x,oy+17,ox+x+1,oy+18),fill=shade(c,-.2))
            elif direction==1:
                d.rectangle((ox+10,oy+18,ox+11,oy+19),fill=shade(c,-.2))
            elif direction==3:
                d.rectangle((ox+22,oy+18,ox+23,oy+19),fill=shade(c,-.2))
            for x in (6,23):
                d.rectangle((ox+x,oy+25,ox+x+3,oy+33),fill=skin)
    return out

def enemy(asset_id,region,boss=False):
    a,b,c=colors(region); rng=random.Random(seeded(asset_id))
    out=Image.new("RGBA",(512,128),(0,0,0,0)); d=ImageDraw.Draw(out)
    shape=seeded(asset_id)%5
    for frame in range(4):
        ox=frame*128; wobble=(-2,0,3,0)[frame]
        tone=shade(a,rng.uniform(-.13,.14))
        if shape==0:
            d.ellipse((ox+22,47+wobble,ox+106,112+wobble),fill=tone)
        elif shape==1:
            d.polygon([(ox+20,108),(ox+35,38+wobble),(ox+64,15+wobble),
                       (ox+94,38+wobble),(ox+108,108)],fill=tone)
        elif shape==2:
            d.ellipse((ox+25,35+wobble,ox+101,107+wobble),fill=tone)
            for dx in (-18,18):
                d.line((ox+64+dx,80,ox+64+2*dx,119),fill=shade(c,-.15),width=8)
        elif shape==3:
            d.polygon([(ox+12,74),(ox+35,31+wobble),(ox+66,57),
                       (ox+96,25+wobble),(ox+115,73),(ox+64,110)],fill=tone)
        else:
            d.rounded_rectangle((ox+24,31+wobble,ox+104,110+wobble),20,fill=tone)
        for x in (43,76):
            d.ellipse((ox+x-6,65+wobble,ox+x+6,75+wobble),fill=shade(b,.55))
        if boss:
            for x,dx in ((30,-13),(97,12)):
                d.polygon([(ox+x,52),(ox+x+dx,17+wobble),
                           (ox+x-dx,40)],fill=shade(c,.12))
    return out

def ui(region):
    a,b,c=colors(region)
    out=Image.new("RGBA",(512,128),(*shade(c,-.55),245)); d=ImageDraw.Draw(out)
    d.rounded_rectangle((8,8,503,118),18,outline=shade(b,.37),width=3)
    d.rounded_rectangle((18,18,493,108),11,outline=shade(a,.07),width=2)
    for x in (33,479):
        d.ellipse((x-4,58,x+4,66),fill=shade(b,.63))
    return out

def tasks(root,selected):
    maps=read(root/"data/content/maps.json").get("entries",[])
    av=read(root/"data/assets/av_registry.json")
    regions={safe(r["id"]):r for r in av.get("regions",[])}
    if not maps or not regions:
        raise ValueError("Missing canonical map or region registry")
    default=regions.get("region_coast",next(iter(regions.values())))
    result=[]
    def add(group,name,meta,render):
        if group in selected:
            result.append((group,safe(name),meta,render))
    for r in regions.values():
        rid=safe(r["id"])
        add("terrain",rid,{"region_id":rid,"rows":8},lambda r=r:atlas(r))
        add("ui",rid+"_frame",{"region_id":rid},lambda r=r:ui(r))
        for kind in ("tree","cottage","shop","shrine","well","lantern","crate","banner"):
            add("props",rid+"_"+kind,{"region_id":rid,"kind":kind},
                lambda r=r,kind=kind:prop(r,kind))
    known=set(); map_regions={}
    for m in maps:
        mid=safe(m["id"])
        if mid in known:
            raise ValueError("Repeated map ID "+mid)
        known.add(mid)
        rid=m.get("region_id",default["id"])
        r=regions.get(rid,default); map_regions[mid]=r
        add("maps",mid,{"map_id":mid,"region_id":rid,
                        "use":"decorative_backdrop_not_playable_geometry"},
            lambda m=m,r=r:backdrop(m,r))
    for path in sorted((root/"data/levels/v4/interiors").glob("*.json")):
        room=read(path); r=map_regions.get(room.get("map_id"),default)
        add("interiors",path.stem,
            {"map_id":room.get("map_id"),"building_id":room.get("building_id"),
             "source_layout":str(path.relative_to(root)),
             "use":"material_atlas_does_not_modify_collision"},
            lambda r=r,room=room:atlas(r,room.get("building_id","room")))
    for group,key in (("characters","characters"),("npcs","npcs"),
                      ("monsters","monsters"),("bosses","bosses")):
        ids=set()
        for entity in av.get(key,[]):
            asset_id=safe(entity["id"])
            if asset_id in ids:
                raise ValueError("Repeated identity "+asset_id)
            ids.add(asset_id)
            rid=entity.get("region_id",default["id"])
            if group=="bosses" and rid==default["id"]:
                act=max(1,int(entity.get("act",1)))
                rid=list(regions)[min(len(regions)-1,(act-1)*len(regions)//12)]
            r=regions.get(rid,default)
            metadata={"canonical_id":asset_id,"region_id":rid,
                      "identity_acceptance":"not_approved"}
            if group in ("characters","npcs"):
                add(group,asset_id,metadata,lambda asset_id=asset_id,r=r:walker(asset_id,r))
            else:
                add(group,asset_id,metadata,
                    lambda asset_id=asset_id,r=r,group=group:enemy(asset_id,r,group=="bosses"))
    return result

def verify(path,group):
    with Image.open(path) as image:
        image.verify()
    with Image.open(path) as image:
        if image.size!=SIZES[group] or image.mode not in ("RGBA","RGB"):
            raise ValueError("Wrong image dimensions/mode for "+str(path))
    return {"size":list(SIZES[group]),"sha256":hashlib.sha256(path.read_bytes()).hexdigest()}

def produce(root,output,selected,dry_run=False,force=False,limit=0,source_root=None):
    root=root.resolve(); output=output.resolve()
    if output in (root,root/"assets",root/"assets/art",root/"assets/art/runtime"):
        raise ValueError("Refusing to overwrite live art directories")
    queue=tasks(root,selected)
    if limit:
        queue=queue[:limit]
    report={"schema":"starlit.global_art_factory.v3","version":VERSION,
            "source":"canonical maps, AV registry and V4 interiors",
            "status":"candidate_only_not_runtime_integrated",
            "game_runtime_modified":False,"counts":{},"assets":[],"errors":[]}
    if dry_run:
        for group,*_ in queue:
            report["counts"][group]=report["counts"].get(group,0)+1
        report["status"]="dry_run"
        return report
    output.mkdir(parents=True,exist_ok=True)
    index={}
    for group,asset_id,meta,render in queue:
        path=output/group/(asset_id+".png")
        origin=source_root/group/(asset_id+".png") if source_root else None
        try:
            path.parent.mkdir(parents=True,exist_ok=True)
            provenance="generated_procedural_candidate"
            if origin and origin.is_file():
                with Image.open(origin) as source:
                    source.load()
                    if source.size!=SIZES[group]:
                        raise ValueError("Curated art dimensions do not match "+asset_id)
                    image=source.convert("RGBA")
                provenance="imported_exact_size_candidate"
            elif not force and path.is_file():
                proof=verify(path,group)
                entry={"id":asset_id,"group":group,
                       "path":path.relative_to(output).as_posix(),
                       "provenance":"existing_candidate",**meta,**proof}
                report["assets"].append(entry)
                report["counts"][group]=report["counts"].get(group,0)+1
                index[group+"."+asset_id]=entry["path"]
                continue
            else:
                image=render()
                if image.size!=SIZES[group]:
                    raise ValueError("Renderer size mismatch for "+asset_id)
            temporary=path.with_suffix(".partial.png")
            image.save(temporary,format="PNG",optimize=True)
            proof=verify(temporary,group)
            temporary.replace(path)
            entry={"id":asset_id,"group":group,
                   "path":path.relative_to(output).as_posix(),
                   "provenance":provenance,**meta,**proof}
            report["assets"].append(entry)
            report["counts"][group]=report["counts"].get(group,0)+1
            index[group+"."+asset_id]=entry["path"]
        except (OSError,ValueError,KeyError,TypeError) as exc:
            report["errors"].append({"id":asset_id,"group":group,"error":str(exc)})
    report["status"]="candidates_complete" if not report["errors"] else "candidates_partial_errors"
    (output/"candidate_index.json").write_text(
        json.dumps({"schema":"starlit.global_art_index.v3","assets":index},
                   ensure_ascii=False,indent=2)+"\n",encoding="utf-8")
    (output/"candidate_manifest.json").write_text(
        json.dumps(report,ensure_ascii=False,indent=2)+"\n",encoding="utf-8")
    return report

def main(argv=None):
    parser=argparse.ArgumentParser(description="Full-game art candidate generator; runtime assets stay unchanged")
    parser.add_argument("--project",type=Path,default=Path(__file__).resolve().parents[1])
    parser.add_argument("--output",type=Path)
    parser.add_argument("--scope",choices=("all",)+SCOPES,default="all")
    parser.add_argument("--source-root",type=Path,help="Exact-size artist/AI candidate PNGs, category/ID.png")
    parser.add_argument("--dry-run",action="store_true")
    parser.add_argument("--force",action="store_true")
    parser.add_argument("--limit",type=int,default=0)
    args=parser.parse_args(argv)
    out=args.output or args.project/"build/starlit_global_art_factory_v3"
    try:
        result=produce(args.project,out,set(SCOPES) if args.scope=="all" else {args.scope},
                       args.dry_run,args.force,max(0,args.limit),args.source_root)
    except (OSError,ValueError,KeyError,TypeError) as exc:
        print("GLOBAL ART FACTORY: "+str(exc),file=sys.stderr)
        return 2
    print(json.dumps({"status":result["status"],"counts":result["counts"],
                      "errors":result["errors"][:8],"error_count":len(result["errors"]),
                      "manifest":None if args.dry_run else str(out/"candidate_manifest.json")},
                     ensure_ascii=False,indent=2))
    return 0 if not result["errors"] else 1

if __name__=="__main__":
    raise SystemExit(main())
