#!/usr/bin/env python3
"""Create a playable Godot snapshot from Main2; never ship raw source packs."""
import argparse
import json
import re
import shutil
import subprocess
from pathlib import Path

ART = "assets/art/"
SOURCE_PACKS = ART + "source_packs/"
CURATED = ART + "runtime/act01_global_v14/"
CURATED_ACT01_SEMANTIC = ART + "runtime/act01_semantic_v17/"
CURATED_ACT01_HD2D = ART + "runtime/act01_hd2d_v18/"
IMAGES = {".png", ".jpg", ".jpeg", ".webp", ".svg", ".gif", ".bmp"}
EXCLUDE_DATA = ("c_art_allocation_v", "c_art_usage_", "c_art_source_originals",
    "c_art_nonimage_groups", "c_art_group_contracts", "c_art_selection",
    "c_uploaded_only_full_audit", "c_act01_archive_triage",
    "c_act01_semantic_rematch", "external_cc0_named_index")
SMOKES = ("smoke_c_act01_global_art_v14.gd", "smoke_c_main2_art_runtime.gd",
    "smoke_battle_actors.gd", "smoke_first_act_flow.gd",
    "smoke_act01_six_chapters_normal.gd",
    "smoke_rpg_core.gd", "smoke_save_integrity.gd",
    "smoke_c_regional_monsters_v15.gd",
    "smoke_main2_act01_harbor_rooms_visual.gd",
    "smoke_main2_lighthouse_story_state.gd",
    "smoke_c_act01_semantic_v17.gd",
    "smoke_main2_act01_live_boss_motion.gd",
    "smoke_main2_act01_coast_monster_identity.gd",
    "smoke_main2_act01_canonical_chapter_routes.gd",
    "smoke_b_act01_journey.gd",
    # Release-gate regressions: travel from the actual game controller,
    # indoor/camp save recovery, and optional-story transaction replay.
    "smoke_world_story_interactions.gd",
    "smoke_world_checkpoints.gd",
    "smoke_branch_story_phase19.gd",
    "smoke_c_act01_hd2d_v18.gd")
RES_PATTERN = re.compile(r"""res://assets/[^"' \t\r\n\]\),;<>]+""")

def data(root, name):
    return json.loads((root/name).read_text(encoding="utf-8"))

def tracked(root):
    proc = subprocess.run(["git", "-C", str(root), "ls-files", "-z"],
        capture_output=True, check=True)
    return {b.decode("utf-8") for b in proc.stdout.split(b"\0") if b}

def is_game_file(name):
    if name in (".gitignore", "project.godot", "export_presets.cfg"):
        return True
    if name.startswith("scripts/"):
        return name.endswith((".gd", ".gd.uid"))
    if name.startswith("scenes/"):
        return name.endswith((".tscn", ".tres")) and name not in (
            "scenes/art_gallery.tscn", "scenes/c_art_distribution_gallery.tscn")
    if name.startswith("story/"):
        return Path(name).suffix in (".json", ".csv", ".gd", ".tscn", ".tres")
    if name.startswith("data/"):
        if Path(name).suffix not in (".json", ".csv", ".tscn", ".tres"):
            return False
        return not (name.startswith("data/assets/") and Path(name).name.startswith(EXCLUDE_DATA))
    if name.startswith("shaders/"):
        # Screen-space shaders live outside assets/ and are preloaded by game scripts.
        return Path(name).suffix.lower() in {".gdshader", ".gdshaderinc"}
    if name.startswith("assets/fonts/"):
        # Font resources referenced by project.godot must reach the slim IPA.
        return Path(name).suffix.lower() in {".ttf", ".otf", ".woff", ".woff2", ".tres"}
    if name.startswith(("assets/audio/", "assets/shaders/", "assets/fx/", "assets/enemies/")):
        return Path(name).suffix.lower() in IMAGES | {".ogg", ".wav", ".mp3", ".gdshader", ".tres"}
    if name.startswith(ART):
        return name.endswith(".json") and (name.startswith(ART+"runtime/") or
            name.startswith(ART+"b02/") or name.startswith(ART+"b03/"))
    return False

