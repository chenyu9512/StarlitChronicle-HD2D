#!/usr/bin/env python3
"""Read-only C V6 allocation and content-icon path/identity validator."""
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent

def read(path):
    with (ROOT / path).open(encoding="utf-8") as file:
        return json.load(file)

def validate():
    candidate=read("assets/art/candidates/manifest.json")
    external=read("data/assets/external_cc0_named_index.json")
    selection=read("data/assets/c_art_selection.json")
    assign=read("data/assets/c_art_allocation_v6.json")
    icons=read("data/assets/c_art_content_icons_v6.json")
    expected = set(e["source"] for e in candidate["entries"]) | set(x["path"] for x in external["assets"]) | set("res://"+x for x in selection["reserve_core"])
    rows=assign["rows"]
    assert len(rows)==1885 and len(expected)==1885 and {x["source"] for x in rows}==expected, "Missing/untracked allocation"
    maps=read("data/content/maps.json")["entries"]
    regions=read("data/content/regions.json")["entries"]
    map_ids={m["id"] for m in maps}
    region_ids={r["id"] for r in regions}
    for row in rows:
        assert row["map_id"] in map_ids and row["region"] in region_ids, row
        path=row["source"]
        assert path.startswith("res://assets/") and ".." not in path, path
        assert (ROOT / path[6:]).is_file(), path
    pools = ["items","weapons","armor","skills"]
    content_ids={r["id"] for cat in pools for r in read("data/content/"+cat+".json")["entries"]}
    registered={x["path"] for x in external["assets"]}
    icon_rows=icons["records"]
    assert len(icon_rows)==len(content_ids)==288
    assert {row["id"] for row in icon_rows}==content_ids
    for row in icon_rows:
        assert row["icon"] in registered and (ROOT / row["icon"][6:]).is_file(), row
    assert len(candidate["entries"])==746
    for entry in candidate["entries"]:
        a=entry["allocation_v6"]
        assert a["region_id"] in region_ids and a["map_id"] in map_ids
    print(f"SUCCESS: {len(rows)} allocated source/core/external records; {len(icon_rows)} runtime UI content icon IDs")

if __name__=="__main__":
    validate()
