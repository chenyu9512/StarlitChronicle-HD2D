#!/usr/bin/env python3
"""Synchronize A-line Main2 runtime art registry against the staged Git tree.

Must run after installer, after 'git add -A assets/art'. Never asserts that
generated candidate images passed visual, identity or scene-rendering QA.
"""
from __future__ import annotations
import argparse
import hashlib
import json
import subprocess
from pathlib import Path

EXT = {".png", ".svg", ".jpg", ".jpeg", ".webp"}
REGIONS = (
    "region_coast", "region_oaths", "region_forge", "region_isles",
    "region_mirror", "region_oldland", "region_sanctum", "region_city",
)
FACTORY = "res://assets/art/runtime/global_factory_v3/"
GROUPS = {"terrain", "ui", "props", "maps", "interiors",
          "characters", "npcs", "monsters", "bosses"}
ROLES = ("tree", "cottage", "shop", "shrine", "well", "lantern", "crate", "banner")


def read(path: Path) -> dict:
    data = json.loads(path.read_text(encoding="utf-8-sig"))
    if not isinstance(data, dict):
        raise ValueError(f"Not a JSON mapping: {path}")
    return data


def tracked(root: Path) -> dict[str, str]:
    result = subprocess.run(
        ["git", "ls-files", "-z", "--", "assets/art"],
        cwd=root, capture_output=True, check=True,
    )
    paths = [p.decode("utf-8", "surrogateescape")
             for p in result.stdout.split(b"\0") if p]
    out = {}
    for name in paths:
        file = root / name
        if file.suffix.lower() not in EXT or not file.is_file():
            continue
        data = file.read_bytes()
        gitblob = b"blob " + str(len(data)).encode("ascii") + b"\0" + data
        out["res://" + name.replace("\\", "/")] = hashlib.sha1(gitblob).hexdigest()
    return dict(sorted(out.items()))


