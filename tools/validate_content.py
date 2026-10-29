#!/usr/bin/env python3
"""Offline content integrity test, no external dependencies."""
from pathlib import Path
import json
root=Path(__file__).resolve().parents[1]
base=root/"data"/"content"

# Main2 maps deleted project-authored art slots to existing third-party PNGs.
# Validate the *physical* fallback source, not an intentionally retired path.
migration_file=root/"data"/"assets"/"c_third_party_only_migration_v1.json"
migrated_paths={}
if migration_file.is_file():
    migration=json.loads(migration_file.read_text(encoding="utf8"))
    for pair in migration.get("mappings",[]):
        former=str(pair.get("old_path",""))
        source=str(pair.get("new_source",""))
        if former and source:
            assert former not in migrated_paths,("duplicate migrated art id",former)
            migrated_paths[former]=source

def physical_resource_exists(value):
    assert value.startswith("res://"),value
    logical=value.removeprefix("res://")
    original=root/logical
    if original.is_file():
        return True
    replacement=migrated_paths.get(logical,"")
    assert replacement.startswith("assets/art/external/cc0_named_v1/"),(logical,replacement)
    assert ".." not in Path(replacement).parts,(logical,replacement)
    return (root/replacement).is_file()
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
        assert physical_resource_exists(row["preview_fallback"]),row["id"]
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

# The 72 canonical story IDs must stay distinct and in chapter order.
main_quests=sorted((q for q in tables["quests"].values() if q["kind"]=="main"),key=lambda q:q["chapter"])
assert [q.get("story_chapter_id") for q in main_quests]==[f"ch{i:03d}" for i in range(1,73)]
assert all(q.get("story_source") and q.get("complete_flag") for q in main_quests)
assert {lamp["name"] for lamp in world["mother_lamps"]}=={"潮歌母灯","律序母灯","炉心母灯","风航母灯","镜眠母灯","根忆母灯","天衡母灯"}
