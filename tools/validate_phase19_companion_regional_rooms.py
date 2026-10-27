#!/usr/bin/env python3
"""Phase19-7 canonical + real navigation audit of 54 new V4 rooms / 30 outdoor sites."""
import json
from collections import deque
from pathlib import Path
from art_source_contract import available
P = Path(__file__).resolve().parents[1]
def load(name):
    return json.loads((P / name).read_text(encoding="utf-8"))
canonical = {}
for basename in ("companion_quests", "regional_quests_v2"):
    for quest in load("story/data/"+basename+".json")["quests"]:
        assert quest["id"] not in canonical
        canonical[quest["id"]] = quest
anchors = {q["quest_id"]: q for q in load("story/data/phase19_quest_world_anchors.json")["quests"]}
dossiers = {q["quest_id"]: q for q in load("story/data/phase19_scene_dressing.json")["quests"]}
doc = load("story/data/phase19_companion_regional_submaps.json")
errors=[]
def ck(ok,label):
    if not ok: errors.append(label)
seen=set(); geometry=set(); listed_outdoors=set()
for entry in doc["quests"]:
    id=entry["quest_id"]
    ck(id not in seen, "duplicate "+id);seen.add(id)
    q=canonical.get(id,{})
    a=anchors.get(id,{})
    d=dossiers.get(id,{})
    ck(bool(q) and entry["story_title"]==q.get("title"), "unchanged original title "+id)
    ck(entry["quest_type"]==a.get("quest_type") and a.get("building_id") is not None,
       "canonical indoor type "+id)
    ck(entry["map_id"]==a.get("map_id") and entry["original_location"]==a.get("script_location")
       and entry["original_npc"]==a.get("story_npc") and entry["door_hint"]==a.get("anchor_hint")
       and entry["open_chapter"]==a.get("first_chapter"),"chapter/map/NPC contract "+id)
    ck(entry["building_id"]=="quest__"+id,"own non-overwriting interior ID "+id)
    ck(entry["displays"][1]==d.get("evidence_label") and
       entry["displays"][2]==d.get("record_label"),"evidence grounded in canon "+id)
    path=entry["unique_layout_file"]
    ck((P/path).exists(),"existing V4 room "+id)
    if not (P/path).exists():continue
    data=load(path)
    ck(data.get("schema")=="starlit.interior.v4" and data.get("map_id")==entry["map_id"]
       and data.get("building_id")==entry["building_id"] and data.get("script_quest_id")==id,
       "V4 room identity "+id)
    ck(data.get("scene_kind")==entry["quest_type"]+"_indoor","correct set design "+id)
    ck(data.get("art_profile")=="quest_research_v1" and len(data.get("visuals",[]))>=4,
       "day/night art dressing present "+id)
    ck(len(data.get("floor_regions",[]))>=5 and len(data.get("solid_regions",[]))>=4,
       "individual geometry "+id)
    csig=json.dumps([data["floor_regions"],data["solid_regions"],data["door_regions"]],sort_keys=True)
    ck(csig not in geometry, "repeated floor plan "+id);geometry.add(csig)
    ck(len(data.get("quest_points",[]))==3 and len(data.get("story_stage_points",[]))==5
       and len(data.get("branch_stage_points",[]))==3,"eleven different interaction targets "+id)
    exp={tuple(t) for t in data["quest_points"]}
    stages={tuple(t) for t in data["story_stage_points"]}
    branches={tuple(t) for t in data["branch_stage_points"]}
    ck(len(exp)==3 and len(stages)==5 and len(branches)==3 and
       not exp.intersection(stages) and not exp.intersection(branches) and
       not stages.intersection(branches),"no overlapping task markers "+id)
    ground=set()
    for rect in data["floor_regions"]:
        x0,y0,x1,y1=rect["rect"];ground.update((x,y) for x in range(x0,x1+1) for y in range(y0,y1+1))
    for rect in data["solid_regions"]:
        x0,y0,x1,y1=rect["rect"];ground.difference_update((x,y) for x in range(x0,x1+1) for y in range(y0,y1+1))
    for rect in data["door_regions"]:
        x0,y0,x1,y1=rect["rect"];ground.update((x,y) for x in range(x0,x1+1) for y in range(y0,y1+1))
    for p in data.get("art_collision_cells",[]):ground.discard(tuple(p))
    start=tuple(data["points"]["spawn"]);que=deque([start]);reachable={start}
    while que:
        x,y=que.popleft()
        for n in ((x-1,y),(x+1,y),(x,y-1),(x,y+1)):
            if n in ground and n not in reachable:
                reachable.add(n);que.append(n)
    for cell in list(data["points"].values())+data["quest_points"]+data["story_stage_points"]+data["branch_stage_points"]:
        ck(tuple(cell) in reachable,"walkable scene goal "+id+" "+str(cell))
    ck(len(reachable)>=400,"no tiny token room "+id)
    for v in data.get("visuals",[]):
        asset=v.get("asset")
        ck(any(available(f"assets/art/interiors/{folder}/{asset}.svg")
               for folder in ("morning_dew_inn","coastal_district")),
           "real mapped art "+id+":"+str(asset))
for record in doc["outdoor_preserved"]:
    id=record["quest_id"]
    ck(id not in listed_outdoors, "duplicate outdoors "+id)
    listed_outdoors.add(id)
    a=anchors.get(id,{})
    ck(id in canonical and a.get("building_id") is None and
       a.get("map_id")==record["map_id"] and a.get("script_location")==record["location"]
       and a.get("first_chapter")==record["open_chapter"],
       "real outdoors at canon location "+id)
ck(not seen.intersection(listed_outdoors) and seen|listed_outdoors==set(canonical),
   "all 84 original companion and regional quests preserved")
counts={"companion_indoor":sum(x["quest_type"]=="companion" for x in doc["quests"]),
        "regional_indoor":sum(x["quest_type"]=="regional" for x in doc["quests"]),
        "companion_outdoor":sum(x["quest_type"]=="companion" for x in doc["outdoor_preserved"]),
        "regional_outdoor":sum(x["quest_type"]=="regional" for x in doc["outdoor_preserved"])}
ck(counts==doc.get("counts")=={"companion_indoor":34,"regional_indoor":20,
    "companion_outdoor":14,"regional_outdoor":16},"accurate inventory and type split")
print(f"Phase19-7: {len(seen)} unique interior rooms, {len(listed_outdoors)} original outdoor sites, {len(geometry)} unique V4 footprints; errors={len(errors)}")
if errors:
    print("FAIL:",*errors,sep="\n - ")
    raise SystemExit(1)
print("PASS: 84 canonical quest sites, 54 walkable decorated 11-node rooms and 30 outdoor sites.")
