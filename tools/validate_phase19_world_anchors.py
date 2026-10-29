#!/usr/bin/env python3
"""Phase19-2: canonical, chapter-safe positions for all 120 pre-existing quests."""
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
def read(path):
    return json.loads((ROOT / path).read_text(encoding="utf-8"))
source = read("story/data/phase19_quest_world_anchors.json")
quests = {}
for name in ("side_quests","companion_quests","regional_quests_v2"):
    quests.update({q["id"]:q for q in read(f"story/data/{name}.json")["quests"]})
maps = {m["id"]:m for m in read("data/content/maps.json")["entries"]}
zones = {m["id"]:m for m in read("data/levels/world_atlas_v2.json")["zones"]}
chapters = {}
for q in read("data/content/quests.json")["entries"]:
    if q["kind"]=="main":
        chapters[q["map_id"]] = min(chapters.get(q["map_id"],999),q["chapter"])
# Act I contains transit sectors: the Saltwind Road is legitimately entered
# in chapter 3 on the way to the cave, even though the separate shoal plot
# in that same sector is not the chapter-3 destination. Mirror the live world
# registry's strictly coastal, physically authored route unlocking policy
# instead of assuming that only quest *destinations* unlock a map.
contract = read("data/levels/act01_scene_locations_v1.json")
for chapter_scene in contract.get("chapters", []):
    chapter = int(chapter_scene.get("chapter", 0))
    if not 1 <= chapter <= 6:
        continue
    # Historical save exits do NOT grant chapter-5 access to the lighthouse.
    # Only primary routes establish global initial visit eligibility.
    for route_id in chapter_scene.get("route_map_ids", []):
        if route_id in maps and maps[route_id].get("region_id") == "region_coast":
            chapters[route_id] = min(chapters.get(route_id, 999), chapter)
anchors = source["quests"]
issues=[]
def test(condition,message):
    if not condition: issues.append(message)
test(len(quests)==120 and len(anchors)==120,"120 original quest keys and 120 authored anchors")
test(len({q["quest_id"] for q in anchors})==120,"no duplicate quest mapping")
test(set(q["quest_id"] for q in anchors)==set(quests),"all 120 quest IDs exactly covered")
test(len(maps)==42 and len([m for m in maps.values() if m["type"]!="prototype"])==40,
     "do not remove 40 original playable sectors")
test(source["map_dimensions"]==[72,48] and source["tile_pixels"]==32,"world tile dimensions")
for row in anchors:
    qid = row["quest_id"]
    if qid not in quests: continue
    quest = quests[qid]
    map_id = row["map_id"]
    test(map_id in maps and map_id in zones,"unknown map "+qid)
    if map_id not in maps or map_id not in zones: continue
    area = zones[map_id]
    first = int(quest["required_chapter"][2:])
    test(chapters.get(map_id,999)<=first,"locked before story time "+qid)
    test(row["first_chapter"]==quest["required_chapter"],"original chapter mismatch "+qid)
    test(row["region_id"]==maps[map_id]["region_id"]==area["region_id"],
         "world zone mismatch "+qid)
    test(row["map_name"]==maps[map_id]["name"] and row["title"]==quest["title"],
         "mismatched display and quest data "+qid)
    test(row["script_location"]==quest.get("region",""),"original named area drift "+qid)
    test(row["stage_roles"]==["npc","evidence","notice"],"physical sequence change "+qid)
    test(len(row["anchor_hint"])==2 and 2<=row["anchor_hint"][0]<70 and
         2<=row["anchor_hint"][1]<46,"map cell outside playable bounds "+qid)
    bid = row["building_id"]
    if bid is not None:
        existing = next((b for b in area.get("buildings",[]) if b["id"]==bid),None)
        test(existing is not None,"invented building ID "+qid)
        if existing:
            test(row["anchor_hint"]==existing["door"],"misplaced official building entrance "+qid)
    test(row["story_npc"].strip()!="","missing NPC "+qid)
    test(map_id not in ("map_legacy_village","map_legacy_ruins"),"old non-playable map "+qid)
for manifest in ("phase17_lost_pages_manifest","phase17_life_manifest",
                 "phase17_regional_manifest","phase18_companion_manifest"):
    file = read("story/data/"+manifest+".json")
    test(set(entry["id"] for entry in file["entries"])<=set(quests),
         "unmatched original ids in "+manifest)
print(f"Phase19World quests={len(anchors)} maps={len(set(a['map_id'] for a in anchors))} errors={len(issues)}")
if issues:
    print("FAIL:",*issues,sep="\n - ")
    raise SystemExit(1)
print("PASS: all 120 quests map to a canonically unlocked sector and real authored doorway/cell.")
