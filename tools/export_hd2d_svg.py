#!/usr/bin/env python3
"""Export reproducible HD2D PNG art from SVG masters with CairoSVG."""
import json
from pathlib import Path
import cairosvg
root=Path(__file__).resolve().parents[1]
assets=json.loads((root/"assets/art/art_manifest.json").read_text(encoding="utf-8"))["assets"]
for item in assets:
    src=root/item["path"]
    dst=src.with_suffix(".png")
    w,h=item["size"]
    dst.parent.mkdir(parents=True,exist_ok=True)
    cairosvg.svg2png(url=str(src),write_to=str(dst),output_width=w,output_height=h)
print("Exported",len(assets),"PNG assets")
