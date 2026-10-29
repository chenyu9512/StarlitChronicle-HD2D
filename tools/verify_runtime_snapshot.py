#!/usr/bin/env python3
"""Verify a standalone generated-only Godot snapshot, never raw third-party art."""
from __future__ import annotations
import argparse
import hashlib
import json
from pathlib import Path

IMAGE_SUFFIXES = {".png", ".jpg", ".jpeg", ".webp", ".svg", ".gif", ".bmp"}
FORBIDDEN = (
    "assets/art/source_packs/", "assets/art/candidates/",
    "assets/art/external/", "docs/", ".github/", "build/", "tools/",
)
REQUIRED = (
    "project.godot", "scenes/first_act.tscn",
    "data/assets/c_act01_global_distribution_v14.json",
    "data/assets/c_art_content_icons_v6.json",
    "data/assets/c_art_allocated_decor_runtime_v1.json",
    "data/assets/c_art_packs.json",
    "data/assets/c_act01_hd2d_v18.json",
    "data/assets/art_theme_v2.json",
    "data/assets/c_art_runtime_registry_v1.json",
    "assets/art/runtime/global_factory_v3/active.json",
    "assets/art/runtime/generated_gaps_v10/manifest.json",
    "assets/art/runtime/boss_motion_v1/manifest.json",
)


def references(value):
    if isinstance(value, str) and value.startswith("res://assets/"):
        yield value.removeprefix("res://")
    elif isinstance(value, dict):
        for child in value.values():
            yield from references(child)
    elif isinstance(value, list):
        for child in value:
            yield from references(child)


