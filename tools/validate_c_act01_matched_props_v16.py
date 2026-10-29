#!/usr/bin/env python3
"""Validate the dock boat's actual generated ID, PNG integrity and live binding.

The prior V16 source-pack boat and its migration JSON were deliberately purged.
Never validate a deleted physical file or accept a mismatched wooden bridge.
"""
from __future__ import annotations
import hashlib
import json
import struct
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
ID = "prop.harbor.dock_boat"
SOURCE = "res://assets/art/runtime/generated_gaps_v10/prop__harbor__dock_boat.png"


def check() -> dict:
    manifest = json.loads((ROOT / "assets/art/runtime/generated_gaps_v10/manifest.json").read_text("utf-8"))
    registry = json.loads((ROOT / "data/assets/c_art_runtime_registry_v1.json").read_text("utf-8"))
    theme = json.loads((ROOT / "data/assets/art_theme_v2.json").read_text("utf-8"))
    assert manifest["schema"] == "starlit.main2.gap_fill.v10"
    item = manifest["assets"].get(ID)
    assert isinstance(item, dict) and item.get("source") == SOURCE, "Missing exact dock boat asset identity"
    assert registry["canonical_slots"][ID]["source"] == SOURCE
    assert theme["themes"][0]["slots"][ID]["source"] == SOURCE
    target = ROOT / SOURCE.removeprefix("res://")
    assert target.is_file(), f"Dock boat PNG absent: {target}"
    data = target.read_bytes()
    assert len(data) >= 24 and data[:8] == b"\x89PNG\r\n\x1a\n"
    w, h = struct.unpack(">II", data[16:24])
    assert 32 <= w <= 512 and 32 <= h <= 512
    assert item.get("dimensions") == [w, h]
    assert hashlib.sha256(data).hexdigest() == item["sha256"]
    script = (ROOT / "scripts/first_act_world.gd").read_text("utf-8")
    adapter = (ROOT / "scripts/c_act01_matched_props_v16.gd").read_text("utf-8")
    assert "CAct01MatchedProps.texture_for_prop(kind)" in script
    assert 'sprite.set_meta("act01_matched_source_v16", kind)' in script
    assert 'var source: String = RuntimeArt.slot_source(DOCK_SLOT)' in adapter
    assert SOURCE in adapter
    assert 'if kind != "dock_boat":' in adapter
    return {"status": "PASS", "asset_id": ID, "width": w, "height": h,
            "sha256": item["sha256"], "retired_bridge_not_used": True,
            "human_visual_approval": "not_tested"}


if __name__ == "__main__":
    print(json.dumps(check(), ensure_ascii=False, sort_keys=True))
