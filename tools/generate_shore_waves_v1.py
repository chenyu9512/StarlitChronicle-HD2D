#!/usr/bin/env python3
"""Create 8 playable, independent three-frame shoreline sprite sheets.

All original 2D surf foam strokes drawn over transparent canvas. The effects
are visual only; authoritative real water mask chooses their placement.
"""
from __future__ import annotations
import argparse
import hashlib
import json
import math
from pathlib import Path
from PIL import Image, ImageDraw

ROOT = Path("assets/art/runtime/shore_waves_v1")
HEADINGS = ("down", "up", "left", "right")
SIZES = {"small":32, "big":64}

def render(size: int, heading: str, phase: int) -> Image.Image:
    image=Image.new("RGBA",(size,size),(0,0,0,0))
    d=ImageDraw.Draw(image,"RGBA")
    dx={"left":-1,"right":1}.get(heading,0)
    dy={"up":-1,"down":1}.get(heading,0)
    for i in range(3):
        offset=math.sin((phase*0.7+i*0.8))*size*0.065
        y=int(size*(0.25+i*0.19)+offset+dy*2)
        p=[]
        for x in range(2,size-2,2):
            yy=int(y+math.sin(x/size*6.283+phase*1.1+i)*size*0.038)
            p.append((min(size-2,max(1,x+dx*phase)),max(1,min(size-2,yy))))
        d.line(p,fill=(217,247,240,160-i*32),width=max(1,size//20))
        if i<2:
            for k in range(4):
                x=(k*(size//4)+phase*3+i*9)%(size-6)+3
                py=y+(((k+phase)%3)-1)*3
                if 2<py<size-3:
                    d.ellipse((x-1,py-1,x+1,py+1),fill=(237,255,238,138))
    return image

def generate(project: Path, verify_only: bool=False) -> dict:
    out=project/ROOT
    records={}
    for band,size in SIZES.items():
        for heading in HEADINGS:
            file=out/(band+"_"+heading+".png")
            if not verify_only:
                result=Image.new("RGBA",(size*3,size))
                for phase in range(3):
                    result.alpha_composite(render(size,heading,phase),(size*phase,0))
                file.parent.mkdir(parents=True,exist_ok=True)
                temp=file.with_suffix(".partial.png")
                result.save(temp,format="PNG",optimize=True)
                temp.replace(file)
            if not file.is_file():
                raise FileNotFoundError(file)
            with Image.open(file) as png:
                png.verify()
            with Image.open(file) as png:
                if png.size!=(size*3,size) or png.getbbox() is None:
                    raise ValueError("Invalid shoreline frames: "+str(file))
            records[band+"_"+heading]={
                "source":"res://"+(ROOT/file.name).as_posix(),
                "size":[size*3,size],
                "sha256":hashlib.sha256(file.read_bytes()).hexdigest(),
                "status":"procedural_overlay_not_artistic_QA",
            }
    manifest={"schema":"starlit.shore_waves.runtime.v1",
        "count":8,"frames":3,"visual_acceptance":"未测试","assets":records}
    index=out/"manifest.json"
    if verify_only:
        if json.loads(index.read_text(encoding="utf-8"))!=manifest:
            raise ValueError("Wave manifest has stale identity/hash")
    else:
        index.write_text(json.dumps(manifest,ensure_ascii=False,indent=2)+"\n",encoding="utf-8")
    return {"sheets":8,"frames":3,"stage":"runtime_not_visually_approved"}

def main():
    parser=argparse.ArgumentParser()
    parser.add_argument("--project",type=Path,default=Path(__file__).resolve().parents[1])
    parser.add_argument("--verify-only",action="store_true")
    args=parser.parse_args()
    print(json.dumps(generate(args.project.resolve(),args.verify_only),ensure_ascii=False))
    return 0
if __name__=="__main__":
    raise SystemExit(main())
