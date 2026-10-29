#!/usr/bin/env python3
"""Generate path-preserving V4.2 detail derivatives of remaining playable art.

Never overwrite provenance-locked curated source PNGs. Old layout dimensions,
alpha masks and animation grids remain pixel-exact; new files are published under
one runtime override root and activated through the canonical texture gateway.
This produces retouched derivatives, not replacement hand-painted concept art.
"""
from __future__ import annotations

import argparse
import hashlib
import json
import random
import re
from pathlib import Path
from PIL import Image, ImageEnhance, ImageFilter, ImageOps, ImageStat

SOURCE_ROOTS = (
    "assets/art/runtime/act01_global_v14",
    "assets/art/runtime/act01_hd2d_v18",
    "assets/art/runtime/act01_matched_v16",
    "assets/art/runtime/act01_semantic_v17",
    "assets/art/runtime/imported",
    "assets/art/runtime/region_monsters_v15",
    "assets/art/external/cc0_named_v1",
)
OUT = Path("assets/art/runtime/refined_overrides_v1")
SCHEMA = "starlit.refined_overrides.v1"
FORBIDDEN = ("/boss_candidates/",)
PNG_MAGIC = bytes((137, 80, 78, 71, 13, 10, 26, 10))


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def paths(root):
    result = []
    for prefix in SOURCE_ROOTS:
        for file in sorted((root / prefix).rglob("*.png")):
            if any(mark in file.as_posix() for mark in FORBIDDEN):
                continue  # Candidates without approved battle identity stay inactive.
            result.append(file)
    return result


def detail_image(original, key):
    rgba = original.convert("RGBA")
    alpha = rgba.getchannel("A")
    # Do not resample the atlas or shift a single transparent/collision pixel.
    rgb = rgba.convert("RGB")
    tiny = min(rgb.size) <= 64
    # Photo-like sources receive gentler contrast than tiny HUD and sprite art.
    colored = ImageEnhance.Color(rgb).enhance(1.045 if tiny else 1.07)
    colored = ImageEnhance.Contrast(colored).enhance(1.035 if tiny else 1.06)
    if min(rgb.size) >= 96:
        colored = colored.filter(ImageFilter.UnsharpMask(radius=0.9 if tiny else 1.25,
                                                         percent=62 if tiny else 89,
                                                         threshold=3))
    # Small, restrained palette-separation pass; keep original linework/identity.
    bias = (int(hashlib.sha256(key.encode()).hexdigest()[0:2], 16) % 3) - 1
    if bias:
        from PIL import ImageChops
        tint = Image.new("RGB", rgb.size, (0, 0, 0))
        r, g, b = colored.split()
        if bias > 0:
            r = ImageChops.add(r, Image.new("L", rgb.size, 2))
        else:
            b = ImageChops.add(b, Image.new("L", rgb.size, 2))
        colored = Image.merge("RGB", (r, g, b))
    colored.putalpha(alpha)
    return colored


def generate(root, verify_only=False):
    root = root.resolve()
    folder = root / OUT
    manifest = folder / "manifest.json"
    originals = paths(root)
    if not originals:
        raise ValueError("No canonical retained source images found")
    if verify_only:
        data = json.loads(manifest.read_text(encoding="utf-8"))
        if data.get("schema") != SCHEMA:
            raise ValueError("Unexpected detail-pass manifest schema")
        routes = data.get("routes", {})
        if len(routes) != len(originals):
            raise ValueError(f"Detail-pass inventory drift: {len(routes)} != {len(originals)}")
        for file in originals:
            key = "res://" + file.relative_to(root).as_posix()
            row = routes.get(key)
            if not row:
                raise ValueError("Missing detail-pass route: " + key)
            dest = root / row["output"].removeprefix("res://")
            if not dest.is_file() or sha(dest) != row["sha256"]:
                raise ValueError("Refined image absent or changed: " + key)
            if sha(file) != row["source_sha256"]:
                raise ValueError("Original source changed after detail pass: " + key)
            with Image.open(file) as original, Image.open(dest) as refined:
                if original.size != refined.size or original.convert("RGBA").getchannel("A").tobytes() != refined.getchannel("A").tobytes():
                    raise ValueError("Image dimensions or opacity grid changed: " + key)
        return {"status": "verified", "count": len(routes), "errors": 0}
    folder.mkdir(parents=True, exist_ok=True)
    routes = {}
    for file in originals:
        rel = file.relative_to(root).as_posix()
        key = "res://" + rel
        target = folder / rel
        target.parent.mkdir(parents=True, exist_ok=True)
        with Image.open(file) as source:
            source.load()
            original = source.convert("RGBA")
        image = detail_image(original, rel)
        if image.size != original.size or image.getchannel("A").tobytes() != original.getchannel("A").tobytes():
            raise ValueError("Detail pass changed alpha/geometry for " + rel)
        partial = target.with_suffix(".partial.png")
        image.save(partial, optimize=True)
        partial.replace(target)
        digest = sha(target)
        if digest == sha(file):
            raise ValueError("Detail pass was an exact byte-copy for " + rel)
        routes[key] = {
            "output": "res://" + target.relative_to(root).as_posix(),
            "sha256": digest,
            "source_sha256": sha(file),
            "size": list(image.size),
            "status": "derivative_visual_review_pending",
        }
    payload = {
        "schema": SCHEMA,
        "renderer": "V4.2-refined-derivative",
        "enabled": True,
        "count": len(routes),
        "quality": "source_preserving_detail_retouche_not_handpainted",
        "visual_acceptance": "not_tested",
        "routes": dict(sorted(routes.items())),
    }
    manifest.write_text(json.dumps(payload, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    verify = generate(root, verify_only=True)
    return {"status": "generated_and_verified", "count": verify["count"], "errors": 0}


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--project", type=Path, default=Path(__file__).resolve().parents[1])
    parser.add_argument("--verify-only", action="store_true")
    opts = parser.parse_args()
    result = generate(opts.project, opts.verify_only)
    print(json.dumps(result, ensure_ascii=False, indent=2))


if __name__ == "__main__":
    main()
