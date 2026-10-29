#!/usr/bin/env python3
"""A-line static audit of the single Main2 runtime art registry.

Run from any directory: python tools/check_c_art_runtime_registry.py
Checks tracked file existence/identity and registry semantics. This does NOT
claim Godot import, live scene drawing, animation, aesthetic or visual QA.
"""
from __future__ import annotations

import hashlib
import json
from collections import defaultdict
from pathlib import Path
import subprocess
import sys
import struct

ROOT = Path(__file__).resolve().parents[1]
INDEX = ROOT / "data/assets/c_art_runtime_registry_v1.json"
KINDS = (".png", ".svg", ".jpg", ".jpeg", ".webp")
EXPECTED_REGIONS = {
    "region_coast", "region_oaths", "region_forge", "region_isles",
    "region_mirror", "region_oldland", "region_sanctum", "region_city",
}


def tracked_images() -> set[str]:
    try:
        result = subprocess.run(
            ["git", "ls-files", "-z", "--", "assets/art"],
            cwd=ROOT, check=True, capture_output=True,
        )
        paths = [p.decode("utf-8") for p in result.stdout.split(b"\0") if p]
        return {"res://" + p for p in paths if p.lower().endswith(KINDS)}
    except (FileNotFoundError, subprocess.CalledProcessError):
        return {
            "res://" + str(p.relative_to(ROOT)).replace("\\", "/")
            for p in (ROOT / "assets/art").rglob("*")
            if p.is_file() and p.suffix.lower() in KINDS
        }


def file_path(source: str) -> Path | None:
    if not isinstance(source, str) or not source.startswith("res://"):
        return None
    relative = Path(source[6:])
    if relative.is_absolute() or ".." in relative.parts:
        return None
    return ROOT / relative


def sha_blob(path: Path) -> str:
    data = path.read_bytes()
    prefix = b"blob " + str(len(data)).encode("ascii") + b"\0"
    return hashlib.sha1(prefix + data).hexdigest()


