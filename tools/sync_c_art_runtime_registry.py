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
DETAIL_PASS = "res://assets/art/runtime/refined_overrides_v1/"
SEMANTIC_PASS = "res://assets/art/runtime/semantic_generated_v1/"
ALLOCATED_PASS = "res://assets/art/runtime/allocated_decor_generated_v1/"
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

    detail_manifest_path = root / "assets/art/runtime/refined_overrides_v1/manifest.json"
    detail_routes = {}
    if detail_manifest_path.is_file():
        detail_manifest = read(detail_manifest_path)
        if detail_manifest.get("schema") != "starlit.refined_overrides.v1":
            raise ValueError("Incorrect V4.2 detail-pass manifest schema")
        detail_routes = detail_manifest.get("routes", {})
        if not isinstance(detail_routes, dict) or len(detail_routes) != detail_manifest.get("count"):
            raise ValueError("V4.2 detail-pass manifest count mismatch")
        for original, detail in detail_routes.items():
            target = detail.get("output", "")
            if (not original.startswith("res://assets/art/") or
                not target.startswith(DETAIL_PASS) or
                ".." in original or ".." in target):
                raise ValueError("Invalid generated detail-pass path")
            if original not in physical or target not in physical:
                raise ValueError("Generated detail source/target not staged: " + original)
            source_path = root / original.removeprefix("res://")
            target_path = root / target.removeprefix("res://")
            if hashlib.sha256(source_path.read_bytes()).hexdigest() != detail.get("source_sha256"):
                raise ValueError("Detail-pass original changed: " + original)
            if hashlib.sha256(target_path.read_bytes()).hexdigest() != detail.get("sha256"):
                raise ValueError("Detail-pass new image SHA mismatch: " + target)

    allocated_manifest_path = root / "assets/art/runtime/allocated_decor_generated_v1/manifest.json"
    generated_allocated = {}
    if allocated_manifest_path.is_file():
        allocated_manifest = read(allocated_manifest_path)
        if allocated_manifest.get("schema") != "starlit.allocated_decor_generated.v1":
            raise ValueError("Wrong generated 32px placement manifest schema")
        generated_allocated = allocated_manifest.get("assets", {})
        if len(generated_allocated) != 25 or len(generated_allocated) != allocated_manifest.get("count"):
            raise ValueError("Exactly 25 allocated scenes need generated 32px props")
        for item in generated_allocated.values():
            source = item.get("source", "")
            if not source.startswith(ALLOCATED_PASS) or source not in physical:
                raise ValueError("Missing generated allocated prop: " + source)
            if hashlib.sha256((root/source.removeprefix("res://")).read_bytes()).hexdigest() != item.get("sha256"):
                raise ValueError("Incorrect generated 32px prop checksum: " + source)
    # All 109 historic visual slots now have project-generated V10 variants.
    # Verify every output before reconciling the canonical runtime registry.
    gap_file = root / "assets/art/runtime/generated_gaps_v10/manifest.json"
    generated_gaps = {}
    if gap_file.is_file():
        gaps = read(gap_file)
        if gaps.get("schema") != "starlit.main2.gap_fill.v10":
            raise ValueError("Incorrect generated-gap contract")
        generated_gaps = gaps.get("assets", {})
        if len(generated_gaps) != gaps.get("generated_count"):
            raise ValueError("Generated-gap count mismatch")
        for name, row in generated_gaps.items():
            path = row.get("source", "")
            if not path.startswith("res://assets/art/runtime/generated_gaps_v10/"):
                raise ValueError("Invalid generated-gap path: " + name)
            if path not in physical:
                raise ValueError("Generated-gap image not staged: " + name)
            if hashlib.sha256((root/path.removeprefix("res://")).read_bytes()).hexdigest() != row.get("sha256"):
                raise ValueError("Generated-gap SHA mismatch: " + name)
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
    motion = read(root / "assets/art/runtime/boss_motion_v1/manifest.json")
    if motion.get("schema") != "starlit.boss_motion.runtime.v1" or motion.get("count") != 66:
        raise ValueError("Expected exactly 66 generated boss action sheets")
    boss_records = motion.get("assets", {})
    expected_boss_ids = {x["id"] for x in read(root / "data/assets/av_registry.json")["bosses"]}
    if set(boss_records) != expected_boss_ids:
        raise ValueError("Generated motion sheet identities do not cover canonical 66 bosses")
    boss_paths = {item["source"] for item in boss_records.values()}
    if len(boss_paths) != 66 or not boss_paths.issubset(physical):
        raise ValueError("Boss motion files missing or aliased to another identity")
    for boss_id, item in boss_records.items():
        p = root / item["source"].removeprefix("res://")
        if hashlib.sha256(p.read_bytes()).hexdigest() != item["sha256"]:
            raise ValueError("Boss motion checksum mismatch: " + boss_id)
    wave_manifest=read(root / "assets/art/runtime/shore_waves_v1/manifest.json")
    if wave_manifest.get("schema")!="starlit.shore_waves.runtime.v1" or wave_manifest.get("count")!=8:
        raise ValueError("Eight directional shoreline waves must be installed")
    wave_records=wave_manifest.get("assets",{})
    wave_paths={row["source"] for row in wave_records.values()}
    if len(wave_paths)!=8 or not wave_paths.issubset(physical):
        raise ValueError("Some real shoreline animation PNGs are absent")
    for row in wave_records.values():
        path=root/row["source"].removeprefix("res://")
        if hashlib.sha256(path.read_bytes()).hexdigest()!=row["sha256"]:
            raise ValueError("Shoreline animated sprite checksum mismatch")
    current["shore_wave_sources"]={k:v["source"] for k,v in wave_records.items()}
    for path, sha in physical.items():
        previous = old.get(path, {})
        produced = path.startswith(FACTORY) or path.startswith(DETAIL_PASS) or path.startswith(SEMANTIC_PASS) or path.startswith(ALLOCATED_PASS) or path.startswith("res://assets/art/runtime/generated_gaps_v10/")
        same_blob = previous.get("sha") == sha
        sources[path] = {
            "sha": sha, "physically_present": True,
            "registered": produced or path in detail_roots.values() or path in icon_paths or path in boss_paths or path in wave_paths or bool(previous.get("registered", False)),
            "code_reference": ("generated_semantic_resolver" if produced else
                               "scene_detail_runtime_renderer" if path in detail_roots.values() else
                               "generated_content_icon_lookup" if path in icon_paths else
                               "boss_action_atlas_runtime" if path in boss_paths else
                               "shoreline_wave_animation_runtime" if path in wave_paths else
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
    current["boss_motion_sources"] = {
        key: boss_records[key]["source"] for key in sorted(boss_records)
    }
    current["boss_motion_contract"] = {
        "count":66, "states":["idle","attack","hit","status","down","phase_change"],
        "frames_per_state":4, "manifest":"res://assets/art/runtime/boss_motion_v1/manifest.json",
        "state":"real_animated_frames; visual_art_direction_unverified",
    }
    # Every remaining source-only file gets an explicit role and disposition.
    # These assets are not promoted as in-game content without exact identity.
    def candidate_role(path: str) -> str:
        if "/bosses/" in path:
            return "unmatched_boss_motion_candidate"
        if "/characters/" in path:
            return "unmatched_character_motion_candidate"
        if "/monsters/" in path:
            return "unmatched_monster_motion_candidate"
        if "/tilesets/" in path:
            return "external_tileset_candidate"
        if "/icons/" in path:
            return "unassigned_icon_candidate"
        if "/props/" in path:
            return "regional_prop_candidate"
        if "/exteriors/" in path:
            return "authored_exterior_candidate"
        if "/ui/" in path:
            return "evidence_ui_candidate"
        return "world_reference_candidate"
    current["source_candidate_pool"] = {
        path: {
            "role":candidate_role(path),
            "source":path,
            "sha":record["sha"],
            "in_game_binding":"not_approved",
            "disposition":"retain_for_exact_role_review",
            "visual_acceptance":"未测试",
        }
        for path,record in sources.items() if not record["registered"]
    }
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

    current["refined_generated_routes"] = {
        source: {"output": record["output"], "sha256": record["sha256"],
                 "source_sha256": record["source_sha256"],
                 "visual_status": "未测试"}
        for source, record in sorted(detail_routes.items())
    }
    # Generated-only art branch: the 109 historic theme slots were retired
    # with the third-party image purge. Rebind only exact, verified canonical
    # semantic equivalents; leave unmatched optional slots explicitly empty.
    semantic_manifest_path = root / "assets/art/runtime/semantic_generated_v1/manifest.json"
    semantic_routes = {}
    if semantic_manifest_path.is_file():
        semantic_data = read(semantic_manifest_path)
        if semantic_data.get("schema") != "starlit.semantic_generated.v1":
            raise ValueError("Invalid semantic generated image manifest")
        semantic_routes = semantic_data.get("routes", {})
        if len(semantic_routes) != semantic_data.get("count"):
            raise ValueError("Semantic image count mismatch")
        for name, row in semantic_routes.items():
            if row.get("source", "") not in physical:
                raise ValueError("Semantic generated image was not staged: " + name)
            if hashlib.sha256((root / row["source"].removeprefix("res://")).read_bytes()).hexdigest() != row.get("sha256"):
                raise ValueError("Semantic generated image hash mismatch: " + name)
    def semantic_source(name):
        record = semantic_routes.get(name, {})
        return str(record.get("source", ""))
    required_bindings = {
        "scene.coast.sea_crystal": semantic_source("scene.coast.sea_crystal"),
        "scene.coast.harbor_crane": semantic_source("scene.coast.harbor_crane"),
        "scene.coast.tide_pool": semantic_source("scene.coast.tide_pool"),
        "prop.coast.cottage": generated["props.region_coast_cottage"]["source"],
        "prop.coast.sign": semantic_source("prop.coast.sign"),
        "prop.coast.well": generated["props.region_coast_well"]["source"],
        "landmark.coast.tide_lighthouse_landmark": semantic_source("landmark.coast.tide_lighthouse_landmark"),
        "terrain.coast.map_1_ground": generated["terrain.region_coast_ground"]["source"],
        "terrain.coast.map_1_water": generated["terrain.region_coast_water"]["source"],
        "interior.tavern.tavern_wood_atlas": generated["interiors.map_coast_02__tavern"]["source"],
        "interior.tavern.tavern_bench": semantic_source("interior.tavern.tavern_bench"),
        "interior.tavern.tavern_counter": semantic_source("interior.tavern.tavern_counter"),
        "interior.tavern.tavern_ledger": semantic_source("interior.tavern.tavern_ledger"),
        "interior.tavern.tavern_table": semantic_source("interior.tavern.tavern_table"),
    }
    slots = current.get("canonical_slots", {})
    for slot, record in slots.items():
        existing = str(record.get("source", ""))
        if existing and existing in physical and existing.startswith("res://assets/art/runtime/generated_gaps_v10/"):
            source = existing
        elif slot in required_bindings:
            source = required_bindings[slot]
        elif slot == "prop.coast.crate":
            source = generated["props.region_coast_crate"]["source"]
        elif slot == "prop.coast.star_lantern":
            source = generated["props.region_coast_lantern"]["source"]
        elif slot.startswith("background.coast.map_"):
            ordinal = slot.rsplit("_",1)[1]
            source = str(generated.get("maps.map_coast_0"+ordinal, {}).get("source",""))
        elif slot.startswith("monster.coast.mon_coast_"):
            asset_id=slot.split(".")[-1]
            source = str(generated.get("monsters."+asset_id, {}).get("source",""))
        elif slot.startswith("monster.region."):
            asset_id=slot.split(".")[-1]
            source = str(generated.get("monsters."+asset_id, {}).get("source",""))
        else:
            source = ""
        if source and source not in physical:
            raise ValueError("Slot generation produced non-existent image: "+slot)
        record["source"] = source
        record["stage"] = "generated_source_visual_review_pending" if source else "retired_source_unmapped"
    current["canonical_slots"] = slots
    for region, record in current.get("regions",{}).items():
        record["material_preview"] = {
            "ground": generated["terrain."+region+"_ground"]["source"],
            "water": generated["terrain."+region+"_water"]["source"],
        }
        record["scene_props"] = {key:source for key,source in record.get("scene_props",{}).items() if source}
        record["unique_monster_candidates"] = [
            item["source"] for key,item in sorted(generated.items())
            if key.startswith("monsters.") and
            item.get("region_id", "") == region
        ][:6]

    current["generated_allocated_scene_props"] = {
        name: record["source"] for name, record in sorted(generated_allocated.items())
    }
    current["generated_gap_art"] = {
        name: {"source": row["source"], "sha256": row["sha256"]}
        for name, row in sorted(generated_gaps.items())
    }
    current["generated_semantic_scene_assets"] = {
        key: row["source"] for key,row in sorted(semantic_routes.items())
    }
    current["generated_assets"] = generated
    current["generated_manifest"] = {
        "source": FACTORY + "active.json",
        "manifest_images": len(manifest),
        "generated_detail_variants": len(detail_routes),
        "generated_gaps_v10": len(generated_gaps),
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
        "boss_motion_sheets":len(boss_records),
        "shoreline_motion_sheets":len(wave_records),
        "candidate_sources_classified":len(current["source_candidate_pool"]),
        "removed_invalid_bindings": rejected, "visual_status": "未测试",
    }
    current["version"] = "global-factory-v3-auto-synced"
    current.pop("audit_head", None)
    # Keep the baseline 109-slot Godot theme in sync with the generated-only
    # canonical sources. A generated image is NOT automatic visual approval.
    theme_path = root / "data/assets/art_theme_v2.json"
    if theme_path.is_file():
        theme = read(theme_path)
        if theme.get("schema") != "starlit.art_theme.v2":
            raise ValueError("Unexpected V2 art-theme schema")
        baseline = next((item for item in theme.get("themes", [])
                         if item.get("id") == "starlit_hd2d_act01"), None)
        if baseline is None or set(baseline.get("slots", {})) != set(current.get("canonical_slots", {})):
            raise ValueError("109 art-theme slots do not match canonical registry")
        for key, row in baseline["slots"].items():
            source = str(current["canonical_slots"][key].get("source", ""))
            row["source"] = source
            row["stage"] = "runtime_generated_pending_visual_signoff" if source else "retired_unmapped"
        theme_text = json.dumps(theme, ensure_ascii=False, indent=2) + "\n"
        if theme_path.read_text(encoding="utf-8") != theme_text:
            theme_path.write_text(theme_text, encoding="utf-8")
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
