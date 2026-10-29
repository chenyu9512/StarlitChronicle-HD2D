#!/usr/bin/env python3
"""Independent static B-line NPC / housing integrity validation (no Godot required).

Usage: python tools/validate_b_npc_home.py
Validates authored JSON and physical target reachability; NOT a runtime QA pass.
"""
from __future__ import annotations

import json
from collections import Counter, deque
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
REGIONS = {
    "region_coast", "region_oaths", "region_forge", "region_isles",
    "region_mirror", "region_oldland", "region_sanctum", "region_city",
}
KINDS = ("inn", "shop", "house", "guild", "smith", "shrine")
DIALOGUES = ("first", "repeat", "night", "after_chapter", "choice_reflection", "after_quest")
SOCIAL = ("pre_chapter", "night", "after_chapter", "after_project")


def load(path: str) -> dict:
    with (ROOT / path).open(encoding="utf-8") as fp:
        return json.load(fp)


def room_reachable(room: dict) -> set[tuple[int, int]]:
    width, height = room.get("size", [72, 48])
    accessible: set[tuple[int, int]] = set()

    def fill(regions: list[dict], is_floor: bool) -> None:
        for region in regions:
            x0, y0, x1, y1 = region["rect"]
            for y in range(max(2, y0), min(height - 3, y1) + 1):
                for x in range(max(2, x0), min(width - 3, x1) + 1):
                    if is_floor:
                        accessible.add((x, y))
                    else:
                        accessible.discard((x, y))

    fill(room.get("floor_regions", []), True)
    fill(room.get("solid_regions", []), False)
    fill(room.get("door_regions", []), True)
    for pos in room.get("art_collision_cells", []):
        accessible.discard(tuple(pos))
    start = tuple(room["points"]["spawn"])
    if start not in accessible:
        return set()
    seen = {start}
    pending = deque([start])
    while pending:
        x, y = pending.popleft()
        for tile in ((x + 1, y), (x - 1, y), (x, y + 1), (x, y - 1)):
            if tile in accessible and tile not in seen:
                seen.add(tile)
                pending.append(tile)
    return seen


def main() -> int:
    errors: list[str] = []
    entries = load("data/content/npcs.json")["entries"]
    maps = load("data/content/maps.json")["entries"]
    town_plans = load("data/levels/town_director_v4.json")["towns"]
    ecology = load("data/levels/v7/town_ecology.json")["towns"]
    production = [m for m in maps if m.get("type") != "prototype"]
    canonical_ids = {m["id"] for m in production}
    if len(production) != 40 or len(canonical_ids) != 40:
        errors.append("Production atlas should contain 40 unique maps")
    if len(maps) != 42:
        errors.append("Unexpected removal/addition of original prototype maps")

    identities = [npc["id"] for npc in entries]
    if len(entries) != 40 or len(set(identities)) != 40:
        errors.append("Expected 40 unique canonical NPCs")
    counts = Counter(npc["region_id"] for npc in entries)
    if set(counts) != REGIONS or any(value != 5 for value in counts.values()):
        errors.append("Expected five distinct NPCs in each of eight regions")
    for mode in ("first", "after_quest"):
        lines = [npc.get("dialogue_states", {}).get(mode, "") for npc in entries]
        if len(set(lines)) != len(entries) or any(not line for line in lines):
            errors.append("NPC dialogue not uniquely authored for: " + mode)
    for npc in entries:
        ident = npc["id"]
        town = town_plans.get(npc.get("map_id"), {})
        if npc.get("map_id") not in canonical_ids or not town:
            errors.append("NPC without canonical home town: " + ident)
        if any(not npc.get("dialogue_states", {}).get(k) for k in DIALOGUES):
            errors.append("NPC lacks required conversation state: " + ident)
        periods = npc.get("daily_routine", [])
        if len(periods) != 5:
            errors.append("NPC needs five schedule periods: " + ident)
        districts = {d["name"] for d in town.get("districts", [])}
        occupancy = [0] * 1440
        for routine in periods:
            if routine.get("district") not in districts:
                errors.append("NPC references unknown town district: " + ident)
            start = routine.get("start", -1)
            end = routine.get("end", -1)
            if not isinstance(start, int) or not isinstance(end, int) or not (0 <= start <= 23 and 0 <= end <= 24):
                errors.append("Invalid NPC schedule clock: " + ident)
                continue
            for minute in range(1440):
                here = minute // 60
                if (start < end and start <= here < end) or (
                    start > end and (here >= start or here < end)
                ):
                    occupancy[minute] += 1
        if any(number != 1 for number in occupancy):
            errors.append("NPC schedule gap/overlap: " + ident)
    if len(ecology) != 11 or set(ecology) != set(town_plans):
        errors.append("Missing one of 11 known settlements")
    for map_id, town in ecology.items():
        social = town.get("social_life", {})
        if any(not social.get(k) for k in SOCIAL):
            errors.append("Town has no authored social reaction phase: " + map_id)

    rooms = 0
    objects = 0
    for map_id in ("map_coast_01", "map_coast_02"):
        for kind in KINDS:
            room = load(f"data/levels/v4/interiors/{map_id}__{kind}.json")
            rooms += 1
            if room.get("schema") != "starlit.interior.v4" or room.get("map_id") != map_id or room.get("building_id") != kind:
                errors.append(f"Invalid indoor identity: {map_id}/{kind}")
            reachable = room_reachable(room)
            if not reachable:
                errors.append(f"Interior spawn blocked: {map_id}/{kind}")
            positions: set[tuple[int, int]] = set()
            identifiers: set[str] = set()
            props = room.get("investigations", [])
            if len(props) < 4:
                errors.append(f"Insufficient authored furniture: {map_id}/{kind}")
            for prop in props:
                objects += 1
                loc = tuple(prop["cell"])
                ident = prop["id"]
                if loc not in reachable or loc in positions or ident in identifiers:
                    errors.append(f"Furniture unreachable/duplicate: {map_id}/{kind}/{ident}")
                positions.add(loc)
                identifiers.add(ident)
                if any(not prop.get(k) for k in ("first_text", "repeat_text", "after_text", "after_flag")):
                    errors.append(f"Furniture lacks distinct states: {map_id}/{kind}/{ident}")
                if prop.get("reward") is not None:
                    errors.append(f"Unreviewed economy reward at {map_id}/{kind}/{ident}")
    if rooms != 12 or objects != 52:
        errors.append(f"Room/furniture totals changed: {rooms} rooms, {objects} objects")
    result = {"kind": "B_STATIC_JSON_ONLY", "passed": not errors,
              "canonical_maps": len(production), "npcs": len(entries),
              "settlements": len(ecology), "interiors": rooms,
              "furniture": objects, "errors": errors}
    print(json.dumps(result, ensure_ascii=False, indent=2))
    return 1 if errors else 0


if __name__ == "__main__":
    raise SystemExit(main())
