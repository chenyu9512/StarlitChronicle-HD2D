#!/usr/bin/env python3
"""Fail-fast offline release gate. No Godot, account, network, or extra pip dependencies.

This catches malformed empty GDScript suites and broken content contracts before
expensive scene imports. It is NOT a substitute for the Godot parser or playtests.
"""
from __future__ import annotations

import argparse
import json
import re
import sys
from collections import Counter
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
HEADER = re.compile(r"^\s*(?:static\s+func\s|func\s|if\s|elif\s|else\s*:|for\s|while\s|match\s|class\s)")
PRELOAD = re.compile(r'preload\(\s*["\']res://([^"\']+)["\']\s*\)')
SCENE_REF = re.compile(r'^\[ext_resource\s+type="[^"]+"\s+path="res://([^"]+)"', re.MULTILINE)
FUNC = re.compile(r"^func\s+(\w+)\s*\(", re.MULTILINE)


def validate() -> tuple[list[str], dict]:
    problems: list[str] = []
    metrics: dict = {}
    scripts = sorted((ROOT / "scripts").glob("*.gd"))
    tests = sorted((ROOT / "tools").glob("*.gd"))
    scenes = sorted((ROOT / "scenes").glob("*.tscn"))
    metrics["gd_scripts"] = len(scripts)
    metrics["gd_test_scripts"] = len(tests)
    metrics["scenes"] = len(scenes)
    if not scripts or not scenes:
        problems.append("Godot script or scene directory is empty")
    for path in scripts + tests:
        lines = path.read_text(encoding="utf-8-sig").splitlines()
        found: list[str] = []
        for n, line in enumerate(lines):
            match = FUNC.match(line)
            if match:
                found.append(match.group(1))
            if not HEADER.match(line) or not line.rstrip().endswith(":"):
                continue
            indent = len(line) - len(line.lstrip(" \t"))
            next_line = n + 1
            while next_line < len(lines) and (
                not lines[next_line].strip() or lines[next_line].lstrip().startswith("#")
            ):
                next_line += 1
            if next_line >= len(lines):
                problems.append(f"{path.relative_to(ROOT)}:{n + 1}: empty block at EOF")
                continue
            following = lines[next_line]
            following_indent = len(following) - len(following.lstrip(" \t"))
            if following_indent <= indent:
                problems.append(
                    f"{path.relative_to(ROOT)}:{n + 1}: empty block before line {next_line + 1}"
                )
        for name, count in Counter(found).items():
            if count > 1:
                problems.append(f"{path.relative_to(ROOT)}: duplicate top-level func {name}")
        for target in PRELOAD.findall("\n".join(lines)):
            if not (ROOT / target).is_file():
                problems.append(f"{path.relative_to(ROOT)}: missing preload res://{target}")
    for scene in scenes:
        for target in SCENE_REF.findall(scene.read_text(encoding="utf-8-sig")):
            if not (ROOT / target).is_file():
                problems.append(f"{scene.relative_to(ROOT)}: missing resource res://{target}")

    def read(path: str):
        file = ROOT / path
        try:
            return json.loads(file.read_text(encoding="utf-8-sig"))
        except (OSError, ValueError) as exc:
            problems.append(f"{path}: invalid or missing JSON ({exc})")
            return {}

    chapters = [item for act in range(1, 13)
                for item in read(f"story/campaign/act_{act:02d}.json").get("chapters", [])]
    metrics["chapters"] = len(chapters)
    metrics["main_scenes"] = sum(len(ch.get("scenes", [])) for ch in chapters)
    if len(chapters) != 72 or [c.get("number") for c in chapters] != list(range(1, 73)):
        problems.append("Main campaign chapter IDs are not a contiguous 1..72")
    if metrics["main_scenes"] != 289:
        problems.append(f"Main scene count changed: {metrics['main_scenes']} (expected 289)")
    quest_files = ["story/data/side_quests.json",
                   "story/data/regional_quests_v2.json",
                   "story/data/companion_quests.json"]
    quests = [q for file in quest_files for q in read(file).get("quests", [])]
    ids = [str(q.get("id", "")) for q in quests]
    metrics["side_quests"] = len(quests)
    if len(quests) != 120 or len(set(ids)) != 120 or not all(ids):
        problems.append("120 canonical side quests are missing or their IDs repeat")
    anchors = read("story/data/phase19_quest_world_anchors.json").get("quests", [])
    a_ids = [str(q.get("quest_id", "")) for q in anchors]
    metrics["quest_anchors"] = len(anchors)
    if len(anchors) != 120 or set(ids) != set(a_ids):
        problems.append("Quest world anchors are missing or do not cover all 120 quest IDs")

    maps = read("data/content/maps.json").get("entries", [])
    all_map_ids = {m.get("id") for m in maps}
    levels = read("data/levels/world_levels_v3.json").get("levels", {})
    metrics["map_records"] = len(maps)
    metrics["world_levels"] = len(levels)
    if len(maps) != 42 or len(levels) != 40:
        problems.append("Expected 42 atlas entries and 40 playable authored map levels")
    if not set(levels).issubset(all_map_ids):
        problems.append("World level collection references an unknown map ID")
    for mapping in maps:
        if not set(mapping.get("neighbors", [])).issubset(all_map_ids):
            problems.append("Broken map neighbor references: " + str(mapping.get("id")))

    skills = read("data/content/skills.json").get("entries", [])
    fx_keys = [str(skill.get("fx_key", "")) for skill in skills]
    metrics["skills"] = len(skills)
    if len(skills) != 63 or len(set(fx_keys)) != 63 or not all(fx_keys):
        problems.append("Expected 63 skills with unique nonempty FX signatures")
    regions = read("data/content/regions.json").get("entries", [])
    region_ids = {x.get("id") for x in regions}
    items = read("data/content/items.json").get("entries", [])
    item_ids = {x.get("id") for x in items}
    if len(regions) != 8:
        problems.append("World regions count is not eight")

    fields = read("data/levels/v7/field_ecology.json").get("maps", {})
    towns = read("data/levels/v7/town_ecology.json").get("towns", {})
    dungeons = read("data/levels/v7/dungeon_puzzles.json").get("maps", {})
    metrics.update(wilderness=len(fields), field_sites=0, towns=len(towns),
                   town_events=0, dungeons=len(dungeons), dungeon_controls=0)
    if (len(fields), len(towns), len(dungeons)) != (21, 11, 8):
        problems.append("V7 world must contain 21 fields, 11 towns and 8 dungeons")
    for map_id, spec in fields.items():
        sites = spec.get("sites", [])
        metrics["field_sites"] += len(sites)
        if map_id not in all_map_ids or set(s.get("id") for s in sites) != {
                "trial", "gather", "passage", "cache"} or len(sites) != 4:
            problems.append("Malformed wilderness interaction sites on " + map_id)
        if not all(spec.get(key) for key in ("challenge", "gather", "secret", "reward")):
            problems.append("Missing wilderness interaction config on " + map_id)
        if spec.get("gather", {}).get("item_id") not in item_ids:
            problems.append("Missing wilderness gather reward item on " + map_id)
    for map_id, spec in towns.items():
        events = spec.get("events", [])
        metrics["town_events"] += len(events)
        if map_id not in all_map_ids or len(events) != 3:
            problems.append("Malformed town event sequence on " + map_id)
    for map_id, spec in dungeons.items():
        controls = spec.get("controls", [])
        metrics["dungeon_controls"] += len(controls)
        if map_id not in all_map_ids or len(controls) != 3:
            problems.append("Malformed dungeon controls on " + map_id)
    for anchor in anchors:
        if anchor.get("map_id") not in all_map_ids:
            problems.append("Unknown quest anchor map: " + str(anchor.get("quest_id")))
    if (metrics["field_sites"], metrics["town_events"],
            metrics["dungeon_controls"]) != (84, 33, 24):
        problems.append("V7 interaction sites totals changed unexpectedly")
    metrics["source_block_checks"] = len(scripts) + len(tests)
    return problems, metrics


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--json", action="store_true", help="Print machine-readable findings")
    args = parser.parse_args()
    failures, counts = validate()
    result = {"status": "FAIL" if failures else "PASS", "metrics": counts,
              "errors": failures, "note": "Static gate only; Godot/runtime QA still required."}
    if args.json:
        print(json.dumps(result, ensure_ascii=False, indent=2))
    else:
        print(f"{result['status']} static release gate: " +
              ", ".join(f"{k}={v}" for k, v in counts.items()))
        for failure in failures:
            print("ERROR " + failure, file=sys.stderr)
    return 1 if failures else 0


if __name__ == "__main__":
    raise SystemExit(main())
