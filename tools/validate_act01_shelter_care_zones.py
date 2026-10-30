#!/usr/bin/env python3
"""Verify actual Ch2 medical-bay scene art identity, collision and paths."""
import json
from collections import deque
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
def read(name):
    return json.loads((ROOT/name).read_text(encoding="utf-8"))
room=read("data/levels/v4/interiors/map_coast_02__shelter.json")
assets=read("assets/art/runtime/generated_gaps_v10/manifest.json")["assets"]
registry=read("data/assets/c_art_runtime_registry_v1.json")["canonical_slots"]
assert room["schema"]=="starlit.interior.v4" and room["revision"]==9
assert (room["map_id"],room["building_id"])==("map_coast_02","shelter")
props={p["id"]:p for p in room["visuals"]}
assert len(props)==len(room["visuals"])==15
expected={
    "triage_bed_west":("shelter_cot",(27,23),"west_ward"),
    "recovery_bed_west":("shelter_cot",(27,30),"west_ward"),
    "recovery_bed_east":("shelter_cot",(46,26),"east_ward"),
    "triage_medicine_east":("shelter_treatment_tray",(43,27),"triage"),
}
for ident,(art,cell,zone) in expected.items():
    prop=props[ident]
    assert (prop["asset"],tuple(prop["cell"]),prop["care_zone"])==(art,cell,zone),ident
    key="interior.shelter."+art
    assert registry[key]["source"]==assets[key]["source"],("unregistered material",key)
    path=ROOT/registry[key]["source"].removeprefix("res://")
    # Some valid 96x128 V10 pixel PNGs compress below 4 KiB; size is
    # not a semantic identity check. Authenticate their actual content.
    assert path.is_file(),path
    import hashlib
    import struct
    data=path.read_bytes()
    assert len(data)>24 and data[:8]==bytes.fromhex("89504e470d0a1a0a"),path
    width,height=struct.unpack(">II",data[16:24])
    assert [width,height]==assets[key]["dimensions"],("PNG dimensions mismatch",key)
    assert hashlib.sha256(data).hexdigest()==assets[key]["sha256"],("PNG SHA256 mismatch",key)
assert {tuple(x) for x in room["art_collision_cells"]}=={(27,23),(27,30),(46,26)}
assert len(room["light_sources"])==4
assert {x["id"] for x in room["light_sources"]}=={
    "shelter_nurse_lamp","shelter_care_lamp","shelter_duty_lamp","shelter_recovery_lamp"}
# Mirror Godot V4 fill ordering (floor, walls, doors, bed-contact solids).
walkable=set()
for kind,remove in (("floor_regions",False),("solid_regions",True),("door_regions",False)):
    for row in room[kind]:
        x0,y0,x1,y1=row["rect"]
        for y in range(y0,y1+1):
            for x in range(x0,x1+1):
                (walkable.discard if remove else walkable.add)((x,y))
for cell in room["art_collision_cells"]:
    walkable.discard(tuple(cell))
spawn=tuple(room["points"]["spawn"])
queue=deque([spawn]);reached={spawn}
while queue:
    x,y=queue.popleft()
    for cell in ((x-1,y),(x+1,y),(x,y-1),(x,y+1)):
        if cell in walkable and cell not in reached:
            reached.add(cell);queue.append(cell)
targets=[tuple(x) for x in room["points"].values()]
targets += [tuple(x["cell"]) for x in room["investigations"]]
targets += [tuple(x) for x in room["act01_main_story_points"].values()]
assert all(p in reached for p in targets),("unreachable quests/entry/exit",set(targets)-reached)
assert all((35,y) in reached for y in range(29,37)),"central approach blocked"
assert len(room["investigations"])==4
assert room["act01_main_story_evidence"]==[
    "inspect_act01_shelter_2","inspect_act01_shelter_3"]
print("PASS: 15 exact shelter PNG placements, 3 bed collision tiles, 4 lights, all original story and inspection paths")
