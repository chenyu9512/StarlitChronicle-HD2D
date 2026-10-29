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
from art_style_v8 import (terrain_cell, character_sheet, draw_prop,
                          enemy_sheet, landscape, normal_map, write_auxiliary_svgs)

VERSION = "4.2.0"
NORMAL_GROUPS = frozenset(("terrain", "interiors", "props", "characters", "npcs", "monsters", "bosses"))
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

def tile(d, x, y, c, kind, seed):
    return terrain_cell(d, x, y, c, kind, seed)

# Material colors are biome roles, not the three-color regional mood board.
# The sea-blue Coast mood swatch must never become grass.
TERRAIN_ROLE_COLORS = {
    "region_coast": ("#789674","#baa47e","#737e80","#947859","#928a77","#d9c59d","#386a82","#655d5d"),
    "region_oaths": ("#8c986c","#b09b78","#686d79","#866a55","#a7a093","#cdb68a","#486a83","#656678"),
    "region_forge": ("#877962","#ad7759","#615963","#796459","#8e7970","#d6b48c","#546779","#514950"),
    "region_isles": ("#5d9a72","#e0ca95","#788b85","#aa8660","#9a988a","#e9d9aa","#427d97","#5f7074"),
    "region_mirror": ("#86968a","#c1b1bf","#8a899a","#8e8196","#afa6b4","#d6c9cf","#567d9b","#757585"),
    "region_oldland": ("#748c66","#9b866a","#62675e","#8e755c","#837e6e","#baa583","#526f74","#535850"),
    "region_sanctum": ("#a0ae85","#d9c7a1","#aab0b3","#b49a7f","#c9bcaa","#e8d8bc","#7598b0","#aaa99f"),
    "region_city": ("#87927c","#b9a187","#7d858a","#946e58","#a29b90","#d0bba1","#607f98","#6e6c72"),
}
def _hexrgb(value):
    return tuple(int(value[i:i+2],16) for i in (1,3,5))

def atlas(region,room_id=""):
    a,b,c=colors(region)
    kinds=("grass","road","stone","wood","cobbles","sand","water","wall")
    semantic=TERRAIN_ROLE_COLORS.get(region["id"])
    bases=tuple(map(_hexrgb,semantic)) if semantic else (a,b,shade(c,.15),blend(b,c,.35),shade(b,-.14),shade(b,.25),c,shade(c,-.2))
    if room_id:
        kinds=("wood","wood","cobbles","grass","stone","road","wall","sand")
        bases=(shade(b,.18),b,a,shade(a,.25),c,shade(b,.38),shade(c,-.2),shade(b,.46))
    out=Image.new("RGBA",(256,256),(0,0,0,0)); d=ImageDraw.Draw(out)
    for row,(kind,base) in enumerate(zip(kinds,bases)):
        for col in range(8):
            tile(d,col*32,row*32,base,kind,
                 seeded(region["id"],room_id,row,col))
    return out

def backdrop(entry,region):
    return landscape(entry,region)

def prop(region,kind):
    return draw_prop(region,kind)

def walker(asset_id,region):
    return character_sheet(asset_id,region)

def enemy(asset_id,region,boss=False):
    return enemy_sheet(asset_id,region,boss)

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

def write_normal_candidate(image,output,group,asset_id):
    """Non-destructive sibling PNG with identical image size/alpha."""
    relative=Path("normal_maps")/group/(asset_id+"_n.png")
    final=output/relative
    final.parent.mkdir(parents=True,exist_ok=True)
    temporary=final.with_suffix(".partial.png")
    baked=normal_map(image)
    if baked.size!=image.size or baked.getchannel("A").tobytes()!=image.convert("RGBA").getchannel("A").tobytes():
        raise ValueError("Normal map alpha/size mismatch for "+asset_id)
    baked.save(temporary,format="PNG",optimize=True)
    verify(temporary,group)
    temporary.replace(final)
    return {"normal_map_path":relative.as_posix(),
            "normal_map_sha256":hashlib.sha256(final.read_bytes()).hexdigest()}

