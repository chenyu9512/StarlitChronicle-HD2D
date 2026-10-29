#!/usr/bin/env python3
"""Fail fast when the first-act story, quest catalog and physical routes diverge.

This audits ALL actual source catalogs without requiring Godot or loading art.
Gameplay/save gates are additionally exercised by the Godot chapter-route smoke.
"""
import json
from collections import deque
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
def load(path):
    return json.loads((ROOT / path).read_text(encoding="utf-8"))

MAPS = {m["id"]: m for m in load("data/content/maps.json")["entries"]}
QUESTS = {int(q["chapter"]): q for q in load("data/content/quests.json")["entries"]
          if q.get("kind") == "main" and int(q.get("act", 0)) == 1}
SCENES = {int(s["chapter"]): s for s in load("data/levels/act01_scene_locations_v1.json")["chapters"]}
EXPECTED = {1: "map_coast_01", 2: "map_coast_02", 3: "map_coast_04",
            4: "map_coast_02", 5: "map_coast_03", 6: "map_coast_05"}
issues = []
def check(ok, why):
    if not ok:
        issues.append(why)

for chapter, target in EXPECTED.items():
    quest = QUESTS.get(chapter, {})
    scene = SCENES.get(chapter, {})
    check(quest.get("map_id") == target,
          f"chapter {chapter} quest map is {quest.get('map_id')}, expected {target}")
    check(scene.get("required_map_id") == target,
          f"chapter {chapter} canonical scene is not {target}")
    route = scene.get("route_map_ids", [])
    check(isinstance(route, list) and len(route) > 0,
          f"chapter {chapter} missing physical route")
    for place in route:
        check(place in MAPS, f"chapter {chapter} unknown route map {place}")
        if place in MAPS:
            check(MAPS[place].get("region_id") == "region_coast",
                  f"chapter {chapter} must not unlock a distant region {place}")
    for source, destination in zip(route, route[1:]):
        if source in MAPS and destination in MAPS:
            check(destination in MAPS[source].get("neighbors", []) and
                  source in MAPS[destination].get("neighbors", []),
                  f"chapter {chapter} route {source}->{destination} not physically adjacent")
    check(target in route, f"chapter {chapter} destination absent from authored route")
    legacy = scene.get("legacy_route_map_ids", [])
    if legacy:
        check(legacy[-1] == target, f"chapter {chapter} old-save route has wrong destination")
        for source, destination in zip(legacy, legacy[1:]):
            check(source in MAPS and destination in MAPS and
                  destination in MAPS[source].get("neighbors", []) and
                  source in MAPS[destination].get("neighbors", []),
                  f"chapter {chapter} legacy path {source}->{destination} skips a physical exit")
check(SCENES.get(5, {}).get("route_map_ids") == ["map_coast_02", "map_coast_03"],
      "Chapter 5 current players must walk from the harbor to the shoal")
check(SCENES.get(5, {}).get("legacy_route_map_ids") ==
      ["map_coast_05", "map_coast_04", "map_coast_03"],
      "Chapter 5 old lighthouse save needs the cave return path")

# The first occurrence of an area in either an actual main quest or a
# chapter's traversable route determines the earliest legal visit.
earliest = {}
for chapter, target in EXPECTED.items():
    earliest[target] = min(chapter, earliest.get(target, 999))
for chapter, scene in SCENES.items():
    if chapter in EXPECTED:
        # Saved players can EXIT legacy positions via earlier-opened neighbors,
        # but legacy routes must never globally unlock later destinations.
        for place in scene.get("route_map_ids", []):
            if place in MAPS and MAPS[place].get("region_id") == "region_coast":
                earliest[place] = min(chapter, earliest.get(place, 999))
check(earliest.get("map_coast_03") == 3, "saltwind transit must be open by chapter 3")
check(earliest.get("map_coast_04") == 3, "cave must be open by chapter 3")
# Chapter 5 is the saltwind shoal. The keeper's lighthouse is the
# chapter-6 destination, not an early-access route or a chapter-5 shortcut.
check(earliest.get("map_coast_05") == 6,
      "lighthouse must first unlock in chapter 6, after the shoal")

# Simulate a legal chapter-3 adjacent path from the chapter-2 harbor, never
# allowing nonadjacent teleport or undiscovered distant-map shortcuts.
available = {m for m, first in earliest.items() if first <= 3}
queue = deque([("map_coast_02", ["map_coast_02"])])
found = None
visited = {"map_coast_02"}
while queue:
    area, route = queue.popleft()
    if area == "map_coast_04":
        found = route
        break
    for next_map in MAPS[area].get("neighbors", []):
        if next_map not in visited and next_map in available:
            visited.add(next_map)
            queue.append((next_map, route + [next_map]))
check(found == ["map_coast_02", "map_coast_03", "map_coast_04"],
      f"chapter 3 route to cave is not on foot: {found}")

if issues:
    raise SystemExit("FAIL Act-I canonical route gate:\n" + "\n".join(f" - {x}" for x in issues))
print("PASS Act-I: all six main-quest map anchors, authored neighboring routes, chapter-3 transit and early-access locks")
