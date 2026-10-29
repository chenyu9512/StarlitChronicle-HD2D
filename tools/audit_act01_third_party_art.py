#!/usr/bin/env python3
"""Act-I generated-only migration QA.

The old third-party-only V11/Migration catalogs were intentionally deleted.
Check the current identity-aware runtime assets and all 6 chapter scene
contracts, not a deleted source index. This is not visual approval.
"""
from __future__ import annotations

import argparse
import hashlib
import json
import struct
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
RUNTIME = "assets/art/runtime/"
THEME = "data/assets/art_theme_v2.json"
INDEX = "data/assets/c_art_runtime_registry_v1.json"
PACKS = "data/assets/c_art_packs.json"


def load(name: str) -> dict:
    obj = json.loads((ROOT / name).read_text(encoding="utf-8"))
    if not isinstance(obj, dict):
        raise ValueError("Expected JSON object: " + name)
    return obj


def verify_image(path: str, sha: str | None = None) -> None:
    if not path.startswith("res://" + RUNTIME) or ".." in Path(path).parts:
        raise ValueError("Noncanonical/misrouted runtime image: " + path)
    target = ROOT / path.removeprefix("res://")
    if not target.is_file():
        raise ValueError("Missing canonical runtime image: " + path)
    with target.open("rb") as handle:
        header = handle.read(24)
    if len(header) < 24 or header[:8] != b"\x89PNG\r\n\x1a\n" or header[12:16] != b"IHDR":
        raise ValueError("Malformed PNG: " + path)
    w, h = struct.unpack(">II", header[16:24])
    if not (8 <= w <= 8192 and 8 <= h <= 8192):
        raise ValueError("Unusable image dimensions: " + path)
    if sha and hashlib.sha256(target.read_bytes()).hexdigest() != sha:
        raise ValueError("Runtime image SHA256 differs from manifest: " + path)


def audit() -> dict:
    theme = load(THEME)
    registry = load(INDEX)
    pack = load(PACKS)
    gaps = load(RUNTIME + "generated_gaps_v10/manifest.json")
    assert theme.get("schema") == "starlit.art_theme.v2"
    assert registry.get("schema") == "starlit.c.art_runtime_registry.v1"
    assert pack.get("schema") == "starlit.c.art_packs.v1" and pack.get("packs") == [], "Retired uploads remain enabled"
    assert gaps.get("schema") == "starlit.main2.gap_fill.v10"
    assert gaps.get("generated_count") == len(gaps.get("assets", {}))
    assert not (ROOT / "assets/art/external").exists(), "Removed third-party source images were restored"
    themes = theme.get("themes", [])
    assert len(themes) == 1
    slots = themes[0].get("slots", {})
    assert len(slots) == 109 and len(registry.get("canonical_slots", {})) == 109
    checked = set()
    for name, row in slots.items():
        source = row.get("source", "")
        assert registry["canonical_slots"][name]["source"] == source, f"Theme/registry route mismatch: {name}"
        if source not in checked:
            v10 = next((item for item in gaps["assets"].values() if item.get("source") == source), None)
            verify_image(source, v10.get("sha256") if v10 else None)
            checked.add(source)
    for chapter in range(1, 7):
        data = load(f"story/campaign/act_01.json") if chapter == 1 else None
        if chapter == 1:
            assert len(data.get("chapters", [])) == 6, "First act chapter count changed"
    for room in ("map_coast_02__shelter", "map_coast_02__tavern"):
        v4 = load(f"data/levels/v4/interiors/{room}.json")
        assert v4.get("schema") == "starlit.interior.v4" and len(v4.get("visuals", [])) >= 8
    approved = sum(str(row.get("stage", "")) == "commercial_visual_accepted" for row in slots.values())
    return {"status": "success", "runtime_semantic_sources_verified": len(checked),
            "official_slots": len(slots), "chapters": 6, "source_provenance": "new_generated_runtime",
            "retired_third_party_packs": 0, "commercially_approved_slots": approved,
            "visual_acceptance": "not_tested"}


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--require-commercial", action="store_true")
    args = parser.parse_args()
    result = audit()
    print(json.dumps(result, ensure_ascii=False))
    if args.require_commercial and result["commercially_approved_slots"] != result["official_slots"]:
        print("FAIL: first-act visual identity/scene placement not commercially approved")
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