def create_snapshot(source, output, with_smoke=False):
    source, output = source.resolve(), output.resolve()
    if source == output or source in output.parents:
        raise ValueError("Runtime snapshot destination must be outside Main2 checkout")
    known = tracked(source)
    selected = {p for p in known if is_game_file(p)}
    if "project.godot" not in selected or "scenes/first_act.tscn" not in selected:
        raise RuntimeError("Missing player entrypoint")

    def read(name, schema=None):
        if name not in known:
            raise RuntimeError("Required live manifest missing: " + name)
        result = data(source, name)
        if not isinstance(result, dict) or (schema and result.get("schema") != schema):
            raise RuntimeError("Unexpected runtime manifest schema: " + name)
        selected.add(name)
        return result

    def actual_image(reference, identity):
        if not isinstance(reference, str) or not reference.startswith("res://assets/art/runtime/"):
            raise RuntimeError("Non-runtime image source for " + identity + ": " + str(reference))
        name = reference.removeprefix("res://")
        if ".." in Path(name).parts or Path(name).suffix.lower() not in IMAGES:
            raise RuntimeError("Unsafe generated image source: " + identity)
        if name not in known or not (source / name).is_file():
            raise RuntimeError("Live playable image missing: " + identity + " -> " + name)
        selected.add(name)
        return name

    def references(v):
        if isinstance(v, dict):
            for item in v.values():
                yield from references(item)
        elif isinstance(v, list):
            for item in v:
                yield from references(item)
        elif isinstance(v, str) and v.startswith("res://assets/"):
            yield v

    # The old third-party migrations, Foozle pack and V17/V18 hardcoded
    # directories were deliberately deleted from Main2. The only authority
    # is the generated-and-bound runtime source graph; never restore them.
    theme = read("data/assets/art_theme_v2.json", "starlit.art_theme.v2")
    themes = theme.get("themes", [])
    if len(themes) != 1 or len(themes[0].get("slots", {})) != 109:
        raise RuntimeError("Canonical 109-slot generated theme is incomplete")
    for identity, record in themes[0]["slots"].items():
        actual_image(record.get("source"), identity)

    registry = read("data/assets/c_art_runtime_registry_v1.json",
                    "starlit.c.art_runtime_registry.v1")
    for identity, record in registry.get("canonical_slots", {}).items():
        actual_image(record.get("source"), identity)
    if set(registry.get("canonical_slots", {})) != set(themes[0]["slots"]):
        raise RuntimeError("Theme/runtime slot identities diverged")

    # Player equipment/item/skill icons are now looked up by stable content ID
    # in the generated registry. The obsolete V6 icon field is deliberately
    # blank and must not cause a third-party image to be resurrected.
    generated_icons = read("assets/art/runtime/content_icons_v1/manifest.json",
                           "starlit.content_icons.runtime.v1")
    icon_entries = generated_icons.get("assets", {})
    id_paths = registry.get("content_icons", {})
    if len(icon_entries) != 288 or len(id_paths) != 288:
        raise RuntimeError("All 288 generated equipment/content icons required")
    for identity, record in icon_entries.items():
        if record.get("source") != id_paths.get(identity):
            raise RuntimeError("Content icon source/id mismatch: " + identity)
        actual_image(record["source"], "content_icon:" + identity)

    # Visual layers whose paths are dynamically assembled (shore animations,
    # regional decoration, scene details) must ship with their real textures.
    for group in ("generated_allocated_scene_props", "scene_detail_sources",
                  "shore_wave_sources", "generated_semantic_scene_assets", "ui"):
        for identity, path in registry.get(group, {}).items():
            actual_image(path, group + ":" + identity)
    for manifest_path, schema, group in (
        ("assets/art/runtime/scene_details_v1/manifest.json",
         "starlit.scene_details.runtime.v1", "scene_detail_sources"),
        ("assets/art/runtime/shore_waves_v1/manifest.json",
         "starlit.shore_waves.runtime.v1", "shore_wave_sources"),
        ("assets/art/runtime/semantic_generated_v1/manifest.json",
         "starlit.semantic_generated.v1", "generated_semantic_scene_assets"),
    ):
        manifest = read(manifest_path, schema)
        entries = manifest.get("routes", {}) if "routes" in manifest else manifest.get("assets", {})
        if not isinstance(entries, dict):
            raise RuntimeError("Invalid supplemental live source manifest: " + manifest_path)
        for identity, row in entries.items():
            # Do not shadow the Path-valued source project root: doing so
            # broke all Runtime builds when the first image was processed.
            image_ref = row.get("source") if isinstance(row, dict) else row
            actual_image(image_ref, manifest_path + ":" + identity)

    # 451 unique named original HD2D images + every real normal map used by
    # the live renderer; missing images make the release fail, not disappear.
    factory = read("assets/art/runtime/global_factory_v3/active.json",
                   "starlit.global_factory.live.v3")
    assets = factory.get("assets", {})
    if factory.get("enabled") is not True or len(assets) != factory.get("asset_count") or len(assets) != 451:
        raise RuntimeError("Current generated active asset graph not complete")
    normal_count = 0
    for identity, record in assets.items():
        actual_image(record.get("path"), identity)
        normal = record.get("normal_map_path")
        if normal:
            actual_image(normal, identity + ".normal")
            normal_count += 1
    if normal_count != factory.get("normal_map_count"):
        raise RuntimeError("Generated normal-map graph incomplete")

    # All 116 V10 named replacements are registered by actual role. They
    # are a small live generated runtime pool, NOT uploaded source-pack art.
    gaps = read("assets/art/runtime/generated_gaps_v10/manifest.json",
                "starlit.main2.gap_fill.v10")
    if len(gaps.get("assets", {})) != gaps.get("generated_count"):
        raise RuntimeError("Current V10 semantic art count invalid")
    for identity, record in gaps["assets"].items():
        actual_image(record.get("source"), identity)

    motion = read("assets/art/runtime/boss_motion_v1/manifest.json",
                  "starlit.boss_motion.runtime.v1")
    if len(motion.get("assets", {})) != motion.get("count") or len(motion["assets"]) != 66:
        raise RuntimeError("Runtime must include all 66 independently named boss action sheets")
    for identity, record in motion["assets"].items():
        actual_image(record.get("source_identity"), identity + ".portrait")
        actual_image(record.get("source"), identity + ".six_state")

    # The original V14 logical map and NPC/monster IDs still route gameplay
    # to V10 generated images. Include exactly their manifest targets.
    v14 = read("data/assets/c_act01_global_distribution_v14.json",
               "starlit.c.act01_global_distribution.v14")
    if set(v14.get("maps", {})) != {f"map_coast_{i:02d}" for i in range(1, 6)}:
        raise RuntimeError("Playable Act-I map distribution incomplete")
    for number, path in enumerate(references(v14.get("runtime", {}))):
        actual_image(path, "v14_runtime_" + str(number))

    hd2d = read("data/assets/c_act01_hd2d_v18.json",
                "starlit.c.act01_hd2d_v18")
    props = {str(record.get("source", "")) for record in hd2d.get("placements", [])}
    materials = set(hd2d.get("materials", {}).values())
    if len(hd2d.get("placements", [])) != 17 or len(props) != 14 or len(materials) != 11:
        raise RuntimeError("V18 live scene role contract incomplete")
    for number, path in enumerate(sorted(props | materials)):
        actual_image(path, "v18_scene_" + str(number))

    tavern = read("data/levels/v4/interiors/map_coast_02__tavern.json")
    shelter = read("data/levels/v4/interiors/map_coast_02__shelter.json")
    for room_name, room in (("tavern", tavern), ("shelter", shelter)):
        if room.get("art_profile") != "coast_act01_" + room_name + "_v1":
            raise RuntimeError("Act-I authored interior not registered: " + room_name)
        actual_image(room.get("art_tileset"), room_name + "_atlas")
        for row in room.get("visuals", []):
            role = str(row.get("asset", ""))
            if room_name == "tavern" or role in (
                    "shelter_cot", "shelter_medicine_cabinet", "shelter_linen_cart",
                    "shelter_treatment_tray", "medical_registration_counter", "treatment_bench"):
                slot = "interior." + room_name + "." + role
                if slot not in registry.get("canonical_slots", {}):
                    raise RuntimeError("Missing exact room furniture identity: " + slot)
                actual_image(registry["canonical_slots"][slot]["source"], slot)

    content_records = read("data/assets/c_art_content_icons_v6.json").get("records", [])
    if len(content_records) != 288 or {row.get("id") for row in content_records} != set(id_paths):
        raise RuntimeError("Content icon IDs diverged from actual 288-item generated registry")
    for row in content_records:
        canonical_path = id_paths[str(row["id"])]
        if row.get("icon") and row["icon"] != canonical_path:
            raise RuntimeError("Noncanonical V6 source: " + str(row["id"]))
        actual_image(canonical_path, "content_record:" + str(row["id"]))
    for number, row in enumerate(read("data/assets/c_art_allocated_decor_runtime_v1.json").get("placements", [])):
        actual_image(row.get("source"), "active_decoration:" + str(number))
    packs = read("data/assets/c_art_packs.json", "starlit.c.art_packs.v1")
    if packs.get("packs", []) != []:
        raise RuntimeError("Third-party uploaded art packs must remain removed")

    # Ordinary static source URLs may name other actually playable art, for
    # example battle overlays or controls. Unknown/retired URLs do not cause
    # a third-party source archive to reappear.
    for name in list(selected):
        if name in ("data/assets/c_art_catalog.json", "data/assets/c_art_packs.json"):
            continue
        if Path(name).suffix.lower() not in {".gd", ".tscn", ".tres", ".json", ".cfg", ".csv"}:
            continue
        file = source / name
        if file.stat().st_size > 3000000:
            continue
        for ref in RES_PATTERN.findall(file.read_text(encoding="utf-8", errors="replace")):
            candidate = ref.removeprefix("res://")
            if (candidate in known and Path(candidate).suffix.lower() in IMAGES
                    and candidate.startswith("assets/") and
                    not candidate.startswith((SOURCE_PACKS, "assets/art/candidates/",
                                              "assets/art/external/"))):
                selected.add(candidate)

    # Regenerated details are overlays of images included above; never
    # publish a second unrelated candidate pack.
    overlay_manifest = "assets/art/runtime/refined_overrides_v1/manifest.json"
    if overlay_manifest in known:
        overlay = read(overlay_manifest, "starlit.refined_overrides.v1")
        for original, row in overlay.get("routes", {}).items():
            if not original.startswith("res://assets/art/") or ".." in original:
                raise RuntimeError("Unsafe refined source key: " + original)
            old = original.removeprefix("res://")
            replacement = str(row.get("output", "")).removeprefix("res://")
            if old in selected:
                if (not replacement.startswith("assets/art/runtime/refined_overrides_v1/")
                        or replacement not in known):
                    raise RuntimeError("Broken playable regenerated image: " + replacement)
                selected.add(replacement)

    if with_smoke:
        for script in SMOKES:
            filename = "tools/" + script
            if filename not in known:
                raise RuntimeError("Missing runtime player smoke test: " + filename)
            selected.add(filename)
    selected = {p for p in selected if p in known and
                not p.startswith((SOURCE_PACKS, "assets/art/candidates/",
                                  "assets/art/external/"))}
    if output.exists():
        shutil.rmtree(output)
    output.mkdir(parents=True)
    for name in sorted(selected):
        destination = output / name
        destination.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(source / name, destination)

    # The actual Runtime has no editor addon. Never mutate the Main2 source.
    runtime_project = output / "project.godot"
    lines = runtime_project.read_text(encoding="utf-8").splitlines()
    cleaned = []
    editor_plugins = False
    for line in lines:
        if line.strip() == "[editor_plugins]":
            editor_plugins = True
            continue
        if editor_plugins and line.startswith("[") and line.rstrip().endswith("]"):
            editor_plugins = False
        if not editor_plugins:
            cleaned.append(line)
    runtime_project.write_text("\n".join(cleaned).rstrip() + "\n", encoding="utf-8")

    # Prevent a production catalog from advertising deleted raw imports.
    catalog_file = output / "data/assets/c_art_catalog.json"
    if catalog_file.is_file():
        catalog = json.loads(catalog_file.read_text(encoding="utf-8"))
        kept = [row for row in catalog.get("assets", [])
                if isinstance(row, dict) and
                str(row.get("path", "")).removeprefix("res://") in selected]
        catalog["assets"] = kept
        catalog["count"] = len(kept)
        catalog_file.write_text(json.dumps(catalog, ensure_ascii=False, separators=(",", ":")) + "\n",
                                encoding="utf-8")

    # Match the V14 gameplay graph without shipping its old source library
    # inventory. All records used by live GDScript must still point to real art.
    art_file = output / "data/assets/c_act01_global_distribution_v14.json"
    art_registry = json.loads(art_file.read_text(encoding="utf-8"))
    art_registry["source_index"] = []
    if "count" in art_registry and isinstance(art_registry["count"], dict):
        art_registry["count"]["source_files"] = 0
    art_file.write_text(json.dumps(art_registry, ensure_ascii=False, separators=(",", ":")) + "\n",
                        encoding="utf-8")

    if any(p.startswith((SOURCE_PACKS, "assets/art/external/", "assets/art/candidates/"))
           for p in selected):
        raise RuntimeError("Raw uploaded or candidate artwork leaked into Runtime")
    art_images = sum(Path(p).suffix.lower() in IMAGES
                     for p in selected if p.startswith(ART))
    result = {"files": len(selected), "art_images": art_images,
              "v3_active_images": len(assets),
              "v3_normal_maps": normal_count,
              "v10_semantic_images": len(gaps["assets"]),
              "boss_action_sheets": len(motion["assets"]),
              "source_pack_files": 0,
              "temporary_test_scripts": len(SMOKES) if with_smoke else 0}
    print(json.dumps(result, ensure_ascii=False, sort_keys=True))
    return result

if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--source", default=".")
    parser.add_argument("--dest", required=True)
    parser.add_argument("--with-smoke", action="store_true")
    args = parser.parse_args()
    create_snapshot(Path(args.source), Path(args.dest), args.with_smoke)
