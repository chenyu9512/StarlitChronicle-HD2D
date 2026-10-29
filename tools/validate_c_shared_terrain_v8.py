#!/usr/bin/env python3
"""C8 static atlas-family and map routing validator, not a Godot smoke substitute."""
import json
from pathlib import Path
ROOT=Path(__file__).resolve().parent.parent
def data(p):
    return json.loads((ROOT/p).read_text(encoding="utf8"))
def check():
    cfg=data("data/assets/c_shared_terrain_v8.json")
    assert cfg["tile_size"]==32 and cfg["columns"]==cfg["rows"]==8
    assert len(cfg["regions"])==8
    assert len(cfg["groups"]["terrain_ground"])==11
    assert len(cfg["groups"]["terrain_water"])==10
    catalog=data("data/assets/c_art_catalog.json")
    slots={r["path"] for r in catalog["assets"]}
    paths=set(cfg["groups"]["terrain_ground"]+cfg["groups"]["terrain_water"])
    assert len(paths)==21
    for path in paths:
        assert path in slots and (ROOT/path[6:]).is_file(), path
    packs=data("data/assets/c_art_packs.json")["packs"]
    built=next(p for p in packs if p["id"]=="shared_terrain")
    assert len(built["mappings"])==19
    assert {m["target"] for m in built["mappings"]}==paths-{cfg["base"]["ground"],cfg["base"]["water"]}
    for m in built["mappings"]:
        assert m["source"] in [cfg["base"]["ground"],cfg["base"]["water"]]
    maps=data("data/content/maps.json")["entries"]
    assert len(maps)==42 and all(m["region_id"] in cfg["regions"] for m in maps)
    for entry in cfg["map_overrides"].values():
        for path in entry.values():
            assert path in paths
    source=(ROOT/"scripts/first_act_world.gd").read_text(encoding="utf8")
    pool=(ROOT/"scripts/world_tileset_pool.gd").read_text(encoding="utf8")
    art=(ROOT/"scripts/c_art_overrides.gd").read_text(encoding="utf8")
    assert "TerrainAtlas.atlas_sources(region,map_id,chosen_atlas,outside)" in source
    assert "texture.get_instance_id()" in pool
    assert "TerrainAtlas.group_slots(group_id)" in art
    assert 'expanded.append({"target": slot' in art
    print("SUCCESS: 42 maps, 8 regions, 21 group IDs, 19 one-click builtin mappings")

if __name__=="__main__":
    check()