def main() -> int:
    errors: list[str] = []
    notes: list[str] = []
    index = json.loads(INDEX.read_text(encoding="utf-8"))
    if index.get("schema") != "starlit.c.art_runtime_registry.v1":
        errors.append("Wrong runtime registry schema")
    entries = index.get("sources", {})
    actual = tracked_images()
    recorded = set(entries)
    for path in sorted(actual - recorded):
        errors.append("Tracked image absent from registry: " + path)
    for path in sorted(recorded - actual):
        errors.append("Registry image not tracked: " + path)
    # Global Factory V3 is live: include both 451 declared images and its
    # 16 per-region ground/water atlases. A generated file is a registered
    # candidate, NOT evidence that a scene drew or approved that image.
    generated_root = "res://assets/art/runtime/global_factory_v3/"
    active_file = ROOT / "assets/art/runtime/global_factory_v3/active.json"
    generated_actual = {p for p in actual if p.startswith(generated_root)}
    generated_declared: set[str] = set()
    normal_declared: set[str] = set()
    live: dict = {}
    if not active_file.is_file():
        errors.append("Live factory active.json is absent")
    else:
        live = json.loads(active_file.read_text(encoding="utf-8"))
        if live.get("schema") != "starlit.global_factory.live.v3" or not live.get("enabled", False):
            errors.append("Global Factory V3 is not active")
        for slot, asset in live.get("assets", {}).items():
            path = asset.get("path", "")
            generated_declared.add(path)
            if path not in actual:
                errors.append("Generated manifest image missing: " + path)
            normal = asset.get("normal_map_path")
            if normal:
                group, dot, asset_id = slot.partition(".")
                expected = generated_root + "normal_maps/" + group + "/" + asset_id + "_n.png"
                if not dot or normal != expected:
                    errors.append("Wrong generated normal map binding: " + slot)
                normal_declared.add(normal)
                if normal not in actual:
                    errors.append("Generated normal map not tracked: " + normal)
                local = file_path(normal)
                diffuse = file_path(path)
                if local is None or diffuse is None or not local.is_file() or not diffuse.is_file():
                    errors.append("Generated normal map or diffuse image absent: " + slot)
                else:
                    checksum = hashlib.sha256(local.read_bytes()).hexdigest()
                    if checksum != asset.get("normal_map_sha256"):
                        errors.append("Generated normal map SHA mismatch: " + slot)
                    nh = local.read_bytes()[:24]
                    dh = diffuse.read_bytes()[:24]
                    png_magic = bytes((137, 80, 78, 71, 13, 10, 26, 10))
                    if not (nh.startswith(png_magic) and dh.startswith(png_magic) and
                            nh[16:24] == dh[16:24]):
                        errors.append("Generated normal map dimensions differ: " + slot)
        if live.get("asset_count") != len(generated_declared):
            errors.append("Generated manifest count does not match its assets")
    expected_terrain = {
        generated_root + "terrain/" + rid + "_" + kind + ".png"
        for rid in EXPECTED_REGIONS for kind in ("ground", "water")
    }
    for path in sorted(expected_terrain - actual):
        errors.append("Generated regional atlas missing: " + path)
    unexpected_generated = generated_actual - generated_declared - expected_terrain - normal_declared
    for path in sorted(unexpected_generated):
        errors.append("Generated image not covered by factory contract: " + path)

    # The authoritative generated-source resolver must mirror live active.json.
    declared_index = index.get("generated_assets", {})
    expected_index_paths = generated_declared | expected_terrain
    indexed_paths = {meta.get("source", "") for meta in declared_index.values()}
    for path in sorted(expected_index_paths - indexed_paths):
        errors.append("Generated runtime source absent from canonical index: " + path)
    for path in sorted(indexed_paths - expected_index_paths):
        errors.append("Canonical generated source absent from active manifest: " + path)
    for key, meta in declared_index.items():
        path = meta.get("source", "")
        category, dot, name = key.partition(".")
        expected_path = generated_root + category + "/" + name + ".png"
        if not dot or path != expected_path:
            errors.append("Wrong generated semantic-to-file binding: " + key)
        if path in generated_declared:
            source_meta = live.get("assets", {}).get(key, {})
            if source_meta.get("path") != path or source_meta.get("sha256") != meta.get("manifest_sha256"):
                errors.append("Generated checksum/identity metadata mismatch: " + key)
            else:
                local = file_path(path)
                if local is not None and local.is_file():
                    checksum = hashlib.sha256(local.read_bytes()).hexdigest()
                else:
                    checksum = ""
                if checksum != meta["manifest_sha256"]:
                    errors.append("Changed generated PNG checksum: " + key)
        local = file_path(path)
        if path in expected_terrain and local is not None and local.is_file():
            header = local.read_bytes()[:24]
            if not header.startswith(b"\x89PNG\r\n\x1a\n") or struct.unpack(">II", header[16:24]) != (256, 256):
                errors.append("Non-256x256 generated regional atlas: " + key)

    hashes: dict[str, list[str]] = defaultdict(list)
    for source, row in entries.items():
        local = file_path(source)
        if local is None or not local.is_file():
            errors.append("Physical image absent: " + source)
            continue
        if not row.get("physically_present", False):
            errors.append("Physical image misclassified: " + source)
        blob_sha = sha_blob(local)
        hashes[blob_sha].append(source)
        if row.get("sha") != blob_sha:
            errors.append("Git blob checksum mismatch: " + source)
        if row.get("drawn_in_scene") == "成功" or row.get("visual_correct") == "成功":
            notes.append("Manually reconfirm success evidence: " + source)

    def must_exist(label: str, source: str) -> None:
        if source not in actual:
            errors.append(label + " references missing image: " + str(source))

    wave_sources=index.get("shore_wave_sources",{})
    if len(wave_sources)!=8:
        errors.append("Eight directional live shoreline wave strips missing")
    for key,source in wave_sources.items():
        must_exist("live shoreline wave "+key,source)
    motion_map = index.get("boss_motion_sources", {})
    if len(motion_map) != 66:
        errors.append("66 canonical boss motion routes are missing")
    for name, source in motion_map.items():
        must_exist("boss animation " + str(name), source)
        local = file_path(source)
        if local is not None and local.is_file():
            header = local.read_bytes()[:24]
            if not header.startswith(b"\x89PNG\r\n\x1a\n") or struct.unpack(">II",header[16:24]) != (512,768):
                errors.append("Wrong 4x6 boss action sprite sheet: " + str(name))
    source_only = index.get("source_candidate_pool", {})
    unresolved = {path for path,row in entries.items() if not row.get("registered",False)}
    if set(source_only) != unresolved:
        errors.append("Unregistered real source files not exhaustively catalogued")
    for path, item in source_only.items():
        must_exist("source-only art " + path, path)
        if item.get("in_game_binding") != "not_approved":
            errors.append("Unapproved source masquerades as live art: " + path)
    for name, source in index.get("scene_detail_sources", {}).items():
        must_exist("scene detail " + str(name), source)
    for slot, entry in index.get("canonical_slots", {}).items():
        must_exist("slot " + slot, entry.get("source", ""))
    for old, target in index.get("verified_legacy_redirects", {}).items():
        if not old.startswith("res://assets/"):
            errors.append("Unsafe legacy alias key: " + old)
        must_exist("approved redirect " + old, target)
    for name, source in index.get("ui", {}).items():
        must_exist("UI " + name, source)
    for name, source in index.get("content_icons", {}).items():
        must_exist("content icon " + name, source)
    for name, source in index.get("monster_id_sources", {}).items():
        must_exist("monster " + name, source)

    regions = index.get("regions", {})
    if set(regions) != EXPECTED_REGIONS:
        errors.append("Eight regional identities not preserved")
    for region_id, record in regions.items():
        terrain = record.get("terrain", {})
        for kind in ("ground", "water"):
            path = terrain.get(kind, "")
            if not path.startswith("res://assets/art/") or ".." in path:
                errors.append("Invalid logical atlas " + region_id + "/" + kind)
            else:
                must_exist("region terrain " + region_id + "/" + kind, path)
        for category in ("scene_props", "material_preview", "building_bindings",
                         "npc_identity_bindings", "boss_identity_bindings"):
            for name, source in record.get(category, {}).items():
                must_exist(region_id + " " + category + " " + name, source)
        for path in record.get("unique_monster_candidates", []):
            must_exist(region_id + " monster candidate", path)
        if record.get("boss_identity_bindings"):
            notes.append("Boss identity bindings need separate visual/canon QA: " + region_id)

    duplicates = [v for v in hashes.values() if len(v) > 1]
    report = {
        "schema": "starlit.a_line.static_audit.v1",
        "tracked_images": len(actual),
        "boss_motion_sheet_count": len(index.get("boss_motion_sources",{})),
        "source_candidate_pool_count":len(index.get("source_candidate_pool",{})),
        "factory_images": len(generated_actual),
        "factory_manifest_images": len(generated_declared),
        "factory_normal_maps": len(normal_declared),
        "factory_terrain_images": len(expected_terrain & actual),
        "indexed_generated_images": len(declared_index),
        "registry_images": len(entries),
        "registered_images": sum(bool(x.get("registered")) for x in entries.values()),
        "unverified_registration": sum(not bool(x.get("registered")) for x in entries.values()),
        "theme_slots": len(index.get("canonical_slots", {})),
        "regions": len(regions),
        "content_icon_ids": len(index.get("content_icons", {})),
        "monster_ids": len(index.get("monster_id_sources", {})),
        "approved_legacy_aliases": len(index.get("verified_legacy_redirects", {})),
        "same_blob_groups_retained": len(duplicates),
        "errors": errors,
        "notes": notes,
        "godot_run": "未测试",
        "visual_acceptance": "未测试",
    }
    print(json.dumps(report, ensure_ascii=False, indent=2))
    return 1 if errors else 0


if __name__ == "__main__":
    sys.exit(main())
