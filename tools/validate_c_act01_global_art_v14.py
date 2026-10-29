#!/usr/bin/env python3
"""Validate the V14 first-act assignment registry AFTER V10 regeneration.

V14 scene IDs and exact map/Chapter ownership remain immutable; all physical
render images are now V10 generated-only PNGs. Pin every one to V10's SHA256,
not to a deleted and duplicate-filled source-pack inventory.
"""
from __future__ import annotations

import hashlib
import json
import struct
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
RUNTIME = "res://assets/art/runtime/generated_gaps_v10/"
EXPECTED = {"props": 10, "scenery": 6, "monsters": 9,
            "boss_candidates": 5, "terrain": 10, "backgrounds": 2, "ui": 3}
PREFIX = {"props": "prop.coast.", "scenery": "landmark.coast.",
          "monsters": "monster.coast.", "boss_candidates": "boss.coast.",
          "terrain": "terrain.coast.", "backgrounds": "background.coast.",
          "ui": "ui.game."}


def read(path):
    return json.loads((ROOT / path).read_text(encoding="utf-8"))


def flatten(category, values):
    if category == "terrain":
        for map_id, surfaces in values.items():
            for kind, path in surfaces.items():
                yield f"map_{int(map_id[-2:])}_{kind}", path
    elif category == "boss_candidates":
        # Authored boss IDs are boss.ch002..006, while generation names the
        # visual role chapter_2..6. Preserve one-to-one chapter identity.
        for boss_id, path in values.items():
            if not boss_id.startswith("boss.ch") or not boss_id[7:].isdigit():
                raise ValueError("Unexpected boss chapter ID: " + boss_id)
            yield "chapter_" + str(int(boss_id[7:])), path
    else:
        yield from values.items()


def audit():
    dist = read("data/assets/c_act01_global_distribution_v14.json")
    regenerated = read("assets/art/runtime/generated_gaps_v10/manifest.json")
    assert dist.get("schema") == "starlit.c.act01_global_distribution.v14"
    assert regenerated.get("schema") == "starlit.main2.gap_fill.v10"
    index = regenerated["assets"]
    assert isinstance(index, dict) and len(index) == regenerated["generated_count"]
    assert set(dist.get("maps", {})) == {f"map_coast_{i:02d}" for i in range(1, 6)}
    assert {int(row["chapter"]) for row in dist["chapter_routes"]} == set(range(1, 7))
    runtime = dist["runtime"]
    verified = set()
    for section, expected_count in EXPECTED.items():
        entries = dict(flatten(section, runtime[section]))
        assert len(entries) == expected_count, f"Missing live V14 mapping: {section}"
        for name, source in entries.items():
            identity = PREFIX[section] + name
            row = index.get(identity)
            if not isinstance(row, dict):
                raise ValueError("Missing exact generated identity: " + identity)
            if source != row.get("source") or not source.startswith(RUNTIME):
                raise ValueError("Source changed object identity: " + identity)
            asset = ROOT / source.removeprefix("res://")
            if not asset.is_file():
                raise ValueError("Generated source missing: " + source)
            data = asset.read_bytes()
            if len(data) < 24 or not data.startswith(b"\x89PNG\r\n\x1a\n"):
                raise ValueError("Invalid generated PNG: " + source)
            width, height = struct.unpack(">II", data[16:24])
            if not (8 <= width <= 8192 and 8 <= height <= 8192):
                raise ValueError("Invalid image dimensions: " + source)
            if row.get("dimensions") != [width, height]:
                raise ValueError("Wrong generated dimensions: " + source)
            if hashlib.sha256(data).hexdigest() != row.get("sha256"):
                raise ValueError("Generated file SHA mismatch: " + source)
            verified.add(source)
    assert len(verified) == 45, "Missing or duplicated V14 live image roles"
    code = (ROOT / "scripts/c_act01_global_art_v14.gd").read_text("utf-8")
    assert "RuntimeArt.texture_path(path)" in code and RUNTIME in code, "Scene adapter still rejects V10 sources"
    print(f"PASS: 5 maps, 6 chapters, {len(verified)} role-exact V10 images, verified SHA256; visual signoff pending")


if __name__ == "__main__":
    audit()
