#!/usr/bin/env python3
"""Validate the Starlit Chronicle story pack without Godot. Run from repository root."""
import json
from pathlib import Path
from collections import Counter
import re

ROOT = Path(__file__).resolve().parent.parent
STORY = ROOT / "story"
errors = []
total_scenes = 0
dialogue_ids = set()
chapters = []


def load(relative):
    path = STORY / relative
    if not path.exists():
        errors.append(f"Missing: {relative}")
        return {}
    try:
        data = json.loads(path.read_text(encoding="utf-8"))
        if not isinstance(data, dict):
            errors.append(f"Top-level not object: {relative}")
            return {}
        return data
    except (ValueError, UnicodeError) as exc:
        errors.append(f"Unreadable {relative}: {exc}")
        return {}


def check_dialogues(scenes, context):
    global total_scenes
    for scene in scenes:
        total_scenes += 1
        lines = scene.get("dialogue", [])
        if not isinstance(lines, list) or len(lines) < 3:
            errors.append(f"Too few lines: {context}/{scene.get('id')}")
            continue
        for line in lines:
            text = str(line.get("text", "")).strip()
            key = str(line.get("id", "")).strip()
            if not key or key in dialogue_ids or not text or not line.get("speaker"):
                errors.append(f"Bad dialogue {context}: {key}")
            dialogue_ids.add(key)


prologue = load("campaign/prologue.json")
check_dialogues(prologue.get("scenes", []), "prologue")
if len(prologue.get("scenes", [])) != 9:
    errors.append("Prologue must have nine scenes")
if prologue.get("finish_flag") != "story.prologue_done":
    errors.append("Prologue unlock does not match chapter 1")

for act in range(1, 13):
    data = load(f"campaign/act_{act:02d}.json")
    entries = data.get("chapters", [])
    if len(entries) != 6:
        errors.append(f"Act {act} must contain six chapters")
    for ch in entries:
        index = len(chapters) + 1
        cid = f"ch{index:03d}"
        if ch.get("id") != cid or ch.get("number") != index or ch.get("act") != act:
            errors.append(f"Chapter numbering mismatch: {cid}")
        flags = ch.get("required_flags", [])
        previous = "story.prologue_done" if index == 1 else f"story.ch{index-1:03d}.done"
        if flags != [previous]:
            errors.append(f"Wrong predecessor for {cid}: {flags}")
        scenes = ch.get("scenes", [])
        if len(scenes) != (5 if index == 72 else 4):
            errors.append(f"Scene count mismatch: {cid}")
        if re.fullmatch(r"scripted_blocking_v[1-9][0-9]*(?:_phase[1-9][0-9]*_[a-z0-9_]+)?", str(ch.get("production_status", ""))) is None:
            errors.append(f"Unrecognized content stage: {cid}")
        ids = [sc.get("id") for sc in scenes]
        if len(set(ids)) != len(ids):
            errors.append(f"Repeated scene ID: {cid}")
        for sc in scenes:
            if sc.get("encounter"):
                encounter = sc["encounter"]
                if not encounter.get("win_flag") or not encounter.get("enemy_id"):
                    errors.append(f"Bad boss trigger: {cid}")
        check_dialogues(scenes, cid)
        chapters.append(ch)

if len(chapters) != 72:
    errors.append(f"Expected 72 chapters, got {len(chapters)}")
if total_scenes != 298:  # 289 main + 9 prologue
    errors.append(f"Expected 298 scenes, got {total_scenes}")

side = load("data/side_quests.json")
quests = side.get("quests", [])
if len(quests) != 36 or len({q.get("id") for q in quests}) != 36:
    errors.append("Expected 36 unique side quests")
for q in quests:
    expected = 5 if q.get("type") in ("lost_page", "regional") else 3
    if len(q.get("stages", [])) != expected:
        errors.append(f"Side quest needs {expected} stages: {q.get('id')}")
pages = [q for q in quests if q.get("type") == "lost_page"]
if len(pages) != 12 or set(q.get("page_number") for q in pages) != set(range(1, 13)):
    errors.append("Expected all twelve lost page quests")
goal = side.get("global_milestone", {})
if len(goal.get("requires_flags", [])) != 12:
    errors.append("Lost pages completion aggregate is incomplete")

jobs = load("data/jobs.json").get("jobs", [])
if len(jobs) != 20 or len({j.get("id") for j in jobs}) != 20:
    errors.append("Expected 20 unique classes")
ends = load("data/endings.json").get("endings", [])
if set(e.get("id") for e in ends) != {"A", "B", "C"}:
    errors.append("Expected endings A/B/C")
ui = load("data/ui_zh_CN.json")
for key in ("buttons", "battle", "system", "tutorial"):
    if not ui.get(key):
        errors.append(f"Missing UI category: {key}")
load("data/npc_barks.json")

print(f"Chapters: {len(chapters)} | Acts: 12 | Scenes: {total_scenes} | Dialogue IDs: {len(dialogue_ids)}")
print(f"Side quests: {len(quests)} | Lost pages: {len(pages)} | Jobs: {len(jobs)} | Endings: {len(ends)}")
if errors:
    print("FAILED with", len(errors), "issues:")
    for item in errors:
        print(" -", item)
    raise SystemExit(1)
print("PASS: story pack structural validation")
