#!/usr/bin/env python3
"""Phase 10: Red Furnace narrative/production-plan static validation.
Run in repository root: python tools/validate_phase10_red_furnace.py
Data checks only; no Godot simulation or map registration.
"""
import json
from pathlib import Path

root = Path(__file__).resolve().parents[1] / "story"
errors = []

def read(path):
    return json.loads((root / path).read_text(encoding="utf-8"))

def need(cond, desc):
    if not cond:
        errors.append(desc)

a = read("campaign/act_03.json")
chapters = a["chapters"]
need([c["id"] for c in chapters] == [f"ch{i:03}" for i in range(13, 19)], "chapter IDs/order")
need(a["phase10_revision"]["new_lines"] == 120, "phase10 revision total")
need(len(chapters) == 6, "chapter total")
lines = set()
total = 0
for chapter in chapters:
    cid = chapter["id"]
    need(len(chapter["scenes"]) == 4, cid + ": altered scene topology")
    need(chapter["phase10_revision"]["new_lines"] == 20, cid + ": new line total")
    prior = f"story.ch{chapter['number'] - 1:03}.done"
    need(chapter["required_flags"] == [prior], cid + ": changed prior flag")
    scene_ids = [scene["id"] for scene in chapter["scenes"]]
    need(scene_ids == [f"{cid}.{s}" for s in ("opening", "investigate", "crisis", "resolve")],
         cid + ": scene order mismatch")
    for scene in chapter["scenes"]:
        sid = scene["id"]
        newlines = [d for d in scene["dialogue"] if ".p10." in d["id"]]
        need(len(newlines) == 5, sid + ": expected five inserted phase10 lines")
        need(bool(scene.get("direction", {}).get("phase10_editorial_focus")),
             sid + ": no direction")
        for d in scene["dialogue"]:
            total += 1
            need(d["id"] not in lines, "duplicate mainline ID " + d["id"])
            lines.add(d["id"])
            need(bool(d.get("speaker")) and bool(d.get("text")), "empty mainline text " + d["id"])
    effects = chapter["scenes"][-1]["effects"]
    need(any(e.get("type") == "set_flag" and e.get("key") == f"story.{cid}.done"
             for e in effects), cid + ": completion changed")
    options = chapter["scenes"][2].get("choice", {}).get("options", [])
    need(len(options) == 2 and {x["id"] for x in options} == {"listen", "act"},
         cid + ": choice options changed")

need(total == 317, "expected 317 mainline lines")

pack = read("data/phase10_act03_optional_scenes.json")
choice = read("data/phase10_act03_choice_reactions.json")
plan = read("data/phase10_act03_production_plan.json")
jobs = read("data/jobs.json")["jobs"]
need(pack["status"] == "text_only_not_runtime_bound", "optional pack falsely runtime-bound")
need(choice["status"] == "text_only_not_runtime_bound", "choices falsely runtime-bound")
need(plan["status"] == "production_design_only_not_runtime_bound", "plan falsely runtime-bound")
need(len(pack["scenes"]) == 12, "expected 12 optional scenes")
need(len(choice["followups"]) == 12, "expected 12 A/B reactions")
need(len(plan["event_plan"]) == 12, "expected 12 event action plans")
need(len(plan["choice_reaction_plan"]) == 12, "expected 12 reaction plans")
all_extra_ids = set()
for sc in pack["scenes"]:
    ch = next((c for c in chapters if c["id"] == sc["chapter_id"]), None)
    need(ch is not None, "orphan optional scene " + sc["id"])
    if ch:
        need(sc["insert_after_scene_id"] in {s["id"] for s in ch["scenes"]},
             "missing scene insertion anchor: " + sc["id"])
        expected = sc["chapter_id"] + ("." + ("started" if sc["kind"] == "town" else "evidence"))
        need(sc["required_flags"] == [expected], "optional required flag: " + sc["id"])
    need(len(sc["dialogue"]) == 6, "optional lines count " + sc["id"])
    for d in sc["dialogue"]:
        need(d["id"] not in lines and d["id"] not in all_extra_ids, "extra duplicate " + d["id"])
        all_extra_ids.add(d["id"])
for item in choice["followups"]:
    ch = next((c for c in chapters if c["id"] == item["chapter_id"]), None)
    matches = [o for s in (ch or {}).get("scenes", [])
               if s.get("choice", {}).get("id") == item["after_choice_id"]
               for o in s["choice"]["options"] if o["id"] == item["choice_option_id"]]
    need(len(matches) == 1, "orphan choice reaction " + item["id"])
    if matches:
        need(matches[0]["sets"] == item["condition"], "choice predicate mismatch: " + item["id"])
    need(len(item["dialogue"]) == 3, "choice response lines " + item["id"])
    for d in item["dialogue"]:
        need(d["id"] not in lines and d["id"] not in all_extra_ids, "extra duplicate " + d["id"])
        all_extra_ids.add(d["id"])

eventids = {e["id"] for e in plan["event_plan"]}
need(eventids == {sc["id"] for sc in pack["scenes"]}, "event plan incomplete")
need({x["id"] for x in plan["choice_reaction_plan"]}
     == {x["id"] for x in choice["followups"]}, "reaction plan incomplete")
for e in plan["event_plan"]:
    need(bool(e["player_actions"]) and len(e["player_actions"]) >= 3, "no gameplay action " + e["id"])
    need(e["trigger_contract"]["once_only"] and e["trigger_contract"]["skippable"],
         "event forced mandatory " + e["id"])
    need(e["production"]["runtime_registered"] is False, "claimed gameplay event " + e["id"])
for item in plan["choice_reaction_plan"]:
    need(item["runtime_registered"] is False, "claimed playable choice " + item["id"])

setpieces = plan["major_setpiece_design"]
trial = setpieces["ch015_eight_class_trials"]["base_jobs"]
need(len(trial) == 8, "expected eight base-class trials")
need([x["id"] for x in trial] == [x["id"] for x in jobs[:8]],
     "trial job IDs not aligned with jobs.json")
valves = setpieces["ch017_four_valves"]["valves"]
need(len(valves) == 4 and {x["id"] for x in valves}
     == {"weapon", "defense", "medical", "civilian"}, "incorrect valve roles")

reading = (root / "screenplay/act_03_phase10_full.md").read_text(encoding="utf-8")
for chapter in chapters:
    for scene in chapter["scenes"]:
        for line in scene["dialogue"]:
            need(line["text"] in reading, "reading manuscript missing " + line["id"])
index = (root / "SCREENPLAY_CURRENT_INDEX.md").read_text(encoding="utf-8")
need("act_03_phase10_full.md" in index, "current screenplay index not updated")
print(f"RedFurnaceChapters={len(chapters)} MainLines={total} IndependentLines={len(all_extra_ids)} "
      f"Scenes={len(pack['scenes'])} Reactions={len(choice['followups'])}")
if errors:
    print("FAIL: static act III validation", *errors, sep="\n- ")
    raise SystemExit(1)
print("PASS: static narrative/choice/production contracts (NOT runtime or playtest)")
