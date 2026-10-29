#!/usr/bin/env python3
"""Verify Act-I artwork selection by exact Git blob and actual runtime routing.

This check runs on Main2 before pruning source_packs. It must never be run as
a substitute for the Godot in-scene smoke or human composition assessment.
"""
import hashlib
import json
from pathlib import Path
from act01_source_provenance import verify_art

ROOT = Path(__file__).resolve().parent.parent
SOURCE = Path("assets/art/source_packs/Golden-Horizon-2D-01-Sprites-Icons-Effects/2D/Prepared/Sprites")
RUNTIME = Path("assets/art/runtime/act01_semantic_v17")
SEA_CRAB_SOURCE = Path("assets/art/source_packs/Aekashics Librarium Static Battlers/Frontview Batch Battlers/Sea Crab.png")
MATCHES = {
    "flowerpot": "urn-planter.png",
    "sea_crystal": "crystal-cache.png",
    "harbor_crane": "harbour-crane.png",
    "sea_wind_pine": "pine.png",
    "saltwind_oak": "great-oak.png",
    "tide_pool": "tide-pool-rocks.png",
    "mangrove": "mangrove.png",
    "crab": "Sea Crab.png",
}
PROPS = {"flowerpot", "sea_crystal", "palm_tree", "crab"}
SCENERY = {"harbor_crane", "sea_wind_pine", "saltwind_oak",
           "tide_pool", "cave_crystal"}
V14_SCENERY = {"fish_net_stand", "tide_cliff", "sea_bridge", "cave_altar",
               "dune_shrub", "tide_lighthouse_landmark"}
NOT_MATCHED = {"dune_grass", "cave_stalactite",
               "cave_foreground_column", "cave_hanging_ledge"}
SCENERY_EFFECTS = {"quest_glow"}


def blob_sha(payload):
    return hashlib.sha1(b"blob " + str(len(payload)).encode() + b"\0" + payload).hexdigest()


def validate():
    if not (ROOT / "project.godot").exists():
        raise RuntimeError("Run from Main2 complete repository checkout")
    reviewed = []
    for role, source_name in MATCHES.items():
        source = ROOT / (SEA_CRAB_SOURCE if role == "crab" else SOURCE / source_name)
        destination = ROOT / RUNTIME / (role + ".png")
        proof = verify_art((RUNTIME / (role + ".png")).as_posix(), source.relative_to(ROOT))
        reviewed.append({"role": role, "sha": proof["sha"], "bytes": proof["bytes"]})
    scenes = json.loads((ROOT / "data/levels/v4/coastal_scenery.json").read_text("utf-8"))
    expected_maps = {f"map_coast_{idx:02d}" for idx in range(1, 6)}
    if set(scenes) != expected_maps:
        raise RuntimeError("Act-I map set changed: review required")
    actual_scenery = {x.get("asset") for map_spec in scenes.values()
                      for x in map_spec.get("scenery", [])}
    categorized = SCENERY | V14_SCENERY | NOT_MATCHED | SCENERY_EFFECTS
    if actual_scenery != categorized:
        raise RuntimeError("Unclassified scenic art: " + repr(actual_scenery ^ categorized))
    registry = json.loads((ROOT / "data/assets/c_act01_global_distribution_v14.json").read_text("utf-8"))
    aliases = registry.get("runtime", {}).get("scenery", {})
    for kind in V14_SCENERY:
        real = aliases.get(kind, "").removeprefix("res://")
        if not real or not (ROOT / real).is_file():
            raise RuntimeError("Previously accepted V14 scenery missing: " + kind)
    loader = (ROOT / "scripts/world_coastal_scene.gd").read_text("utf-8")
    props = (ROOT / "scripts/first_act_world.gd").read_text("utf-8")
    mapper = (ROOT / "scripts/c_act01_semantic_art_v17.gd").read_text("utf-8")
    if ('SemanticArt.texture_for_scenery(asset,map_id)' not in loader or
            'GlobalArt.texture_for_scenery(asset,map_id)' not in loader):
        raise RuntimeError("Semantic scenery not connected to Godot scene")
    if 'CAct01Semantic.texture_for_prop(kind)' not in props:
        raise RuntimeError("Correctly matched props missing from live world")
    for kind in PROPS:
        if kind not in mapper:
            raise RuntimeError("Unmapped curated prop: " + kind)
    for kind in SCENERY:
        if kind not in mapper:
            raise RuntimeError("Unmapped curated scenery: " + kind)
    if 'var wave := _sprite("tide_pool",point)' in loader:
        raise RuntimeError("False tidal rocks still stamped into deep water")
    if 'var file: String=Act01Art.sprite_path(map_id, asset)' in loader:
        raise RuntimeError("Scenery still uses unapproved old redirect fallback")
    if '"quest_glow"' not in loader or "_light_falloff_texture()" not in loader:
        raise RuntimeError("Unbound quest glow needs non-image procedural overlay")
    return {"status":"PASS", "maps":len(scenes), "runtime_original_blobs":len(reviewed),
            "scene_kinds_from_v14":len(V14_SCENERY),
            "scene_kinds_from_v17":len(SCENERY),
            "scene_kinds_generated_effect":len(SCENERY_EFFECTS),
            "scene_kinds_correctly_blocked":sorted(NOT_MATCHED),
            "sources":reviewed, "visual_acceptance":"NOT_YET_APPROVED"}


if __name__ == "__main__":
    print(json.dumps(validate(), ensure_ascii=False, sort_keys=True))