def produce(root,output,selected,dry_run=False,force=False,limit=0,source_root=None,
            normal_maps=True,legacy_ui=True):
    root=root.resolve(); output=output.resolve()
    if output in (root,root/"assets",root/"assets/art",root/"assets/art/runtime"):
        raise ValueError("Refusing to overwrite live art directories")
    queue=tasks(root,selected)
    if limit:
        queue=queue[:limit]
    report={"schema":"starlit.global_art_factory.v3","version":VERSION,
            "source":"canonical maps, AV registry and V4 interiors",
            "status":"candidate_only_not_runtime_integrated",
            "game_runtime_modified":False,"counts":{},"assets":[],"errors":[],
            "normal_map_count":0,"auxiliary_svg_paths":[] }
    if dry_run:
        for group,*_ in queue:
            report["counts"][group]=report["counts"].get(group,0)+1
        report["status"]="dry_run"
        return report
    output.mkdir(parents=True,exist_ok=True)
    index={}
    prior_path=output/"candidate_manifest.json"
    try:
        previous=read(prior_path) if prior_path.is_file() else {}
    except (OSError,ValueError,TypeError):
        previous={}
    cache_version=previous.get("version")==VERSION
    # Never discard reviewed artist/AI imports merely because the procedural
    # renderer version changed. Only procedural candidates are regenerated.
    curated_previous={(a.get("group"),a.get("id")):a for a in previous.get("assets",[])
                      if isinstance(a,dict) and a.get("provenance") in
                      ("imported_exact_size_candidate","existing_curated_candidate")}
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
            elif not force and path.is_file() and (cache_version or (group,asset_id) in curated_previous):
                proof=verify(path,group)
                entry={"id":asset_id,"group":group,
                       "path":path.relative_to(output).as_posix(),
                       "provenance":("existing_candidate" if cache_version and
                         (group,asset_id) not in curated_previous else "existing_curated_candidate"),
                       **meta,**proof}
                if normal_maps and group in NORMAL_GROUPS:
                    target=output/"normal_maps"/group/(asset_id+"_n.png")
                    if target.is_file() and not force:
                        verified=verify(target,group)
                        entry["normal_map_path"]=target.relative_to(output).as_posix()
                        entry["normal_map_sha256"]=verified["sha256"]
                    else:
                        with Image.open(path) as existing:
                            info=write_normal_candidate(existing.convert("RGBA"),output,group,asset_id)
                        entry.update(info)
                        report["normal_map_count"]+=1
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
            if normal_maps and group in NORMAL_GROUPS:
                entry.update(write_normal_candidate(image,output,group,asset_id))
                report["normal_map_count"]+=1
            report["assets"].append(entry)
            report["counts"][group]=report["counts"].get(group,0)+1
            index[group+"."+asset_id]=entry["path"]
        except (OSError,ValueError,KeyError,TypeError) as exc:
            report["errors"].append({"id":asset_id,"group":group,"error":str(exc)})
    if legacy_ui and "ui" in selected:
        try:
            report["auxiliary_svg_paths"]=write_auxiliary_svgs(output)
        except (OSError,ValueError,TypeError) as exc:
            report["errors"].append({"group":"ui_svg","error":str(exc)})
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
    parser.add_argument("--no-normal-maps",action="store_true",help="Skip normal-map baking")
    parser.add_argument("--no-legacy-ui",action="store_true",help="Skip 8 job + 4 evidence SVG assets")
    parser.add_argument("--limit",type=int,default=0)
    args=parser.parse_args(argv)
    out=args.output or args.project/"build/starlit_global_art_factory_v3"
    try:
        result=produce(args.project,out,set(SCOPES) if args.scope=="all" else {args.scope},
                       args.dry_run,args.force,max(0,args.limit),args.source_root,
                       normal_maps=not args.no_normal_maps,legacy_ui=not args.no_legacy_ui)
    except (OSError,ValueError,KeyError,TypeError) as exc:
        print("GLOBAL ART FACTORY: "+str(exc),file=sys.stderr)
        return 2
    print(json.dumps({"status":result["status"],"counts":result["counts"],
                      "errors":result["errors"][:8],"error_count":len(result["errors"]),
                      "normal_map_count":result["normal_map_count"],
                      "auxiliary_svg_count":len(result["auxiliary_svg_paths"]),
                      "manifest":None if args.dry_run else str(out/"candidate_manifest.json")},
                     ensure_ascii=False,indent=2))
    return 0 if not result["errors"] else 1

if __name__=="__main__":
    raise SystemExit(main())
