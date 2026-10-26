#!/usr/bin/env python3
"""Static map-display audit. This never substitutes for actual Godot rendering."""
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]

def read(p):
    return json.loads((ROOT / p).read_text(encoding="utf-8"))

def main():
    errors = []
    maps = read("data/content/maps.json")["entries"]
    geo = read("data/levels/world_atlas_v2.json")
    authored = read("data/levels/world_levels_v3.json")["levels"]
    nodes = {z["id"]: z for z in geo["zones"]}
    active = [m for m in maps if m.get("type") != "prototype"]
    ids = {m["id"] for m in active}
    if len(maps)!=42 or len(active)!=40 or len(ids)!=40 or len(nodes)!=42 or len(authored)!=40:
        errors.append("40 production maps, two prototypes, 42 atlas locations required")
    if len(geo["regions"])!=8:
        errors.append("Eight authored regions required")
    atlas_w, atlas_h = geo["world_size"]
    for entry in active:
        map_id = entry["id"]
        source = Path("data/levels/v3") / (map_id+".json")
        if not (ROOT/source).exists():
            errors.append(f"Missing terrain file: {map_id}")
            continue
        sidecar = read(str(source))
        authored_record = authored.get(map_id,{})
        zone = nodes.get(map_id,{})
        dim = sidecar.get("size",[])
        if (sidecar.get("map_id")!=map_id or dim!=entry.get("grid_size")
                or dim!=authored_record.get("size") or len(dim)!=2
                or not 72<=dim[0]<=112 or not 48<=dim[1]<=78):
            errors.append(f"Terrain/atlas dimensions disagree: {map_id}")
        if not zone.get("playable") or zone.get("region_id")!=entry.get("region_id"):
            errors.append(f"Missing playable atlas entry: {map_id}")
        point = zone.get("atlas",[])
        if len(point)!=2 or not (0<=point[0]<=atlas_w and 0<=point[1]<=atlas_h):
            errors.append(f"Unrenderable world-map pin: {map_id}")
        if set(zone.get("neighbors",[])) != set(entry.get("neighbors",[])):
            errors.append(f"Atlas and travel edges differ: {map_id}")
        if not sidecar.get("roads"):
            errors.append(f"No drawn travel routes: {map_id}")
    rooms = list((ROOT/"data/levels/v4/interiors").glob("*.json"))
    if len(rooms)!=97:
        errors.append(f"Expected 97 authored interiors, found {len(rooms)}")
    for file in rooms:
        d = json.loads(file.read_text(encoding="utf-8"))
        mid = str(d.get("map_id",""))
        bid = str(d.get("building_id",""))
        if (mid not in ids or file.name!=f"{mid}__{bid}.json"
                or d.get("schema")!="starlit.interior.v4" or d.get("size")!=[72,48]):
            errors.append(f"Interior cannot map to canonical grid: {file.name}")
        for target in ("spawn","exit"):
            cell = d.get("points",{}).get(target,[])
            if len(cell)!=2 or not (2<=cell[0]<70 and 2<=cell[1]<46):
                errors.append(f"Invalid interior {target}: {file.name}")
    for proto in (m for m in maps if m.get("type")=="prototype"):
        if nodes.get(proto["id"],{}).get("playable"):
            errors.append(f"Prototype displayed as playable: {proto['id']}")
    print(json.dumps({"kind":"STATIC_MAP_DISPLAY", "passed":not errors,
                      "maps":len(active),"regions":len(geo["regions"]),
                      "interiors":len(rooms),"engine_tested":False,"errors":errors},
                     ensure_ascii=False,indent=2))
    return 1 if errors else 0

if __name__=="__main__":
    raise SystemExit(main())
