#!/usr/bin/env python3
"""V2.1 cross-file narrative audit (offline, no Godot dependency).

Run: python tools/validate_narrative_v21.py
Checks continuity/data contracts, not literary merit or actual runtime behavior.
"""
from collections import Counter
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1] / "story"
errors = []
warnings = []

def load(rel):
    try:
        return json.loads((ROOT / rel).read_text(encoding="utf-8"))
    except (OSError, ValueError) as exc:
        errors.append(f"LOAD {rel}: {exc}")
        return {}

def check(condition, msg):
    if not condition:
        errors.append(msg)

acts = [load(f"campaign/act_{i:02d}.json") for i in range(1, 13)]
chapters = [chapter for act in acts for chapter in act.get("chapters", [])]
chapter_index = {ch.get("id"): ch for ch in chapters}
all_ids = set()
main_lines = {}
core_count = 0
chapter_complete = set()

def add_line(line, where):
    key = line.get("id")
    if not key or key in all_ids:
        errors.append(f"DUPLICATE_OR_EMPTY_ID {key} at {where}")
    all_ids.add(key)
    if not line.get("speaker") or not line.get("text"):
        errors.append(f"EMPTY_LINE {key} at {where}")

check(len(chapters) == 72, f"Expected 72 chapters; got {len(chapters)}")
for number, ch in enumerate(chapters, 1):
    cid = f"ch{number:03d}"
    check(ch.get("id") == cid and ch.get("number") == number, f"Chapter ordering: {cid}")
    predecessor = "story.prologue_done" if number == 1 else f"story.ch{number-1:03d}.done"
    check(ch.get("required_flags") == [predecessor], f"Chapter dependency: {cid}")
    scenes = ch.get("scenes", [])
    check(len(scenes) == (5 if number == 72 else 4), f"Scene layout: {cid}")
    for scene in scenes:
        for line in scene.get("dialogue", []):
            add_line(line, scene.get("id"))
            main_lines[line.get("id")] = line
            core_count += 1
        for eff in scene.get("effects", []):
            if eff.get("type") == "set_flag" and eff.get("key") == f"story.{cid}.done":
                chapter_complete.add(cid)
check(len(chapter_complete) == 72, "Missing chapter completion flags")

prologue = load("campaign/prologue.json")
for scene in prologue.get("scenes", []):
    for line in scene.get("dialogue", []):
        add_line(line, scene.get("id"))

c22 = chapter_index.get("ch022", {})
check("伊泽" not in c22.get("summary", ""), "P0: ch022 summary prematurely names Ize")
c26 = chapter_index.get("ch026", {})
check("第一张失落航页" not in c26.get("summary", ""), "P0: ch026 chapter summary page order")
for scene in c26.get("scenes", []):
    for line in scene.get("dialogue", []):
        check("第一张失落航页" not in line.get("text", ""), "P0: ch026 page-first line")

last = chapter_index.get("ch072", {})
resolve = next((s for s in last.get("scenes", []) if s.get("id") == "ch072.resolve"), {})
ending_scene = next((s for s in last.get("scenes", []) if s.get("id") == "ch072.ending"), {})
check(not any("正篇结束" in line.get("text", "") for line in resolve.get("dialogue", [])),
      "P0: ending message plays before final choice")
check(any(opt.get("sets", {}).get("world.ending") == "C"
          for opt in ending_scene.get("choice", {}).get("options", [])),
      "P0: final choice has no ending C")

qfiles = ["data/side_quests.json", "data/companion_quests.json", "data/regional_quests_v2.json"]
groups = [load(p).get("quests", []) for p in qfiles]
quests = [q for group in groups for q in group]
qidx = {q.get("id"): q for q in quests}
qdialogue = {}
check([len(group) for group in groups] == [36, 48, 36], "Quest category totals")
check(len(qidx) == 120, "Quest IDs not 120 unique")
check(sum(len(q.get("stages", [])) for q in quests) == 516, "Stage total drifted")
pages = [q for q in quests if q.get("type") == "lost_page"]
check(len(pages) == 12 and {q.get("page_number") for q in pages} == set(range(1, 13)),
      "12 lost-page quest numbering")
for q in quests:
    qid = q.get("id")
    stages = q.get("stages", [])
    if q in pages:
        check(len(stages) == 5, f"Outdated lost-page stage length {qid}")
    check(q.get("required_chapter") in chapter_index, f"Quest unlock chapter {qid}")
    for stage in stages:
        for line in stage.get("dialogue", []):
            add_line(line, stage.get("id"))
            qdialogue[line.get("id")] = line
        for opt in stage.get("choice", {}).get("options", []):
            for line in opt.get("branch_dialogue", []):
                add_line(line, stage.get("id"))
                qdialogue[line.get("id")] = line

sources_checked = 0
def inspect_source(obj, where, lookup):
    global sources_checked
    source = obj.get("source_dialogue_id")
    if source:
        sources_checked += 1
        original = lookup.get(source)
        check(original is not None, f"Unresolved source {where}: {source}")
        if original:
            check(original.get("text") == obj.get("text"),
                  f"Source text diverged {where}: {source}")
            if obj.get("speaker"):
                check(original.get("speaker") == obj.get("speaker"),
                      f"Source speaker diverged {where}: {source}")

for range_file in ["1_24", "25_48", "49_72"]:
    for ch in load(f"data/stage07_chapter_objects_{range_file}.json").get("chapters", []):
        check(ch.get("chapter_id") in chapter_index, "Orphan chapter object group")
        for obj in ch.get("objects", []):
            for line in obj.get("after_inspect", []):
                inspect_source(line, obj.get("id"), main_lines)
    for ch in load(f"data/stage07_chapter_npc_states_{range_file}.json").get("chapters", []):
        check(ch.get("id") in chapter_index, "Orphan chapter npc group")
        for obj in ch.get("npc_states", {}).values():
            inspect_source(obj, obj.get("id"), main_lines)

