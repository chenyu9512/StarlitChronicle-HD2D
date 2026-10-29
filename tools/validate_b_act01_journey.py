#!/usr/bin/env python3
"""Static Act-I physical-route contract. No Godot simulation, no save writes.

The chapter 3 cave is deliberately *reported as blocked* because the current
D chapter router unlocks map_coast_04 only in chapter 4. Do not call this an
accepted six-chapter player experience until D migrates that gate safely.
"""
from pathlib import Path
import json

ROOT=Path(__file__).resolve().parents[1]


def load(path):
    return json.loads((ROOT/path).read_text(encoding="utf-8"))


def main():
    contracts=load("data/levels/act01_scene_locations_v1.json")["chapters"]
    atlas={v["id"]:v for v in load("data/levels/world_atlas_v2.json")["zones"]}
    quests=[q for q in load("data/content/quests.json")["entries"]
            if q.get("kind")=="main"]
    anchors={int(q["chapter"]):q["map_id"] for q in quests}
    unlocks={}
    for q in quests:
        m=q["map_id"]
        unlocks[m]=min(unlocks.get(m,1000),int(q["chapter"]))
    errors=[]
    if len(contracts)!=6 or len({int(c["chapter"]) for c in contracts})!=6:
        errors.append("Six canonical Act-I chapter routes required")
    if len(atlas)!=42 or len(anchors)!=72:
        errors.append("Original maps or main quest source records changed")
    blocked=[]
    chapter_arrival_hints=set()
    for contract in contracts:
        chapter=int(contract["chapter"])
        for stage in ("route","arrived","locked"):
            hint=contract.get(stage+"_guidance","")
            if not isinstance(hint,str) or len(hint)<20:
                errors.append(f"Chapter {chapter} missing human-readable {stage} guidance")
        if contract.get("arrived_guidance") in chapter_arrival_hints:
            errors.append(f"Chapter {chapter} duplicates another story destination prompt")
        chapter_arrival_hints.add(contract.get("arrived_guidance"))
        route=contract.get("route_map_ids",[])
        goal=contract.get("required_map_id","")
        anchor=anchors.get(chapter,"")
        if not route or route[-1]!=goal:
            errors.append(f"Chapter {chapter} route must end at its real story location")
            continue
        if anchor not in route:
            errors.append(f"Chapter {chapter} route no longer includes legacy chapter spawn")
        if goal not in atlas:
            errors.append(f"Chapter {chapter} story zone is missing from physical atlas")
        for i,m in enumerate(route):
            if m not in atlas:
                errors.append(f"Unknown chapter {chapter} region {m}")
                continue
            if atlas[m].get("type")=="prototype":
                errors.append(f"Chapter {chapter} uses prototype map {m}")
            if i and m not in atlas[route[i-1]].get("neighbors",[]):
                errors.append(f"Chapter {chapter} illegally skips {route[i-1]} -> {m}")
            if unlocks.get(m,999)>chapter:
                blocked.append({"chapter":chapter,"map":m,
                    "required_chapter":unlocks[m]})
        if contract.get("required_building_id"):
            path=(ROOT/"data/levels/v4/interiors"/
                  f"{goal}__{contract['required_building_id']}.json")
            if not path.is_file():
                errors.append(f"Chapter {chapter} missing physical story room {path.name}")
    if blocked != [{"chapter":3,"map":"map_coast_04","required_chapter":4}]:
        errors.append(f"Chapter-lock discrepancy changed: {blocked!r}")
    if errors:
        for error in errors:
            print("FAIL:",error)
        return 1
    print("PASS: six authentic adjacent Act-I route definitions, old spawn coverage,"
          " original rooms, chapter-3 cave gate correctly reported as BLOCKED")
    return 0


if __name__=="__main__":
    raise SystemExit(main())
