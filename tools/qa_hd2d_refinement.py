#!/usr/bin/env python3
"""Verify current Main2 curated assets instead of intentionally deleted legacy masters."""
import json
from pathlib import Path
from xml.etree import ElementTree
import struct
ROOT=Path(__file__).resolve().parents[1]
themes=json.loads((ROOT/"data/assets/art_theme_v2.json").read_text(encoding="utf-8"))
slots=next(x["slots"] for x in themes["themes"] if x["id"]=="starlit_hd2d_act01")
assert len(slots)>=70
assert sum(bool(x.get("required")) for x in slots.values())>=14
for name,entry in slots.items():
    path=ROOT/entry["source"].removeprefix("res://")
    assert path.is_file(), (name,path)
    if path.suffix==".png":
        with path.open("rb") as image:
            header=image.read(24)
        assert len(header)>=24 and header[:8]==bytes.fromhex("89504e470d0a1a0a"), name
        width,height=struct.unpack(">II",header[16:24])
        assert width>=8 and height>=8, (name,width,height)
    elif path.suffix==".svg":
        assert ElementTree.parse(path).getroot().tag.endswith("svg"), name
    else:
        raise AssertionError("Unsupported V2 runtime image: "+str(path))
print("PASS: %d real V2 art files valid. Historical art removed by migration; human screenshot approval pending."%len(slots))
