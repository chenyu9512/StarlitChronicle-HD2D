#!/usr/bin/env python3
"""B-line Act-I commercial readiness (source evidence; no false engine claims).

Static contract checks authored chapter geography, availability of required
interiors, 6 side quests, 5 Boss definitions, story ID continuity. The strict
gate intentionally fails on missing playable scene bindings so 'six scripted
chapters' cannot be mistaken for a commercial-ready Act I.
"""
from __future__ import annotations
import argparse
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


def load(path: str) -> dict:
    return json.loads((ROOT / path).read_text(encoding="utf-8"))


def run() -> dict:
    contract = load("data/levels/act01_scene_locations_v1.json")
    quest_catalog = load("data/content/quests.json")["entries"]
    map_catalog = load("data/content/maps.json")["entries"]
    canonical = load("story/campaign/act_01.json")["chapters"]
    sidequests = load("data/first_act_side_quests.json")["quests"]
    bosses = load("story/data/bosses.json")["bosses"]
    registry = {m["id"]:m for m in map_catalog}
    anchors = {q["chapter"]:q for q in quest_catalog if q.get("kind")=="main"}
    boss_ids = {b["id"] for b in bosses}
    fatal = []
    commercial_blockers = []
    details = []
    chapters = contract.get("chapters",[])
    if len(chapters)!=6 or len(canonical)!=6 or len(sidequests)!=6:
        fatal.append("Act I must have six authored chapters and six local side quests")
    if len({a.get("chapter") for a in chapters})!=6:
        fatal.append("Act I location contract has duplicate chapter IDs")
    for number in range(1,7):
        record = next((x for x in chapters if x.get("chapter")==number),None)
        quest = anchors.get(number,{})
        story = next((x for x in canonical if x.get("id")==f"ch{number:03d}"),{})
        if record is None or not quest or not story:
            fatal.append(f"Missing Act-I canonical story/contract/quest for chapter {number}")
            continue
        expected = record["required_map_id"]
        actual = quest.get("map_id","")
        if expected not in registry:
            fatal.append(f"Missing intended playable map {expected} for chapter {number}")
        if len(story.get("scenes",[]))!=4:
            fatal.append(f"Chapter {number} no longer has four authored story scenes")
        if number>=2 and f"boss.ch{number:03d}" not in boss_ids:
            fatal.append(f"Boss missing for chapter {number}")
        local_side = [s for s in sidequests if s.get("chapter")==number]
        if len(local_side)!=1:
            fatal.append(f"Missing unique local side quest for chapter {number}")
        same_map = expected==actual
        if not same_map:
            commercial_blockers.append(
                f"Chapter {number} story location {record['story_location']} belongs to "
                f"{expected}, but current game opens {actual}")
        required_building = record.get("required_building_id","")
        interior_path = (ROOT / "data/levels/v4/interiors" /
                         f"{expected}__{required_building}.json")
        room_ready = not required_building or interior_path.is_file()
        if not room_ready:
            commercial_blockers.append(
                f"Chapter {number} requires a missing authored {record['required_scene_kind']}"
                f" interior: {interior_path.relative_to(ROOT)}")
        if record["required_scene_kind"]=="shore_subzone":
            commercial_blockers.append(
                f"Chapter {number} needs a distinctive whale-shoal gameplay subzone"
                f" within {expected}; existing sector identity remains saltwind road")
        details.append({
            "chapter":number, "story_location":record["story_location"],
            "story_map_id":expected, "current_anchor_map_id":actual,
            "map_alignment":same_map, "authored_room_file":room_ready,
            "unique_side_quest_id":local_side[0]["id"] if local_side else None,
            "boss_design_id":f"boss.ch{number:03d}" if number>=2 else None,
            "physical_path_tested":False, "godot_tested":False,
            "player_experience_accepted":False,
        })
    if len(registry)!=42:
        fatal.append(f"Expected 40 formal + 2 prototype maps, got {len(registry)}")
    return {"schema":"starlit.b.act01.commercial_gate.v1",
        "source_only":True, "chapters":details, "fatal_source_errors":fatal,
        "commercial_blockers":commercial_blockers,
        "ready_for_commercial_acceptance":not fatal and not commercial_blockers}


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--strict",action="store_true",
                        help="Fail until narrative-to-playable-world mismatch is resolved")
    parser.add_argument("--output",type=Path)
    args=parser.parse_args()
    result=run()
    if args.output:
        args.output.parent.mkdir(parents=True,exist_ok=True)
        args.output.write_text(json.dumps(result,ensure_ascii=False,indent=2)+"\n",encoding="utf-8")
    print(json.dumps({"canonical_chapters":len(result["chapters"]),
                      "fatal_errors":result["fatal_source_errors"],
                      "commercial_blockers":result["commercial_blockers"],
                      "commercial_accepted":False},ensure_ascii=False,indent=2))
    return 1 if result["fatal_source_errors"] or (args.strict and result["commercial_blockers"]) else 0


if __name__=="__main__":
    raise SystemExit(main())
