#!/usr/bin/env python3
"""Act IV (19-24) static narrative validation.
Run: python tools/validate_phase11_memories.py
Does not simulate Godot or guarantee scene staging is connected.
"""
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1] / "story"
problems = []

def load(rel):
    return json.loads((ROOT / rel).read_text(encoding="utf-8"))

def require(cond, msg):
    if not cond:
        problems.append(msg)

act = load("campaign/act_04.json")
chapters = act["chapters"]
require([x["id"] for x in chapters] == [f"ch{i:03}" for i in range(19, 25)], "chapter order")
require(act.get("phase11_revision", {}).get("new_lines") == 120, "new lines count")
main_ids = set()
all_main = []
era_map = {"ch019": "ten_years_ago", "ch020": "seven_years_ago", "ch021": "ten_years_ago_childhood"}
for c in chapters:
    cid = c["id"]
    scenes = c.get("scenes", [])
    require(len(scenes) == 4, "original four scenes lost: " + cid)
    require(c.get("phase11_revision", {}).get("new_lines") == 20, "chapter new lines: " + cid)
    require(c["required_flags"] == [f"story.ch{c['number']-1:03}.done"], "chapter entry: " + cid)
    require([s["id"] for s in scenes] == [f"{cid}.{phase}" for phase in
             ("opening", "investigate", "crisis", "resolve")], "scene order: " + cid)
    for scene in scenes:
        sid = scene["id"]
        added = [x for x in scene["dialogue"] if ".p11." in x["id"]]
        require(len(added) == 5, "exactly five new dialogue lines: " + sid)
        require(bool(scene.get("direction", {}).get("phase11_history_contract")),
                "missing temporal direction " + sid)
        for d in scene["dialogue"]:
            key = d.get("id", "")
            require(key and key not in main_ids, "duplicate or empty main ID: " + key)
            require(bool(d.get("speaker") and d.get("text")), "empty main text: " + key)
            main_ids.add(key)
            all_main.append(d)
    require(any(e.get("type") == "set_flag" and e.get("key") == f"story.{cid}.done"
                for e in scenes[-1].get("effects", [])), "chapter done missing: " + cid)
    opts = scenes[2].get("choice", {}).get("options", [])
    require(len(opts) == 2 and {o.get("id") for o in opts} == {"listen", "act"},
            "existing choice damaged: " + cid)

require(len(all_main) == 310, "Act IV must have 310 main dialogue lines")
ch21 = chapters[2]
switch_scene = ch21["scenes"][2]
require("回到现世" in switch_scene.get("direction", {}).get("phase11_player_time_transition", ""),
        "ch021 present choice transition missing")
require("十年后的营火" in switch_scene["dialogue"][-1]["text"],
        "ch021 memory transition must be the final spoken line before choice")
require(ch21["scenes"][3]["dialogue"][0]["speaker"] == "旁白",
        "ch021 resolve present-day camp scene changed")
for c in chapters[:2]:
    for scene in c["scenes"][:3]:
        for d in scene["dialogue"]:
            require(d["speaker"] not in ("现在的雷索", "现在的朔弦", "成年主角", "主角",
                                         "岚音", "缇珐", "伊泽", "玄璃", "诺依", "维莎"),
                    "present-day speaker in historic action: " + d["id"])
for c in chapters[3:]:
    for scene in c["scenes"]:
        for d in scene["dialogue"]:
            require(d["speaker"] not in ("伊泽", "维莎"),
                    "premature party appearance in act IV " + d["id"])
require("伊泽" not in chapters[3]["summary"], "Ize mentioned as performer in ch022")
require(any("维莎" in d["text"] for sc in chapters[4]["scenes"] for d in sc["dialogue"]),
        "Visha manuscript clue disappeared")

