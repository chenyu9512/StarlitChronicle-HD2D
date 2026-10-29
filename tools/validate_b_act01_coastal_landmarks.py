#!/usr/bin/env python3
"""Act-I authored coastal landmarks: validate live V5 events against V3/V7.

This is a source/data gate, not a substitute for Godot movement tests.
"""
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


def load(path):
    return json.loads((ROOT / path).read_text(encoding="utf-8"))


def main():
    errors = []
    events = load("data/levels/v5/world_discoveries.json")["maps"]
    puzzles = load("data/levels/v7/dungeon_puzzles.json")["maps"]
    atlas = load("data/levels/world_atlas_v2.json")["zones"]
    allowed = {z["id"] for z in atlas}
    coastal = ["map_coast_03", "map_coast_04", "map_coast_05"]
    if len(events) != 40 or len(allowed) != 42:
        errors.append("The 40 playable maps and two original prototypes changed")
    unique_text = set()
    for map_id in coastal:
        level = load(f"data/levels/v3/{map_id}.json")
        width, height = level["size"]
        scene = events[map_id]["events"]
        if [e["id"] for e in scene] != ["trace", "mechanism", "cache"]:
            errors.append(f"{map_id}: stable first-act discovery/receipt IDs changed")
        if [e["require"] for e in scene] != ["", "trace", "mechanism"]:
            errors.append(f"{map_id}: player can bypass discovery prerequisites")
        decorated = {tuple(node["cell"]) for node in level.get("expansion_nodes", [])}
        for event in scene:
            if tuple(event["cell"]) in decorated:
                errors.append(f"{map_id}/{event['id']}: click target overlaps environmental art")
        if any(e["reward"] is not None for e in scene[:2]):
            errors.append(f"{map_id}: a clue grants an unexpected reward")
        if not isinstance(scene[2]["reward"], dict):
            errors.append(f"{map_id}: one-time exploration reward missing")
        for e in scene:
            x, y = e["cell"]
            if not 3 <= x < width-3 or not 3 <= y < height-3:
                errors.append(f"{map_id}/{e['id']}: outside playable terrain")
            if len(e["text"]) < 45:
                errors.append(f"{map_id}/{e['id']}: no authored environmental storytelling")
            if e["text"] in unique_text:
                errors.append(f"{map_id}: duplicated story clue")
            unique_text.add(e["text"])
    shoal = load("data/levels/v3/map_coast_03.json")
    shoal_clearings = {tuple(c["center"]) for c in shoal.get("clearings", [])}
    if not {(62, 43), (66, 45)} <= shoal_clearings:
        errors.append("Whale shoal walkable staging ground was not authored")
    if not all("鲸骨浅滩" in e["name"] for e in events["map_coast_03"]["events"]):
        errors.append("Saltwind lacks its distinct whale-shoal narrative")
    beacon = load("data/levels/v3/map_coast_05.json")
    beacon_clearings = {tuple(c["center"]) for c in beacon.get("clearings", [])}
    if not {(80, 29), (74, 35)} <= beacon_clearings:
        errors.append("Lighthouse lacks its navigable maintenance deck")
    if not all("潮歌灯塔" in e["name"] for e in events["map_coast_05"]["events"]):
        errors.append("Lighthouse repair clues are unnamed")
    cave = puzzles["map_coast_04"]
    if cave["mode"] != "sequence" or cave["pattern"] != ["b", "a", "c"]:
        errors.append("Original three-valve tide sequence changed")
    interactive = {tuple(c["cell"]) for c in cave["controls"] + [cave["seal"]]}
    for item in events["map_coast_04"]["events"]:
        location = tuple(item["cell"])
        if location in interactive:
            errors.append(f"Cave clue {item['id']} collides with a live stone valve")
        if min(abs(location[0]-x)+abs(location[1]-y) for x, y in interactive) > 10:
            errors.append(f"Cave clue {item['id']} is no longer near the tide puzzle")
    if errors:
        for item in errors:
            print("FAIL:", item)
        return 1
    print("PASS B: 9 unique coastal clues, shoal and lighthouse floor zones, cave controls with no overlap")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
