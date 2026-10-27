#!/usr/bin/env python3
"""Act I global art distribution: verify real sources, exact SHA aliases, map coverage."""
import hashlib
import json
from pathlib import Path

root = Path(__file__).resolve().parent.parent
manifest = json.loads((root / "data/assets/c_act01_global_distribution_v14.json").read_text("utf-8"))
assert manifest["schema"] == "starlit.c.act01_global_distribution.v14"
rows = manifest["source_index"]
assert len(rows) == manifest["counts"]["source_files"]
assert len({r["source"] for r in rows}) == len(rows)
runtimes = [r for r in rows if "game_path" in r]
assert len(runtimes) == manifest["counts"]["physical_aliases"]
assert set(manifest["maps"]) == {f"map_coast_{i:02d}" for i in range(1,6)}
assert set(c["chapter"] for c in manifest["chapter_routes"]) == set(range(1,7))
for row in rows:
    source = root / row["source"]
    assert source.is_file(), f"Missing source: {source}"
    if "game_path" in row:
        target = root / row["game_path"].removeprefix("res://")
        assert target.is_file(), f"Missing imported runtime: {target}"
        digest = lambda p: hashlib.sha256(p.read_bytes()).hexdigest()
        assert digest(source) == digest(target), f"Alias corruption: {target}"
for section in ["props", "scenery", "monsters", "boss_candidates"]:
    for name,path in manifest["runtime"][section].items():
        assert (root / path.removeprefix("res://")).is_file(), (section,name)
print("PASS: Act I source catalog, runtime aliases, chapter/map coverage and file integrity.")
