#!/usr/bin/env python3
"""Offline Main2 project-integrity audit, replacing removed demo-migration checks.

Godot gameplay, screenshot and visual approval are separate quality gates.
"""
from __future__ import annotations
import json
from pathlib import Path
import re
from audit_generated_only_art_v1 import audit as audit_generated_art

ROOT = Path(__file__).resolve().parents[1]

def check() -> None:
    project = ROOT / "project.godot"
    assert project.is_file(), "Godot project.godot missing"
    settings = project.read_text(encoding="utf-8-sig")
    assert 'run/main_scene="res://scenes/first_act.tscn"' in settings, "Unexpected playable main scene"
    icon_match = re.search(r'^config/icon="res://([^"]+)"
    assert (ROOT / "scripts/first_act.gd").is_file()
    catalog = json.loads((ROOT / "data/content/maps.json").read_text(encoding="utf-8-sig"))
    maps = catalog.get("entries", [])
    world = sorted((ROOT / "data/levels/v3").glob("*.json"))
    interiors = sorted((ROOT / "data/levels/v4/interiors").glob("*.json"))
    assert len(maps) >= 40, f"Missing canonical map entries: {len(maps)}"
    assert len(world) >= 40, f"Missing authored V3 maps: {len(world)}"
    assert len(interiors) >= 153, f"Missing V4 room layouts: {len(interiors)}"
    for file in world + interiors:
        row = json.loads(file.read_text(encoding="utf-8-sig"))
        assert isinstance(row, dict) and row, f"Unreadable map/interior JSON: {file}"
    inventory = audit_generated_art(ROOT)
    assert inventory["status"] == "success", "Art source integrity: " + repr(inventory["errors"][:10])
    assert inventory["non_runtime_images"] == 0
    assert inventory["missing_images"] == 0 and inventory["orphaned_images"] == 0
    assert inventory["generated_main"] >= 451
    print("PASS CURRENT PROJECT:",len(maps),"map entries,",len(world),"V3 maps,",len(interiors),
          "V4 interiors,",inventory["total_image_assets"],"project-owned art files")
    print("Human art direction and full Godot walkthrough: not tested by this static audit.")

if __name__ == "__main__":
    check()
, settings, flags=re.MULTILINE)
    assert icon_match is not None, "Godot icon path missing"
    icon_path = Path(icon_match.group(1))
    assert icon_path.parts[:3] == ("assets", "art", "runtime"), (
        "Godot icon must be a retained project-owned runtime asset"
    )
    assert (ROOT / icon_path).is_file(), f"Godot icon references missing asset: {icon_path}"
    assert icon_path.suffix.lower() in (".png", ".svg"), "Unsupported Godot icon image"
    assert (ROOT / "scenes/first_act.tscn").is_file()
    assert (ROOT / "scripts/first_act.gd").is_file()
    catalog = json.loads((ROOT / "data/content/maps.json").read_text(encoding="utf-8-sig"))
    maps = catalog.get("entries", [])
    world = sorted((ROOT / "data/levels/v3").glob("*.json"))
    interiors = sorted((ROOT / "data/levels/v4/interiors").glob("*.json"))
    assert len(maps) >= 40, f"Missing canonical map entries: {len(maps)}"
    assert len(world) >= 40, f"Missing authored V3 maps: {len(world)}"
    assert len(interiors) >= 153, f"Missing V4 room layouts: {len(interiors)}"
    for file in world + interiors:
        row = json.loads(file.read_text(encoding="utf-8-sig"))
        assert isinstance(row, dict) and row, f"Unreadable map/interior JSON: {file}"
    inventory = audit_generated_art(ROOT)
    assert inventory["status"] == "success", "Art source integrity: " + repr(inventory["errors"][:10])
    assert inventory["non_runtime_images"] == 0
    assert inventory["missing_images"] == 0 and inventory["orphaned_images"] == 0
    assert inventory["generated_main"] >= 451
    print("PASS CURRENT PROJECT:",len(maps),"map entries,",len(world),"V3 maps,",len(interiors),
          "V4 interiors,",inventory["total_image_assets"],"project-owned art files")
    print("Human art direction and full Godot walkthrough: not tested by this static audit.")

if __name__ == "__main__":
    check()
