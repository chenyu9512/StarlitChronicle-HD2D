#!/usr/bin/env python3
"""B-line static spatial audit for the live Godot V3/V4 gameplay data.

Run from the repository root: python tools/validate_b_world_spatial_integrity.py
No Godot engine is required. This is *not* a substitute for player-route or
visual acceptance; the runtime renderer and body collision still need testing.
"""
from __future__ import annotations

from collections import deque
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
LEVELS = ROOT / "data" / "levels"
INTERIORS = LEVELS / "v4" / "interiors"
ISSUES: list[str] = []
STEPS = ((1, 0), (-1, 0), (0, 1), (0, -1))


def document(path: Path) -> dict:
    try:
        result = json.loads(path.read_text(encoding="utf-8"))
    except (OSError, UnicodeDecodeError, json.JSONDecodeError) as exc:
        ISSUES.append(f"{path.relative_to(ROOT)}: cannot read JSON: {exc}")
        return {}
    if not isinstance(result, dict):
        ISSUES.append(f"{path.relative_to(ROOT)}: expected JSON object")
        return {}
    return result


def cell(raw: object) -> tuple[int, int] | None:
    if not isinstance(raw, list) or len(raw) != 2:
        return None
    if not all(isinstance(v, (int, float)) for v in raw):
        return None
    return (int(raw[0]), int(raw[1]))


def interior_rooms() -> int:
    files = sorted(INTERIORS.glob("*.json"))
    if len(files) < 153:
        ISSUES.append(f"V4 room inventory: expected at least 153 files, got {len(files)}")
    count = 0
    for path in files:
        d = document(path)
        if not d:
            continue
        count += 1
        name = path.name
        prefix = f"{d.get('map_id', '')}__{d.get('building_id', '')}.json"
        if name != prefix or d.get("schema") != "starlit.interior.v4":
            ISSUES.append(f"{name}: V4 identity mismatch")
        size = d.get("size", [])
        if size != [72, 48]:
            ISSUES.append(f"{name}: expected 72x48 room coordinates, got {size!r}")
        if d.get("region_design"):
            # Staged art is committed per room when reviewed; remaining
            # region rooms receive the same semantic assets at runtime.
            profile = d.get("art_profile", "")
            if profile not in ("", "regional_functional_v1"):
                ISSUES.append(f"{name}: unexpected regional art profile {profile!r}")
            if len(d.get("features", [])) != 8 or len(d.get("investigations", [])) != 2:
                ISSUES.append(f"{name}: incomplete regional furniture or clues")
            if profile == "regional_functional_v1":
                visuals = d.get("visuals", [])
                if len(visuals) < 12 or len(d.get("light_sources", [])) < 2:
                    ISSUES.append(f"{name}: missing regional visuals or light sources")
                art_ids = [v.get("id") for v in visuals if isinstance(v, dict)]
                if len(art_ids) != len(set(art_ids)):
                    ISSUES.append(f"{name}: duplicated visual IDs")
                visual_cells = {tuple(v.get("cell", [])) for v in visuals
                                if isinstance(v, dict) and isinstance(v.get("cell"), list)}
                for prop in d["features"]:
                    if tuple(prop.get("cell", [])) not in visual_cells:
                        ISSUES.append(f"{name}: physical furniture lacks an anchored sprite")
                for inquiry in d["investigations"]:
                    if tuple(inquiry.get("cell", [])) not in visual_cells:
                        ISSUES.append(f"{name}: inspection clue not visibly staged")
        # Identical authority order to world_interior_v4.gd, including art.
        width, height = 72, 48
        walls = {(x, y) for y in range(height) for x in range(width)}
        for name_of_region, solid in (("floor_regions", False),
                                      ("solid_regions", True),
                                      ("door_regions", False)):
            for record in d.get(name_of_region, []):
                rect = record.get("rect") if isinstance(record, dict) else None
                if not isinstance(rect, list) or len(rect) != 4:
                    ISSUES.append(f"{name}: invalid {name_of_region} rect")
                    continue
                x0, y0, x1, y1 = (int(v) for v in rect)
                x0, x1 = max(2, x0), min(width - 3, x1)
                y0, y1 = max(2, y0), min(height - 3, y1)
                for yy in range(y0, y1 + 1):
                    for xx in range(x0, x1 + 1):
                        if solid:
                            walls.add((xx, yy))
                        else:
                            walls.discard((xx, yy))
        for raw in d.get("art_collision_cells", []):
            p = cell(raw)
            if p and 2 <= p[0] < width - 2 and 2 <= p[1] < height - 2:
                walls.add(p)
        points = d.get("points", {})
        if not isinstance(points, dict):
            ISSUES.append(f"{name}: points is not an object")
            continue
        targets: list[tuple[str, tuple[int, int] | None]] = [
            (key, cell(points.get(key))) for key in
            ("spawn", "exit", "service", "storage")
        ]
        for key in ("quest_points", "story_stage_points", "branch_stage_points"):
            targets.extend((f"{key}[{i}]", cell(v))
                           for i, v in enumerate(d.get(key, [])))
        targets.extend((f"investigations/{v.get('id', '')}", cell(v.get("cell")))
                       for v in d.get("investigations", []) if isinstance(v, dict))
        targets.extend((f"act01_story/{k}", cell(v))
                       for k, v in d.get("act01_main_story_points", {}).items())
        spawn = cell(points.get("spawn"))
        if spawn is None or spawn in walls:
            ISSUES.append(f"{name}: invalid or blocked spawn")
            continue
        visited = {spawn}
        queue = deque([spawn])
        while queue:
            x, y = queue.popleft()
            for dx, dy in STEPS:
                next_cell = (x + dx, y + dy)
                if (not 2 <= next_cell[0] < width - 2
                        or not 2 <= next_cell[1] < height - 2
                        or next_cell in walls or next_cell in visited):
                    continue
                visited.add(next_cell)
                queue.append(next_cell)
        for label, p in targets:
            if p is None or p not in visited:
                ISSUES.append(f"{name}: {label} unreachable from spawn ({p})")
        if d.get("act01_main_story_points"):
            if len(d["act01_main_story_points"]) != 5:
                ISSUES.append(f"{name}: incomplete Act-I story stations")
            evidence = d.get("act01_main_story_evidence", [])
            present = {v.get("id") for v in d.get("investigations", [])
                       if isinstance(v, dict)}
            if len(evidence) != 2 or not set(evidence) <= present:
                ISSUES.append(f"{name}: missing authored Act-I evidence")
    return count


