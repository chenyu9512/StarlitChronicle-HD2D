#!/usr/bin/env python3
"""D world-coverage static gate: source-of-truth inventories; never changes content."""
import argparse
from collections import Counter
import json
from pathlib import Path


def audit(root: Path) -> dict:
    def read(p):
        return json.loads((root / p).read_text(encoding="utf-8-sig"))
    atlas = read("data/levels/world_atlas_v2.json")
    layouts = read("data/levels/world_levels_v3.json")["levels"]
    catalog = read("data/content/maps.json")["entries"]
    towns = read("data/levels/town_director_v4.json")["towns"]
    npcs = read("data/content/npcs.json")["entries"]
    zones = {x["id"]: x for x in atlas["zones"] if x.get("id") in layouts}
    active = {x["id"] for x in catalog if x.get("type") != "prototype"}
    errors, warnings = [], []
    if set(zones) != active or len(active) != 40:
        errors.append("40 active maps mismatch atlas, catalog and layouts")
    directed = [(zid, target) for zid, z in zones.items() for target in z.get("neighbors", [])]
    for start, target in directed:
        if target not in zones:
            errors.append(f"{start}: neighbor {target} not an active map")
        elif start not in zones[target].get("neighbors", []):
            errors.append(f"{start}->{target}: reverse gate absent")
    buildings = []
    for zid, zone in zones.items():
        dimensions = layouts[zid].get("size", [72, 48])
        unique = set()
        for building in zone.get("buildings", []):
            bid = building.get("id", "")
            door = building.get("door", [])
            if not bid or bid in unique:
                errors.append(f"{zid}: duplicate/invalid building id {bid}")
            unique.add(bid)
            if len(door) != 2 or not (2 <= door[0] < dimensions[0]-2 and
                                        2 <= door[1] < dimensions[1]-2):
                errors.append(f"{zid}#{bid}: invalid door coordinate")
            buildings.append({"map_id": zid, "building_id": bid,
                              "kind": building.get("kind", ""),
                              "door": door, "requires_godot": True})
        if zone.get("settlement", False) and zid not in towns:
            errors.append(f"{zid}: settlement has no town director")
    if len(towns) != 11 or len(buildings) != 66:
        errors.append("11-town/66-door authored count changed")
    by_id = {x["id"]: x for x in npcs}
    if len(npcs) != 40 or len(by_id) != 40:
        errors.append("40 stable NPC identity count mismatch")
    region_ids = {r["id"] for r in atlas.get("regions", [])}
    npc_records = []
    for person in npcs:
        npc_id = person["id"]
        if person.get("region_id") not in region_ids:
            errors.append(f"{npc_id}: unknown NPC region")
        routine = person.get("daily_routine", [])
        coverage = [0] * 1440
        for block in routine:
            begin, end = int(block["start"])*60, int(block["end"])*60
            if begin == end or begin < 0 or end > 1440:
                errors.append(f"{npc_id}: malformed routine block")
                continue
            for minute in range(1440):
                if (begin < end and begin <= minute < end) or (begin > end and
                        (minute >= begin or minute < end)):
                    coverage[minute] += 1
        if any(v != 1 for v in coverage):
            errors.append(f"{npc_id}: missing/overlapping daily routine minutes")
        npc_records.append({"id": npc_id, "region_id": person["region_id"],
                            "routine_blocks": len(routine), "runtime": "NOT_TESTED"})
    left, components = set(zones), []
    while left:
        origin = sorted(left)[0]
        queue = [origin]
        left.remove(origin)
        i = 0
        while i < len(queue):
            current = queue[i]; i += 1
            for neighbor in zones[current].get("neighbors", []):
                if neighbor in left:
                    left.remove(neighbor)
                    queue.append(neighbor)
        components.append(sorted(queue))
    if len(components) > 1:
        warnings.append(f"Ordinary exit graph has {len(components)} disconnected components; "
                        "story/script transfers not independently verified")
    interiors = list((root / "data/levels/v4/interiors").glob("*.json"))
    authored_buildings = 0
    for item in buildings:
        filename = f'{item["map_id"]}__{item["building_id"]}.json'
        if (root / "data/levels/v4/interiors" / filename).exists():
            authored_buildings += 1
    return {"status": "FAIL" if errors else "STATIC_PASS_RUNTIME_UNVERIFIED",
            "errors": errors, "warnings": warnings,
            "counts": {"active_maps": len(zones),"towns": len(towns),
                "buildings": len(buildings),"authored_normal_interiors":authored_buildings,
                "interior_json_total":len(interiors),"npcs":len(npcs),
                "directed_gates":len(directed),"undirected_gates":len(directed)//2,
                "graph_components":len(components)},
            "graph_components": components,"npc_coverage":npc_records,
            "building_coverage":buildings,
            "godot_entrance_exit_tests":"NOT_RUN",
            "godot_npc_life_tests":"NOT_RUN",
            "mobile_device_tests":"NOT_RUN"}


def main() -> int:
    p = argparse.ArgumentParser()
    p.add_argument("--root", type=Path, default=Path(__file__).resolve().parents[2])
    p.add_argument("--output", type=Path)
    p.add_argument("--strict", action="store_true")
    args = p.parse_args()
    try:
        report = audit(args.root)
    except (OSError, ValueError, KeyError, TypeError) as exc:
        report = {"status": "FAIL", "errors": [str(exc)]}
    if args.output:
        args.output.parent.mkdir(parents=True, exist_ok=True)
        args.output.write_text(json.dumps(report, ensure_ascii=False, indent=2)+"\n",
                               encoding="utf-8")
    else:
        print(json.dumps(report, ensure_ascii=False, indent=2))
    return int(args.strict and report["status"] == "FAIL")


if __name__ == "__main__":
    raise SystemExit(main())
