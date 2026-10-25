#!/usr/bin/env python3
"""Seed forty independent V3 authoring files from the world catalog.

Never overwrites an existing author-edited sector. Sidecar files take precedence
over fallback world_levels_v3.json at runtime and in map_v3_editor.py.
"""
from __future__ import annotations
import argparse
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / "data/levels/world_levels_v3.json"
OUTPUT = SOURCE.parent / "v3"

def run(verify: bool = False) -> int:
    raw = json.loads(SOURCE.read_text(encoding="utf-8"))
    levels = raw["levels"]
    if len(levels) != 40:
        raise RuntimeError(f"Expected 40 map definitions, received {len(levels)}")
    created = 0
    for map_id,record in sorted(levels.items()):
        if not map_id.startswith("map_") or map_id != record["map_id"] or not (72<=int(record["size"][0])<=112 and 48<=int(record["size"][1])<=78):
            raise RuntimeError(f"Invalid sector layout: {map_id}")
        path = OUTPUT / f"{map_id}.json"
        if path.is_file():
            existing = json.loads(path.read_text(encoding="utf-8"))
            if existing!=record:
                raise RuntimeError(f"Broken independent map file {path}")
            continue
        if verify:
            raise RuntimeError(f"Missing independently editable map: {path}")
        OUTPUT.mkdir(parents=True, exist_ok=True)
        path.write_text(json.dumps(record,ensure_ascii=False,indent=2)+"\n",encoding="utf-8")
        created += 1
    paths = list(OUTPUT.glob("map_*.json"))
    if len(paths)!=40:
        raise RuntimeError(f"Expected exactly 40 tracked region files, found {len(paths)}")
    print(f"PASS: {len(paths)} independently editable V3 map files, newly materialized={created}, no existing work overwritten")
    return 0

if __name__=="__main__":
    parser=argparse.ArgumentParser()
    parser.add_argument("--verify",action="store_true")
    args=parser.parse_args()
    raise SystemExit(run(args.verify))
