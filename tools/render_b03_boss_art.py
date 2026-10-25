#!/usr/bin/env python3
"""Render only missing B03 boss-concept SVGs to checked transparent PNGs.

No B01/B02 resources or runtime art references are changed.
"""
from __future__ import annotations

import argparse
import hashlib
import json
from pathlib import Path

import cairosvg
from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parents[1]
SOURCE_DIR = ROOT / "assets/art/b03/boss_battle_concepts"
MANIFEST = SOURCE_DIR / "manifest.json"


def digest(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def validate_png(path: Path, expected: tuple[int, int]) -> dict:
    with Image.open(path) as image:
        image.verify()
    with Image.open(path) as image:
        if image.size != expected or image.mode != "RGBA":
            raise ValueError(f"{path}: wanted RGBA {expected}, got {image.mode} {image.size}")
        alpha = image.getchannel("A")
        low, high = alpha.getextrema()
        if low != 0 or high < 230:
            raise ValueError(f"{path}: bad transparency range ({low}, {high})")
        bbox = alpha.getbbox()
        if bbox is None or bbox[2] - bbox[0] < expected[0] * 0.42:
            raise ValueError(f"{path}: empty or implausibly narrow")
        color_count = len(
            image.convert("RGB").resize((64, 64)).quantize(colors=128).getcolors(4096) or []
        )
        if color_count < 12:
            raise ValueError(f"{path}: flat rendering ({color_count} colors)")
        return {
            "sha256": digest(path),
            "pixels": list(expected),
            "alpha": [low, high],
            "subject_bbox": list(bbox),
            "palette_colors": color_count,
        }


def make_review_sheet(images: list[Path], output: Path) -> None:
    tile = 282
    review = Image.new("RGB", (len(images) * tile + 40, tile + 40), "#182335")
    draw = ImageDraw.Draw(review)
    for index, filepath in enumerate(images):
        ox, oy = 32 + index * tile, 32
        for r in range(8):
            for c in range(8):
                draw.rectangle(
                    (ox + 32 * c, oy + 32 * r, ox + 32 * (c + 1) - 1, oy + 32 * (r + 1) - 1),
                    fill="#b7c3cb" if (r + c) % 2 else "#dfe6e8",
                )
        with Image.open(filepath) as image:
            avatar = image.convert("RGBA")
            avatar.thumbnail((254, 254), Image.Resampling.LANCZOS)
        review.paste(
            avatar,
            (ox + (256 - avatar.width) // 2, oy + (256 - avatar.height) // 2),
            avatar,
        )
        draw.text((ox + 5, oy + 259), f"CH{index + 2:03d}", fill="#f2d9a2")
    review.save(output, optimize=True)


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--check-only", action="store_true")
    args = parser.parse_args()
    records = json.loads(MANIFEST.read_text(encoding="utf-8"))["assets"]
    if len(records) != 5 or len({r["boss_id"] for r in records}) != 5:
        raise ValueError("Expected exactly five unique Act I boss records")

    new_files = []
    full_hashes = set()
    reviewed = {}
    display_images = []
    for record in records:
        source = ROOT / record["path"]
        if not source.is_file() or not source.read_text(encoding="utf-8").startswith("<svg"):
            raise ValueError(f"Missing or malformed source: {source}")
        export_master = source.with_suffix(".png")
        export_small = source.with_name(source.stem + "_battle_512.png")
        for output, size in (
            (export_master, (1024, 1024)),
            (export_small, (512, 512)),
        ):
            if not output.exists():
                if args.check_only:
                    raise FileNotFoundError(output)
                cairosvg.svg2png(
                    url=str(source),
                    write_to=str(output),
                    output_width=size[0],
                    output_height=size[1],
                )
                new_files.append(output.relative_to(ROOT).as_posix())
            reviewed[output.relative_to(ROOT).as_posix()] = validate_png(output, size)
        signature = reviewed[export_master.relative_to(ROOT).as_posix()]["sha256"]
        if signature in full_hashes:
            raise ValueError(f"Duplicate export for {record['boss_id']}")
        full_hashes.add(signature)
        display_images.append(export_small)

    review = SOURCE_DIR / "contact_sheet_review.png"
    if not review.exists():
        if args.check_only:
            raise FileNotFoundError(review)
        make_review_sheet(display_images, review)
        new_files.append(review.relative_to(ROOT).as_posix())
    with Image.open(review) as image:
        image.verify()
    print(
        json.dumps(
            {
                "result": "PASS",
                "bosses": 5,
                "validated_pngs": 10,
                "created_files": new_files,
                "preview": review.relative_to(ROOT).as_posix(),
                "png_details": reviewed,
            },
            ensure_ascii=False,
            indent=2,
        )
    )


if __name__ == "__main__":
    main()
