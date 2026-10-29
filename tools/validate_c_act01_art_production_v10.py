#!/usr/bin/env python3
"""Read-only C10 first act art / duplicate alias structural QA."""
import json, hashlib
from pathlib import Path
ROOT=Path(__file__).resolve().parent.parent
def load(p):
    return json.loads((ROOT/p).read_text(encoding="utf8"))
def verify():
    registry=load("data/assets/c_act01_art_production_v10.json")
    archive=load("data/assets/c_act01_archive_triage_v10.json")
    live=load("data/levels/v4/coastal_scenery.json")
    maps=load("data/content/maps.json")["entries"]
    sources=load("data/assets/c_art_source_originals.json")
    staging=load("assets/art/candidates/manifest.json")
    alloc=load("data/assets/c_art_allocation_v6.json")
    assert len(registry["maps"])==5 and len(registry["chapters"])==6
    assert len(sources["files"])==len(staging["entries"])==746
    assert len(alloc["rows"])==1885
    ids={m["id"] for m in maps}
    for key,bundle in registry["maps"].items():
        assert key in ids and key in live
        assert len(live[key]["scenery"])==bundle["scenery_count"]
        for field in ["ground","water","detail"]:
            path=bundle["terrain"][field]
            assert (ROOT/path[6:]).is_file(), (key,field,path)
        for group in ["scenery_sources","facades","interior_tilesets","props","character_slots","coastal_monster_assets"]:
            for path in bundle[group]:
                assert path.startswith("res://assets/art/") and (ROOT/path[6:]).is_file(), path
    for ch in registry["chapters"]:
        assert ch["canonical_scene_map_id"] in registry["maps"]
        assert ch["chapter_route_blocker"] in ["none","D_line_story_anchor_mismatch"]
    assert len(archive["actually_deleted"])==3
    for alias in archive["actually_deleted"]:
        assert not (ROOT/alias["original_path"]).exists()
        assert (ROOT/alias["kept_path"]).is_file()
        content=(ROOT/alias["kept_path"]).read_bytes()
        blob=hashlib.sha1(b"blob "+str(len(content)).encode()+b"\0"+content).hexdigest()
        assert blob==alias["blob_sha"],alias
    code=(ROOT/"scripts/world_coastal_scene.gd").read_text(encoding="utf8")
    world=(ROOT/"scripts/first_act_world.gd").read_text(encoding="utf8")
    assert "Act01Art.sprite_path(map_id, asset)" in code
    assert "Act01Art.has_map(map_id)" in code
    assert '"map_coast_05"' in world
    print("SUCCESS: 6 chapters, 5 canonical maps, atlas references and 3 exact-blob alias deletions")

if __name__=="__main__":
    verify()
