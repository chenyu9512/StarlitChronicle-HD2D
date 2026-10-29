#!/usr/bin/env python3
"""Model-assisted high-detail asset production for Global Art Factory V3.

Only --render makes image-generation API calls; --jobs-only exports prompts
with zero API usage. Uses the same canonical IDs as global_art_factory_v3.py.
Generated art enters the exact-size candidate import folder, never runtime.
"""
from __future__ import annotations
import argparse
import base64
import io
import json
import os
import sys
import hashlib
from pathlib import Path

from PIL import Image
from global_art_factory_v3 import SCOPES, SIZES, read, safe, tasks

MODEL = "gpt-image-2.5-sunburst"
QUALITY = "xhigh"
PIPELINE_REV = "quality-v4-20261029"
TRANSPARENT = frozenset(("props", "characters", "npcs", "monsters", "bosses"))
# The image API permits up to 3:1; we crop creature masters to the 4:1 strip.
SOURCE_SIZES = {
    "terrain": "1536x1536", "maps": "1536x864",
    "interiors": "1536x1536", "props": "1024x1536",
    "characters": "1024x2048", "npcs": "1024x2048",
    "monsters": "1536x512", "bosses": "1536x512", "ui": "1536x512"}
FRAMES = {"characters": (4, 3), "npcs": (4, 3),
          "monsters": (1, 4), "bosses": (1, 4)}
STYLE = (
    "Original premium hand-painted high definition 2D Japanese fantasy RPG art. "
    "Precise authored silhouettes and anatomy, readable even at 32px, richly "
    "layered color temperature, soft painterly texture and controlled highlights, "
    "coherent light direction, believable materials, beautiful original design. "
    "Consistent visual language and scale across the entire game. Strictly 2D: "
    "no 3D renders, no stock clipart, no photo collage, no flat geometric placeholders. "
    "No letters, caption, text, copyright logos, framing mockups or watermark.")
DESIGN = {
    "terrain": "Top-down orthographic EIGHT by EIGHT independent tileable material cells "
               "with invisible boundaries, never a landscape illustration. Rows: organic ground, "
               "road, stone, planks, cobbles, sand, water, walls. Uniform lighting, no "
               "perspective, no printed grid lines, no shadows crossing cell boundaries.",
    "maps": "One detailed original 2D panoramic parallax scenery plate, distant landmark "
            "clarity and atmospheric near/mid/far layers, no gameplay terrain or collision.",
    "interiors": "TOP-DOWN 8x8 orthographic material texture atlas, exactly 64 separate "
                 "square cells. Believable floor, wall, rug, stone and timber materials, "
                 "seamless tiling, no furniture, no people, no isometric room mockup.",
    "props": "One perfectly isolated three-quarter-view 2D functional object, fine handmade "
             "material details and recognizable silhouette, bottom-center floor contact; "
             "TRUE transparent background, no cast floor shadows or scenery.",
    "characters": "Exactly four horizontal rows (front,left,back,right) of three walking "
                  "animation frames each (step, idle, step), total TWELVE rectangular "
                  "cells. Same recognizable clothing and proportions in every frame, "
                  "identical feet baselines, 32x48 target pixels per cell. TRUE transparency.",
    "npcs": "EXACTLY 4 direction rows (front,left,back,right) by 3 frames per row. "
            "Maintain exactly one same identifiable NPC per cell, stable body and "
            "costume design, 32x48 target per cell, aligned baseline. TRUE transparency.",
    "monsters": "Four different but subtly animated IDLE poses of SAME unique monster "
                "across FOUR square cells left-to-right, identical anatomy and markings. "
                "Center four cells in the MIDDLE 75% height of source; leave 12.5% "
                "transparent padding above and below for crop. TRUE transparency.",
    "bosses": "Four distinct aligned idle-phase frames of the SAME unique story boss, "
              "exquisite narrative silhouette and original phase ornaments, consistent "
              "body proportions and gear across all four square cells. Composition only "
              "in the middle 75% of source height, transparent top/bottom 12.5% margin. "
              "TRUE transparency. Never use a generic recycled enemy.",
    "ui": "Elegant meticulously hand-drawn ornate JRPG dialog frame, sophisticated brass "
          "filigree with regional accents, clean EMPTY central readable field, "
          "balanced corners. No typography, lettering or icons.",
}

