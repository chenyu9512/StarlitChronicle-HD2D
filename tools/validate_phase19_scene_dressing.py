#!/usr/bin/env python3
"""Phase19-3: every quest field-prop label is traceable to existing script evidence."""
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
def load(path):
    return json.loads((ROOT / path).read_text(encoding="utf-8"))
quests = {}
for name in ("side_quests", "companion_quests", "regional_quests_v2"):
    for quest in load(f"story/data/{name}.json")["quests"]:
        assert quest["id"] not in quests
        quests[quest["id"]] = quest
anchors = {q["quest_id"]:q for q in load("story/data/phase19_quest_world_anchors.json")["quests"]}
doc = load("story/data/phase19_scene_dressing.json")
records = doc["quests"]
fail = []
def require(value,why):
    if not value:
        fail.append(why)
require(len(records)==120 and len({r["quest_id"] for r in records})==120,"120 unique scene dressings")
require(set(r["quest_id"] for r in records)==set(quests)==set(anchors),"all scenes canonically mapped")
require(doc["counts"]["quests"]==120,"declared scene coverage")
valid={"crate","sea_crystal","star_lantern","barrel","medicine_basket","flowerpot"}
for row in records:
    id=row["quest_id"]
    q=quests.get(id)
    a=anchors.get(id)
    if not q or not a:
        continue
    require(row["map_id"]==a["map_id"] and row["location"]==a["script_location"],
        f"original site does not match scene {id}")
    require(row["title"]==q["title"] and row["witness_name"]==a["story_npc"],
        f"quest identity changed {id}")
    require(row["evidence_prop"] in valid, f"invalid evidence sprite {id}")
    require(len(str(row["evidence_label"]))>1 and len(str(row["record_label"]))>1,
        f"generic missing names {id}")
    require(row["original_stage_ids"]==[s["id"] for s in q["stages"]],
        f"original stage order changed {id}")
    evidence=q["stages"][1].get("dialogue",[])
    original_evidence=str(evidence[0]["text"]) if evidence else str(q["stages"][1]["objective"])
    require(row["observation"]==original_evidence.replace("“","").replace("”","").lstrip("，。： ").strip()[:48],
        f"evidence must cite canonical line {id}")
    finale=q["stages"][-1].get("dialogue",[])
    original_finale=str(finale[0]["text"]) if finale else str(q["stages"][-1]["objective"])
    require(row["later_record"]==original_finale.replace("“","").replace("”","").lstrip("，。： ").strip()[:48],
        f"ending record must cite canonical line {id}")
    require(row["detailed_scene_available"] is False,
        f"cannot claim dedicated room art for sector-only scene {id}")
print(f"Phase19SceneDress quests={len(records)} props={len(valid)} errors={len(fail)}")
if fail:
    print("FAIL:",*fail,sep="\n - ")
    raise SystemExit(1)
print("PASS: all 120 quest scenes grounded in original investigation/resolution lines, no forged submaps.")