optional = load("data/phase11_act04_optional_scenes.json")
reactions = load("data/phase11_act04_choice_reactions.json")
plan = load("data/phase11_act04_production_plan.json")
require(optional.get("status") == "text_only_not_runtime_bound", "optional falsely playable")
require(reactions.get("status") == "text_only_not_runtime_bound", "reactions falsely playable")
require(plan.get("status") == "production_design_only_not_runtime_bound", "plan falsely playable")
require(len(optional["scenes"]) == 12 and len(reactions["followups"]) == 12,
        "optional and response scene counts")
require(len(plan["event_plan"]) == 12 and len(plan["choice_reaction_plan"]) == 12,
        "planned event and response counts")

by_id = {c["id"]: c for c in chapters}
extra_ids = set()
for sc in optional["scenes"]:
    cid, kind = sc["chapter_id"], sc["kind"]
    chapter = by_id[cid]
    require(sc["insert_after_scene_id"] in {s["id"] for s in chapter["scenes"]},
            "orphan optional anchor " + sc["id"])
    require(sc["required_flags"] == [cid + ("." + ("started" if kind == "town" else "evidence"))],
            "wrong optional flag " + sc["id"])
    require(sc["time_layer"] == era_map.get(cid, "present_day"), "incorrect time layer " + sc["id"])
    require(len(sc["dialogue"]) == 6, "expected six optional lines " + sc["id"])
    for d in sc["dialogue"]:
        require(d["id"] not in main_ids and d["id"] not in extra_ids,
                "duplicate optional ID " + d["id"])
        extra_ids.add(d["id"])
for rec in reactions["followups"]:
    c = by_id[rec["chapter_id"]]
    matching = [o for scene in c["scenes"] for o in scene.get("choice", {}).get("options", [])
                if scene.get("choice", {}).get("id") == rec["after_choice_id"] and
                o["id"] == rec["choice_option_id"]]
    require(len(matching) == 1, "orphan choice " + rec["id"])
    if matching:
        require(rec["condition"] == matching[0]["sets"], "wrong choice condition " + rec["id"])
    correct_layer = ("ten_years_ago" if rec["chapter_id"] == "ch019" else
                     "seven_years_ago" if rec["chapter_id"] == "ch020" else "present_day")
    require(rec["time_layer"] == correct_layer, "choice time layer " + rec["id"])
    require(len(rec["dialogue"]) == 3, "expected three response lines " + rec["id"])
    for d in rec["dialogue"]:
        require(d["id"] not in main_ids and d["id"] not in extra_ids,
                "duplicate response ID " + d["id"])
        extra_ids.add(d["id"])
require(len(extra_ids) == 108, "expected 108 extra lines")
require({e["id"] for e in plan["event_plan"]} == {s["id"] for s in optional["scenes"]},
        "plan doesn't cover optional scenes")
require({e["id"] for e in plan["choice_reaction_plan"]} == {s["id"] for s in reactions["followups"]},
        "plan doesn't cover reactions")
for event in plan["event_plan"]:
    require(event["production"]["runtime_registered"] is False, "event wrongly runnable " + event["id"])
    require(len(event["player_actions"]) == 3 and
            event["trigger_contract"]["once_only"] and event["trigger_contract"]["skippable"],
            "event planning incomplete " + event["id"])
for rec in plan["choice_reaction_plan"]:
    require(rec["runtime_registered"] is False, "reaction wrongly runnable " + rec["id"])
reading = (ROOT / "screenplay/act_04_phase11_full.md").read_text(encoding="utf-8")
for d in all_main:
    require(d["text"] in reading, "reading script missing " + d["id"])
index = (ROOT / "SCREENPLAY_CURRENT_INDEX.md").read_text(encoding="utf-8")
require("act_04_phase11_full.md" in index, "current manuscript not indexed")

print(f"Chapters={len(chapters)} MainLines={len(all_main)} "
      f"OptionalScenes={len(optional['scenes'])} Reactions={len(reactions['followups'])} "
      f"NewOptionalLines={len(extra_ids)} Errors={len(problems)}")
if problems:
    print("FAIL: phase11 static narrative validation", *problems, sep="\n - ")
    raise SystemExit(1)
print("PASS: phase11 static cross-file contracts only (NOT Godot runtime)")
