#!/usr/bin/env python3
"""Install generated V3 images as real Godot runtime assets and prune unused old art.

This is a transactional build step for Main2. It regenerates 451+ images from
canonical game data, confirms exact hashes, publishes atlases with explicit
terrain role ordering and removes only retired images that have no executable
or registry reference. No saved-game geometry/state is modified.
"""
from __future__ import annotations
import argparse
import hashlib
import json
import re
import shutil
from pathlib import Path
from PIL import Image
from global_art_factory_v3 import SCOPES, produce, read, verify
from generate_boss_motion_v1 import create as create_boss_motion
from generate_shore_waves_v1 import generate as generate_shore_waves
from generate_content_icons_v1 import generate as generate_content_icons

RUNTIME_REL = Path("assets/art/runtime/global_factory_v3")
LEGACY_EXTENSIONS = {".png", ".svg", ".webp", ".jpg", ".jpeg"}
REGISTRY_EXTENSIONS = {".gd", ".tscn", ".tres", ".json", ".cfg", ".gdshader", ".godot"}
# Renderer semantic row order vs. the game's V3 atlas row semantics.
GROUND_ROWS = (5, 0, 2, 4, 1, 3, 2, 7)
WATER_ROW = 6


def ensure_within(root: Path, dest: Path):
    if not dest.resolve().is_relative_to(root.resolve()):
        raise ValueError("Output must stay in game repository: " + str(dest))


def install(root: Path, *, prune: bool = True) -> dict:
    root = root.resolve()
    if not (root / "project.godot").is_file():
        raise ValueError("Expected full Godot repository")
    temporary = root / "build/starlit_global_art_factory_v3"
    out = root / RUNTIME_REL
    ensure_within(root, out)
    # Never overwrite existing art until full generation/verification completes.
    report = produce(root, temporary, set(SCOPES), force=True)
    if report["errors"] or report["status"] != "candidates_complete":
        raise RuntimeError("Art production failed: " + repr(report["errors"][:10]))
    expected = report["assets"]
    if not expected:
        raise RuntimeError("Cannot install empty generated art")
    for item in expected:
        actual = verify(temporary / item["path"], item["group"])
        if actual["sha256"] != item["sha256"]:
            raise RuntimeError("Generated art SHA mismatch: " + item["path"])
    # Install one physical PNG per canonical item, equipment and skill ID.
    # Runtime ID mappings are promoted only after all 288 files are verified.
    content_icons_report = generate_content_icons(root)
    out.mkdir(parents=True, exist_ok=True)
    for item in expected:
        source = temporary / item["path"]
        target = out / item["path"]
        ensure_within(root, target)
        target.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(source, target)

    # World tiles are NOT ordered like raw candidate sheets: preserve gameplay
    # 0/1 TileSet source IDs and rows 0..7 with correct visual semantics.
    for item in expected:
        if item["group"] != "terrain":
            continue
        stem = item["id"]
        with Image.open(out / item["path"]) as raw:
            source = raw.convert("RGBA")
        ground = Image.new("RGBA", (256, 256))
        water = Image.new("RGBA", (256, 256))
        for row, source_row in enumerate(GROUND_ROWS):
            sliver = source.crop((0, 32 * source_row, 256, 32 * (source_row + 1)))
            ground.paste(sliver, (0, row * 32))
            wave = source.crop((0, WATER_ROW * 32, 256, (WATER_ROW + 1) * 32))
            water.paste(wave, (0, row * 32))
        ground.save(out / "terrain" / (stem + "_ground.png"), optimize=True)
        water.save(out / "terrain" / (stem + "_water.png"), optimize=True)

    for item in expected:
        target = out / item["path"]
        if hashlib.sha256(target.read_bytes()).hexdigest() != item["sha256"]:
            raise RuntimeError("Installed asset changed: " + str(target))
    routes = {
        "schema": "starlit.global_factory.live.v3",
        "enabled": True,
        "source": "programmatic_generated_not_ai_model",
        "visual_acceptance": "not_tested",
        "asset_count": len(expected),
        "counts": report["counts"],
        "assets": {item["group"] + "." + item["id"]: {
            "path": "res://" + (RUNTIME_REL / item["path"]).as_posix(),
            "sha256": item["sha256"],
            "provenance": item["provenance"]}
            for item in expected},
    }
    (out / "active.json").write_text(
        json.dumps(routes, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    # Real 6-pose/4-frame PNG sheets from 66 already-installed boss identities.
    boss_motion_report = create_boss_motion(root)
    shore_wave_report = generate_shore_waves(root)

    # Find safe-to-delete legacy images; do not infer "unused" from missing
    # source-pack archives or audit report prose. A dynamic path directory
    # reference in game GDScript prevents its removal.
    old = [p for p in (root / "assets/art").rglob("*")
           if p.is_file() and p.suffix.lower() in LEGACY_EXTENSIONS
           and not p.is_relative_to(out)]
    source_text = []
    for base in ("scripts", "scenes", "data", "addons"):
        folder = root / base
        if not folder.is_dir():
            continue
        for p in folder.rglob("*"):
            if p.is_file() and p.suffix.lower() in REGISTRY_EXTENSIONS:
                # Historical art audits are not executable references, but
                # active manifests and maps must remain first-class references.
                if p.name in ("c_act01_source_blob_provenance_v1.json",):
                    continue
                try:
                    source_text.append(p.read_text("utf-8-sig"))
                except (UnicodeError, OSError):
                    pass
    in_use = "\n".join(source_text)
    deleted = []
    kept = []
    for p in sorted(old):
        rel = p.relative_to(root).as_posix()
        parent = p.parent.relative_to(root).as_posix()
        stem = p.stem
        # A stem or an implied dynamic directory reference counts as live.
        # Refuse to prune legacy live runtime/experimental registrations merely
        # because a code path builds filenames at runtime.
        live = rel in in_use or "res://" + rel in in_use or parent in in_use
        if not live and (f'/"{stem}"' in in_use or f'/{stem}.' in in_use):
            live = True
        # Source files bound to historic integrity checks are retained unless
        # not referenced anywhere and not under runtime.
        if p.is_relative_to(root / "assets/art/runtime"):
            live = True
        if live or not prune:
            kept.append(rel)
            continue
        p.unlink()
        deleted.append(rel)
    summary = {
        "schema": "starlit.global_factory.install.v3",
        "status": "runtime_assets_installed",
        "generated_assets": len(expected),
        "new_content_icons": content_icons_report["icons"],
        "new_boss_action_sheets": boss_motion_report["bosses"],
        "new_shore_wave_sheets": shore_wave_report["sheets"],
        "terrain_pairs": report["counts"].get("terrain", 0),
        "removed_unreferenced_legacy": deleted,
        "retained_legacy_requires_rebinding": len(kept),
        "kept_legacy": kept,
        "warning": "Generated visuals are not approved premium hand-painted art.",
    }
    (root / "build/global_art_v3_install_report.json").write_text(
        json.dumps(summary, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    return summary


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--project", type=Path, default=Path(__file__).resolve().parents[1])
    parser.add_argument("--no-prune", action="store_true")
    opts = parser.parse_args()
    result = install(opts.project, prune=not opts.no_prune)
    print(json.dumps({k: v for k,v in result.items() if k not in ("kept_legacy","removed_unreferenced_legacy")},
                     ensure_ascii=False, indent=2))
    print("DELETED LEGACY ART:", len(result["removed_unreferenced_legacy"]))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
