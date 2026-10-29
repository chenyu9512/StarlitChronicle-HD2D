#!/usr/bin/env python3
"""Validate chapter 1-12 phase 9 writing and production-design asset contracts.

Runs offline. DOES NOT verify Godot event registration or map coordinates.
"""
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent / "story"
errors = []

def load(relative):
    path = ROOT / relative
    try:
        return json.loads(path.read_text(encoding="utf-8"))
    except (OSError, ValueError) as exc:
        errors.append(f"Cannot read {relative}: {exc}")
        return {}

def expect(test, why):
    if not test:
        errors.append(why)

act1 = load("campaign/act_01.json")
act2 = load("campaign/act_02.json")
chapters = {ch["id"]: ch for act in (act1, act2) for ch in act.get("chapters", [])}
expect(len(chapters) == 12, "Opening story must contain twelve chapters")
expect(len(act2.get("chapters", [])) == 6, "Act II missing chapters")
expect(act2.get("phase9_revision", {}).get("added_lines") == 120, "Act II phase 9 count mismatched")

all_main = {}
for ch in chapters.values():
    for scene in ch.get("scenes", []):
        for line in scene.get("dialogue", []):
            key = line.get("id", "")
            expect(bool(key) and key not in all_main, "Repeated/empty main ID " + key)
            all_main[key] = line

for ch in act2.get("chapters", []):
    phases = {s["id"].split(".")[-1] for s in ch.get("scenes", [])}
    expect(phases == {"opening", "investigate", "crisis", "resolve"},
           "Act II main four-stage shape lost: " + ch["id"])
    for scene in ch["scenes"]:
        extra = [d for d in scene.get("dialogue", []) if ".p9." in d["id"]]
        expect(len(extra) == 5, "Expected 5 new lines in " + scene["id"])
        expect(bool(scene.get("direction", {}).get("phase9_director_focus")),
               "Missing phase 9 blocking note: " + scene["id"])

ch9 = chapters["ch009"]
line = next((d for s in ch9["scenes"] for d in s.get("dialogue", [])
             if d["id"] == "ch009.crisis.l07"), {})
expect("已经安全抵达" not in line.get("text", ""),
       "Witness protection prematurely completed before player choice")

optional = [
    *load("data/phase08_act01_town_scenes.json").get("scenes", []),
    *load("data/phase08_act01_evidence_scenes.json").get("scenes", []),
    *load("data/phase09_act02_optional_scenes.json").get("scenes", []),
]
choices = [
    *load("data/phase08_act01_choice_reactions.json").get("followups", []),
    *load("data/phase09_act02_choice_reactions.json").get("followups", []),
]
plan = load("data/phase09_opening_event_plan.json")
events = plan.get("event_plan", [])
reactions = plan.get("choice_reaction_plan", [])
expect(len(optional) == len(events) == 24, "Opening optional event count must be 24")
expect(len(choices) == len(reactions) == 24, "Opening choice variant count must be 24")
optional_ids = {scene.get("id") for scene in optional}
choice_ids = {r.get("id") for r in choices}
expect({e.get("id") for e in events} == optional_ids, "Event plan must cover every optional scene")
expect({x.get("id") for x in reactions} == choice_ids, "Event plan must cover every choice response")
all_optional_lines = set()

for scene in optional:
    chapter = chapters.get(scene.get("chapter_id"), {})
    source = chapter.get("scenes", [])
    expect(any(x.get("id") == scene.get("insert_after_scene_id") for x in source),
           "Orphan optional anchor " + str(scene.get("id")))
    expect(scene.get("status") != "runtime_bound", "Optional asset incorrectly marked playable")
    for line in scene.get("dialogue", []):
        key = line.get("id", "")
        expect(bool(key) and key not in all_main and key not in all_optional_lines,
               "Duplicate optional line " + key)
        all_optional_lines.add(key)

for reaction in choices:
    chapter = chapters.get(reaction.get("chapter_id"), {})
    candidates = [o for s in chapter.get("scenes", [])
                  if s.get("choice", {}).get("id") == reaction.get("after_choice_id")
                  for o in s["choice"].get("options", [])
                  if o["id"] == reaction.get("choice_option_id")]
    expect(len(candidates) == 1, "Missing choice option " + str(reaction.get("id")))
    if candidates:
        expect(all(candidates[0].get("sets", {}).get(key) == value
                   for key, value in reaction.get("condition", {}).items()),
               "Choice condition drift " + str(reaction.get("id")))
    for line in reaction.get("dialogue", []):
        key = line.get("id", "")
        expect(bool(key) and key not in all_main and key not in all_optional_lines,
               "Duplicate choice reaction line " + key)
        all_optional_lines.add(key)

for event in events:
    chapter = chapters.get(event.get("chapter_id"), {})
    trigger = event.get("trigger_contract", {})
    expect(bool(event.get("player_actions")) and bool(event.get("physical_target")),
           "Missing player behavior " + str(event.get("id")))
    expect(trigger.get("once_only") and trigger.get("skippable"),
           "Optional event cannot be mandatory " + str(event.get("id")))
    expect(event.get("production", {}).get("runtime_registered") is False,
           "Do not mark event runnable before Godot implementation " + str(event.get("id")))
    expect(any(s.get("id") == trigger.get("after_scene_id")
               for s in chapter.get("scenes", [])),
           "Bad production plan anchor " + str(event.get("id")))
    expected_flag = event.get("chapter_id") + (
        ".started" if event.get("entry_stage") == "between_opening_and_investigate"
        else ".evidence")
    expect(expected_flag in trigger.get("required_flags", []),
           "Bad optional production trigger " + str(event.get("id")))

for item in reactions:
    expect(item.get("runtime_registered") is False,
           "Choice response must not claim runtime integration: " + str(item.get("id")))

expect(plan.get("status") == "production_design_only_not_runtime_bound",
       "Production design status unexpectedly marked playable")
full = (ROOT / "screenplay/act_02_phase09_full.md").read_text(encoding="utf-8")
for line in (line for ch in act2["chapters"] for s in ch["scenes"] for line in s["dialogue"]):
    expect(line.get("text", "") in full, "Reading manuscript diverged: " + line["id"])
index = (ROOT / "SCREENPLAY_CURRENT_INDEX.md").read_text(encoding="utf-8")
expect("act_02_phase09_full.md" in index, "Current screenplay index missing phase 9")

print(f"Main12={len(all_main)} ActII={sum(len(s['dialogue']) for ch in act2['chapters'] for s in ch['scenes'])}"
      f" OptionalEvents={len(optional)} ChoiceVariants={len(choices)}"
      f" OptionalLines={len(all_optional_lines)}")
if errors:
    print("FAIL: " + str(len(errors)) + " phase 9 issues")
    for error in errors:
        print(" - " + error)
    raise SystemExit(1)
print("PASS: phase 9 source/anchor/choice/manuscript structure (not Godot runtime)")
