#!/usr/bin/env python3
"""Strict checks for a generated, standalone and source-pack-free Godot runtime."""
import argparse
import json
from pathlib import Path

IMAGE_SUFFIXES = {".png", ".jpg", ".jpeg", ".webp", ".svg", ".gif", ".bmp"}
FORBIDDEN = (
    "assets/art/source_packs/", "assets/art/candidates/",
    "docs/", ".github/", "build/"
)
REQUIRED = ("project.godot", "scenes/first_act.tscn",
            "data/assets/c_act01_global_distribution_v14.json",
            "data/assets/c_art_content_icons_v6.json",
            "data/assets/c_art_allocated_decor_runtime_v1.json",
            "data/assets/c_art_packs.json",
            "data/assets/c_act01_hd2d_v18.json",
            "data/assets/art_theme_v2.json")


def references(value):
    if isinstance(value, str) and value.startswith("res://assets/"):
        yield value[6:]
    elif isinstance(value, dict):
        for child in value.values():
            yield from references(child)
    elif isinstance(value, list):
        for child in value:
            yield from references(child)


def verify(root: Path) -> dict:
    errors = []
    files = [p for p in root.rglob("*") if p.is_file() and ".git" not in p.parts]
    rel = {p.relative_to(root).as_posix() for p in files}
    for path in REQUIRED:
        if path not in rel:
            errors.append("Required runtime file missing: " + path)
    for path in sorted(rel):
        if path.startswith(FORBIDDEN) or path.startswith("tools/"):
            errors.append("Development-only file leaked: " + path)
    if errors:
        raise RuntimeError("\n".join(errors[:60]))
    # The standalone Runtime has no editor addons: a dangling enabled plugin
    # produces a Godot clean-import warning and confuses local users.
    project_text = (root / "project.godot").read_text(encoding="utf-8")
    if "[editor_plugins]" in project_text:
        errors.append("Runtime contains editor-only plugin configuration")
    registry = json.loads((root / REQUIRED[2]).read_text(encoding="utf-8"))
    runtime = registry.get("runtime", {})
    used_paths = set(references(runtime))
    # All 81 official art-theme slots are loadable by players, including
    # file names assembled dynamically in GDScript. A slim build may not
    # silently omit them while still advertising the same theme.
    theme = json.loads((root / "data/assets/art_theme_v2.json").read_text(encoding="utf-8"))
    if theme.get("schema") != "starlit.art_theme.v2":
        errors.append("Runtime art theme schema mismatch")
    theme_paths = set()
    for item in theme.get("themes", []):
        for slot_id, slot in item.get("slots", {}).items():
            source = str(slot.get("source", ""))
            if not source.startswith("res://assets/art/runtime/") or ".." in source:
                errors.append("Unsafe art-theme source in Runtime: " + slot_id)
            else:
                theme_paths.add(source.removeprefix("res://"))
    if not theme_paths:
        errors.append("Runtime has no official playable theme slots")
    used_paths.update(theme_paths)
    # Semantic V17 art uses const-prefix GDScript concatenation; these eight
    # real gameplay files are intentionally not visible to the URL regex.
    v17 = "assets/art/runtime/act01_semantic_v17/"
    v17_live = {"flowerpot.png", "sea_crystal.png", "mangrove.png", "crab.png",
                "harbor_crane.png", "sea_wind_pine.png", "saltwind_oak.png",
                "tide_pool.png"}
    used_paths.update(v17 + name for name in v17_live)
    if {p for p in rel if p.startswith(v17)} != {v17 + x for x in v17_live}:
        errors.append("Runtime V17 art does not exactly match seven bound files")
    # V18 names come from a manifest, not literals in the Godot script.
    hd2d = json.loads((root / "data/assets/c_act01_hd2d_v18.json").read_text(encoding="utf-8"))
    v18_paths = set(references(hd2d.get("materials", {})))
    v18_paths.update(str(row.get("source", "")).removeprefix("res://")
                     for row in hd2d.get("placements", []))
    v18_root = "assets/art/runtime/act01_hd2d_v18/"
    distinct_props = {str(row.get("source","")).removeprefix("res://")
                      for row in hd2d.get("placements", [])}
    material_count = len(hd2d.get("materials", {}))
    if (material_count != 11 or len(distinct_props) < 10 or
            len(v18_paths) != material_count + len(distinct_props) or
            {p for p in rel if p.startswith(v18_root)} != v18_paths):
        errors.append("V18 Runtime does not exactly match the active manifest art")
    used_paths.update(v18_paths)
    icons = json.loads((root / REQUIRED[3]).read_text(encoding="utf-8"))
    decor = json.loads((root / REQUIRED[4]).read_text(encoding="utf-8"))
    packs = json.loads((root / REQUIRED[5]).read_text(encoding="utf-8"))
    used_paths.update(str(x.get("icon", "")).removeprefix("res://") for x in icons.get("records", []))
    used_paths.update(str(x.get("source", "")).removeprefix("res://") for x in decor.get("placements", []))
    for pack in packs.get("packs", []):
        if pack.get("id") == "uploaded_later_v1":
            used_paths.update(str(x.get("source", "")).removeprefix("res://")
                              for x in pack.get("mappings", []))
    for path in sorted(used_paths):
        if not path.startswith("assets/") or path not in rel:
            errors.append("Referenced image is absent or invalid: " + path)
        elif Path(path).suffix.lower() not in IMAGE_SUFFIXES:
            errors.append("Art slot does not point to an image: " + path)
        elif path.startswith(FORBIDDEN):
            errors.append("Runtime refers to production-only material: " + path)
    all_images = {p for p in rel if p.startswith("assets/art/") and
                  Path(p).suffix.lower() in IMAGE_SUFFIXES}
    for path in sorted(all_images):
        target = root / path
        if target.stat().st_size == 0:
            errors.append("Zero-length art image: " + path)
        if path.endswith(".png") and target.open("rb").read(8) != b"\x89PNG\r\n\x1a\n":
            errors.append("Invalid PNG signature: " + path)
    if errors:
        raise RuntimeError("\n".join(errors[:60]))
    return {"runtime_files": len(rel), "runtime_art_images": len(all_images),
            "explicit_art_references_verified": len(used_paths),
            "source_pack_files": 0, "act01_hd2d_images": len(v18_paths)}


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--path", required=True)
    args = parser.parse_args()
    result = verify(Path(args.path).resolve())
    print(json.dumps({"status": "PASS", **result}, ensure_ascii=False, sort_keys=True))


if __name__ == "__main__":
    main()
