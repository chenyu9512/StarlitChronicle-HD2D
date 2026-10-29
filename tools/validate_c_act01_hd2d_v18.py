#!/usr/bin/env python3
"""Validate actual V18 scene placement against hashed V10 generated art.

The previous source-pack SHA comparison was obsolete after intentional
third-party removal. This retains exact identity, image bytes, per-map roles,
collision-free presentation, terrain dimensions and zero orphan checks.
Procedural art remains unapproved for commercial visual signoff.
"""
from __future__ import annotations
import hashlib
import json
import struct
from collections import Counter
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
GAPS = "assets/art/runtime/generated_gaps_v10/"
ROLE_BY_MAP = {
    "map_coast_01": {"market-stall", "flower-fence", "great-oak", "flower-bench"},
    "map_coast_02": {"crate-stack", "barrel-cache", "market-stall", "flower-bench"},
    "map_coast_03": {"tide-pool-rocks", "barge-wreck", "rock-bank"},
    "map_coast_04": {"crystal-cache", "ruined-arch", "cliff-ledge", "rock-bank"},
    "map_coast_05": {"bench-lantern", "camp-banner"},
}


def read(path):
    return json.loads((ROOT / path).read_text(encoding="utf-8"))


def checked(role, source, source_index, size=None):
    row = source_index.get(role)
    assert isinstance(row, dict), f"V10 semantic identity missing: {role}"
    assert row.get("source") == source and source.startswith("res://" + GAPS), f"Source identity mismatch: {role}"
    target = ROOT / source.removeprefix("res://")
    assert target.is_file(), f"Runtime source missing: {source}"
    blob = target.read_bytes()
    assert blob.startswith(b"\x89PNG\r\n\x1a\n") and len(blob) >= 24, f"Invalid PNG: {source}"
    w, h = struct.unpack(">II", blob[16:24])
    assert 8 <= w <= 8192 and 8 <= h <= 8192, f"Invalid image dimensions: {source}"
    assert hashlib.sha256(blob).hexdigest() == row.get("sha256"), f"Image hash mismatch: {source}"
    assert row.get("dimensions") == [w, h], f"Image dimensions differ from V10: {source}"
    if size is not None:
        assert [w, h] == size, f"Wrong 8x8 atlas size: {source}"
    return source


def main():
    data = read("data/assets/c_act01_hd2d_v18.json")
    v10 = read(GAPS + "manifest.json")
    index = v10.get("assets", {})
    assert data.get("schema") == "starlit.c.act01_hd2d_v18"
    assert v10.get("schema") == "starlit.main2.gap_fill.v10"
    assert isinstance(index, dict) and len(index) == v10.get("generated_count")
    used = set()
    counts = Counter()
    ids = set()
    role_names = set()
    for row in data.get("placements", []):
        mid, kind = row["map_id"], row["kind"]
        assert mid in ROLE_BY_MAP and kind in ROLE_BY_MAP[mid], f"Wrong map/prop identity: {mid}/{kind}"
        assert row["id"] not in ids, f"Duplicate placed sprite: {row['id']}"
        ids.add(row["id"])
        assert row.get("visual_only") is True, f"V18 is not a collision-only art layer: {row['id']}"
        assert isinstance(row.get("cell"), list) and len(row["cell"]) == 2
        assert all(type(n) is int and 0 <= n < 128 for n in row["cell"])
        assert 32 <= row.get("max_width", 0) <= 192 and 32 <= row.get("max_height", 0) <= 210
        name = "prop.hd2d." + kind
        expected = "res://" + GAPS + "prop__hd2d__" + kind.replace("-", "_") + ".png"
        used.add(checked(name, row["source"], index))
        assert row["source"] == expected, f"Noncanonical V10 role/source: {kind}"
        counts[mid] += 1
        role_names.add(name)
    assert set(counts) == set(ROLE_BY_MAP) and min(counts.values()) >= 2
    assert len(data["placements"]) == 17 and len(role_names) == 14
    assert any(x["map_id"] == "map_coast_01" and x["kind"] == "great-oak" for x in data["placements"])
    material_names = set()
    for kind, source in data.get("materials", {}).items():
        role = "material.coast." + kind
        expected = "res://" + GAPS + "material__coast__" + kind.replace("-", "_") + ".png"
        assert source == expected
        used.add(checked(role, source, index, [256, 256]))
        material_names.add(role)
    assert len(material_names) == 11
    assert len(used) == 25, "All distinct first-act V18 textures must be accounted for"
    print(f"PASS: V18 {len(ids)} real placed sites / {len(role_names)} prop IDs / {len(material_names)} 256px materials; SHA256 and identity verified; visual approval not tested")


if __name__ == "__main__":
    main()
