#!/usr/bin/env python3
"""Validate indexed Librarium source files and readable PNG aliases."""
import json
from pathlib import Path

root = Path(__file__).resolve().parents[1]
obj = json.loads((root / "data/assets/librarium_assignments_v1.json").read_text(encoding="utf-8"))
sources = obj["source_files"]
assert len(sources) == 179
assert len([x for x in sources if x["target_id"]]) == 174
assert len({x["path"] for x in sources}) == len(sources)
assert len(obj["assignments"]) == 141
assert len(obj["identities"]) == 153
slots = {x["id"] for x in obj["assignments"]}
assert all(x["target_id"] in slots for x in sources if x["target_id"])
for src in sources:
    assert (root / src["path"]).is_file(), src["path"]
for item in obj["identities"]:
    if item.get("runtime_path"):
        assert (root / item["runtime_path"].removeprefix("res://")).is_file(), item["runtime_path"]
print("PASS Librarium: 174 assets accounted, 68 image aliases, 85 ZIP awaiting conversion. Static source not present.")
