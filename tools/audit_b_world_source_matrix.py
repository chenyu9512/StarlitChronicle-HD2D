#!/usr/bin/env python3
"""B-line source linkage matrix. NEVER equate authored data with Godot gameplay."""
from __future__ import annotations

import argparse
import json
from collections import Counter, defaultdict
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
QUEST_SOURCES = (
    "story/data/side_quests.json",
    "story/data/regional_quests_v2.json",
    "story/data/companion_quests.json",
)


def load(path: str) -> dict:
    return json.loads((ROOT / path).read_text(encoding="utf-8"))


def audit() -> tuple[dict, list[str]]:
    errors: list[str] = []
    maps = load("data/content/maps.json")["entries"]
    atlas = {z["id"]: z for z in load("data/levels/world_atlas_v2.json")["zones"]}
    npcs = load("data/content/npcs.json")["entries"]
    direct_quests = load("data/content/quests.json")["entries"]
    chapters = [q for q in direct_quests if q.get("kind") == "main"]
    side = [quest for source in QUEST_SOURCES for quest in load(source)["quests"]]
    anchors = load("story/data/phase19_quest_world_anchors.json")["quests"]
    bosses = load("story/data/bosses.json")["bosses"]
    town_plans = load("data/levels/town_director_v4.json")["towns"]
    zones = {m["id"]: m for m in maps if m.get("type") != "prototype"}
    npc_maps: dict[str, list[str]] = defaultdict(list)
    quest_maps: dict[str, list[str]] = defaultdict(list)
    chapter_maps: dict[str, list[int]] = defaultdict(list)
    anchor_map = {a["quest_id"]: a for a in anchors}
    town_rooms: dict[str, list[str]] = defaultdict(list)
    all_rooms: dict[str, list[str]] = defaultdict(list)
    if len(zones) != 40 or len(maps) != 42 or len(atlas) != 42:
        errors.append("Canonical 40 production + 2 prototype maps changed")
    if len(chapters) != 72 or len({q["chapter"] for q in chapters}) != 72:
        errors.append("72 chapter quest IDs or indices missing")
    ids = [q["id"] for q in side]
    if len(side) != 120 or len(set(ids)) != 120:
        errors.append("120 distinct side-quest IDs required")
    if len(anchors) != 120 or set(anchor_map) != set(ids):
        errors.append("120 quest to world-anchor references do not match")
    if len(bosses) != 66 or len({b["id"] for b in bosses}) != 66:
        errors.append("66 independently identified story bosses required")
    if len(npcs) != 40 or len({n["id"] for n in npcs}) != 40:
        errors.append("40 independently identified NPCs required")
    if len(town_plans) != 11:
        errors.append("11 distinct settlement director plans required")

    for npc in npcs:
        mid = str(npc.get("map_id", ""))
        npc_maps[mid].append(str(npc.get("id", "")))
        if mid not in zones or not atlas.get(mid, {}).get("settlement", False):
            errors.append(f"NPC lacks valid settlement: {npc.get('id')}")
        if not npc.get("daily_routine") or not npc.get("dialogue_states"):
            errors.append(f"NPC missing routine/dialogue: {npc.get('id')}")
    for q in chapters:
        mid = str(q.get("map_id", ""))
        chapter_maps[mid].append(int(q.get("chapter", -1)))
        if mid not in zones:
            errors.append(f"Chapter lacks a playable world map: {q.get('id')}")
    for q in side:
        a = anchor_map.get(q["id"], {})
        mid = str(a.get("map_id", ""))
        quest_maps[mid].append(q["id"])
        if mid not in zones:
            errors.append(f"Side quest lacks playable map: {q['id']}")
        if str(q.get("completion_flag", "")) != "side." + q["id"] + ".done":
            errors.append(f"Side quest has inconsistent completion key: {q['id']}")
        if not q.get("stages"):
            errors.append(f"Side quest has no authored steps: {q['id']}")
    for path in sorted((ROOT / "data/levels/v4/interiors").glob("*.json")):
        record = json.loads(path.read_text(encoding="utf-8"))
        mid = str(record.get("map_id", ""))
        bid = str(record.get("building_id", ""))
        all_rooms[mid].append(bid)
        if not bid.startswith("quest__"):
            town_rooms[mid].append(bid)
        if mid not in zones or path.name != f"{mid}__{bid}.json":
            errors.append(f"Interior points to unknown map/building: {path.name}")
    production_rooms = sum(len(v) for v in all_rooms.values())
    if production_rooms != 153:
        errors.append(f"153 V4 interior source records expected, got {production_rooms}")

    rows = []
    entrances = 0
    for mid, entry in sorted(zones.items()):
        z = atlas.get(mid, {})
        sidecar = ROOT / "data/levels/v3" / f"{mid}.json"
        info = load(str(sidecar.relative_to(ROOT))) if sidecar.exists() else {}
        size = info.get("size", [])
        if not info or size != entry.get("grid_size"):
            errors.append(f"Terrain missing or not canonical size: {mid}")
        if not z.get("playable", False):
            errors.append(f"Production map is missing playable atlas pin: {mid}")
        seen_buildings = set()
        buildings = z.get("buildings", [])
        for building in buildings:
            bid = str(building.get("id", ""))
            if not bid or bid in seen_buildings:
                errors.append(f"Missing/duplicated building ID: {mid}/{bid}")
            seen_buildings.add(bid)
            if bid not in town_rooms.get(mid, []):
                errors.append(f"Exterior building has no corresponding authored V4 room: {mid}/{bid}")
            center = building.get("pos", [])
            scale = building.get("size", [])
            door = building.get("door", [])
            if len(center) != 2 or len(scale) != 2 or len(door) != 2:
                errors.append(f"Building lacks authored entrance: {mid}/{bid}")
                continue
            if size and not (2 <= door[0] < size[0]-2 and 2 <= door[1] < size[1]-3):
                errors.append(f"Building door outside authored ground: {mid}/{bid}")
            entrances += 1
        if z.get("settlement", False) and mid not in town_plans:
            errors.append(f"Settlement has no street/district layout: {mid}")
        rows.append({
            "map_id": mid,
            "region_id": entry.get("region_id"),
            "map_type": entry.get("type"),
            "authored_grid": size,
            "atlas_linked": bool(z),
            "building_entrance_sources": len(buildings),
            "v4_interior_sources": sorted(all_rooms.get(mid, [])),
            "town_interior_sources": sorted(town_rooms.get(mid, [])),
            "npc_ids": sorted(npc_maps.get(mid, [])),
            "main_chapters": sorted(chapter_maps.get(mid, [])),
            "side_quest_ids": sorted(quest_maps.get(mid, [])),
            "source_verified": bool(info and z),
            "live_world_nodes_verified": False,
            "physical_player_reachability_verified": False,
            "godot_tested": False,
            "commercial_accepted": False,
        })
    if entrances != 68:
        errors.append(f"Expected 68 building entrance definitions, got {entrances}")
    result = {
        "schema": "starlit.b_world.source_matrix.v1",
        "scope": "SOURCE_REFERENCE_ONLY_NOT_GODOT",
        "source_counts": {
            "playable_maps": len(zones),
            "registered_atlas_nodes": len(atlas),
            "town_director_plans": len(town_plans),
            "building_entrances": entrances,
            "interior_files": production_rooms,
            "canonical_npcs": len(npcs),
            "main_chapters": len(chapters),
            "side_quests": len(side),
            "story_boss_designs": len(bosses)
        },
        "remaining_gates": [
            "B/D: live NPC identity filtered by current map rather than whole region",
            "D: stable world.interact routing for furniture and doors",
            "D: V3 transactional NPC conversations and service rewards",
            "B/D: actual walkability, 40 maps and 68 entrances in Godot",
            "A/D: 66 actual boss encounters and battle/world settlement",
            "C: final scene art + visual collision agreement",
            "D: actual save/load and full player path acceptance",
        ],
        "maps": rows,
        "proven_engine_success": False,
        "static_errors": errors,
    }
    return result, errors


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--output", type=Path, help="Optional JSON output path; stdout otherwise")
    args = parser.parse_args()
    result, failures = audit()
    payload = json.dumps(result, ensure_ascii=False, indent=2) + "\n"
    if args.output is not None:
        args.output.parent.mkdir(parents=True, exist_ok=True)
        args.output.write_text(payload, encoding="utf-8")
        print(json.dumps({"passed": not failures, "counts": result["source_counts"],
                          "output": str(args.output), "errors": failures},
                         ensure_ascii=False))
    else:
        print(payload)
    raise SystemExit(1 if failures else 0)
