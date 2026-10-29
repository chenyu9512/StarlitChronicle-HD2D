#!/usr/bin/env python3
"""66 canonical boss action atlases (six states x four frames), generated
from the actual installed V3 identity art. Presentation-only; NOT individually
hand-painted animation or boss character identity approval.
"""
from __future__ import annotations
import argparse
import hashlib
import json
import math
from pathlib import Path
from PIL import Image, ImageDraw, ImageEnhance

ROOT = Path("assets/art/runtime/boss_motion_v1")
STATES = ("idle", "attack", "hit", "status", "down", "phase_change")
FRAME = 128
COLS = 4
SIZE = (COLS * FRAME, len(STATES) * FRAME)

def sha(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()

def cell(source: Image.Image, kind: str, tick: int, seed: int) -> Image.Image:
    canvas = Image.new("RGBA", (FRAME, FRAME), (0, 0, 0, 0))
    paint = ImageDraw.Draw(canvas, "RGBA")
    phase = tick / 3.0
    if kind == "phase_change":
        radius = 40 + tick * 4
        paint.ellipse((64-radius, 64-radius, 64+radius, 64+radius),
                      outline=(239, 211, 124, 130+tick*20), width=3)
    if kind == "status":
        for mark in range(3):
            x = 27 + mark * 29
            y = 17 + ((seed+mark+tick) % 7)
            paint.ellipse((x-3,y-3,x+3,y+3),fill=(141,230,242,145))
    pixels = source.copy()
    if kind == "hit":
        pixels = ImageEnhance.Color(pixels).enhance(0.7)
    width = 104 + int(6*math.sin((seed%7 + tick)*0.9))
    height = 103 + (3*tick if kind == "attack" else 0)
    if kind == "down":
        width = 106+tick*3
        height = 102-tick*16
    elif kind == "idle":
        height = 101 + int(3 * math.sin((tick+seed%3)*1.2))
    width = max(32, min(118, width))
    height = max(24, min(115, height))
    pixels = pixels.resize((width, height), Image.Resampling.LANCZOS)
    x = (FRAME-width)//2
    y = 10 + (110-height)//2
    if kind == "attack":
        x += (0, 10, 17, 4)[tick]
        y -= (0, 3, 9, 2)[tick]
    elif kind == "hit":
        x += (0, -6, 5, -2)[tick]
    elif kind == "idle":
        y += (0, -2, -4, -1)[tick]
    elif kind == "phase_change":
        y -= tick*2
    canvas.alpha_composite(pixels,(x,y))
    if kind == "hit":
        tint = Image.new("RGBA", (FRAME,FRAME), (246,62,57,32+tick*8))
        canvas = Image.alpha_composite(canvas,tint)
    elif kind == "attack":
        paint = ImageDraw.Draw(canvas, "RGBA")
        paint.arc((9+tick*3,13,117,118),205,335,fill=(255,210,142,100+tick*25),width=3)
    elif kind == "status":
        paint = ImageDraw.Draw(canvas, "RGBA")
        paint.arc((15,14,113,117),0,330,fill=(150,224,241,120+tick*15),width=2)
    elif kind == "down":
        alpha = canvas.getchannel("A").point(lambda v: v*(3-tick)//3)
        canvas.putalpha(alpha)
    return canvas

def create(root: Path, verify_only: bool=False) -> dict:
    live = root / "assets/art/runtime/global_factory_v3/active.json"
    manifest = json.loads(live.read_text(encoding="utf-8"))
    bosses = {slot.split(".",1)[1]: spec for slot,spec in manifest["assets"].items()
              if slot.startswith("bosses.")}
    if len(bosses) != 66:
        raise ValueError("Expected 66 installed canonical boss images, got %d" % len(bosses))
    output = root / ROOT
    entries = {}
    for name in sorted(bosses):
        source_rel = bosses[name]["path"].removeprefix("res://")
        source = root / source_rel
        if not source.is_file() or sha(source)!=bosses[name]["sha256"]:
            raise ValueError("Boss identity source mismatch: " + name)
        target = output / (name+".png")
        if not verify_only:
            with Image.open(source) as original:
                raw = original.convert("RGBA")
            bounds = raw.getbbox()
            if bounds:
                raw = raw.crop(bounds)
            sheet = Image.new("RGBA", SIZE, (0,0,0,0))
            seed = int(hashlib.sha256(name.encode()).hexdigest()[:6],16)
            for row,kind in enumerate(STATES):
                for tick in range(COLS):
                    sheet.alpha_composite(cell(raw,kind,tick,seed),
                                          (tick*FRAME,row*FRAME))
            target.parent.mkdir(parents=True,exist_ok=True)
            temporary=target.with_suffix(".partial.png")
            sheet.save(temporary,format="PNG",optimize=True)
            temporary.replace(target)
        if not target.is_file():
            raise ValueError("Boss action sheet missing: " + str(target))
        with Image.open(target) as check:
            check.verify()
        with Image.open(target) as check:
            if check.size!=SIZE or check.getbbox() is None:
                raise ValueError("Boss sheet has wrong pixels/dimensions: " + name)
        entries[name] = {
            "source": "res://" + (ROOT/(name+".png")).as_posix(),
            "source_identity":bosses[name]["path"],
            "source_sha256":bosses[name]["sha256"],
            "sha256": sha(target),
            "states":list(STATES),
            "frames_per_state":COLS,
            "frame":[FRAME,FRAME],
            "status":"procedurally_animated_original_identity_visual_QA_pending",
        }
    installed={"schema":"starlit.boss_motion.runtime.v1","count":len(entries),
        "source":"global_factory_v3_boss_identity",
        "visual_acceptance":"未测试","individual_hand_drawn_motion":False,
        "assets":entries}
    index=output/"manifest.json"
    if verify_only:
        if json.loads(index.read_text(encoding="utf-8"))!=installed:
            raise ValueError("Boss motion manifest content/hashes inconsistent")
    else:
        index.write_text(json.dumps(installed,ensure_ascii=False,indent=2)+"\n",encoding="utf-8")
    return {"bosses":len(entries),"states":len(STATES),"frames_per_state":COLS,
            "qa":"real_pngs_verified; human_visual_unverified"}

def main():
    ap=argparse.ArgumentParser()
    ap.add_argument("--project",type=Path,default=Path(__file__).resolve().parents[1])
    ap.add_argument("--verify-only",action="store_true")
    args=ap.parse_args()
    print(json.dumps(create(args.project.resolve(),args.verify_only),ensure_ascii=False))
    return 0
if __name__=="__main__":
    raise SystemExit(main())