def world_maps() -> tuple[int, int]:
    atlas = document(LEVELS / "world_atlas_v2.json")
    zones = atlas.get("zones", [])
    if len(zones) != 42:
        ISSUES.append(f"world_atlas_v2: expected 42 zone IDs, got {len(zones)}")
    playable = 0
    for zone in zones:
        map_id = zone.get("id", "")
        if not zone.get("playable", False):
            continue
        playable += 1
        d = document(LEVELS / "v3" / f"{map_id}.json")
        if d.get("map_id") != map_id:
            ISSUES.append(f"{map_id}: missing authoritative V3 sidecar")
            continue
        size = d.get("size", [])
        if len(size) != 2 or not 72 <= size[0] <= 112 or not 48 <= size[1] <= 78:
            ISSUES.append(f"{map_id}: impossible V3 extent {size!r}")
            continue
        width, height = size
        if not d.get("roads", []):
            ISSUES.append(f"{map_id}: missing authored roads")
        for r in d.get("roads", []):
            for p in r.get("points", []):
                xy = cell(p)
                if xy is None or not 2 <= xy[0] < width - 2 or not 2 <= xy[1] < height - 2:
                    ISSUES.append(f"{map_id}: V3 road out of bounds: {p}")
        occupied: list[tuple[str, tuple[int, int, int, int]]] = []
        # Every outside doorway must resolve to a real V4 room; the old
        # generic interior fallback is no longer a shipping path for towns.
        for building in zone.get("buildings", []):
            expected_room = INTERIORS / f"{map_id}__{building.get('id', '')}.json"
            if not expected_room.is_file():
                ISSUES.append(f"{map_id}/{building.get('id', '')}: missing live V4 interior")
        for building in zone.get("buildings", []):
            b_id = building.get("id", "")
            pos = cell(building.get("pos"))
            span = cell(building.get("size"))
            door = cell(building.get("door"))
            if pos is None or span is None or door is None:
                ISSUES.append(f"{map_id}/{b_id}: incomplete building/door")
                continue
            x0, y0 = pos[0] - span[0] // 2, pos[1] - span[1] // 2
            box = (x0, y0, x0 + span[0], y0 + span[1] + 1)
            if not (2 <= box[0] and 2 <= box[1]
                    and box[2] < width - 2 and box[3] < height - 2):
                ISSUES.append(f"{map_id}/{b_id}: facade outside map {box}")
            if not (box[0] <= door[0] < box[2]
                    and box[1] <= door[1] < box[3]):
                ISSUES.append(f"{map_id}/{b_id}: door outside its facade")
            for old_id, other in occupied:
                if box[0] < other[2] and box[2] > other[0] and box[1] < other[3] and box[3] > other[1]:
                    ISSUES.append(f"{map_id}: facade overlaps {b_id} and {old_id}")
                if other[0] <= door[0] < other[2] and other[1] <= door[1] + 1 < other[3]:
                    ISSUES.append(f"{map_id}/{b_id}: front step inside {old_id}")
            occupied.append((b_id, box))
    if playable != 40:
        ISSUES.append(f"expected 40 playable V3 maps, got {playable}")
    return len(zones), playable


def main() -> int:
    zones, playable = world_maps()
    rooms = interior_rooms()
    print(f"B_WORLD_STATIC_AUDIT zones={zones} playable_v3={playable} v4_rooms={rooms} issues={len(ISSUES)}")
    for issue in ISSUES:
        print("FAIL", issue)
    print("Note: no Godot visual, actor-footprint or real-player acceptance was run.")
    return 1 if ISSUES else 0


if __name__ == "__main__":
    raise SystemExit(main())
