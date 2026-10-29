#!/usr/bin/env python3
"""Draw missing first-act semantic sprites removed with retired source packs.

Outputs own vector-rendered HD-2D PNGs under a new runtime namespace. Never
mislabels a generic prop as a harbor crane, lighthouse or tavern ledger.
"""
from __future__ import annotations
import argparse
import hashlib
import json
from pathlib import Path
from PIL import Image, ImageDraw
from art_style_v7 import Ink, _reduce

ROOT="assets/art/runtime/semantic_generated_v1"
SCHEMA="starlit.semantic_generated.v1"
ROLES=(
    "scene.coast.sea_crystal",
    "scene.coast.harbor_crane",
    "scene.coast.tide_pool",
    "prop.coast.sign",
    "landmark.coast.tide_lighthouse_landmark",
    "interior.tavern.tavern_bench",
    "interior.tavern.tavern_counter",
    "interior.tavern.tavern_ledger",
    "interior.tavern.tavern_table",
)

def paint(role):
    raw=Image.new("RGBA",(288,384))
    d=Ink(raw,3)
    ink=(31,42,54,255)
    wood=(126,84,56,255)
    timber=(174,119,72,255)
    brass=(230,190,104,255)
    light=(234,225,191,255)
    aqua=(80,191,194,255)
    if role=="scene.coast.sea_crystal":
        d.ellipse((13,110,83,119),(15,38,58,80))
        for cx,h,w in ((31,75,15),(48,43,17),(65,67,18)):
            d.poly([(cx-w,112),(cx-w//2,h),(cx,h-16),(cx+w//2,h+5),(cx+w,112)],
                   (52,130,158,240),ink,1.2)
            d.poly([(cx,h-16),(cx+w//2,h+5),(cx+2,111)],
                   (125,233,231,210))
            d.line([(cx,h-12),(cx-3,106)],light,1)
        for x,y in ((20,80),(72,54),(80,105)):
            d.ellipse((x,y,x+3,y+3),brass)
    elif role=="scene.coast.harbor_crane":
        d.ellipse((12,111,91,120),(16,33,47,80))
        d.poly([(21,107),(26,20),(37,20),(42,108)],wood,ink,2)
        d.poly([(27,31),(78,24),(83,33),(36,42)],timber,ink,1.6)
        for y in range(36,102,12):d.line([(25,y),(39,y+4)],brass,.8)
        d.line([(75,31),(75,86)],ink,2)
        d.line([(75,85),(69,92),(72,99),(82,99),(85,92)],brass,2)
        d.poly([(16,103),(49,103),(54,112),(12,112)],timber,ink,1)
        d.ellipse((29,43,41,56),brass,ink,1)
    elif role=="scene.coast.tide_pool":
        d.ellipse((7,73,91,116),(76,75,72,255),ink,2)
        d.ellipse((15,80,83,109),(26,103,123,245),(135,188,171,255),1)
        for cx,cy in ((18,88),(82,94),(34,110),(66,82)):
            d.poly([(cx-9,cy+1),(cx-4,cy-6),(cx+4,cy-4),(cx+8,cy+3)],(111,113,107,255),ink,.8)
        for cx,cy in ((31,89),(52,96),(66,92)):
            d.arc((cx-12,cy-4,cx+10,cy+4),190,355,(176,234,213,190),.9)
    elif role=="prop.coast.sign":
        d.ellipse((16,110,80,117),(15,33,42,70))
        d.poly([(45,37),(55,37),(54,112),(45,112)],wood,ink,1.8)
        d.poly([(12,41),(73,41),(87,52),(73,63),(12,63)],timber,ink,1.5)
        d.line([(15,45),(72,45)],brass,1)
        d.line([(18,58),(72,58)],(81,53,41,255),.8)
        for x in (23,70):d.ellipse((x,50,x+2,52),brass)
    elif role=="landmark.coast.tide_lighthouse_landmark":
        d.ellipse((12,109,89,121),(21,35,53,84))
        d.poly([(30,108),(37,45),(66,45),(73,108)],light,ink,2.1)
        for y in (61,81,102):
            d.poly([(35-(y-61)*.03,y),(68+(y-61)*.03,y),(67+(y-61)*.03,y+5),(34-(y-61)*.03,y+5)],
                   (169,99,78,255))
        d.rect((30,31,75,44),wood,ink,1.3)
        for x in range(35,74,8):d.line([(x,31),(x,44)],brass,.8)
        d.poly([(26,31),(52,13),(78,31)],(119,81,66,255),ink,1.3)
        d.rect((40,32,65,41),brass,ink,.7)
        d.poly([(64,35),(94,18),(94,53)],(252,237,162,60))
        d.rect((45,90,57,108),ink,brass,1)
    elif role.startswith("interior.tavern."):
        kind=role.rsplit(".",1)[1]
        d.ellipse((12,111,85,120),(18,32,45,68))
        if kind in ("tavern_bench","tavern_table","tavern_counter"):
            width=80 if kind=="tavern_counter" else 67
            left=(96-width)//2
            top=64 if kind=="tavern_counter" else 84
            d.poly([(left,top),(left+width,top),(left+width-7,top+15),(left-7,top+15)],
                   timber,ink,2)
            d.line([(left,top+3),(left+width-1,top+3)],brass,.8)
            for x in (left+5,left+width-13):
                d.poly([(x,top+15),(x+8,top+15),(x+6,109),(x+1,109)],wood,ink,1)
            if kind=="tavern_counter":
                d.rect((left+7,top+17,left+width-10,104),wood,ink,1)
                for x in range(left+13,left+width-12,18):
                    d.rect((x,top+24,x+11,top+34),(137,90,62,255),brass,1)
            if kind=="tavern_bench":
                d.rect((left+1,top-29,left+width-5,top-18),wood,ink,1.5)
                d.line([(left+7,top-18),(left+7,top)],brass,1)
                d.line([(left+width-11,top-18),(left+width-11,top)],brass,1)
        else:
            d.poly([(17,77),(47,70),(77,77),(77,111),(47,106),(17,111)],(235,217,170,255),ink,2)
            d.line([(47,74),(47,106)],(157,114,77,255),1.2)
            for y in (82,90,98):
                d.line([(23,y),(42,y-3)],(148,110,91,255),.8)
                d.line([(52,y-3),(72,y)],(148,110,91,255),.8)
            d.poly([(39,73),(47,68),(56,73),(47,79)],brass,ink,.8)
    return _reduce(raw,(96,128))


def generate(project):
    root=project/ROOT
    root.mkdir(parents=True,exist_ok=True)
    routes={}
    for role in ROLES:
        filename=role.replace(".","__")+".png"
        image=paint(role)
        file=root/filename
        image.save(file,optimize=True)
        routes[role]={"source":"res://"+file.relative_to(project).as_posix(),
                      "sha256":hashlib.sha256(file.read_bytes()).hexdigest(),
                      "size":[96,128],"stage":"generated_visual_review_pending"}
    payload={"schema":SCHEMA,"count":len(routes),"routes":routes}
    (root/"manifest.json").write_text(json.dumps(payload,ensure_ascii=False,indent=2)+"\n")
    return payload


def main():
    parser=argparse.ArgumentParser()
    parser.add_argument("--project",type=Path,default=Path(__file__).resolve().parents[1])
    opts=parser.parse_args()
    value=generate(opts.project.resolve())
    print(json.dumps({"status":"generated","count":value["count"]},ensure_ascii=False))

if __name__=="__main__":main()
