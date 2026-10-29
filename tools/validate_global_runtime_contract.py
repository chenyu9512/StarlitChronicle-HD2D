#!/usr/bin/env python3
"""Global Main2 production contract audit. Static only; no gameplay shortcuts.

This checks identities between canonical story data, the live production
catalog, the world atlas, V3 layouts, exterior entrances and authored V4 rooms.
Running it never advances State, claims rewards or declares gameplay complete.
"""
from __future__ import annotations

import json
from collections import Counter
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
STORY = ROOT / "story"
LEVELS = ROOT / "data/levels"
ISSUES: list[str] = []


def read(path: Path) -> dict:
    try:
        value = json.loads(path.read_text(encoding="utf-8"))
    except (OSError, ValueError) as exc:
        ISSUES.append(f"{path.relative_to(ROOT)}: unreadable: {exc}")
        return {}
    if not isinstance(value, dict):
        ISSUES.append(f"{path.relative_to(ROOT)}: top-level JSON must be object")
        return {}
    return value


def require(condition: bool, label: str) -> None:
    if not condition:
        ISSUES.append(label)


def campaign() -> tuple[dict, dict, dict]:
    chapters: dict[str, dict] = {}
    for act in range(1, 13):
        doc = read(STORY / "campaign" / f"act_{act:02d}.json")
        records = doc.get("chapters", [])
        require(doc.get("act") == act, f"Act {act}: wrong canonical act identity")
        require(isinstance(records, list) and len(records) == 6,
                f"Act {act}: not exactly six authored chapters")
        if not isinstance(records, list):
            continue
        for position, chapter in enumerate(records):
            if not isinstance(chapter, dict):
                ISSUES.append(f"Act {act}: non-object chapter")
                continue
            number = (act - 1) * 6 + position + 1
            chapter_id = f"ch{number:03d}"
            require(chapter.get("id") == chapter_id and chapter.get("number") == number
                    and chapter.get("act") == act, f"Act {act}: wrong chapter {chapter_id} authority")
            require(chapter.get("chapter_complete_flag") == f"story.{chapter_id}.done",
                    f"{chapter_id}: completion flag mismatch")
            require(chapter_id not in chapters, f"{chapter_id}: duplicated chapter")
            chapters[chapter_id] = chapter
            scenes = chapter.get("scenes", [])
            names = [scene.get("id") for scene in scenes if isinstance(scene, dict)]
            require(len(names) == len(scenes) and len(names) == len(set(names)),
                    f"{chapter_id}: duplicate or malformed scene")
            require(all(isinstance(sid, str) and sid.startswith(chapter_id + ".")
                        for sid in names), f"{chapter_id}: foreign scene ownership")
            for phase in ("opening", "investigate", "crisis", "resolve"):
                require(f"{chapter_id}.{phase}" in names, f"{chapter_id}: missing {phase}")
    quests: dict[str, dict] = {}
    for name in ("side_quests", "companion_quests", "regional_quests_v2"):
        doc = read(STORY / "data" / f"{name}.json")
        for quest in doc.get("quests", []):
            if not isinstance(quest, dict):
                ISSUES.append(f"{name}: non-object quest")
                continue
            qid = str(quest.get("id", ""))
            require(qid and qid not in quests, f"{name}: duplicated or blank quest {qid}")
            require(quest.get("required_chapter") in chapters,
                    f"{qid}: quest refers to nonexistent chapter")
            require(quest.get("completion_flag") == f"side.{qid}.done",
                    f"{qid}: completion flag mismatch")
            stages = quest.get("stages", [])
            require(isinstance(stages, list) and len(stages) > 0, f"{qid}: empty stage chain")
            if isinstance(stages, list):
                keys = [stage.get("id") for stage in stages if isinstance(stage, dict)]
                require(len(keys) == len(stages) and len(keys) == len(set(keys)) and
                        all(isinstance(k, str) and k.startswith(qid + ".") for k in keys),
                        f"{qid}: duplicated, missing or foreign quest stages")
            quests[qid] = quest
    bosses: dict[str, dict] = {}
    boss_ids: set[str] = set()
    for entry in read(STORY / "data/bosses.json").get("bosses", []):
        if not isinstance(entry, dict):
            ISSUES.append("Non-object boss")
            continue
        chapter_id = str(entry.get("chapter_id", ""))
        boss_id = str(entry.get("id", ""))
        require(chapter_id in chapters, f"{boss_id}: boss is orphaned")
        require(bool(boss_id) and boss_id not in boss_ids and chapter_id not in bosses,
                f"{chapter_id}: duplicated boss")
        bosses[chapter_id] = entry
        boss_ids.add(boss_id)
    pattern = read(STORY / "runtime/chapter_play_patterns.json").get("chapters", {})
    mechanics = read(STORY / "runtime/mechanics_registry.json").get("chapter_mechanics_bindings", {})
    require(isinstance(pattern, dict) and set(pattern) == set(chapters),
            "Play-pattern contract has missing or foreign chapters")
    require(isinstance(mechanics, dict) and set(mechanics).issubset(chapters),
            "Mechanic registry refers to unknown chapter")
    require(len(chapters) == 72 and len(quests) == 120 and len(bosses) == 66,
            f"Unexpected chapter/quest/boss counts: {len(chapters)}/{len(quests)}/{len(bosses)}")
    return chapters, quests, bosses