def synchronize(root: Path) -> dict:
    registry_file = root / "data/assets/c_art_runtime_registry_v1.json"
    current = read(registry_file)
    if current.get("schema") != "starlit.c.art_runtime_registry.v1":
        raise ValueError("Unexpected A-line registry schema")
    active = read(root / "assets/art/runtime/global_factory_v3/active.json")
    if active.get("schema") != "starlit.global_factory.live.v3" or not active.get("enabled"):
        raise ValueError("Generated V3 must be enabled before index promotion")
    physical = tracked(root)
    generated = {}
    groups = {}
    manifest = active.get("assets", {})
    if not isinstance(manifest, dict) or len(manifest) != active.get("asset_count"):
        raise ValueError("Global factory manifest count mismatch")
    for slot, data in manifest.items():
        parts = slot.split(".")
        if len(parts) != 2 or parts[0] not in GROUPS:
            raise ValueError("Unexpected generated semantic slot: " + slot)
        group, identifier = parts
        source = data.get("path", "")
        if source != FACTORY + group + "/" + identifier + ".png" or source not in physical:
            raise ValueError("Generated source missing/incorrect: " + slot)
        generated[slot] = {
            "source": source, "group": group,
            "manifest_sha256": data["sha256"],
            "provenance": data.get("provenance", "generated_procedural_candidate"),
            "stage": "generated_procedural_candidate_visual_qa_pending",
        }
        groups[group] = groups.get(group, 0) + 1
    for region in REGIONS:
        for kind in ("ground", "water"):
            name = region + "_" + kind
            key = "terrain." + name
            source = FACTORY + "terrain/" + name + ".png"
            if source not in physical:
                raise ValueError("Generated 8x8 terrain atlas is missing: " + source)
            generated[key] = {
                "source": source, "group": "terrain", "canvas": [256, 256],
                "provenance": "generated_runtime_atlas",
                "stage": "runtime_atlas_pending_visual_qa",
            }

    old = current.get("sources", {})
    generated_by_path = {item["source"]: item for item in generated.values()}
    sources = {}
    detail_roots = {k: v for k, v in read(root / "assets/art/runtime/scene_details_v1/manifest.json").get("assets", {}).items()}
    for name, image_path in detail_roots.items():
        if image_path not in physical:
            raise ValueError("Missing actual scene detail image: " + str(name) + " -> " + image_path)
    current["scene_detail_sources"] = detail_roots
    icon_manifest = read(root / "assets/art/runtime/content_icons_v1/manifest.json")
    if icon_manifest.get("schema") != "starlit.content_icons.runtime.v1" or icon_manifest.get("count") != 288:
        raise ValueError("Content icon manifest must contain exactly 288 IDs")
    icon_assets = icon_manifest.get("assets", {})
    expected_icons = read(root / "data/assets/c_art_content_icons_v6.json")["records"]
    if len(icon_assets) != 288 or set(icon_assets) != {row["id"] for row in expected_icons}:
        raise ValueError("Generated content icons do not match canonical content IDs")
    icon_paths = {item["source"] for item in icon_assets.values()}
    if not icon_paths.issubset(set(physical)) or len(icon_paths) != 288:
        raise ValueError("Not all 288 generated content icon PNGs exist")
    for path, sha in physical.items():
        previous = old.get(path, {})
        produced = path.startswith(FACTORY)
        same_blob = previous.get("sha") == sha
        sources[path] = {
            "sha": sha, "physically_present": True,
            "registered": produced or path in detail_roots.values() or path in icon_paths or bool(previous.get("registered", False)),
            "code_reference": ("generated_semantic_resolver" if produced else
                               "scene_detail_runtime_renderer" if path in detail_roots.values() else
                               "generated_content_icon_lookup" if path in icon_paths else
                               previous.get("code_reference", "not_confirmed")),
            "drawn_in_scene": previous.get("drawn_in_scene", "未测试") if same_blob else "未测试",
            "visual_correct": previous.get("visual_correct", "未测试") if same_blob else "未测试",
            "tier": ("generated_runtime" if produced else
                     "runtime" if "/runtime/" in path else
                     "external" if "/external/" in path else "other"),
        }
        if produced:
            sources[path]["provenance"] = generated_by_path.get(path, {}).get(
                "provenance", "generated_runtime"
            )
    current["sources"] = sources
    rejected = []
    for field in ("ui", "canonical_slots", "content_icons",
                  "monster_id_sources", "verified_legacy_redirects"):
        valid = {}
        for key, item in current.get(field, {}).items():
            source = item if isinstance(item, str) else item.get("source", "")
            if source in physical:
                valid[key] = item
            else:
                rejected.append(f"{field}:{key}")
        current[field] = valid

    current["content_icons"] = {key: icon_assets[key]["source"] for key in sorted(icon_assets)}
    current["content_icon_generation"] = {"count": len(icon_assets),
        "manifest": "res://assets/art/runtime/content_icons_v1/manifest.json",
        "stage": "runtime_generated_visual_qa_pending"}

    def group_sources(group: str) -> dict[str, str]:
        return {
            slot.split(".", 1)[1]: record["source"]
            for slot, record in generated.items()
            if slot.startswith(group + ".")
        }

    for kind, field in (
        ("characters", "generated_character_candidates"),
        ("npcs", "generated_npc_candidates"),
        ("monsters", "generated_monster_candidates"),
        ("bosses", "generated_boss_candidates"),
        ("maps", "generated_map_backdrops"),
        ("interiors", "generated_interior_backdrops"),
    ):
        current[field] = group_sources(kind)
    all_npcs = read(root / "data/assets/av_registry.json").get("npcs", [])
    for region in REGIONS:
        profile = current["regions"][region]
        profile["generated_terrain"] = {
            kind: generated["terrain." + region + "_" + kind]["source"]
            for kind in ("ground", "water")
        }
        props = profile.setdefault("scene_props", {})
        buildings = profile.setdefault("building_bindings", {})
        actors = profile.setdefault("npc_identity_bindings", {})
        # An obsolete original source is never retained in a live region slot.
        for section in (props, buildings, actors):
            for key in list(section):
                if section[key] not in physical:
                    del section[key]
        for role in ROLES:
            source = generated["props." + region + "_" + role]["source"]
            props.setdefault(role, source)
            if role in {"cottage", "shop", "shrine"}:
                buildings[role] = source
        for npc in all_npcs:
            if npc.get("region_id") == region:
                key = "npcs." + npc["id"]
                if key in generated:
                    actors[npc["id"]] = generated[key]["source"]
        profile["generated_stage"] = "runtime_candidate; visual_identity未测试"

    current["generated_assets"] = generated
    current["generated_manifest"] = {
        "source": FACTORY + "active.json",
        "manifest_images": len(manifest),
        "regional_atlases_extra": 16,
        "groups": groups, "enabled": True, "visual_status": "未测试",
    }
    current["generated_slot_sources"] = {
        "prop.coast." + role: generated["props.region_coast_" + role]["source"]
        for role in ("cottage", "well", "crate")
        if "prop.coast." + role in current["canonical_slots"]
    }
    current["last_reconciliation"] = {
        "tracked_images": len(physical), "generated_images": len(generated),
        "manifest_images": len(manifest),
        "removed_retired_sources": len(set(old) - set(physical)),
        "registered_images": sum(bool(r["registered"]) for r in sources.values()),
        "unregistered_images": sum(not r["registered"] for r in sources.values()),
        "removed_invalid_bindings": rejected, "visual_status": "未测试",
    }
    current["version"] = "global-factory-v3-auto-synced"
    current.pop("audit_head", None)
    new_text = json.dumps(current, ensure_ascii=False, indent=2) + "\n"
    if registry_file.read_text(encoding="utf-8") != new_text:
        registry_file.write_text(new_text, encoding="utf-8")
    return current["last_reconciliation"]


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--project", type=Path,
                        default=Path(__file__).resolve().parents[1])
    args = parser.parse_args()
    print(json.dumps(synchronize(args.project.resolve()),
                     ensure_ascii=False, indent=2))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
