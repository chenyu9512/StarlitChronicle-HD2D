#!/usr/bin/env python3
"""Validate V2 semantically keyed art themes against tracked, importable runtime files."""
from __future__ import annotations
import argparse
import json
import struct
from collections import Counter
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
MANIFEST = ROOT / "data/assets/art_theme_v2.json"
PNG = b"\x89PNG\r\n\x1a\n"

def run(strict: bool = True) -> dict:
    raw = json.loads(MANIFEST.read_text(encoding="utf-8"))
    assert raw["schema"] == "starlit.art_theme.v2"
    errors = []
    rows = []
    seen = set()
    for theme in raw["themes"]:
        theme_id = theme["id"]
        assert theme_id not in seen, f"duplicate theme {theme_id}"
        seen.add(theme_id)
        slots = theme["slots"]
        for alias, target in theme.get("aliases", {}).items():
            if target not in slots or alias in slots:
                errors.append(f"{theme_id}: bad alias {alias} => {target}")
        for key, slot in slots.items():
            source = slot.get("source", "")
            if not source.startswith("res://assets/art/runtime/") or ".." in source:
                errors.append(f"{key}: forbidden source {source}")
                continue
            path = ROOT / source.removeprefix("res://")
            exists = path.is_file()
            if not exists:
                errors.append(f"{key}: missing {source}")
            elif path.suffix.lower() == ".png":
                with path.open("rb") as fh:
                    header = fh.read(24)
                if len(header) < 24 or header[:8] != PNG:
                    errors.append(f"{key}: corrupt PNG signature")
                else:
                    width, height = struct.unpack(">II", header[16:24])
                    if width < 8 or height < 8:
                        errors.append(f"{key}: invalid size {width}x{height}")
            elif path.suffix.lower() != ".svg":
                errors.append(f"{key}: unsupported runtime file {path.suffix}")
            rows.append({"slot": key, "category": slot.get("category",""),"source":source,
                         "required":bool(slot.get("required",False)),"exists":exists,"stage":slot.get("stage","unreviewed")})
    # V2 themes own their 109 semantic slots. New generated runtime roles
    # (288 content icons, 66 boss motion atlases, 153 room materials, etc.)
    # belong to the single A-line runtime registry, NOT to the legacy V2 DLC
    # slot system. Check the UNION, not an impossible V2-only membership.
    canonical = {p.relative_to(ROOT).as_posix() for p in (ROOT/"assets/art/runtime").rglob("*")
                 if p.is_file() and p.suffix.lower() in (".png",".jpg",".jpeg",".webp",".svg")}
    registered = {rec["source"].removeprefix("res://") for rec in rows}
    runtime_file = ROOT / "data/assets/c_art_runtime_registry_v1.json"
    index = json.loads(runtime_file.read_text(encoding="utf-8"))
    if index.get("schema") != "starlit.c.art_runtime_registry.v1":
        errors.append("Invalid A-line canonical runtime registry schema")
    live_sources = index.get("sources", {})
    additional_registered = {
        path.removeprefix("res://") for path,row in live_sources.items()
        if bool(row.get("registered")) and path.startswith("res://assets/art/runtime/")
    }
    for path in sorted(canonical - (registered | additional_registered)):
        errors.append("runtime image absent from BOTH V2 theme and current A-line registry: "+path)
    for path in sorted(registered - canonical):
        errors.append("V2 slot source not tracked in runtime: "+path)
    for path in sorted(additional_registered - canonical):
        errors.append("A-line registered runtime file physically absent: "+path)
    categories = Counter(x["category"] for x in rows)
    result = {"schema":"starlit.art_theme.audit.v2","themes":sorted(seen),
              "registered_slots":len(rows),"registered_categories":dict(categories),
              "present":sum(x["exists"] for x in rows),"missing":errors,
              "required":sum(x["required"] for x in rows),
              "a_line_registered_runtime_files":len(additional_registered),
              "total_runtime_image_files":len(canonical),
              "commercial_visual_approval":False}
    if strict and errors:
        raise SystemExit("\n".join(errors[:60]))
    return result

if __name__ == "__main__":
    cli = argparse.ArgumentParser()
    cli.add_argument("--json",action="store_true")
    a = cli.parse_args()
    result = run()
    print(json.dumps(result,ensure_ascii=False,indent=2) if a.json else
          f"PASS: {result['present']}/{result['registered_slots']} real runtime slots registered; "
          f"{result['required']} required. Visual QA not yet signed off.")