def world() -> tuple[int, int, int]:
    atlas = read(LEVELS / "world_atlas_v2.json")
    regions = {record.get("id") for record in atlas.get("regions", []) if isinstance(record, dict)}
    zones = atlas.get("zones", [])
    all_ids: set[str] = set()
    playable: set[str] = set()
    exterior: set[tuple[str, str]] = set()
    for zone in zones:
        if not isinstance(zone, dict):
            ISSUES.append("Non-object atlas zone")
            continue
        mid = str(zone.get("id", ""))
        require(bool(mid) and mid not in all_ids, f"Atlas duplicate/empty map: {mid}")
        all_ids.add(mid)
        require(zone.get("region_id") in regions, f"{mid}: undefined region")
        if zone.get("playable"):
            playable.add(mid)
            sidecar = read(LEVELS / "v3" / f"{mid}.json")
            require(sidecar.get("map_id") == mid, f"{mid}: missing real V3 map")
            # The world atlas defines travel/sector position, not a duplicate
            # per-map tile dimension. All 40 V3 maps own their actual grid size.
            # Verify that authoritative geometry instead of comparing to an
            # absent atlas.grid_size (which falsely failed every map).
            size = sidecar.get("size")
            require(isinstance(size, list) and len(size) == 2
                    and all(type(n) is int and 8 <= n <= 512 for n in size),
                    f"{mid}: invalid authoritative V3 grid size")
            if "grid_size" in zone:
                require(zone["grid_size"] == size,
                        f"{mid}: explicitly defined atlas grid_size disagrees with V3")
        for building in zone.get("buildings", []):
            if not isinstance(building, dict):
                ISSUES.append(f"{mid}: invalid building")
                continue
            key = (mid, str(building.get("id", "")))
            require(bool(key[1]) and key not in exterior, f"Duplicate exterior building: {key}")
            exterior.add(key)
    rooms = set()
    regional = 0
    for path in sorted((LEVELS / "v4/interiors").glob("*.json")):
        room = read(path)
        mid, bid = str(room.get("map_id", "")), str(room.get("building_id", ""))
        key = (mid, bid)
        require(room.get("schema") == "starlit.interior.v4" and
                path.name == f"{mid}__{bid}.json" and key not in rooms,
                f"{path.name}: V4 identity error or duplicate")
        rooms.add(key)
        require(mid in playable, f"{path.name}: orphan V4 map")
        if room.get("region_design"):
            regional += 1
            require(room.get("art_profile") == "regional_functional_v1",
                    f"{path.name}: missing permanent regional art")
            visuals = room.get("visuals", [])
            require(len(visuals) >= 12 and len(room.get("light_sources", [])) >= 3,
                    f"{path.name}: missing real visible furniture/light specification")
            require(room.get("collision_revision", 0) >= 2,
                    f"{path.name}: stale service/storage physical geometry")
    for key in exterior:
        require(key in rooms, f"Exterior door points to nonexistent authored V4 room: {key}")
    require(len(zones) == 42 and len(playable) == 40 and len(exterior) == 68,
            f"Atlas count mismatch: zones/playable/buildings={len(zones)}/{len(playable)}/{len(exterior)}")
    require(len(rooms) == 153 and regional == 54,
            f"V4 room/region count mismatch: {len(rooms)}/{regional}")
    return len(playable), len(exterior), len(rooms)


def main() -> int:
    chapters, quests, bosses = campaign()
    playable, buildings, rooms = world()
    print(f"GLOBAL_SYNC_STATIC chapter={len(chapters)} quest={len(quests)} boss={len(bosses)}"
          f" maps={playable} exterior={buildings} interiors={rooms} problems={len(ISSUES)}")
    for issue in ISSUES:
        print("FAIL", issue)
    print("Static cross-reference check only; Godot gameplay, save migration, image "
          "approval and release remain unverified.")
    return 1 if ISSUES else 0


if __name__ == "__main__":
    raise SystemExit(main())
