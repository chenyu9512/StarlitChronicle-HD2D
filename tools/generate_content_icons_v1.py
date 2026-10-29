#!/usr/bin/env python3
"""Build 288 unique, deterministic and loadable 64px RPG UI icons.

Each canonical content ID receives an original deterministic RPG silhouette,
gets its own restrained metal/enamel mount, grade marks and ID-locked glyph.
This is usable pixel UI art, not individual hand-painted equipment art approval.
"""
from __future__ import annotations
import argparse
import hashlib
import json
import re
from pathlib import Path
from PIL import Image, ImageDraw

INDEX = Path("data/assets/c_art_content_icons_v6.json")
OUT = Path("assets/art/runtime/content_icons_v1")
PALETTE = {
    "items": ((47, 97, 82), (133, 197, 150)),
    "weapons": ((116, 69, 61), (224, 156, 111)),
    "armor": ((60, 83, 112), (157, 194, 220)),
    "skills": ((95, 67, 125), (199, 166, 225)),
}

def read(path: Path) -> dict:
    return json.loads(path.read_text(encoding="utf-8-sig"))

def draw_icon(root: Path, row: dict) -> Image.Image:
    asset_id = str(row["id"])
    group = str(row["group"])
    if not re.fullmatch(r"[a-z][a-z0-9_]{2,76}", asset_id) or group not in PALETTE:
        raise ValueError("Invalid canonical ID/group: " + repr(row))
    # Fully original silhouette drawn from canonical item/skill identity.
    # The historical third-party pictogram is not loaded or sampled.
    digest = hashlib.sha256(asset_id.encode("utf-8")).digest()
    dark, bright = PALETTE[group]
    art = Image.new("RGBA", (64, 64))
    paint = ImageDraw.Draw(art, "RGBA")
    # Rounded, repeatable metal mount; a large clear silhouette at 32px HUD scale.
    paint.rounded_rectangle((4, 6, 59, 61), radius=10,
                            fill=(13, 21, 33, 178), outline=(*dark, 255), width=2)
    paint.rounded_rectangle((8, 10, 55, 55), radius=8,
                            fill=(*dark, 222), outline=(*bright, 164), width=2)
    paint.rounded_rectangle((11, 13, 52, 51), radius=7,
                            fill=(18, 29, 43, 211))
    # Subtle grade and color treatment vary per item without changing the role.
    for layer in range(4):
        shade = tuple(min(255, v + digest[layer] % 18) for v in bright)
        paint.line((12, 15 + layer * 2, 51, 15 + layer * 2),
                   fill=(*shade, 26 + layer * 4), width=1)
    # Draw distinct original silhouettes for each RPG item family. Shape
    # varies deterministically by ID, with no third-party pixels reused.
    import math
    q = asset_id.lower()
    cx, cy = 32, 32
    if any(w in q for w in ("herb","leaf","seed","flower")):
        paint.line([(31,48),(31,19)],fill=(*bright,255),width=3)
        for side in (-1,1):
            paint.ellipse((cx-3+side*12,20, cx+3+side*12,34),fill=(*bright,245))
            paint.line((cx,36,cx+side*14,26),fill=(*dark,245),width=2)
    elif any(w in q for w in ("ether","elixir","potion","water","tonic","vial")):
        paint.polygon([(26,16),(38,16),(38,23),(45,43),(42,49),(22,49),(19,43),(26,23)],fill=(*bright,240))
        paint.rectangle((28,13,36,20),fill=(*dark,255))
        paint.ellipse((25,35,39,43),fill=(210,245,255,210))
    elif group=="weapons":
        paint.polygon([(22,44),(28,37),(37,19),(42,17),(43,24),(34,40),(28,46)],fill=(*bright,255))
        paint.line((19,27,38,44),fill=(*dark,255),width=5)
        paint.line((21,29,36,42),fill=(*bright,240),width=2)
    elif group=="armor":
        paint.polygon([(20,19),(26,16),(38,16),(44,19),(48,28),(43,29),(42,47),(22,47),(21,29),(16,28)],fill=(*bright,245))
        paint.polygon([(27,22),(37,22),(37,33),(32,39),(27,33)],fill=(*dark,230))
    elif group=="skills":
        rays=5+digest[0]%3
        for i in range(rays):
            angle=i*6.2831853/rays+digest[1]/255.0
            x=int(cx+math.cos(angle)*17); y=int(cy+math.sin(angle)*17)
            paint.line((cx,cy,x,y),fill=(*bright,235),width=3)
            paint.ellipse((x-2,y-2,x+2,y+2),fill=(234,222,161,255))
        paint.ellipse((26,26,38,38),fill=(*dark,255),outline=(*bright,255),width=2)
    else:
        paint.rounded_rectangle((20,22,44,44),radius=5,fill=(*bright,235))
        paint.line((25,19,39,19),fill=(*bright,255),width=3)
    # Each ID has an original heraldic stamp and slight individual variation.
    for bit in range(5):
        if digest[bit] & 1:
            x=23+bit*4
            paint.point((x,46),fill=(*bright,255))
    paint = ImageDraw.Draw(art, "RGBA")
    paint.line((11, 13, 19, 13), fill=(*bright, 185), width=2)
    paint.line((45, 53, 53, 53), fill=(*bright, 200), width=2)
    # Tiny 5x5 ID rune in the upper-right, stable across renders. No numerals.
    for i in range(9):
        if digest[i] & 1:
            x = 45 + (i % 3) * 2
            y = 14 + (i // 3) * 2
            paint.rectangle((x, y, x + 1, y + 1), fill=(*bright, 224))
    # Exactly one category notch (green item / copper weapon / blue armor / violet skill).
    paint.polygon([(27, 56), (32, 52), (37, 56)], fill=(*bright, 232))
    return art

def generate(root: Path, verify_only: bool = False) -> dict:
    original = read(root / INDEX)
    records = original["records"]
    if len(records) != 288 or len({r["id"] for r in records}) != 288:
        raise ValueError("Expected exactly 288 unique canonical content IDs")
    dest = root / OUT
    index = {}
    for row in records:
        asset_id = row["id"]
        path = dest / "icons" / (asset_id + ".png")
        if not verify_only:
            path.parent.mkdir(parents=True, exist_ok=True)
            rendered = draw_icon(root, row)
            staged = path.with_suffix(".partial.png")
            rendered.save(staged, format="PNG", optimize=True)
            staged.replace(path)
        if not path.is_file():
            raise FileNotFoundError("Generated icon absent: " + str(path))
        with Image.open(path) as art:
            art.verify()
        with Image.open(path) as art:
            if art.size != (64, 64) or art.getbbox() is None:
                raise ValueError("Invalid icon pixels: " + str(path))
        index[asset_id] = {
            "source": "res://" + (OUT / "icons" / (asset_id + ".png")).as_posix(),
            "group": row["group"], "generator": "original_id_shape_v2",
            "sha256": hashlib.sha256(path.read_bytes()).hexdigest(),
            "stage": "runtime_generated_visual_qa_pending",
        }
    if len({v["source"] for v in index.values()}) != len(index):
        raise ValueError("Multiple content IDs unexpectedly share the same output file")
    manifest = {
        "schema": "starlit.content_icons.runtime.v1",
        "source": str(INDEX),
        "stage": "physically_available_visual_qa_pending",
        "count": len(index),
        "assets": index,
    }
    manifest_path = dest / "manifest.json"
    if verify_only:
        actual = read(manifest_path)
        if actual != manifest:
            raise ValueError("Installed content icon manifest differs from real PNGs")
    else:
        manifest_path.write_text(json.dumps(manifest, ensure_ascii=False, indent=2) + "\n",
                                 encoding="utf-8")
    return {"status": "verified" if verify_only else "installed",
            "icons": len(index), "groups": {
                name: sum(v["group"] == name for v in index.values())
                for name in PALETTE},
            "visual_qa": "未测试"}

def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--project", type=Path,
                        default=Path(__file__).resolve().parents[1])
    parser.add_argument("--verify-only", action="store_true")
    args = parser.parse_args()
    print(json.dumps(generate(args.project.resolve(), args.verify_only),
                     ensure_ascii=False, indent=2))
    return 0

if __name__ == "__main__":
    raise SystemExit(main())