def name_index(root: Path) -> dict:
    av = read(root / "data/assets/av_registry.json")
    maps = read(root / "data/content/maps.json")
    idx = {}
    for group, key in (("characters","characters"),("npcs","npcs"),
                       ("monsters","monsters"),("bosses","bosses")):
        for item in av.get(key, []):
            idx[(group,str(item["id"]))] = str(item.get("name",item["id"]))
    for item in maps.get("entries", []):
        idx[("maps",str(item["id"]))] = str(item.get("name",item["id"]))
    for item in av.get("regions", []):
        idx[("terrain",str(item["id"]))] = str(item.get("name",item["id"]))
    return idx

def build_jobs(root: Path, selected: set[str], limit: int = 0) -> list[dict]:
    av = read(root / "data/assets/av_registry.json")
    map_items = read(root / "data/content/maps.json").get("entries", [])
    regions = {r["id"]: r for r in av.get("regions", [])}
    names = name_index(root)
    entity_index = {
        group: {str(item["id"]): item for item in av.get(group, [])}
        for group in ("characters", "npcs", "monsters", "bosses")}
    entity_index["maps"] = {str(item["id"]): item for item in map_items}
    queue = tasks(root, selected)
    if limit:
        queue = queue[:limit]
    output = []
    for group, asset_id, meta, _ in queue:
        region = regions.get(meta.get("region_id", ""), {})
        style = region.get("style", {})
        label = names.get((group, asset_id), asset_id)
        target = SIZES[group]
        entity = entity_index.get(group, {}).get(asset_id, {})
        details = "; ".join(str(entity[k]) for k in
                            ("description", "appearance", "visual", "role", "type", "kind", "species")
                            if entity.get(k))
        location = str(meta.get("building_id", "") or meta.get("kind", ""))
        prompt = (
            STYLE + "\nCANONICAL ART IDENTITY: " + label + " (" + asset_id + ").\n"
            "REGION: " + str(region.get("name", meta.get("region_id", ""))) + ". "
            "Art motifs: " + str(style.get("motif", "")) + ". "
            "Color palette: " + ", ".join(map(str, style.get("palette", []))) + ".\n"
            "LORE AND FUNCTION: " + details + "; " + location + ".\n"
            "ASSET SPECIFICATION: " + DESIGN[group] + "\n"
            "TARGET IN-GAME RASTER: " + str(target[0]) + " x " + str(target[1]) +
            " pixels; compose master art with tiny-screen readability and safe margins. "
            "Deliver original high-quality art without text.")
        output.append({
            "group": group, "id": asset_id, "name": label,
            "target_size": list(target), "source_size": SOURCE_SIZES[group],
            "frame_grid": list(FRAMES[group]) if group in FRAMES else None,
            "prompt": prompt, "metadata": meta,
            "qa": "candidate_identity_and_animation_review_required"})
    return output

def fit(image_bytes: bytes, desired: tuple[int, int],
        transparency: bool, group: str = "") -> Image.Image:
    """Rasterize a high-res master, preserving proportions and real alpha."""
    with Image.open(io.BytesIO(image_bytes)) as source:
        source.load()
        im = source.convert("RGBA")
    if group in ("monsters", "bosses"):
        # Source 3:1 -> central 4:1 strip; no stretching/distorted creatures.
        crop_h = round(im.width * desired[1] / desired[0])
        if crop_h <= im.height:
            y0 = (im.height - crop_h) // 2
            im = im.crop((0, y0, im.width, y0 + crop_h))
    if not transparency:
        # Full-bleed instead of letterboxing on an arbitrary dark background.
        ratio = max(desired[0] / im.width, desired[1] / im.height)
        w, h = max(1, round(im.width * ratio)), max(1, round(im.height * ratio))
        im = im.resize((w, h), Image.Resampling.LANCZOS)
        x, y = (w - desired[0]) // 2, (h - desired[1]) // 2
        return im.crop((x, y, x + desired[0], y + desired[1]))
    if group == "props":
        # Never crop/reflow structured sprite sheets; only isolate single props.
        box = im.getchannel("A").getbbox()
        if box:
            im = im.crop(box)
        bounds = (round(desired[0] * .90), round(desired[1] * .92))
    else:
        bounds = desired
    im.thumbnail(bounds, Image.Resampling.LANCZOS)
    canvas = Image.new("RGBA", desired, (0, 0, 0, 0))
    x = (desired[0] - im.width) // 2
    y = desired[1] - im.height if group == "props" else (desired[1] - im.height) // 2
    canvas.alpha_composite(im, (x, y))
    return canvas


