#!/usr/bin/env python3
"""Offline progression smoke test for the full story pack.

Validates that the *data* can advance through 72 chapters with mandatory
dependencies. Does NOT replace Godot editor, runtime, battle or iPhone testing.
"""
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent / "story"
problems = []

def load(path):
    return json.loads((ROOT / path).read_text(encoding="utf-8"))

acts = [load(f"campaign/act_{i:02d}.json") for i in range(1, 13)]
chapters = [ch for act in acts for ch in act["chapters"]]
prologue = load("campaign/prologue.json")
side = load("data/side_quests.json")
endings = load("data/endings.json")
jobs = load("data/jobs.json")
journal = load("data/quest_journal.json")
bosses = load("data/bosses.json")

def require(ok, message):
    if not ok:
        problems.append(message)

flags = {}
lines = []
targets = []
all_scene_ids = set()
for scene in prologue["scenes"]:
    all_scene_ids.add(scene["id"])
    for effect in scene.get("effects", []):
        if effect.get("type") == "set_flag":
            flags[effect["key"]] = effect.get("value", True)
require(flags.get("story.prologue_done", False), "Prologue did not unlock chapter 1")
require(len(chapters) == 72, "Wrong chapter count")

boss_by_id = {item["id"]: item for item in bosses["bosses"]}
for idx, chapter in enumerate(chapters, 1):
    cid = f"ch{idx:03d}"
    require(chapter["id"] == cid, f"Bad chapter order: {cid}")
    require(all(flags.get(key) for key in chapter["required_flags"]), f"Chapter locked: {cid}")
    for scene in chapter["scenes"]:
        sid = scene["id"]
        require(sid not in all_scene_ids, f"Duplicate scene: {sid}")
        all_scene_ids.add(sid)
        trigger = scene.get("trigger", {})
        require(all(flags.get(key) for key in trigger.get("requires_flags", [])), f"Scene locked: {sid}")
        for line in scene.get("dialogue", []):
            lines.append(line["id"])
            require(bool(line.get("speaker") and line.get("text")), f"Empty line in {sid}")
        for objective in scene.get("objectives", []):
            targets.append(objective["target"])
        choice = scene.get("choice")
        if choice:
            require(bool(choice.get("options")), f"Empty choice: {sid}")
            for opt in choice.get("options", []):
                require(opt.get("id") is not None, f"No choice ID: {sid}")
        battle = scene.get("encounter")
        if battle:
            require(battle["enemy_id"] in boss_by_id, f"Unknown boss: {sid}")
            flags[battle["win_flag"]] = True
            if battle["win_flag"] == "ch071.battle_won":
                flags["boss.ch071.won"] = True
        for effect in scene.get("effects", []):
            if effect.get("type") == "set_flag":
                flags[effect["key"]] = effect.get("value", True)
            if effect.get("type") == "time_skip":
                flags["world.years_passed"] = flags.get("world.years_passed", 0) + int(effect.get("years", 0))
        if idx == 72 and sid.endswith(".ending"):
            # Check C remains locked without lossless side quest restoration.
            opts = {opt["id"]: opt for opt in choice["options"]}
            require(all(flags.get(k) for k in opts["keep"].get("requires_flags", [])), "Ending A locked")
            require(all(flags.get(k) for k in opts["release"].get("requires_flags", [])), "Ending B locked")
            require(not all(flags.get(k) for k in opts["share"].get("requires_flags", [])), "Ending C opened without all lost pages")
    if idx == 60:
        flags["world.distributed_network"] = True
    if idx == 66:
        flags["world.seven_lanterns"] = True
    require(flags.get(f"story.{cid}.done", False), f"Missing completion flag: {cid}")

lost_page_quests = [q for q in side["quests"] if q.get("type") == "lost_page"]
require(len(lost_page_quests) == 12, "Wrong page quest count")
for quest in lost_page_quests:
    require(len(quest.get("stages", [])) == 3, "Incomplete side quest: " + quest["id"])
    chapter = quest["required_chapter"]
    require(flags.get("story." + chapter + ".done", False), "Side quest unlocked too early: " + quest["id"])
    flags[f"world.page_{quest['page_number']:02d}"] = True
    flags[quest["completion_flag"]] = True
flags["world.all_twelve_pages"] = all(flags.get(f"world.page_{i:02d}", False) for i in range(1,13))

require(flags.get("world.years_passed") == 12, "Time skip should total 12 years")
require(len(lines) == len(set(lines)), "Dialogue IDs are not unique")
require(len(journal["chapters"]) == 72, "Quest journal does not cover all chapters")
require(len(jobs["jobs"]) == 20, "Jobs data out of sync")
for ending in endings["endings"]:
    require(all(flags.get(f, False) for f in ending["requirements"]), f"Ending cannot unlock: {ending['id']}")
    require(bool(ending.get("epilogue")), f"Missing epilogue: {ending['id']}")

for cid in range(1, 7):
    chapter = chapters[cid-1]
    for scene in chapter["scenes"]:
        require(len(scene["dialogue"]) >= 7, f"Act I dialogue too short: {scene['id']}")
        require(scene.get("direction") is not None, f"Missing camera direction: {scene['id']}")

print(f"Acts=12 Chapters={len(chapters)} Scenes={len(all_scene_ids)} Dialogues={len(lines)}")
print(f"Main quest journal={len(journal['chapters'])} Side quests={len(side['quests'])} Boss templates={len(bosses['bosses'])} Jobs={len(jobs['jobs'])}")
print(f"Time skip={flags.get('world.years_passed')} years, endings unlocked={','.join(x['id'] for x in endings['endings'])}")
if problems:
    print(f"FAIL: {len(problems)} problems")
    for item in problems:
        print(" -", item)
    raise SystemExit(1)
print("PASS: offline story progression and requirements")
