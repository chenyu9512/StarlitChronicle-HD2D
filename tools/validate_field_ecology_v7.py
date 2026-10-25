#!/usr/bin/env python3
"""Static V7 wilderness-contract audit; requires only Python stdlib.
Godot scene generation, reachability, save restoration and live payouts are
separate Godot smoke assertions, never inferred from this static check.
"""
from __future__ import annotations
import json
from collections import Counter
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
def load(path: str):
    return json.loads((ROOT / path).read_text(encoding="utf-8"))
data = load("data/levels/v7/field_ecology.json")
atlas = load("data/levels/world_atlas_v2.json")
levels = load("data/levels/world_levels_v3.json")["levels"]
items = {x["id"] for x in load("data/content/items.json")["entries"]}
props = {path.stem for path in (ROOT / "assets/art/props/coast").glob("*.png")}
wanted = {z["id"]: z["biome"] for z in atlas["zones"]
          if z.get("archetype") in {"field", "route", "landmark"}
          and not z["id"].startswith("map_city_")}
maps = data["maps"]
assert data["schema"] == "starlit.field_ecology.v7"
assert len(wanted) == len(maps) == 21 and set(wanted) == set(maps)
assert len({r["challenge"]["title"] for r in maps.values()}) == 21
assert len({r["secret"]["title"] for r in maps.values()}) == 21
interaction_count = scenery_count = 0
for map_id, spec in maps.items():
    assert spec["biome"] == wanted[map_id], map_id
    width, height = levels[map_id]["size"]
    sites = spec["sites"]
    assert len(sites) == 4, map_id
    assert {s["id"] for s in sites} == {"trial", "gather", "passage", "cache"}, map_id
    assert len({tuple(s["cell"]) for s in sites}) == 4, map_id
    for site in sites:
        interaction_count += 1
        x, y = site["cell"]
        assert 4 <= x < width-4 and 4 <= y < height-4, (map_id, site)
        assert site["icon"] in props, (map_id, site["icon"])
    assert spec["gather"]["item_id"] in items and spec["reward"]["item_id"] in items
    assert spec["challenge"]["danger_weather"] in {"rain","mist","ash"}
    assert spec["secret"]["opening_weather"] in {"rain","mist","ash","clear"}
    assert spec["secret"]["opening_time"] in {"dawn","day","dusk","night"}
    assert 50 <= spec["challenge"]["speed_pct"] <= 100
    assert spec["challenge"]["hp_cost"] > 0
    decorations = spec["scenery"]
    assert len(decorations) == 16, map_id
    scenery_count += len(decorations)
    for art in decorations:
        x, y = art["cell"]
        assert 3 <= x < width-3 and 3 <= y < height-3, (map_id, art)
        assert art["kind"] in props, (map_id, art["kind"])
assert interaction_count == 84 and scenery_count == 336
print(f"PASS: 21 authored wilderness maps / {interaction_count} interactions / {scenery_count} biome scene fixtures; zero schema, item, asset or extent errors")
