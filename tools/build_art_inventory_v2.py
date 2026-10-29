#!/usr/bin/env python3
"""Auditable tree inventory; no archive contents or animation frames double-counted as entities."""
from __future__ import annotations
import json, os, subprocess
from collections import Counter
from pathlib import Path

ROOT=Path(__file__).resolve().parent.parent
STYLES={
    "Golden-Horizon":"hd2d_painterly",
    "painterly-backgrounds":"hd2d_painterly",
    "kenney_sketch":"pixel_town",
    "FreeCityBuilder":"pixel_town",
    "2D Characters":"chibi_character",
    "Chibi-Ragnarok":"chibi_character",
    "Aekashics":"hand_painted_battler",
    "2D Isometric":"isometric_reference",
    "Ultimate_Fantasy":"ui_icon",
}
def audit():
    tracked=subprocess.check_output(["git","ls-files","-z","assets/art"],cwd=ROOT).decode("utf-8").split("\0")
    paths=[p for p in tracked if p and (ROOT/p).is_file()]
    images=[p for p in paths if Path(p).suffix.lower() in {".png",".jpg",".jpeg",".webp",".gif",".svg"}]
    families=Counter()
    zones=Counter()
    for p in images:
        if p.startswith("assets/art/source_packs/"):
            pack=p.split("/")[3]
            label=next((v for k,v in STYLES.items() if k in pack),"reference_or_unclassified")
            zones["source_packs"]+=1
        elif p.startswith("assets/art/external/"):
            label="third_party_pixel_and_ui"
            zones["external"]+=1
        elif p.startswith("assets/art/runtime/"):
            label="curated_runtime_mixed"
            zones["runtime"]+=1
        else:
            label="other_art"
            zones["other"]+=1
        families[label]+=1
    output={"schema":"starlit.art_inventory.v2","tracked_art_images":len(images),
        "zones":dict(zones),"style_families":dict(families),
        "warning":"image files include animation frames, alternate originals and references; not game completion"}
    return output

if __name__=="__main__":
    result=audit()
    output=ROOT/"build/art-theme-v2/inventory.json"
    output.parent.mkdir(parents=True,exist_ok=True)
    output.write_text(json.dumps(result,ensure_ascii=False,indent=2)+"\n",encoding="utf-8")
    print(json.dumps(result,ensure_ascii=False,indent=2))