def quality_metrics(image: Image.Image, group: str) -> dict:
    """Basic machine QA only; visual identity/animation still requires review."""
    if image.size != SIZES[group]:
        raise ValueError("WRONG_CANVAS_DIMENSIONS")
    rgba = image.convert("RGBA")
    histogram = rgba.getchannel("A").histogram()
    pixels = image.width * image.height
    transparent_ratio = sum(histogram[:16]) / pixels
    visible_ratio = sum(histogram[16:]) / pixels
    if group in TRANSPARENT:
        if transparent_ratio < 0.035:
            raise ValueError("MISSING_TRUE_TRANSPARENT_BACKGROUND")
        if visible_ratio < 0.018:
            raise ValueError("ALMOST_EMPTY_ART")
    elif visible_ratio < .98:
        raise ValueError("OPAQUE_BACKGROUND_HAS_HOLES")
    sampled = rgba.resize((64, 64), Image.Resampling.BILINEAR).convert("RGB")
    color_buckets = len(sampled.quantize(colors=32).getcolors(maxcolors=4096) or [])
    if color_buckets < 8:
        raise ValueError("LOW_DETAIL_OR_BLANK_IMAGE")
    coverage = []
    if group in FRAMES:
        rows, cols = FRAMES[group]
        mask = rgba.getchannel("A")
        for row in range(rows):
            for col in range(cols):
                tile = mask.crop(((col * image.width) // cols,
                                  (row * image.height) // rows,
                                  ((col + 1) * image.width) // cols,
                                  ((row + 1) * image.height) // rows))
                cell_visible = sum(tile.histogram()[16:]) / (tile.width * tile.height)
                coverage.append(round(cell_visible, 4))
                if cell_visible < .025:
                    raise ValueError("EMPTY_SHEET_CELL_%d_%d" % (row, col))
    return {
        "transparent_ratio": round(transparent_ratio, 4),
        "color_buckets": color_buckets, "frame_coverage": coverage,
        "machine_minimum_pass": True, "human_visual_review": "required"}


def fingerprint(job: dict, model: str, quality: str) -> str:
    packed = json.dumps({
        "revision": PIPELINE_REV, "prompt": job["prompt"],
        "source_size": job["source_size"], "target_size": job["target_size"],
        "model": model, "quality": quality}, sort_keys=True)
    return hashlib.sha256(packed.encode("utf-8")).hexdigest()

def execute(root: Path, out: Path, selected: set[str], limit=0,
            render=False, model=MODEL, force=False, quality=QUALITY):
    jobs = build_jobs(root, selected, limit)
    out.mkdir(parents=True, exist_ok=True)
    (out / "render_jobs.jsonl").write_text(
        "".join(json.dumps(job, ensure_ascii=False) + "\n" for job in jobs),
        encoding="utf-8")
    report = {
        "schema": "starlit.global_art_ai_candidates.v4",
        "revision": PIPELINE_REV, "model": model, "quality": quality,
        "jobs": len(jobs), "render_requested": render, "complete": 0,
        "cached": 0, "failures": [], "assets": [],
        "output": "quality_checked_candidates_not_game_runtime"}
    if not render:
        (out / "render_report.json").write_text(
            json.dumps(report, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
        return report
    if quality not in ("low", "medium", "high", "xhigh", "max", "auto"):
        raise ValueError("UNSUPPORTED_QUALITY: " + quality)
    if not os.environ.get("OPENAI_API_KEY"):
        raise ValueError("OPENAI_API_KEY is required for --render; --jobs-only is free")
    try:
        from openai import OpenAI
    except ImportError as exc:
        raise ValueError("Install renderer: python -m pip install openai") from exc
    client = OpenAI()
    for job in jobs:
        dest = out / job["group"] / (safe(job["id"]) + ".png")
        receipt = dest.with_suffix(".quality.json")
        key = fingerprint(job, model, quality)
        try:
            dest.parent.mkdir(parents=True, exist_ok=True)
            if dest.is_file() and receipt.is_file() and not force:
                meta = json.loads(receipt.read_text(encoding="utf-8"))
                if (meta.get("fingerprint") == key and
                        meta.get("image_sha256") == hashlib.sha256(dest.read_bytes()).hexdigest()):
                    with Image.open(dest) as cached:
                        cached.load()
                        checks = quality_metrics(cached, job["group"])
                    report["cached"] += 1
                    report["assets"].append({
                        "id": job["id"], "group": job["group"],
                        "path": dest.relative_to(out).as_posix(),
                        "status": "cached_candidate", "qa": checks})
                    continue
            is_transparent = job["group"] in TRANSPARENT
            response = client.images.generate(
                model=model, prompt=job["prompt"], n=1,
                size=job["source_size"], quality=quality,
                background="transparent" if is_transparent else "opaque",
                output_format="png")
            if not response.data or not response.data[0].b64_json:
                raise RuntimeError("IMAGE_API_RETURNED_NO_IMAGE")
            blob = base64.b64decode(response.data[0].b64_json, validate=True)
            result = fit(blob, tuple(job["target_size"]), is_transparent, job["group"])
            checks = quality_metrics(result, job["group"])
            tmp = dest.with_suffix(".partial.png")
            result.save(tmp, format="PNG", optimize=True)
            with Image.open(tmp) as check:
                check.verify()
            tmp.replace(dest)
            receipt.write_text(json.dumps({
                "fingerprint": key,
                "image_sha256": hashlib.sha256(dest.read_bytes()).hexdigest(),
                "qa": checks},
                                          ensure_ascii=False, indent=2) + "\n",
                               encoding="utf-8")
            report["complete"] += 1
            report["assets"].append({
                "id": job["id"], "group": job["group"],
                "path": dest.relative_to(out).as_posix(),
                "status": "machine_checked_candidate_needs_human_review",
                "qa": checks})
        except Exception as exc:
            report["failures"].append({"id": job["id"], "group": job["group"],
                                       "error": str(exc)[:500]})
    (out / "render_report.json").write_text(
        json.dumps(report, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    return report

def main(argv=None):
    p=argparse.ArgumentParser(description="Export all visual briefs or generate high-detail AI art candidates")
    p.add_argument("--project",type=Path,default=Path(__file__).resolve().parents[1])
    p.add_argument("--output",type=Path)
    p.add_argument("--scope",choices=("all",)+SCOPES,default="all")
    p.add_argument("--limit",type=int,default=0)
    p.add_argument("--model",default=MODEL)
    p.add_argument("--quality",choices=("low","medium","high","xhigh","max","auto"),default=QUALITY)
    p.add_argument("--jobs-only",action="store_true",help="Only write canonical art brief JSONL, no API calls")
    p.add_argument("--render",action="store_true",help="Generate PNGs using configured model/API credentials")
    p.add_argument("--force",action="store_true")
    a=p.parse_args(argv)
    if not a.jobs_only and not a.render:
        p.error("Specify --jobs-only or --render to avoid accidental paid calls")
    root=a.project.resolve()
    out=(a.output or root/"build/starlit_global_art_factory_v3/model_sources").resolve()
    if out in (root,root/"assets/art",root/"assets/art/runtime"):
        p.error("Refusing to write image candidates to the live runtime")
    try:
        report=execute(root,out,set(SCOPES) if a.scope=="all" else {a.scope},
                       max(0,a.limit),a.render,a.model,a.force,a.quality)
    except (ValueError,OSError,KeyError,TypeError) as exc:
        print("MODEL ART ERROR:",exc,file=sys.stderr)
        return 2
    print(json.dumps({k:report[k] for k in ("jobs","render_requested","complete","cached")},
                     ensure_ascii=False))
    return 0 if not report["failures"] else 1

if __name__=="__main__":
    raise SystemExit(main())
