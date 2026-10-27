#!/usr/bin/env python3
"""Static art-catalog source validation; does not substitute for Godot visual QA."""
from __future__ import annotations
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
CATALOG = ROOT / "data/assets/c_art_catalog.json"

def run() -> int:
    doc = json.loads(CATALOG.read_text(encoding="utf-8"))
    errors = []
    entries = doc.get("assets", [])
    seen = set()
    for row in entries:
        relative = str(row.get("path", "")).removeprefix("res://")
        full = ROOT / relative
        if row.get("path") != "res://" + relative or not relative.startswith("assets/"):
            errors.append("Invalid path: " + relative)
        if ".." in Path(relative).parts:
            errors.append("Traversal: " + relative)
        if relative in seen:
            errors.append("Duplicate path: " + relative)
        if not full.is_file():
            errors.append("Missing file: " + relative)
        if not row.get("name") or not row.get("category") or not row.get("status"):
            errors.append("Incomplete metadata: " + relative)
        seen.add(relative)
    actual = {
        path.relative_to(ROOT).as_posix()
        for path in (ROOT / "assets").rglob("*")
        if path.is_file() and path.suffix.lower() in {".png", ".svg", ".jpg", ".jpeg", ".webp"}
    }
    # Source originals belong to a separate non-runtime source registry.
    # Do not fill the interactive runtime gallery with raw source-pack atlases.
    source_doc = json.loads((ROOT / "data/assets/c_art_source_originals.json").read_text(encoding="utf-8"))
    originals = set()
    for raw in source_doc.get("files", []):
        path = str(raw.get("path", ""))
        if not path.startswith("assets/art/source_packs/") or ".." in Path(path).parts:
            errors.append("Invalid original path: " + path)
        if path in originals or path in seen:
            errors.append("Duplicate original: " + path)
        if path not in actual:
            errors.append("Source original missing: " + path)
        originals.add(path)
    if source_doc.get("count") != len(originals):
        errors.append("Source original count mismatch")
    for path in sorted(actual - seen - originals):
        errors.append("Not indexed: " + path)
    for path in sorted(seen - actual):
        errors.append("Stale entry: " + path)
    if len(entries) != doc.get("count", -1):
        errors.append("Catalog count mismatch")
    if sorted(set(row["category"] for row in entries)) != sorted(doc.get("categories", [])):
        errors.append("Categories mismatch")
    required = {
        "scripts/c_art_overrides.gd": "func import_image(",
        "scripts/c_art_manager_ui.gd": "func open_manager(",
        "scripts/first_act_ui.gd": "art_manager = ArtManagerUI.new()",
        "scripts/first_act_world.gd": "sprite.texture = CArtOverrides.texture(path)",
        "scripts/first_act_battle.gd": "CArtOverrides.texture(ArtAssets.battle_image(",
        "scripts/world_structure.gd": "facade.texture=ArtOverrides.texture(file)",
        "scripts/world_interior_art.gd": "prop.texture = ArtOverrides.texture(path)",
        "scripts/world_coastal_scene.gd": "sprite.texture=ArtOverrides.texture(file)",
        "scripts/world_npc_visual.gd": "artwork.texture = ArtOverrides.texture(art_path)",
    }
    for filename, marker in required.items():
        if marker not in (ROOT / filename).read_text(encoding="utf-8"):
            errors.append("Runtime hook missing: " + filename)
    for item in errors:
        print("FAIL:", item)
    print(f"Catalog: {len(entries)} paths / {len(doc.get('categories', []))} categories / {len(errors)} issues")
    return int(bool(errors))

if __name__ == "__main__":
    raise SystemExit(run())
