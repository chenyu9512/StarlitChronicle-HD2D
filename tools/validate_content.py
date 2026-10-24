#!/usr/bin/env python3
"""Offline content integrity test, no external dependencies."""
from pathlib import Path
import json
root=Path(__file__).resolve().parents[1]
base=root/"data"/"content"
manifest=json.loads((base/"manifest.json").read_text(encoding="utf8"))
assert manifest["format"]=="starlit.content.v1"
tables={}
for entry in manifest["categories"]:
    category=entry["id"]
    raw=json.loads((base/(category+".json")).read_text(encoding="utf8"))
    assert raw["category"]==category and raw["format"]==manifest["format"]
    records=raw["entries"]
    assert len(records)==entry["count"]
    assert all(row.get("id") and row.get("name") for row in records)
    assert len({row["id"] for row in records})==len(records)
    tables[category]={row["id"]:row for row in records}
def check(category, key, origin):
    assert key in tables[category], f"{origin} references missing {category}:{key}"
for row in tables["maps"].values():
    check("regions",row["region_id"],row["id"])
    for neighbor in row["neighbors"]:check("maps",neighbor,row["id"])
    if row["scene_path"]:assert (root/row["scene_path"].removeprefix("res://")).is_file()
for row in tables["npcs"].values():
    check("regions",row["region_id"],row["id"])
    check("maps",row["map_id"],row["id"])
for category in ("monsters","bosses"):
    for row in tables[category].values():
        check("regions",row["region_id"],row["id"])
        for item in row.get("loot",row.get("drops",[])):
            check("items",item["item_id"],row["id"])
        assert (root/row["preview_fallback"].removeprefix("res://")).is_file()
for row in tables["quests"].values():
    check("regions",row["region_id"],row["id"])
    check("maps",row["map_id"],row["id"])
    if row["giver_id"]:check("npcs",row["giver_id"],row["id"])
    if row["target_id"]:check("bosses",row["target_id"],row["id"])
    if row["required_quest"]:check("quests",row["required_quest"],row["id"])
assert sorted(q["chapter"] for q in tables["quests"].values() if q["kind"]=="main")==list(range(1,73))
world=json.loads((base/"world.json").read_text(encoding="utf8"))
assert len(world["mother_lamps"])==7
for lamp in world["mother_lamps"]:check("regions",lamp["region_id"],lamp["id"])
print("Validated Starlit catalog: "+", ".join(f"{cat}={len(rows)}" for cat,rows in tables.items()))
