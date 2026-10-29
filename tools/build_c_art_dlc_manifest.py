#!/usr/bin/env python3
"""Make a DLC manifest from a folder mirroring canonical art paths.

Example:
 python tools/build_c_art_dlc_manifest.py /path/to/my_art --id my_style --name "我的画风"
 Place images under /path/to/my_art/assets/art/... matching the game paths.
 This never overwrites a runtime original; use the in-game DLC importer.
"""
from __future__ import annotations
import argparse
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
SUFFIXES = {".png", ".jpg", ".jpeg", ".webp"}

def build(directory: Path, pack_id: str, name: str, strict: bool) -> dict:
    assert directory.is_dir(), f"Input folder not found: {directory}"
    assert 1 <= len(pack_id) <= 48 and all(c.lower() in "abcdefghijklmnopqrstuvwxyz0123456789_-" for c in pack_id), "Invalid DLC ID"
    catalog = json.loads((ROOT / "data/assets/c_art_catalog.json").read_text(encoding="utf-8"))
    slots = {item["path"] for item in catalog["assets"]}
    matched = {}
    skipped = []
    for file in sorted(directory.rglob("*")):
        if not file.is_file() or file.suffix.lower() not in SUFFIXES:
            continue
        rel = file.relative_to(directory).as_posix()
        canonical = "res://" + rel if rel.startswith("assets/") else "res://assets/" + rel
        if canonical not in slots:
            skipped.append(rel)
            continue
        if canonical in matched:
            raise ValueError(f"Two images map to one target: {canonical}")
        matched[canonical] = rel
    if not matched:
        raise ValueError("No recognized image paths. Mirror assets/art/... under the pack folder.")
    if strict and len(matched) != len(slots):
        raise ValueError(f"Full-coverage check: {len(matched)}/{len(slots)} registered art slots.")
    return {"schema": "starlit.c.dlc.v1", "id": pack_id, "name": name,
            "mappings": [{"target": k, "file": v} for k, v in sorted(matched.items())],
            "coverage": {"recognized": len(matched), "catalog_slots": len(slots),
                         "unmatched_files": skipped}}

def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("directory", type=Path, help="DLC image directory (mirrored assets/... tree)")
    parser.add_argument("--id", required=True)
    parser.add_argument("--name", required=True)
    parser.add_argument("--strict", action="store_true", help="Require mappings for all registered slots")
    args = parser.parse_args()
    result = build(args.directory.resolve(), args.id, args.name, args.strict)
    out = args.directory.resolve() / "manifest.json"
    out.write_text(json.dumps(result, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(f"SUCCESS: {len(result['mappings'])}/{result['coverage']['catalog_slots']} registered art slots -> {out}")
    if result["coverage"]["unmatched_files"]:
        print(f"Unmatched image files: {len(result['coverage']['unmatched_files'])}")

if __name__ == "__main__":
    main()
