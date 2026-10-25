#!/usr/bin/env python3
"""Recalculate deliverable coverage from canonical runtime data.
Never treat authored plans or asset metadata as complete playable scenes.
"""
import json
from pathlib import Path
ROOT=Path(__file__).resolve().parent.parent
def load(path):
    return json.loads((ROOT/path).read_text(encoding="utf-8"))
acts=[load(f"story/campaign/act_{i:02d}.json") for i in range(1,13)]
chapters=[c for a in acts for c in a["chapters"]]
assert len(chapters)==72 and [c["id"] for c in chapters]==[f"ch{i:03d}" for i in range(1,73)]
scenes=[s for c in chapters for s in c["scenes"]]
assert len(scenes)==289
ids=[line["id"] for s in scenes for line in s.get("dialogue",[])]
assert len(ids)==len(set(ids)), "Duplicate dialogue IDs"
maps=load("data/content/maps.json")["entries"]
assert len(maps)==42
quest_ids=[q["id"] for f in ["side_quests","companion_quests","regional_quests_v2"] for q in load(f"story/data/{f}.json")["quests"]]
assert len(quest_ids)==120 and len(set(quest_ids))==120
optional=[
"phase08_act01_town_scenes","phase08_act01_evidence_scenes",
"phase09_act02_optional_scenes","phase10_act03_optional_scenes"]
reactions=[
"phase08_act01_choice_reactions","phase09_act02_choice_reactions",
"phase10_act03_choice_reactions"]
op=[v for p in optional for v in load(f"story/data/{p}.json")["scenes"]]
rx=[v for p in reactions for v in load(f"story/data/{p}.json")["followups"]]
assert len(op)==36 and len(rx)==36
for entry in op+rx:
    assert entry["chapter_id"] in {c["id"] for c in chapters}
    assert entry.get("dialogue"), entry.get("id")
report={
"schema":"starlit.delivery.audit.v1",
"main_chapters":len(chapters),"main_scenes":len(scenes),"main_dialogue_lines":len(ids),
"authored_quests":len(quest_ids),"planned_maps":len(maps),
"authored_scene_paths":sum(1 for x in maps if str(x.get("scene_path","")).endswith(".tscn")),
"optional_scenes_with_runtime_ids":len(op),
"choice_reactions_with_runtime_ids":len(rx),
"audio_assets":len([p for p in (ROOT/"assets").rglob("*") if p.suffix.lower() in {".ogg",".wav",".mp3",".flac",".m4a"}]),
"not_verified":["commercial map design","full boss AI","iPhone device playthrough","complete audio/art"]
}
print(json.dumps(report,ensure_ascii=False,indent=2))
