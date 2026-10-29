#!/usr/bin/env python3
"""Rebuild all 25 authored world-decor placements as unique generated 32px art.

The old third-party image files were purged. Keep placement/route coordinates
and collision policy; replace exactly the sprite sources, not scene geometry.
"""
from __future__ import annotations
import argparse
import hashlib
import json
import random
from pathlib import Path
from PIL import Image, ImageDraw

ROOT="assets/art/runtime/allocated_decor_generated_v1"
SOURCE="data/assets/c_art_allocated_decor_runtime_v1.json"
SCHEMA="starlit.allocated_decor_generated.v1"


def make_icon(kind, identity):
    rng=random.Random(int(hashlib.sha256(identity.encode()).hexdigest()[:12],16))
    art=Image.new("RGBA",(96,96))
    d=ImageDraw.Draw(art,"RGBA")
    dark=(36,46,54,255); wood=(123,90,62,255)
    gold=(214,181,108,255); stone=(123,135,127,255)
    leaf=(85,145,93,255)
    if "tree" in kind or "bamboo" in kind:
        for x in (46,50):
            d.rectangle((x,39,x+4,88),fill=wood)
        for x,y,r in ((23,39,21),(47,24,25),(69,43,19),(44,49,24)):
            color=(208,139,175,245) if "cherry" in kind else ((198,114,69,250) if "maple" in kind else leaf)
            d.ellipse((x-r,y-r,x+r,y+r),fill=color,outline=dark,width=2)
            for j in range(8):
                xx=x+rng.randrange(-r+3,r-2);yy=y+rng.randrange(-r+3,r-2)
                d.ellipse((xx,yy,xx+3,yy+3),fill=(240,215,146,170))
        if "bamboo" in kind:
            for x in (28,50,69):
                d.line((x,89,x+4,12),fill=(73,139,86,245),width=5)
                for y in (28,51,72):
                    d.line((x-6,y,x+11,y-3),fill=(143,186,115,255),width=3)
    elif kind in ("torii_gate","wooden_gate_mon","watchtower_base","shrine_wall_segment","temple_pillar"):
        if kind=="temple_pillar":
            d.rectangle((34,13,63,88),fill=stone,outline=dark,width=3)
            d.rectangle((23,9,73,20),fill=gold,outline=dark,width=2)
            d.rectangle((23,82,73,91),fill=gold,outline=dark,width=2)
            for x in (42,55):d.line((x,21,x,80),fill=(204,213,187,175),width=2)
        elif kind=="shrine_wall_segment":
            d.rectangle((5,30,91,83),fill=stone,outline=dark,width=3)
            for y in (47,65):d.line((8,y,88,y),fill=(80,97,97,255),width=2)
            for x in (25,59):d.line((x,47,x,66),fill=(80,97,97,255),width=2)
        else:
            for x in (19,69):d.rectangle((x,26,x+9,90),fill=wood,outline=dark,width=2)
            d.rectangle((8,22,88,33),fill=(172,78,63,255),outline=dark,width=2)
            d.rectangle((4,13,91,22),fill=(194,103,67,255),outline=dark,width=2)
            if kind=="watchtower_base":
                for x in (22,72):d.line((x,33,48,80),fill=gold,width=3)
    elif "lantern" in kind:
        d.rectangle((43,48,53,90),fill=stone,outline=dark,width=2)
        d.polygon(((23,49),(32,26),(66,26),(75,49)),fill=stone,outline=dark)
        d.rectangle((34,32,64,52),fill=(246,211,129,255),outline=dark,width=3)
        d.ellipse((42,35,56,49),fill=(252,240,178,255))
    elif "well" in kind:
        d.ellipse((12,37,86,86),fill=stone,outline=dark,width=3)
        d.ellipse((22,44,78,78),fill=(48,112,139,255),outline=dark,width=3)
        d.line((25,41,25,14),fill=wood,width=6)
        d.line((70,41,70,14),fill=wood,width=6)
        d.polygon(((16,18),(48,2),(79,18)),fill=wood,outline=dark)
    elif kind in ("stone_steps","mossy_stone_path","rock_cluster"):
        for j in range(4):
            x=rng.randrange(3,64);y=9+j*20
            d.rounded_rectangle((x,y,x+29,y+18),radius=4,fill=(111+j*7,122+j*5,119+j*3,255),outline=dark,width=2)
            d.line((x+4,y+4,x+23,y+4),fill=(187,195,173,200),width=2)
            if "mossy" in kind:d.ellipse((x+4,y+7,x+12,y+12),fill=leaf)
    elif kind in ("offering_box","sake_barrel","katana_stand","market_stall_roof"):
        if kind=="market_stall_roof":
            d.polygon(((7,44),(30,20),(67,20),(88,44)),fill=(163,89,77,255),outline=dark)
            for x in range(20,77,13):d.line((x,28,x+6,41),fill=gold,width=3)
            for x in (20,76):d.line((x,44,x,88),fill=wood,width=6)
        elif kind=="katana_stand":
            for x in (21,76):d.rectangle((x,45,x+6,86),fill=wood)
            for y in (48,67):d.line((25,y,77,y),fill=dark,width=5)
            d.line((28,36,78,46),fill=(200,207,208,255),width=4)
            d.line((29,34,77,44),fill=gold,width=1)
        else:
            d.rounded_rectangle((23,31,74,87),radius=6,fill=wood,outline=dark,width=3)
            for y in (39,64,80):d.line((25,y,72,y),fill=gold,width=3)
            for x in (36,59):d.line((x,34,x,83),fill=(88,65,48,200),width=2)
    else:
        d.rectangle((19,37,77,80),fill=wood,outline=dark,width=3)
        for y in (49,63,74):d.line((22,y,74,y),fill=gold,width=2)
        if kind=="wooden_fence":
            for x in (25,44,64):d.line((x,23,x,88),fill=wood,width=8)
        elif kind=="fallen_log":
            d.ellipse((15,37,43,81),fill=gold,outline=dark,width=3)
            d.ellipse((22,45,37,71),outline=wood,width=3)
    return art.resize((32,32),Image.Resampling.LANCZOS)


def generate(project):
    path=project/SOURCE
    raw=json.loads(path.read_text(encoding="utf-8"))
    if raw.get("schema")!="starlit.c.allocated_decor_runtime.v1" or len(raw.get("placements",[]))!=25:
        raise ValueError("Expected 25 canonical region prop placements")
    folder=project/ROOT
    folder.mkdir(parents=True,exist_ok=True)
    records={}
    for row in raw["placements"]:
        key=row["id"]
        if not key.replace("_","").isalnum():
            raise ValueError("Unsafe placement ID")
        file=folder/(key+".png")
        make_icon(row["kind"],key).save(file,optimize=True)
        source="res://"+file.relative_to(project).as_posix()
        row["source"]=source
        digest=hashlib.sha256(file.read_bytes()).hexdigest()
        records[key]={"source":source,"sha256":digest,"kind":row["kind"],"map_id":row["map_id"],"size":[32,32]}
    path.write_text(json.dumps(raw,ensure_ascii=False,indent=2)+"\n",encoding="utf-8")
    manifest={"schema":SCHEMA,"count":len(records),"assets":records}
    (folder/"manifest.json").write_text(json.dumps(manifest,ensure_ascii=False,indent=2)+"\n",encoding="utf-8")
    return manifest


def main():
    p=argparse.ArgumentParser()
    p.add_argument("--project",type=Path,default=Path(__file__).resolve().parents[1])
    opts=p.parse_args()
    data=generate(opts.project.resolve())
    print(json.dumps({"status":"generated","count":data["count"]}))
if __name__=="__main__":main()
