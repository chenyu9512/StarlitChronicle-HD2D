#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""Main2 HD-2D Production Gate V6: canonical model jobs, render, QA and staging.

Run this inside the Godot project. Existing assets, main branch, gameplay and
active art themes remain unchanged. A SHA-locked human review is required.
"""
from __future__ import annotations

import argparse
import hashlib
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import sys

from PIL import Image, ImageChops, ImageStat
from global_art_factory_v3 import SCOPES, SIZES, safe
from global_art_ai_provider_v3 import build_jobs, quality_metrics, FRAMES

SCHEMA = "starlit.hd2d.v6.review.v1"
MAX_BYTES = 32 * 1024 * 1024


def digest(path: Path) -> str:
    value = hashlib.sha256()
    with path.open("rb") as src:
        for chunk in iter(lambda: src.read(1024 * 1024), b""):
            value.update(chunk)
    return value.hexdigest()


def frame_quality(image: Image.Image, group: str) -> dict:
    """Detect empty, duplicated and direction-invariant model animation cells."""
    rgba = image.convert("RGBA")
    if group not in FRAMES:
        return {"frame_layout": None, "needs_visual_direction_review": False}
    rows, cols = FRAMES[group]
    frames = []
    masks = []
    for row in range(rows):
        sub = []
        sub_masks = []
        for col in range(cols):
            cell = rgba.crop((
                col * rgba.width // cols, row * rgba.height // rows,
                (col + 1) * rgba.width // cols, (row + 1) * rgba.height // rows))
            sub.append(cell)
            sub_masks.append(cell.getchannel("A").getbbox())
        frames.append(sub)
        masks.append(sub_masks)
    if any(not x for row in masks for x in row):
        raise ValueError("EMPTY_ANIMATION_CELL")
    # Too many byte-identical copies mean a 12-cell animation is not real.
    signatures = {hashlib.sha256(cell.tobytes()).hexdigest()
                  for row in frames for cell in row}
    minimum = 5 if group in ("characters", "npcs") else 2
    if len(signatures) < minimum:
        raise ValueError("DUPLICATE_ANIMATION_FRAMES")
    if group in ("characters", "npcs"):
        center = [frames[r][1] for r in range(4)]
        differing = 0
        for j in range(1, 4):
            if ImageChops.difference(center[0], center[j]).convert("RGB").getbbox() is not None or ImageChops.difference(center[0], center[j]).getchannel("A").getbbox() is not None:
                differing += 1
        if differing < 3:
            raise ValueError("DIRECTION_ROWS_NOT_DISTINCT")
    return {"frame_layout": f"{rows}x{cols}", "distinct_cells": len(signatures),
            "needs_visual_direction_review": True}


def terrain_quality(image: Image.Image, group: str) -> dict:
    """Check atlas repeat seams instead of accepting unrelated landscapes."""
    if group not in ("terrain", "interiors"):
        return {"tile_seams_checked": False}
    if image.size != (256, 256):
        raise ValueError("NOT_8x8_TERRAIN_ATLAS")
    rgba = image.convert("RGB")
    bad = 0
    # Compare opposite edges of every independently tileable 32px tile.
    for row in range(8):
        for col in range(8):
            cell = rgba.crop((col * 32, row * 32, col * 32 + 32, row * 32 + 32))
            px = cell.load()
            horiz = sum(sum(abs(px[0, y][k] - px[31, y][k]) for k in range(3))
                        for y in range(32)) / (32 * 3)
            vert = sum(sum(abs(px[x, 0][k] - px[x, 31][k]) for k in range(3))
                       for x in range(32)) / (32 * 3)
            if max(horiz, vert) > 34:
                bad += 1
    if bad > 6:
        raise ValueError(f"TILE_SEAM_MISMATCH: {bad} of 64 tiles")
    return {"tile_seams_checked": True, "seam_warning_tiles": bad}


def inspect(path: Path, group: str) -> dict:
    if not path.is_file():
        raise FileNotFoundError(str(path))
    if path.stat().st_size >= MAX_BYTES:
        raise ValueError("FILE_TOO_LARGE")
    if path.suffix.lower() != ".png":
        raise ValueError("NOT_PNG")
    with Image.open(path) as src:
        src.load()
        if src.format != "PNG":
            raise ValueError("CORRUPTED_OR_WRONG_PNG")
        if src.size != SIZES[group]:
            raise ValueError(f"WRONG_CANVAS: expected {SIZES[group]} got {src.size}")
        basic = quality_metrics(src, group)
        frames = frame_quality(src, group)
        tiles = terrain_quality(src, group)
    return dict(sha256=digest(path), bytes=path.stat().st_size,
                **basic, **frames, **tiles)


def jobs_for(root: Path, scope: str, limit: int) -> list[dict]:
    groups = set(SCOPES) if scope == "all" else {scope}
    return build_jobs(root, groups, limit)


def write_review(root: Path, source: Path, destination: Path,
                 scope: str = "all", limit: int = 0) -> dict:
    results = []
    for job in jobs_for(root, scope, limit):
        group, asset_id = job["group"], safe(job["id"])
        path = source / group / (asset_id + ".png")
        row = {"group": group, "id": asset_id, "source": f"{group}/{asset_id}.png",
               "visual_approved": False, "status": "missing", "reason": ""}
        if path.is_file():
            try:
                qa = inspect(path, group)
                row.update(status="machine_pass_human_review_required",
                           sha256=qa["sha256"], qa=qa)
            except (ValueError, OSError) as exc:
                row.update(status="rejected", reason=str(exc)[:300])
        results.append(row)
    report = {
        "schema": SCHEMA, "generated_by": "tools/hd2d_production_gate_v6.py",
        "status": "candidate_review_only", "runtime_modified": False,
        "source_root": str(source), "jobs": len(results),
        "machine_pass": sum(row["status"] == "machine_pass_human_review_required"
                            for row in results),
        "rejected": sum(row["status"] == "rejected" for row in results),
        "missing": sum(row["status"] == "missing" for row in results),
        "assets": results}
    destination.parent.mkdir(parents=True, exist_ok=True)
    destination.write_text(json.dumps(report, ensure_ascii=False, indent=2) + "\n",
                           encoding="utf-8")
    return report


def stage_review(review: Path, source: Path, destination: Path) -> dict:
    """Explicitly reviewed and SHA-locked candidates are copied, never activated."""
    data = json.loads(review.read_text(encoding="utf-8"))
    if data.get("schema") != SCHEMA or data.get("runtime_modified") is not False:
        raise ValueError("REVIEW_SCHEMA_OR_RUNTIME_MISMATCH")
    selected = [row for row in data.get("assets", [])
                if row.get("visual_approved") is True]
    if not selected:
        raise ValueError("NO_APPROVED_ASSETS: review assets before staging")
    destination = destination.resolve()
    source = source.resolve()
    if destination == source or destination.is_relative_to(source):
        raise ValueError("STAGING_DESTINATION_OVERLAPS_INPUT")
    all_rows = []
    seen = set()
    # All preconditions are checked before the first copy.
    for row in selected:
        group, item = row["group"], safe(row["id"])
        if group not in SCOPES or (group, item) in seen:
            raise ValueError("INVALID_OR_DUPLICATE_CANONICAL_ID")
        seen.add((group, item))
        path = source / group / (item + ".png")
        qa = inspect(path, group)
        if row.get("status") != "machine_pass_human_review_required":
            raise ValueError(f"UNVERIFIED_ASSET: {group}/{item}")
        if qa["sha256"] != row.get("sha256") or \
                qa["sha256"] != row.get("qa", {}).get("sha256"):
            raise ValueError(f"ASSET_CHANGED_SINCE_REVIEW: {group}/{item}")
        all_rows.append((group, item, path, qa))
    manifest = {"schema": "starlit.hd2d.v6.staged.v1",
                "runtime_modified": False, "assets": []}
    for group, item, path, qa in all_rows:
        output = destination / group / (item + ".png")
        output.parent.mkdir(parents=True, exist_ok=True)
        shutil.copyfile(path, output)
        manifest["assets"].append({
            "group": group, "id": item, "path": f"{group}/{item}.png",
            "sha256": qa["sha256"], "status": "reviewed_candidate_not_published"})
    dest = destination / "staged_manifest.json"
    dest.write_text(json.dumps(manifest, ensure_ascii=False, indent=2) + "\n",
                    encoding="utf-8")
    return manifest


def run_model(root: Path, args) -> int:
    if args.command == "render" and not os.environ.get("OPENAI_API_KEY"):
        raise ValueError("OPENAI_API_KEY required for real model rendering")
    cmd = [sys.executable, str(root / "tools/global_art_ai_provider_v3.py"),
           "--project", str(root), "--scope", args.scope, "--limit", str(args.limit),
           "--quality", args.quality,
           "--render" if args.command == "render" else "--jobs-only"]
    if args.reference_root:
        cmd += ["--reference-root", str(args.reference_root)]
    if args.model:
        cmd += ["--model", args.model]
    return subprocess.run(cmd, cwd=root, check=False).returncode


def main(argv=None):
    parser = argparse.ArgumentParser(
        description="V6: model jobs/render, 12-frame QA, 8x8 tiling QA, reviewed staging")
    parser.add_argument("command", choices=("jobs", "render", "audit", "stage"))
    parser.add_argument("--project", type=Path, default=Path(__file__).resolve().parents[1])
    parser.add_argument("--scope", choices=("all",) + SCOPES, default="all")
    parser.add_argument("--limit", type=int, default=0)
    parser.add_argument("--quality", choices=("low", "medium", "high", "xhigh", "max", "auto"),
                        default="xhigh")
    parser.add_argument("--model", default="")
    parser.add_argument("--reference-root", type=Path)
    parser.add_argument("--source-root", type=Path)
    parser.add_argument("--output", type=Path)
    parser.add_argument("--review", type=Path)
    a = parser.parse_args(argv)
    root = a.project.resolve()
    model_source = root / "build/starlit_global_art_factory_v3/model_sources"
    source = (a.source_root or model_source).resolve()
    destination = (a.output or root / "build/starlit_hd2d_production_gate_v6").resolve()
    if destination.is_relative_to(root / "assets/art/runtime"):
        parser.error("Never write a model candidate to active runtime!")
    try:
        if a.command in ("jobs", "render"):
            return run_model(root, a)
        if a.command == "audit":
            report = write_review(root, source,
                                  destination / "review.json", a.scope, max(0, a.limit))
            print(json.dumps({key: report[key] for key in
                              ("jobs", "machine_pass", "rejected", "missing")},
                             ensure_ascii=False))
            return 0 if not report["rejected"] else 1
        if not a.review:
            parser.error("stage requires --review")
        staged = stage_review(a.review.resolve(), source, destination / "staged")
        print(json.dumps({"status": "成功", "reviewed": len(staged["assets"]),
                          "runtime_modified": False}, ensure_ascii=False))
        return 0
    except (ValueError, OSError, KeyError, json.JSONDecodeError) as exc:
        print("HD2D V6 ERROR:", exc, file=sys.stderr)
        return 2


if __name__ == "__main__":
    raise SystemExit(main())
