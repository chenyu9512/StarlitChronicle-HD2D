#!/usr/bin/env python3
"""Auditable, non-inflated coverage report for Main2 semantic art themes.

Counts physical source files once, runtime slots separately, and does NOT equate
a resolvable image with an accepted commercial visual or gameplay scene.
"""
from __future__ import annotations
import argparse
import json
import struct
from collections import Counter, defaultdict
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
MANIFEST = ROOT / "data/assets/art_theme_v2.json"
PNG_HEADER = bytes.fromhex("89504e470d0a1a0a")
REQUIRED_STATES = {"visual_accepted", "commercial_visual_accepted", "approved_visual"}
SOURCE_ROOT = ROOT / "assets/art/source_packs"
EXTERNAL_ROOT = ROOT / "assets/art/external/cc0_named_v1"
RUNTIME_ROOT = ROOT / "assets/art/runtime"
IMAGE_EXT = {".png", ".jpg", ".jpeg", ".webp", ".svg", ".gif"}


def _files(folder: Path) -> list[Path]:
    return sorted(p for p in folder.rglob("*") if p.is_file() and p.suffix.lower() in IMAGE_EXT) if folder.exists() else []


def _probe(path: Path) -> tuple[bool, str]:
    if not path.is_file():
        return False, "missing"
    if path.suffix.lower() == ".png":
        with path.open("rb") as stream:
            head = stream.read(24)
        if len(head) != 24 or head[:8] != PNG_HEADER:
            return False, "invalid_png_signature"
        width, height = struct.unpack(">II", head[16:24])
        if width < 8 or height < 8 or width > 8192 or height > 8192:
            return False, "invalid_dimensions"
    elif path.suffix.lower() == ".svg":
        with path.open("rb") as stream:
            head = stream.read(4096).lower()
        if b"<svg" not in head:
            return False, "invalid_svg"
    return True, "source_present_not_visual_accepted"


def audit() -> dict:
    manifest = json.loads(MANIFEST.read_text(encoding="utf-8"))
    if manifest.get("schema") != "starlit.art_theme.v2":
        raise ValueError("Unexpected art theme manifest schema")
    source_files = _files(SOURCE_ROOT)
    external_files = _files(EXTERNAL_ROOT)
    runtime_files = _files(RUNTIME_ROOT)
    themes = []
    errors = []
    mandatory = set(manifest.get("mandatory_categories", []))
    for theme in manifest.get("themes", []):
        slots = theme.get("slots", {})
        aliases = theme.get("aliases", {})
        category_stats = defaultdict(lambda: Counter())
        unresolved = []
        accepted = 0
        required = 0
        valid_required = 0
        source_paths = set()
        for slot_id, slot in slots.items():
            cat = str(slot.get("category", "unknown"))
            path = str(slot.get("source", ""))
            must = bool(slot.get("required", False))
            state = str(slot.get("stage", "unreviewed")).lower()
            category_stats[cat]["registered"] += 1
            if must:
                category_stats[cat]["required"] += 1
                required += 1
            if not path.startswith("res://assets/art/runtime/") or ".." in path:
                valid, why = False, "forbidden_source_path"
            else:
                source_paths.add(path)
                valid, why = _probe(ROOT / path.removeprefix("res://"))
            if valid:
                category_stats[cat]["loadable_source"] += 1
                if must:
                    valid_required += 1
                if state in REQUIRED_STATES:
                    accepted += 1
                    category_stats[cat]["visual_accepted"] += 1
            else:
                unresolved.append({"id": slot_id, "source": path, "reason": why, "required": must})
                if must:
                    errors.append(f"{theme.get('id')}: required slot {slot_id}: {why}")
        for alias, target in aliases.items():
            if target not in slots or alias in slots:
                errors.append(f"{theme.get('id')}: invalid alias {alias} => {target}")
        missing_categories = sorted(c for c in mandatory if category_stats[c]["required"] == 0)
        if missing_categories:
            errors.append(f"{theme.get('id')}: mandatory categories have no required slots: {missing_categories}")
        themes.append({
            "id": theme.get("id"),
            "state": theme.get("state"),
            "registered_slots": len(slots),
            "required_slots": required,
            "required_source_loadable": valid_required,
            "required_source_coverage_pct": round(100 * valid_required / required, 2) if required else 0,
            "visual_accepted_slots": accepted,
            "visual_acceptance_pct_of_all_slots": round(100 * accepted / len(slots), 2) if slots else 0,
            "unique_runtime_source_paths": len(source_paths),
            "categories": {k: dict(v) for k, v in sorted(category_stats.items())},
            "unresolved": unresolved
        })
    return {
        "schema": "starlit.art_theme.coverage.audit.v2",
        "meaning": "File and semantic-slot audit only; loadable_source is not scene-visible, animation-valid, or visually approved",
        "repository_images": {
            "source_pack_images": len(source_files),
            "external_named_images": len(external_files),
            "runtime_images": len(runtime_files),
            "registered_image_total": len(source_files) + len(external_files) + len(runtime_files)
        },
        "themes": themes,
        "errors": errors
    }


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--out", type=Path, help="Optional JSON audit output")
    parser.add_argument("--strict", action="store_true", help="Exit nonzero on missing required sources, invalid aliases or uncovered mandatory categories")
    args = parser.parse_args()
    report = audit()
    print(json.dumps(report, ensure_ascii=False, indent=2))
    if args.out:
        args.out.parent.mkdir(parents=True, exist_ok=True)
        args.out.write_text(json.dumps(report, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    if args.strict and report["errors"]:
        raise SystemExit(1)


if __name__ == "__main__":
    main()
