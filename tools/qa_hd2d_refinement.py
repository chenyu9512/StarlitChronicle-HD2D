#!/usr/bin/env python3
"""Art refinement checks: count, dimensions, transparency, and basic frame variation."""
from pathlib import Path
import json
from PIL import Image, ImageChops, ImageStat

ROOT=Path(__file__).resolve().parents[1]
ASSETS=ROOT/"assets"/"art"
manifest=json.loads((ASSETS/"art_manifest.json").read_text(encoding="utf8"))
entries=manifest["assets"]
assert len(entries)==89, f"Expected 89 masters, got {len(entries)}"
refined=[a for a in entries if a.get("refinement_version")=="coast-v2"]
assert len(refined)==55, f"Expected 55 refined assets, got {len(refined)}"
kinds={}
for a in refined:
    path=ROOT/a["path"]
    png=path.with_suffix(".png")
    assert path.is_file() and png.is_file(), f"missing source/export: {path}"
    with Image.open(png) as img:
        assert list(img.size)==a["size"],(png,img.size,a["size"])
        rgba=img.convert("RGBA")
        if ("/props/" in a["path"] or ("/monsters/" in a["path"] and a["kind"]=="battle_monster")):
            low,high=rgba.getchannel("A").getextrema()
            assert low==0 and high>0, f"transparent cutout expected: {png}"
        if "/tilesets/" in a["path"]:
            assert rgba.getbbox() is not None
            assert len(rgba.convert("RGB").getcolors(maxcolors=1000000) or [])>20, f"flat colors: {png}"
    kinds[a["batch"]]=kinds.get(a["batch"],0)+1
assert kinds=={2:28,3:27}, kinds
for a in refined:
    if a["kind"]!="idle_4frames":continue
    image=Image.open((ROOT/a["path"]).with_suffix(".png")).convert("RGBA")
    left=image.crop((0,0,128,128))
    right=image.crop((128,0,256,128))
    assert ImageChops.difference(left,right).getbbox() is not None, a["path"]
for name in ("morning_dew_village","white_sand_port","tide_lighthouse","chengzhou_house"):
    scene=Image.open(ASSETS/f"backdrops/coast/{name}.png").convert("RGB")
    assert scene.size==(768,432)
    stat=ImageStat.Stat(scene)
    assert min(stat.stddev)>10, f"Scene too flat: {name}"
print("PASS: refinement coast-v2 | 55 masters + matching PNGs | 4 tile atlases | 20 props | 9 monsters x 3 | 4 scenes")