for kind in ["original", "companion", "regional"]:
    pack = load(f"data/stage07_{kind}_quest_interactions.json")
    for record in pack.get("quests", []):
        quest = qidx.get(record.get("quest_id"))
        check(quest is not None, f"Orphan stage07 quest {record.get('quest_id')}")
        stages = {s.get("id") for s in quest.get("stages", [])} if quest else set()
        for obj in record.get("objects", []):
            check(obj.get("linked_stage") in stages, f"Bad interaction stage: {obj.get('id')}")
            inspect_source(obj.get("description_source", {}), obj.get("id"), qdialogue)
        for obj in record.get("npc_states", {}).values():
            inspect_source(obj, obj.get("id"), qdialogue)

deep_count = 0
for num in (1, 2):
    pack = load(f"data/stage07_companion_deepening_{num:02d}.json")
    for record in pack.get("quests", []):
        deep_count += 1
        quest = qidx.get(record.get("quest_id"))
        check(quest is not None, f"Orphan companion deepening {record.get('quest_id')}")
        stage_ids = {s.get("id") for s in quest.get("stages", [])} if quest else set()
        for field in ("insert_before_stage", "insert_after_stage"):
            check(record.get(field) in stage_ids, f"Bad deepening anchor {field}: {record.get('quest_id')}")
        for scene in record.get("scenes", []):
            for line in scene.get("dialogue", []):
                add_line(line, scene.get("id"))
check(deep_count == 16, "Companion deepening coverage not 16")

optional_paths = [
    "data/phase08_act01_town_scenes.json",
    "data/phase08_act01_evidence_scenes.json",
    "data/phase08_act01_choice_reactions.json",
    "data/phase08_act09_optional_scenes.json",
    "data/phase08_act09_choice_reactions.json",
    "data/phase08_act12_optional_scenes.json",
    "data/phase08_act12_choice_reactions.json",
]
optional_scenes = 0
choice_reactions = 0
for path in optional_paths:
    pack = load(path)
    for scene in pack.get("scenes", []):
        optional_scenes += 1
        ch = chapter_index.get(scene.get("chapter_id"), {})
        check(any(sc.get("id") == scene.get("insert_after_scene_id")
                  for sc in ch.get("scenes", [])), f"Missing optional anchor: {scene.get('id')}")
        for line in scene.get("dialogue", []):
            add_line(line, scene.get("id"))
    for reaction in pack.get("followups", []):
        choice_reactions += 1
        ch = chapter_index.get(reaction.get("chapter_id"), {})
        options = [(sc.get("choice", {}).get("id"), op) for sc in ch.get("scenes", [])
                   for op in sc.get("choice", {}).get("options", [])]
        relevant = [op for node, op in options
                    if node == reaction.get("after_choice_id")
                    and op.get("id") == reaction.get("choice_option_id")]
        check(len(relevant) == 1, f"Missing choice response anchor: {reaction.get('id')}")
        if relevant:
            check(all(relevant[0].get("sets", {}).get(k) == v
                      for k, v in reaction.get("condition", {}).items()),
                  f"Wrong choice condition: {reaction.get('id')}")
        for line in reaction.get("dialogue", []):
            add_line(line, reaction.get("id"))
check(optional_scenes == 36 and choice_reactions == 39,
      f"Stage 8 extras drift: {optional_scenes}/{choice_reactions}")

page_reactions = load("data/v21_ch026_page_reactions.json")
check(len(page_reactions.get("variants", [])) == 2, "Missing ch026 page-state variants")
for variant in page_reactions.get("variants", []):
    for line in variant.get("dialogue", []):
        add_line(line, variant.get("id"))

ending_pack = load("data/endings.json")
endings = {e.get("id"): e for e in ending_pack.get("endings", [])}
check(set(endings) == {"A", "B", "C"}, "Endings A/B/C not present")
required_c = ["story.ch072.done", "ch071.battle_won",
              "world.all_twelve_pages", "world.distributed_network", "world.seven_lanterns"]
check(endings.get("C", {}).get("requirements") == required_c, "Ending C requirements drift")
check(endings.get("C", {}).get("regional_cooperation_contract", {}).get("not_additional_runtime_gate") is True,
      "Ending C cooperation interpretation missing")
bosses = load("data/bosses.json").get("bosses", [])
check(len(bosses) == 66, "Boss count drift")
boss = next((b for b in bosses if b.get("id") == "boss.ch071"), {})
check(len(boss.get("phase_design", [])) == 2 and len(boss.get("narrative_lanes", [])) == 3,
      "Hesian 3 ideology / 2 battle phases mapping invalid")

journal = load("data/quest_journal.json")
entry = next((c for c in journal.get("chapters", []) if c.get("id") == "ch026"), {})
check("第一张失落航页" not in entry.get("log_after", ""), "Chapter 26 journal still implies first page")
check(len(journal.get("chapters", [])) == 72, "Quest journal chapter count")

print(f"Chapters={len(chapters)} MainDialogue={core_count} Quests={len(quests)}")
print(f"OriginalReferences={sources_checked} OptionalScenes={optional_scenes} "
      f"ChoiceReactions={choice_reactions} DeepenedQuests={deep_count}")
print(f"AllDialogueIDs={len(all_ids)} Errors={len(errors)}")
if warnings:
    print("Warnings:", *warnings, sep="\n - ")
if errors:
    print("FAIL:", *errors, sep="\n - ")
    raise SystemExit(1)
print("PASS: V2.1 offline narrative structure and cross-references (NOT runtime/playtest)")
