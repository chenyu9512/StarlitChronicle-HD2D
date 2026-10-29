#!/usr/bin/env python3
"""Offline Act-I harbor room acceptance: actual collision cells and exit routes.

Run without Godot first. Engine travel/input acceptance is a separate gate.
"""
import json
from collections import deque
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


def read(path):
    return json.loads((ROOT / path).read_text(encoding="utf-8"))


def room_walkable(room):
    open_cells = set()
    for name, value in (("floor_regions", True), ("solid_regions", False),
                        ("door_regions", True)):
        for rec in room[name]:
            x0, y0, x1, y1 = rec["rect"]
            for x in range(x0, x1 + 1):
                for y in range(y0, y1 + 1):
                    if value:
                        open_cells.add((x, y))
                    else:
                        open_cells.discard((x, y))
    for x, y in room.get("art_collision_cells", []):
        open_cells.discard((x, y))
    return open_cells


def reachable(start, free):
    seen = {start}
    todo = deque([start])
    while todo:
        x, y = todo.popleft()
        for next_cell in ((x - 1, y), (x + 1, y),
                          (x, y - 1), (x, y + 1)):
            if next_cell in free and next_cell not in seen:
                seen.add(next_cell)
                todo.append(next_cell)
    return seen


def main():
    failures = []
    maps = read("data/content/maps.json")["entries"]
    atlas = read("data/levels/world_atlas_v2.json")["zones"]
    harbor = next(zone for zone in atlas if zone["id"] == "map_coast_02")
    atlas_ids = {zone["id"] for zone in atlas}
    if len(atlas_ids) != 42 or len(maps) != 42:
        failures.append("Original 40 formal maps and 2 prototypes changed")
    buildings = harbor["buildings"]
    if len(buildings) != 8:
        failures.append("Harbor must contain six original houses and two authored story venues")
    bounds = []
    for b in buildings:
        x, y = b["pos"]
        w, h = b["size"]
        x0, x1 = x - w // 2, x + w // 2
        y0, y1 = y - h // 2, y + h // 2
        bounds.append((b["id"], x0, y0, x1, y1))
        if b["door"] != [x, y + h // 2]:
            failures.append(f"Door not at visible front wall for {b['id']}")
    for i, (a, ax0, ay0, ax1, ay1) in enumerate(bounds):
        for b, bx0, by0, bx1, by1 in bounds[i + 1:]:
            if ax0 <= bx1 and bx0 <= ax1 and ay0 <= by1 and by0 <= ay1:
                failures.append(f"Overlap: {a} / {b}")
    checked_clues = 0
    for building_id, chapter in (("shelter", 2), ("tavern", 4)):
        match = [b for b in buildings if b["id"] == building_id]
        if len(match) != 1:
            failures.append(f"Missing live harbor door for {building_id}")
            continue
        room = read(f"data/levels/v4/interiors/map_coast_02__{building_id}.json")
        if (room["schema"] != "starlit.interior.v4" or
                room["map_id"] != "map_coast_02" or
                room["building_id"] != building_id or
                room["size"] != [72, 48]):
            failures.append(f"Bad V4 room identity/dimensions {building_id}")
        free = room_walkable(room)
        spawn = tuple(room["points"]["spawn"])
        safe = reachable(spawn, free)
        for name in ("spawn", "exit", "service", "storage"):
            cell = tuple(room["points"][name])
            if cell not in safe:
                failures.append(f"No connected player path to {building_id}/{name}")
        seen_ids = set()
        seen_cells = set()
        for prop in room.get("investigations", []):
            clue_id = prop["id"]
            cell = tuple(prop["cell"])
            if clue_id in seen_ids or cell in seen_cells:
                failures.append(f"Duplicate investigation identity/cell in {building_id}")
            seen_ids.add(clue_id)
            seen_cells.add(cell)
            if cell not in safe:
                failures.append(f"Unreachable investigation {building_id}/{clue_id}")
            if (not prop.get("first_text") or not prop.get("repeat_text") or
                    not prop.get("after_text")):
                failures.append(f"Unwritten investigation narrative {building_id}/{clue_id}")
            if prop.get("reward") is not None or prop.get("privacy") != "observe_only":
                failures.append(f"Unsafe loot/privacy contract in {building_id}/{clue_id}")
            if prop.get("after_flag") != f"story.ch{chapter:03d}.done":
                failures.append(f"Wrong Act-I progression binding {building_id}/{clue_id}")
            checked_clues += 1
        if len(seen_ids) != 4:
            failures.append(f"{building_id} requires four authored clues")
    if checked_clues != 8:
        failures.append(f"Expected 8 independent shelter/tavern investigation points, got {checked_clues}")
    if failures:
        for failure in failures:
            print("FAIL:", failure)
        return 1
    print("PASS: eight nonoverlapping harbor buildings, two connected V4 rooms, eight safe story clues")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
