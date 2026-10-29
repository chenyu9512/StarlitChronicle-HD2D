#!/usr/bin/env python3
"""Audit source-to-runtime rowboat promotion and real game wiring (Main2 only)."""
import hashlib
import json
import struct
from pathlib import Path
from act01_source_provenance import verify_art

ROOT = Path(__file__).resolve().parent.parent
ORIGINAL = ROOT / "assets/art/source_packs/Golden-Horizon-2D-01-Sprites-Icons-Effects/2D/Prepared/Sprites/rowboat.png"
RUNTIME = ROOT / "assets/art/runtime/act01_matched_v16/dock_boat.png"
BRIDGE = "assets/art/external/cc0_named_v1/props/pixelkensei_structures/base/prop_pixelkensei_structures_04_wooden_bridge_32_x_32.png"


def git_blob_sha(content: bytes) -> str:
    payload = b"blob " + str(len(content)).encode("ascii") + b"\0" + content
    return hashlib.sha1(payload).hexdigest()


def check() -> dict:
    proof = verify_art("assets/art/runtime/act01_matched_v16/dock_boat.png", ORIGINAL.relative_to(ROOT))
    candidate = RUNTIME.read_bytes()
    if ORIGINAL.is_file() and ORIGINAL.read_bytes() != candidate:
        raise RuntimeError("Runtime rowboat does not contain the source PNG bytes")
    if candidate[:8] != bytes.fromhex("89504e470d0a1a0a") or len(candidate) < 24:
        raise RuntimeError("Curated rowboat is not a PNG")
    width, height = struct.unpack(">II", candidate[16:24])
    if not (8 <= width <= 8192 and 8 <= height <= 8192):
        raise RuntimeError(f"Invalid original rowboat image bounds: {width}x{height}")
    index = json.loads((ROOT / "data/assets/c_third_party_only_migration_v1.json").read_text(encoding="utf-8"))
    old = next((x for x in index["mappings"] if x.get("old_path") ==
                "assets/art/props/coast/dock_boat.png"), None)
    if old is None or old.get("new_source") != BRIDGE:
        raise RuntimeError("The historical dock-boat mismatch changed; review routing")
    script = (ROOT / "scripts/first_act_world.gd").read_text(encoding="utf-8")
    adapter = (ROOT / "scripts/c_act01_matched_props_v16.gd").read_text(encoding="utf-8")
    assert "CAct01MatchedProps.texture_for_prop(kind)" in script
    assert 'sprite.set_meta("act01_matched_source_v16", kind)' in script
    assert "res://assets/art/runtime/act01_matched_v16/dock_boat.png" in adapter
    assert 'if kind != "dock_boat":' in adapter
    return {"status": "PASS", "approved_kind": "dock_boat",
            "source_bytes": len(candidate), "width": width, "height": height,
            "same_git_blob_sha": git_blob_sha(candidate),
            "mismatched_legacy_bridge_bypassed": True}


if __name__ == "__main__":
    print(json.dumps(check(), sort_keys=True))
