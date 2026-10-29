#!/usr/bin/env python3
"""First-act content and generated-only runtime art integrity.

No dependency on deleted uploaded/source-pack artwork. This validates the
actual active V3 art manifest with SHA256 and matching canonical IDs; it does
not claim that procedural artwork has passed human visual acceptance.
"""
from __future__ import annotations

import hashlib
import json
import struct
from pathlib import Path

root = Path(__file__).resolve().parents[1]


def read(path: str) -> dict:
    result = json.loads((root / path).read_text(encoding="utf-8"))
    assert isinstance(result, dict), f"Invalid JSON object: {path}"
    return result


def image(path: str, expected: str) -> None:
    assert path.startswith("res://assets/art/runtime/global_factory_v3/") and ".." not in Path(path).parts, path
    source = root / path.removeprefix("res://")
    assert source.is_file(), f"Generated runtime PNG missing: {path}"
    data = source.read_bytes()
    assert data.startswith(b"\x89PNG\r\n\x1a\n") and len(data) >= 24, f"Invalid PNG: {path}"
    width, height = struct.unpack(">II", data[16:24])
    assert 8 <= width <= 8192 and 8 <= height <= 8192, f"Invalid PNG dimensions: {path}"
    assert hashlib.sha256(data).hexdigest() == expected, f"Art SHA mismatch: {path}"


assert (root / "scenes/first_act.tscn").is_file()
assert 'run/main_scene="res://scenes/first_act.tscn"' in (root / "project.godot").read_text("utf-8")
for name in ("first_act", "first_act_state", "first_act_actor", "first_act_world", "first_act_ui", "first_act_battle", "global_generated_art_v3"):
    assert (root / "scripts" / (name + ".gd")).is_file(), f"Missing runtime controller: {name}"

active = read("assets/art/runtime/global_factory_v3/active.json")
registry = read("data/assets/c_art_runtime_registry_v1.json")
assets = active.get("assets", {})
generated = registry.get("generated_assets", {})
counts = active.get("counts", {})
assert active.get("schema") == "starlit.global_factory.live.v3" and active.get("enabled") is True
assert registry.get("schema") == "starlit.c.art_runtime_registry.v1"
assert isinstance(assets, dict) and len(assets) == active.get("asset_count") == 451
assert sum(counts.values()) == 451
for group, minimum in (("characters", 12), ("npcs", 35), ("monsters", 63),
                       ("bosses", 66), ("maps", 42), ("interiors", 153), ("terrain", 8)):
    assert counts.get(group, 0) >= minimum, f"Insufficient generated {group}"
normal_maps = 0
for identity, row in assets.items():
    group, separator, asset_id = identity.partition(".")
    assert separator and group in counts and asset_id, f"Malformed identity: {identity}"
    expected = f"res://assets/art/runtime/global_factory_v3/{group}/{asset_id}.png"
    assert row.get("path") == expected, f"Generated ID routed to wrong image: {identity}"
    assert generated.get(identity, {}).get("source") == expected, f"Runtime registry not bound to generated ID: {identity}"
    assert generated[identity].get("manifest_sha256") == row.get("sha256"), f"Registry SHA mismatch: {identity}"
    image(expected, row.get("sha256"))
    normal = row.get("normal_map_path")
    if normal:
        assert normal == f"res://assets/art/runtime/global_factory_v3/normal_maps/{group}/{asset_id}_n.png"
        image(normal, row.get("normal_map_sha256"))
        normal_maps += 1
assert normal_maps == active.get("normal_map_count"), "Missing generated normal maps"

chapters = read("story/campaign/act_01.json")["chapters"]
assert len(chapters) == 6 and [c["id"] for c in chapters] == [f"ch{i:03d}" for i in range(1, 7)]
for i, chapter in enumerate(chapters, 1):
    scenes = chapter.get("scenes", [])
    assert len(scenes) == 4, f"Chapter {i} must retain four player phases"
    assert [s["id"] for s in scenes] == [f"ch{i:03d}.{phase}" for phase in ("opening", "investigate", "crisis", "resolve")]
    assert len(scenes[0].get("dialogue", [])) >= 5
    assert len(scenes[2].get("choice", {}).get("options", [])) == 2
    assert scenes[0]["objectives"][1]["target"] == f"ch{i:03d}.key_npc"
    assert scenes[1]["objectives"][0]["target"] == f"ch{i:03d}.clue"
    assert scenes[1]["objectives"][1]["target"] == f"ch{i:03d}.witness"
    assert scenes[2]["objectives"][0]["target"] == f"ch{i:03d}.choice"
    if i > 1:
        assert scenes[2]["encounter"]["enemy_id"] == f"boss.ch{i:03d}"
        assert scenes[3]["trigger"]["requires_flags"] == [f"ch{i:03d}.battle_won"]
    else:
        assert scenes[2]["encounter"] is None
    assert scenes[3]["objectives"][0]["target"] == chapter["id"]
assert len(read("story/campaign/prologue.json")["scenes"]) == 9
bosses = {row["id"] for row in read("story/data/bosses.json")["bosses"]}
assert all(f"boss.ch{i:03d}" in bosses for i in range(2, 7))
quests = read("data/first_act_side_quests.json")["quests"]
assert len(quests) == 6 and [q["chapter"] for q in quests] == list(range(1, 7))
for quest in quests:
    assert all(quest.get(field) for field in ("id", "name", "start", "find", "finish"))
print(f"PASS: first-act canonical content + {len(assets)} hashed generated images + {normal_maps} hashed normals; actual Godot visual/player QA separate")
