#!/usr/bin/env python3
"""Export SVG-authored HD2D art to PNG; retained raster-only art is already exported."""
import json
from pathlib import Path
import cairosvg

root = Path(__file__).resolve().parents[1]
assets = json.loads((root / "assets/art/art_manifest.json").read_text(encoding="utf-8"))["assets"]
exported = 0
preserved = 0
for item in assets:
    src = root / item["path"]
    dst = src.with_suffix(".png")
    w, h = item["size"]
    if src.suffix.lower() == ".png":
        assert src.is_file(), src
        from PIL import Image
        with Image.open(src) as im:
            assert list(im.size) == [w, h], (src, im.size)
        preserved += 1
        continue
    assert src.suffix.lower() == ".svg", src
    assert src.is_file(), src
    dst.parent.mkdir(parents=True, exist_ok=True)
    cairosvg.svg2png(url=str(src), write_to=str(dst), output_width=w, output_height=h)
    exported += 1
print(f"Exported {exported} SVG assets; preserved {preserved} verified raster-only PNG assets")
