#!/usr/bin/env python3
"""Static validation for C7 coastal actual render bindings (no engine required)."""
import json
from pathlib import Path
ROOT=Path(__file__).resolve().parent.parent
def read(name):
    return json.loads((ROOT/name).read_text(encoding="utf-8"))
def validate():
    live=read("data/assets/c_art_live_coast_v7.json")
    v6=read("data/assets/c_art_allocation_v6.json")
    catalog=read("data/assets/c_art_catalog.json")
    maps={m["id"]:m for m in read("data/content/maps.json")["entries"]}
    slots={x["path"]:x for x in catalog["assets"]}
    rows=live["placements"]
    assert len(rows)==24==live["count"]
    assert len({x["id"] for x in rows})==24
    paths={row["source"] for row in rows}
    assert len(paths)==7==live["distinct_art_sources"]
    assigned={row["source"]:row for row in v6["rows"] if row.get("state")=="runtime_bound_pending_visual_qa"}
    assert set(assigned)==paths
    for row in rows:
        path=row["source"]
        assert path in slots and slots[path]["expected_size"]==[32,32], path
        assert Path(ROOT/path[6:]).is_file(), path
        assert maps[row["map_id"]]["region_id"]=="region_coast", row
        x,y=row["cell"]
        width,height=maps[row["map_id"]]["grid_size"]
        assert 3<=x<width-3 and 3<=y<height-3, row
        assert row["collision"] is False and row["layer"]=="ground_visual_only", row
        assert row["id"] in assigned[path]["live_placement_ids"], row
    coastal=(ROOT/"scripts/world_coastal_scene.gd").read_text(encoding="utf-8")
    battle=(ROOT/"scripts/battle_enemies.gd").read_text(encoding="utf-8")
    assert "allocated_dressing.configure(map_id, layout)" in coastal
    assert "ArtOverrides.texture(art_path)" in battle
    print("SUCCESS: 24 nonblocking placements, 7 distinct assets, 4 maps, validated resolver callsites")

if __name__=="__main__":
    validate()
