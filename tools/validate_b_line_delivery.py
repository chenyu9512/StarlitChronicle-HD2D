#!/usr/bin/env python3
"""B-line static integrity; complements (never replaces) Godot runtime tests."""
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]

def load(path):
    return json.loads((ROOT / path).read_text(encoding="utf-8"))

def run():
    status = load("story/data/b_line_delivery_matrix_v1.json")
    maps = load("data/content/maps.json")["entries"]
    quests = [x for x in load("data/content/quests.json")["entries"] if x.get("kind") == "main"]
    anchors = load("story/data/phase19_quest_world_anchors.json")["quests"]
    regions = load("data/content/regions.json")["entries"]
    puzzle = load("data/levels/v7/dungeon_puzzles.json")["maps"]
    side_files = ["story/data/side_quests.json","story/data/regional_quests_v2.json",
                  "story/data/companion_quests.json"]
    side = [q for name in side_files for q in load(name)["quests"]]
    failures = []
    def verify(condition,reason):
        if not condition: failures.append(reason)
    verify(len(maps)==42 and len([m for m in maps if m["type"]!="prototype"])==40,"40 playable maps + 2 prototypes")
    verify(len(regions)==8 and len(puzzle)==8,"8 regions with 8 dungeon mechanisms")
    verify(len(quests)==72,"72 chapter world bindings")
    verify(len(anchors)==120 and len(side)==120,"120 quest data and world bindings")
    verify(len(set(q["id"] for q in side))==120,"duplicate quest IDs")
    verify(set(q["id"] for q in side)==set(a["quest_id"] for a in anchors),"quest-world mapping mismatch")
    ids={m["id"] for m in maps}
    for m in maps:
        for target in m.get("neighbors",[]):
            verify(target in ids,f'bad destination {m["id"]}->{target}')
        if m["type"]!="prototype":
            path=m.get("layout_source","").removeprefix("res://")
            verify(bool(path) and (ROOT/path).exists(),f'missing map sidecar {m["id"]}')
    for q in quests:
        verify(q["map_id"] in ids,f'missing chapter destination {q["chapter"]}')
    for i in range(1,13):
        act=load(f"story/campaign/act_{i:02d}.json")
        verify(len(act["chapters"])==6,f'act {i} should contain 6 chapters')
        for chapter in act["chapters"]:
            choices=[s["choice"] for s in chapter["scenes"] if "choice" in s]
            verify(len(choices)==1 and len(choices[0].get("options",[]))==2,
                   f'chapter {chapter["id"]} missing crisis route')
            for option in choices[0].get("options",[]):
                verify(chapter["id"]+".approach" in option.get("sets",{}),
                       f'no persistent flag {chapter["id"]}')
    for key in ("maps","regions","side_quests","chapters"):
        verify(len(status.get(key,[]))=={"maps":42,"regions":8,"side_quests":120,"chapters":72}[key],
               f'manifest {key} count mismatch')
    print(json.dumps({"pass":not failures,"checks":{"maps":40,"regions":8,"quests":120,"chapters":72},
                      "scope":"static references only; Godot gameplay not validated","failures":failures},
                     ensure_ascii=False,indent=2))
    return 0 if not failures else 1

if __name__=="__main__":
    raise SystemExit(run())
