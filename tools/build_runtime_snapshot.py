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
        raise RuntimeError("Missing game entrypoint")
    migration = data(source, "data/assets/c_third_party_only_migration_v1.json")
    redirects = {}
    for entry in migration.get("mappings", []):
        old = str(entry.get("old_path", ""))
        new = str(entry.get("new_source", ""))
        if old.startswith("assets/") and new.startswith(ART+"external/"):
            redirects[old] = new
            # Dynamic texture names are generated from gameplay IDs.
            # Retain migration targets, not the historical unshippable originals.
            if new in known:
                selected.add(new)
    for name in list(selected):
        # The in-game catalog contains *candidates*, not only playable art.
        # Its content must never expand the shipped binary dependency set.
        if name in ("data/assets/c_art_catalog.json", "data/assets/c_art_packs.json"):
            # Quarantined historical pack paths are not runtime dependencies.
            continue
        if Path(name).suffix.lower() not in {".gd", ".tscn", ".tres", ".json", ".cfg", ".csv"}:
            continue
        path = source/name
        if path.stat().st_size > 3000000:
            continue
        content = path.read_text(encoding="utf-8", errors="replace")
        for ref in RES_PATTERN.findall(content):
            candidate = ref.removeprefix("res://")
            if candidate in known and Path(candidate).suffix.lower() in IMAGES:
                if not candidate.startswith(SOURCE_PACKS):
                    selected.add(candidate)
            if candidate in redirects and redirects[candidate] in known:
                selected.add(redirects[candidate])
    # All approved curated aliases are published: these are already bound to
    # real prop/scenery/monster world and battle code, not source candidates.
    selected.update(p for p in known if p.startswith(CURATED) and Path(p).suffix.lower() in IMAGES)

    # Black Sail Chapter IV furnishings are built from an authored art prefix
    # and per-placement asset names, not literal res:// filenames in the script.
    # Include only the pieces actually assigned to the playable tavern. This
    # keeps source packs/candidates out of Runtime while avoiding invisible
    # counters, tables and investigation clues in the slim build.
    tavern = data(source, "data/levels/v4/interiors/map_coast_02__tavern.json")
    if tavern.get("art_profile") != "coast_act01_tavern_v1":
        raise RuntimeError("Playable Black Sail interior profile missing")
    tavern_root = "assets/art/runtime/act01_tavern_v2/"
    tavern_images = {str(tavern.get("art_tileset", "")).removeprefix("res://")}
    for prop in tavern.get("visuals", []):
        if not isinstance(prop, dict):
            raise RuntimeError("Malformed Black Sail furniture placement")
        asset = str(prop.get("asset", ""))
        if not asset.startswith("tavern_") or "/" in asset or ".." in asset:
            raise RuntimeError("Unapproved Black Sail furniture identity: " + asset)
        tavern_images.add(tavern_root + asset + ".svg")
    for image_name in sorted(tavern_images):
        if not (image_name.startswith(tavern_root)
                and image_name.endswith(".svg") and image_name in known):
            raise RuntimeError("Missing playable Black Sail image: " + image_name)
        selected.add(image_name)
    # V17 names are built from a constant prefix plus exact gameplay kind in
    # GDScript (not full res:// literals); static URL scanning cannot see them.
    # These eight aliases are verified before packaging, and only these seven
    # already-live runtime PNGs are shipped, never source_packs.
    v17_approved = {
        "flowerpot.png", "sea_crystal.png", "mangrove.png", "crab.png",
        "harbor_crane.png", "sea_wind_pine.png", "saltwind_oak.png",
        "tide_pool.png",
    }
    for filename in sorted(v17_approved):
        name = CURATED_ACT01_SEMANTIC + filename
        if name not in known:
            raise RuntimeError("Missing promoted and actually bound Act-I art: " + name)
        selected.add(name)

    # Curated V18 images are dynamically loaded by kind / material name.
    # Include only images actually bound to five first-act maps.
    hd2d = data(source, "data/assets/c_act01_hd2d_v18.json")
    if hd2d.get("schema") != "starlit.c.act01_hd2d_v18":
        raise RuntimeError("Bad V18 playable manifest")
    props = {str(row.get("source", "")).removeprefix("res://")
             for row in hd2d.get("placements", [])}
    materials = {str(v).removeprefix("res://")
                 for v in hd2d.get("materials", {}).values()}
    promoted = props | materials
    # Scenery is deliberately pruned when visual review rejects a prop.
    # Publish exactly the current live references, not a stale fixed count.
    if len(materials) != 11 or len(props) < 10 or len(promoted) != len(props) + len(materials):
        raise RuntimeError("V18 image roles incomplete or overlapping")
    for name in promoted:
        if not name.startswith(CURATED_ACT01_HD2D) or name not in known:
            raise RuntimeError("V18 image missing from Main2: " + name)
        selected.add(name)

    for filename, key in (
        ("data/assets/c_art_content_icons_v6.json", "records"),
        ("data/assets/c_art_allocated_decor_runtime_v1.json", "placements")
    ):
        for entry in data(source, filename).get(key, []):
            path = str(entry.get("icon", entry.get("source", ""))).removeprefix("res://")
            if path not in known:
                raise RuntimeError("Missing actual icon/prop: " + path)
            selected.add(path)
    for pack in data(source, "data/assets/c_art_packs.json").get("packs", []):
        if pack.get("id") != "uploaded_later_v1":
            continue
        for entry in pack.get("mappings", []):
            path = str(entry.get("source", "")).removeprefix("res://")
            if path not in known:
                raise RuntimeError("Missing active DLC art: " + path)
            selected.add(path)
    selected = {p for p in selected if p in known
        and not p.startswith((SOURCE_PACKS, "assets/art/candidates/"))}
    # Directional NPC strips are selected by family/action at runtime, not by
    # a literal filename in code; include the documented 3 approved families.
    npc_source_index = data(source, "data/assets/c_art_usage_external_v12.json")
    for npc in npc_source_index.get("rows", []):
        if (npc.get("category") == "characters" and
            npc.get("family") in ("foozle_warrior", "foozle_sorceress", "foozle_necromancer") and
            npc.get("orientation") in ("down", "left", "up", "right") and
            npc.get("clip") in ("idle", "walk", "run")):
            candidate = str(npc.get("source", "")).removeprefix("res://")
            if candidate not in known:
                raise RuntimeError("Missing actual NPC directional art: " + candidate)
            selected.add(candidate)
    # The NPC costume loader reads this manifest dynamically via FileAccess.
    # Ship only the required Foozle 48px 4-direction character entries.
    regional_index = "data/assets/c_art_usage_external_v12.json"
    if regional_index not in known:
        raise RuntimeError("Regional NPC runtime source manifest missing")
    selected.add(regional_index)
    # Ship regenerated V4.2 derivatives only when their original visual
    # source belongs to this playable snapshot. Retain original source paths
    # for provenance and fallback; the runtime resolver uses exact route keys.
    overlay_manifest = "assets/art/runtime/refined_overrides_v1/manifest.json"
    if overlay_manifest in known:
        overlay = data(source, overlay_manifest)
        if overlay.get("schema") != "starlit.refined_overrides.v1":
            raise RuntimeError("Invalid regenerated detail manifest")
        selected.add(overlay_manifest)
        for original, row in overlay.get("routes", {}).items():
            if not original.startswith("res://assets/art/") or ".." in original:
                raise RuntimeError("Unsafe regenerated art original: " + str(original))
            old = original.removeprefix("res://")
            replacement = str(row.get("output", "")).removeprefix("res://")
            if not replacement.startswith("assets/art/runtime/refined_overrides_v1/") or ".." in replacement:
                raise RuntimeError("Unsafe regenerated runtime image: " + replacement)
            if old in selected and replacement in known:
                selected.add(replacement)
            elif old in selected:
                raise RuntimeError("Missing playable regenerated image: " + replacement)
    if with_smoke:
        for script in SMOKES:
            p = "tools/" + script
            if p not in known:
                raise RuntimeError("Missing required Godot smoke: " + p)
            selected.add(p)
    if output.exists():
        shutil.rmtree(output)
    output.mkdir(parents=True)
    for name in sorted(selected):
        destination = output/name
        destination.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(source/name, destination)
    # The playable Runtime deliberately excludes the Main2 editor addon.
    # Strip activation only from the copied project, never the Main2 original.
    runtime_project = output / "project.godot"
    project_lines = runtime_project.read_text(encoding="utf-8").splitlines()
    runtime_lines = []
    in_editor_plugins = False
    for line in project_lines:
        if line.strip() == "[editor_plugins]":
            in_editor_plugins = True
            continue
        if in_editor_plugins and line.startswith("[") and line.rstrip().endswith("]"):
            in_editor_plugins = False
        if not in_editor_plugins:
            runtime_lines.append(line)
    runtime_project.write_text("\n".join(runtime_lines).rstrip() + "\n", encoding="utf-8")
    # Remove production inventory without altering actual gameplay mappings.
    artfile = output/"data/assets/c_act01_global_distribution_v14.json"
    registry = json.loads(artfile.read_text(encoding="utf-8"))
    if registry.get("schema") != "starlit.c.act01_global_distribution.v14":
        raise RuntimeError("Unexpected live art registry schema")
    registry["source_index"] = []
    registry.setdefault("counts", {})["source_files"] = 0
    artfile.write_text(json.dumps(registry, ensure_ascii=False, separators=(",", ":")) + "\n",
        encoding="utf-8")
    def runtime_paths(v):
        if isinstance(v, dict):
            for child in v.values():
                yield from runtime_paths(child)
        elif isinstance(v, list):
            for child in v:
                yield from runtime_paths(child)
        elif isinstance(v, str) and v.startswith("res://assets/art/runtime/"):
            yield v.removeprefix("res://")
    for name in runtime_paths(registry.get("runtime", {})):
        if not (output/name).is_file():
            raise RuntimeError("Curated gameplay image excluded by mistake: " + name)
    # Reduce 667 source-library catalog rows to the NPC families actually
    # used by CArtRegionalNPC.costume(), retaining valid frame references.
    npcfile = output/"data/assets/c_art_usage_external_v12.json"
    npc_manifest = json.loads(npcfile.read_text(encoding="utf-8"))
    allowed_families = {"foozle_warrior", "foozle_sorceress", "foozle_necromancer"}
    npc_rows = [row for row in npc_manifest.get("rows", [])
        if row.get("category") == "characters" and row.get("family") in allowed_families
        and row.get("orientation") in ("down", "left", "up", "right")
        and row.get("clip") in ("idle", "walk", "run")]
    if len(npc_rows) < 20:
        raise RuntimeError("Incomplete runtime NPC 4-direction animation source index")
    for row in npc_rows:
        name = str(row.get("source", "")).removeprefix("res://")
        if not (output/name).is_file():
            raise RuntimeError("Regional NPC frame missing from runtime: " + name)
    npc_manifest["rows"] = npc_rows
    npc_manifest["image_count"] = len(npc_rows)
    npc_manifest["group_summaries"] = {}
    npc_manifest["status_counts"] = {}
    npcfile.write_text(json.dumps(npc_manifest, ensure_ascii=False, separators=(",", ":")) + "\n", encoding="utf-8")
    # The in-game art manager must not present 1,000+ absent candidates.
    catalogfile = output/"data/assets/c_art_catalog.json"
    catalog = json.loads(catalogfile.read_text(encoding="utf-8"))
    records = []
    for row in catalog.get("assets", []):
        if not isinstance(row, dict):
            continue
        name = str(row.get("path", "")).removeprefix("res://")
        if name in selected or (name in redirects and redirects[name] in selected):
            records.append(row)
    catalog["assets"] = records
    catalog["count"] = len(records)
    catalogfile.write_text(json.dumps(catalog, ensure_ascii=False, separators=(",", ":")) + "\n",
        encoding="utf-8")
    for filename, key in (
        ("data/assets/c_art_content_icons_v6.json", "records"),
        ("data/assets/c_art_allocated_decor_runtime_v1.json", "placements")
    ):
        for entry in data(output, filename).get(key, []):
            name = str(entry.get("icon", entry.get("source", ""))).removeprefix("res://")
            if not (output/name).is_file():
                raise RuntimeError("Dangling visible art reference: " + name)
    if any(p.startswith(SOURCE_PACKS) for p in selected):
        raise RuntimeError("Production source packs leaked to Runtime")
    summary = {"files":len(selected), "art_images":sum(Path(p).suffix.lower() in IMAGES
        for p in selected if p.startswith(ART)), "catalog_visible":len(records),
        "source_pack_files":0, "temporary_test_scripts":len(SMOKES) if with_smoke else 0}
    print(json.dumps(summary, ensure_ascii=False, sort_keys=True))
    return summary

if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--source", default=".")
    parser.add_argument("--dest", required=True)
    parser.add_argument("--with-smoke", action="store_true")
    args = parser.parse_args()
    create_snapshot(Path(args.source), Path(args.dest), args.with_smoke)
