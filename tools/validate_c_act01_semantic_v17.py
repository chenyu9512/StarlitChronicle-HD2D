#!/usr/bin/env python3
"""Check Act-I semantic V17 art against current V10 physical image identities.

Old Golden Horizon source-pack byte pins were retired during generated-only
migration. Keep the five-map semantic layout, exact-image SHA, transparent
object roles and engine routing checks. Visual signoff is not implied.
"""
from __future__ import annotations
import hashlib
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
PROPS = {"flowerpot": "flowerpot", "sea_crystal": "sea_crystal",
         "palm_tree": "mangrove", "crab": "crab"}
SCENERY = {"harbor_crane": "harbor_crane",
           "sea_wind_pine": "sea_wind_pine",
           "saltwind_oak": "saltwind_oak",
           "tide_pool": "tide_pool",
           "cave_crystal": "sea_crystal"}
V14 = {"fish_net_stand", "tide_cliff", "sea_bridge", "cave_altar",
       "dune_shrub", "tide_lighthouse_landmark"}
BLOCKED = {"dune_grass", "cave_stalactite",
           "cave_foreground_column", "cave_hanging_ledge"}
EFFECTS = {"quest_glow"}


def read(path):
    return json.loads((ROOT / path).read_text(encoding="utf-8"))


def check_image(slot, slots, generated):
    record = slots.get(slot)
    if not isinstance(record, dict):
        raise ValueError("Missing exact semantic identity: " + slot)
    path = record.get("source", "")
    v10 = generated.get(slot)
    if not isinstance(v10, dict) or v10.get("source") != path:
        raise ValueError("Semantic slot not linked to original generated file: " + slot)
    if not path.startswith("res://assets/art/runtime/generated_gaps_v10/"):
        raise ValueError("Retired or foreign image route: " + slot)
    file = ROOT / path.removeprefix("res://")
    if not file.is_file() or hashlib.sha256(file.read_bytes()).hexdigest() != v10.get("sha256"):
        raise ValueError("Missing or corrupt exact role image: " + path)
    return {"role": slot, "image": path, "sha256": v10["sha256"]}


def validate():
    theme = read("data/assets/art_theme_v2.json")
    v10 = read("assets/art/runtime/generated_gaps_v10/manifest.json")
    slots = theme["themes"][0]["slots"]
    generated = v10["assets"]
    proofs = []
    for role, identity in sorted({**PROPS, **SCENERY}.items()):
        proofs.append(check_image("scene.coast." + identity, slots, generated))
    for identity in sorted(V14):
        proofs.append(check_image("landmark.coast." + identity, slots, generated))
    scenes = read("data/levels/v4/coastal_scenery.json")
    assert set(scenes) == {f"map_coast_{i:02d}" for i in range(1, 6)}
    mapped = {x["asset"] for area in scenes.values() for x in area.get("scenery", [])}
    expected = set(SCENERY) | V14 | BLOCKED | EFFECTS
    assert mapped == expected, "Unreviewed coastal art categories: " + repr(mapped ^ expected)
    loader = (ROOT / "scripts/world_coastal_scene.gd").read_text("utf-8")
    props = (ROOT / "scripts/first_act_world.gd").read_text("utf-8")
    mapper = (ROOT / "scripts/c_act01_semantic_art_v17.gd").read_text("utf-8")
    assert "SemanticArt.texture_for_scenery(asset,map_id)" in loader
    assert "GlobalArt.texture_for_scenery(asset,map_id)" in loader
    assert "CAct01Semantic.texture_for_prop(kind)" in props
    assert 'var identity: String = "mangrove" if kind == "palm_tree" else kind' in mapper
    assert 'var identity: String = "sea_crystal" if kind == "cave_crystal" else kind' in mapper
    assert "var wave := _sprite(\"tide_pool\",point)" not in loader
    assert '"quest_glow"' in loader and "_light_falloff_texture()" in loader
    return {"status": "PASS", "maps": len(scenes), "curated_verified_sources": len(proofs),
            "blocked_unmatched_roles": sorted(BLOCKED),
            "visual_approval": "not_tested"}


if __name__ == "__main__":
    print(json.dumps(validate(), ensure_ascii=False, sort_keys=True))