def verify(root: Path) -> dict:
    files = {p.relative_to(root).as_posix(): p
             for p in root.rglob("*") if p.is_file() and ".git" not in p.parts}
    rel = set(files)
    errors: list[str] = []
    for name in REQUIRED:
        if name not in rel:
            errors.append("Missing playable runtime contract: " + name)
    for name in sorted(rel):
        if name.startswith(FORBIDDEN):
            errors.append("Non-player source leaked: " + name)
    if errors:
        raise RuntimeError("\n".join(errors[:60]))

    def read(name, schema):
        result = json.loads(files[name].read_text(encoding="utf-8"))
        if not isinstance(result, dict) or result.get("schema") != schema:
            errors.append("Runtime JSON schema mismatch: " + name)
            return {}
        return result

    required_images: set[str] = set()
    sha256s: dict[str, str] = {}

    def add(source, label, sha=None):
        if not isinstance(source, str) or not source.startswith("res://assets/art/runtime/"):
            errors.append("Noncanonical playable art: " + label + " " + str(source))
            return
        path = source.removeprefix("res://")
        if ".." in Path(path).parts or Path(path).suffix.lower() not in IMAGE_SUFFIXES:
            errors.append("Unsafe runtime image: " + label + " " + path)
            return
        required_images.add(path)
        if path not in rel:
            errors.append("Referenced playable image missing: " + label + " " + path)
            return
        if sha and sha256s.get(path, sha) != sha:
            errors.append("Conflicting image checksums: " + path)
        elif sha:
            sha256s[path] = sha

    if "[editor_plugins]" in files["project.godot"].read_text(encoding="utf-8"):
        errors.append("Development editor plugin enabled in player build")

    theme = read("data/assets/art_theme_v2.json", "starlit.art_theme.v2")
    themes = theme.get("themes", [])
    slots = themes[0].get("slots", {}) if len(themes) == 1 else {}
    if len(slots) != 109:
        errors.append("109 official playable art slots required")
    for identity, entry in slots.items():
        add(entry.get("source"), "theme:" + identity)

    registry = read("data/assets/c_art_runtime_registry_v1.json",
                    "starlit.c.art_runtime_registry.v1")
    canonical = registry.get("canonical_slots", {})
    if set(canonical) != set(slots):
        errors.append("Runtime art slots differ from displayed official theme")
    for identity, entry in canonical.items():
        source = entry.get("source")
        if source != slots.get(identity, {}).get("source"):
            errors.append("Canonical theme source divergence: " + identity)
        add(source, "registry:" + identity)

    factory = read("assets/art/runtime/global_factory_v3/active.json",
                   "starlit.global_factory.live.v3")
    assets = factory.get("assets", {})
    if factory.get("enabled") is not True or factory.get("asset_count") != 451 or len(assets) != 451:
        errors.append("Original generated V3 player assets incomplete")
    normals = 0
    for identity, record in assets.items():
        add(record.get("path"), "V3:" + identity, record.get("sha256"))
        normal = record.get("normal_map_path")
        if normal:
            normals += 1
            add(normal, "V3 normal:" + identity, record.get("normal_map_sha256"))
    if normals != factory.get("normal_map_count"):
        errors.append("Original generated normal maps incomplete")

    gaps = read("assets/art/runtime/generated_gaps_v10/manifest.json",
                "starlit.main2.gap_fill.v10")
    if len(gaps.get("assets", {})) != gaps.get("generated_count"):
        errors.append("Generated exact-role V10 art incomplete")
    for identity, record in gaps.get("assets", {}).items():
        add(record.get("source"), "V10:" + identity, record.get("sha256"))

    boss = read("assets/art/runtime/boss_motion_v1/manifest.json",
                "starlit.boss_motion.runtime.v1")
    if len(boss.get("assets", {})) != boss.get("count") or len(boss.get("assets", {})) != 66:
        errors.append("66 boss action sheets required")
    for identity, record in boss.get("assets", {}).items():
        add(record.get("source"), "Boss motion:" + identity, record.get("sha256"))
        add(record.get("source_identity"), "Boss portrait:" + identity, record.get("source_sha256"))

    v14 = read("data/assets/c_act01_global_distribution_v14.json",
               "starlit.c.act01_global_distribution.v14")
    for path in references(v14.get("runtime", {})):
        add("res://" + path, "V14 map art")
    v18 = read("data/assets/c_act01_hd2d_v18.json",
               "starlit.c.act01_hd2d_v18")
    placements = v18.get("placements", [])
    materials = v18.get("materials", {})
    props = {str(entry.get("source", "")) for entry in placements}
    if len(placements) != 17 or len(props) != 14 or len(materials) != 11:
        errors.append("V18 playable coast role count incomplete")
    for path in props | set(materials.values()):
        add(path, "V18 coast prop or material")

    for name, field in (
        ("data/assets/c_art_content_icons_v6.json", "records"),
        ("data/assets/c_art_allocated_decor_runtime_v1.json", "placements"),
    ):
        obj = json.loads(files[name].read_text(encoding="utf-8"))
        for entry in obj.get(field, []):
            add(entry.get("icon", entry.get("source", "")), name)

    packs = read("data/assets/c_art_packs.json", "starlit.c.art_packs.v1")
    if packs.get("packs", []) != []:
        errors.append("Removed third-party packs reintroduced into shipping art")

    for name in sorted(rel):
        if not name.startswith("assets/art/") or Path(name).suffix.lower() not in IMAGE_SUFFIXES:
            continue
        target = files[name]
        if target.stat().st_size == 0:
            errors.append("Empty runtime art file: " + name)
            continue
        if name.endswith(".png") and target.open("rb").read(8) != b"\x89PNG\r\n\x1a\n":
            errors.append("Invalid PNG signature: " + name)

    for name, expected in sha256s.items():
        if name in files and hashlib.sha256(files[name].read_bytes()).hexdigest() != expected:
            errors.append("Runtime image content differs from approved manifest SHA: " + name)
    if errors:
        raise RuntimeError("\n".join(errors[:70]))
    art_images = sum(p.startswith("assets/art/") and Path(p).suffix.lower() in IMAGE_SUFFIXES for p in rel)
    return {
        "runtime_files": len(rel), "runtime_art_images": art_images,
        "explicit_art_references_verified": len(required_images),
        "v3_assets": len(assets), "v3_normal_maps": normals,
        "v10_generated_images": len(gaps.get("assets", {})),
        "boss_action_sheets": len(boss.get("assets", {})),
        "theme_slots": len(slots), "source_pack_files": 0,
        "third_party_uploaded_images": 0,
    }


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--path", required=True)
    args = parser.parse_args()
    result = verify(Path(args.path).resolve())
    print(json.dumps({"status": "PASS", **result}, ensure_ascii=False, sort_keys=True))


if __name__ == "__main__":
    main()
