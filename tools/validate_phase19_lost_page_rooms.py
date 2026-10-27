#!/usr/bin/env python3
"""Phase19-4: twelve independent lost-page room layouts and navigable exhibits."""
from collections import deque
from pathlib import Path
import json
from art_source_contract import available

ROOT = Path(__file__).resolve().parents[1]
def load(p):
    return json.loads((ROOT / p).read_text(encoding="utf8"))
quests = {q["id"]:q for q in load("story/data/side_quests.json")["quests"] if q["id"].startswith("sq_page_")}
anchors = {a["quest_id"]:a for a in load("story/data/phase19_quest_world_anchors.json")["quests"]}
manifest = load("story/data/phase19_lost_page_submaps.json")
issues = []
def ck(value, reason):
    if not value:
        issues.append(reason)
ids=set()
geometry=set()
for entry in manifest["quests"]:
    qid=entry["quest_id"]
    ids.add(qid)
    ck(qid in quests and entry["story_title"] == quests[qid]["title"],"canon "+qid)
    canon=anchors.get(qid,{})
    ck(entry["map_id"]==canon.get("map_id") and entry["original_npc"]==canon.get("story_npc")
       and entry["door_hint"]==canon.get("anchor_hint"),"map and NPC "+qid)
    ck(entry["open_chapter"]==canon.get("first_chapter"),"chapter "+qid)
    ck(entry["building_id"]=="quest__"+qid,"building ID "+qid)
    ck(entry["unique_layout_file"]==f"data/levels/v4/interiors/{entry['map_id']}__quest__{qid}.json",
       "real room reference "+qid)
    d=load(entry["unique_layout_file"])
    ck(d["schema"]=="starlit.interior.v4" and d["script_quest_id"]==qid and
       d["building_id"]==entry["building_id"] and d["map_id"]==entry["map_id"],
       "valid V4 header "+qid)
    ck(d["size"]==[72,48] and len(d["floor_regions"])>=5 and len(d["solid_regions"])>=3
       and len(d["features"])>=5,"real room layout complexity "+qid)
    tile=set()
    for r in d["floor_regions"]:
        x0,y0,x1,y1=r["rect"]
        tile.update((x,y) for x in range(x0,x1+1) for y in range(y0,y1+1))
    for r in d["solid_regions"]:
        x0,y0,x1,y1=r["rect"]
        tile.difference_update((x,y) for x in range(x0,x1+1) for y in range(y0,y1+1))
    for r in d.get("door_regions",[]):
        x0,y0,x1,y1=r["rect"]
        tile.update((x,y) for x in range(x0,x1+1) for y in range(y0,y1+1))
    for blocked_furniture in d.get("art_collision_cells",[]):
        tile.discard(tuple(blocked_furniture))
    ck(d.get("art_profile")=="quest_research_v1" and len(d.get("visuals",[]))>=4,
       "distinct authored environment art layers "+qid)
    ck(len(d.get("room_day_tint",""))==6 and len(d.get("room_night_tint",""))==6,
       "individual day/night ambience "+qid)
    for visual in d.get("visuals",[]):
        asset=visual.get("asset","")
        exists=any(available(f"assets/art/interiors/{folder}/{asset}.svg")
                   for folder in ("morning_dew_inn","coastal_district"))
        ck(exists,"actual installed art resource "+qid+":"+asset)
    marks=[d["points"][k] for k in ("spawn","exit","service","storage")]+d["quest_points"]
    ck(len(d["quest_points"])==3 and len({tuple(p) for p in d["quest_points"]})==3,
       "three distinct clue coordinates "+qid)
    for p in marks:
        ck(tuple(p) in tile,"walkable landmark "+qid+str(p))
    origin=tuple(d["points"]["spawn"])
    seen={origin}
    queue=deque([origin])
    while queue:
        x,y=queue.popleft()
        for n in [(x-1,y),(x+1,y),(x,y-1),(x,y+1)]:
            if n not in seen and n in tile:
                seen.add(n)
                queue.append(n)
    for p in marks:
        ck(tuple(p) in seen,"spawn must connect to "+qid+str(p))
    ck(len(seen)>=370,"no token-sized imitation room "+qid)
    signature=json.dumps([d["floor_regions"],d["solid_regions"],d["door_regions"]],sort_keys=True)
    ck(signature not in geometry,"duplicate room footprint "+qid)
    geometry.add(signature)
ck(ids==set(quests) and len(ids)==len(geometry)==12,"all 12 distinct lost-page rooms")
print(f"Phase19Rooms rooms={len(ids)} unique_geometry={len(geometry)} errors={len(issues)}")
if issues:
    print("FAIL:",*issues,sep="\n - ")
    raise SystemExit(1)
print("PASS: 12 canonical unique indoor layouts, traversable spawns, exits and three clue stations.")
