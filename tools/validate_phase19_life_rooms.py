#!/usr/bin/env python3
"""Phase19-6: canon, 19 physically reachable indoor life quests and 5 outdoor quests."""
import json
from pathlib import Path
from collections import deque

ROOT=Path(__file__).resolve().parents[1]
def load(path): return json.loads((ROOT/path).read_text(encoding="utf8"))
orig={q["id"]:q for q in load("story/data/side_quests.json")["quests"] if q["id"].startswith("sq_life_")}
mapped={q["quest_id"]:q for q in load("story/data/phase19_quest_world_anchors.json")["quests"] if q["quest_type"]=="life"}
dossier={q["quest_id"]:q for q in load("story/data/phase19_scene_dressing.json")["quests"]}
m=load("story/data/phase19_life_submaps.json")
errors=[]
def ck(ok,s):
    if not ok:errors.append(s)
entry_ids=set(); signatures=set()
for entry in m["quests"]:
    qid=entry["quest_id"];entry_ids.add(qid)
    q=orig.get(qid,{})
    source=mapped.get(qid,{})
    ck(bool(q) and q["title"]==entry["story_title"],"title "+qid)
    ck(source.get("building_id") is not None and source.get("map_id")==entry["map_id"] and
       source.get("first_chapter")==entry["open_chapter"] and
       source.get("anchor_hint")==entry["door_hint"] and
       source.get("story_npc")==entry["original_npc"],"source location drift "+qid)
    ck(entry["building_id"]=="quest__"+qid,"independent room id "+qid)
    data=load(entry["unique_layout_file"])
    ck(data["schema"]=="starlit.interior.v4" and data["map_id"]==entry["map_id"] and
       data["script_quest_id"]==qid and data["building_id"]==entry["building_id"],
       "real V4 location "+qid)
    ck(data["size"]==[72,48] and len(data["features"])>=5 and len(data["visuals"])>=4,
       "real 72x48 furnished room "+qid)
    ck(len(data["quest_points"])==3 and len({tuple(p) for p in data["quest_points"]})==3,
       "three unique stops "+qid)
    ck(data["art_profile"]=="quest_research_v1","working room art profile "+qid)
    ck(entry["displays"][1]==dossier[qid]["evidence_label"],"evidence not canon "+qid)
    tiles=set()
    for r in data["floor_regions"]:
        x0,y0,x1,y1=r["rect"];tiles.update((x,y) for x in range(x0,x1+1) for y in range(y0,y1+1))
    for r in data["solid_regions"]:
        x0,y0,x1,y1=r["rect"];tiles.difference_update((x,y) for x in range(x0,x1+1) for y in range(y0,y1+1))
    for r in data["door_regions"]:
        x0,y0,x1,y1=r["rect"];tiles.update((x,y) for x in range(x0,x1+1) for y in range(y0,y1+1))
    for pt in data.get("art_collision_cells",[]):tiles.discard(tuple(pt))
    start=tuple(data["points"]["spawn"]); reached={start}; queue=deque([start])
    while queue:
        x,y=queue.popleft()
        for pt in ((x+1,y),(x-1,y),(x,y+1),(x,y-1)):
            if pt not in reached and pt in tiles:
                reached.add(pt);queue.append(pt)
    for p in list(data["points"].values())+data["quest_points"]:
        ck(tuple(p) in reached,"unreachable room objective "+qid+" "+str(p))
    ck(len(reached)>=370,"room too small "+qid)
    sig=json.dumps([data["floor_regions"],data["solid_regions"],data["door_regions"]],sort_keys=True)
    ck(sig not in signatures,"identical room geometry "+qid)
    signatures.add(sig)
    for visual in data["visuals"]:
        asset=visual["asset"]
        ck(any((ROOT/f"assets/art/interiors/{folder}/{asset}.svg").exists() for folder in ("morning_dew_inn","coastal_district")),
           "missing furniture asset "+qid+":"+asset)
out_ids={v["quest_id"] for v in m["outdoor_preserved"]}
ck(len(entry_ids)==19 and len(out_ids)==5 and not entry_ids.intersection(out_ids)
   and entry_ids|out_ids==set(orig)==set(mapped),"all 24 life quests covered, 5 untouched outdoors")
ck(m["counts"]=={"indoor":19,"outdoor":5},"accurate coverage statement")
print(f"Phase19Life interiors={len(entry_ids)} outdoor_preserved={len(out_ids)} unique_rooms={len(signatures)} errors={len(errors)}")
if errors:
    print("FAIL:",*errors,sep="\n - ")
    raise SystemExit(1)
print("PASS: canon life site IDs, unique V4 rooms, genuine collision routes, real existing SVGs, outdoor continuity.")
