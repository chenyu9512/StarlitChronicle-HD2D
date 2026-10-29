#!/usr/bin/env python3
"""V3 single-view art audit. Read existing manifests; do not create another competing registry.

A source file, a declared role, an actual scene link and visual acceptance are separate
facts. The generated report is a derived view, not an authority for runtime substitutions.
"""
from __future__ import annotations

import argparse
import json
import re
import struct
from collections import Counter
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
THEME = "data/assets/art_theme_v2.json"
ALLOCATION = "data/assets/c_art_allocation_v6.json"
EXTERNAL = "data/assets/c_art_usage_external_v12.json"
SOURCE = "data/assets/c_art_usage_source_v12.json"
CHAPTER_MAPS = (
    "map_coast_01", "map_coast_02", "map_coast_04",
    "map_coast_02", "map_coast_03", "map_coast_05",
)
INTERIORS = (
    "data/levels/v4/interiors/map_coast_01__house.json",
    "data/levels/v4/interiors/map_coast_02__shelter.json",
    "data/levels/v4/interiors/map_coast_02__tavern.json",
)
ALLOWED_STAGES = {
    "runtime_source_pending_visual_signoff",
    "runtime_svg_pending_human_signoff",
    "candidate_not_approved_boss_identity",
    "visual_accepted", "commercial_visual_accepted",
}
IMAGE_TYPES = {".png", ".jpg", ".jpeg", ".webp", ".svg"}


def load(path: str):
    return json.loads((ROOT / path).read_text(encoding="utf-8"))


def image_probe(path: Path) -> str:
    if not path.is_file():
        return "missing_file"
    if path.stat().st_size == 0:
        return "empty_file"
    if path.suffix.lower() not in IMAGE_TYPES:
        return "unsupported_extension"
    if path.suffix.lower() == ".png":
        with path.open("rb") as fh:
            raw = fh.read(24)
        if len(raw) != 24 or raw[:8] != b"\x89PNG\r\n\x1a\n":
            return "bad_png_header"
        w, h = struct.unpack(">II", raw[16:24])
        if not (8 <= w <= 8192 and 8 <= h <= 8192):
            return "bad_png_dimensions"
    elif path.suffix.lower() == ".svg":
        if b"<svg" not in path.read_bytes()[:4096].lower():
            return "bad_svg"
    return "source_present"


def stem(key: str) -> str:
    return re.sub(r"[^a-z0-9]+", "_", key.lower().split(".")[-1]).strip("_")


def audit() -> dict:
    manifest = load(THEME)
    problems = []
    warnings = []
    # The generated-only library intentionally retired these two third-party
    # provenance snapshots. They are archival counts, not active runtime
    # manifests; missing snapshots must not crash strict source verification.
    # Never skip the mandatory live theme, V18 or interior source checks below.
    allocation = load(ALLOCATION)
    external = load(EXTERNAL) if (ROOT / EXTERNAL).is_file() else {"rows": []}
    source = load(SOURCE) if (ROOT / SOURCE).is_file() else {"rows": []}
    for historical in (EXTERNAL, SOURCE):
        if not (ROOT / historical).is_file():
            warnings.append("retired historical snapshot absent: " + historical +
                            "; counts unavailable, not an active art approval")
    if manifest.get("schema") != "starlit.art_theme.v2":
        problems.append("unexpected theme schema")
    themes = manifest.get("themes", [])
    if len(themes) != 1:
        problems.append("expected one curated first-act V2 theme, not duplicate authorities")

    chapters = []
    for number, map_id in enumerate(CHAPTER_MAPS, 1):
        file_path = f"data/levels/v3/{map_id}.json"
        exists = (ROOT / file_path).is_file()
        if not exists:
            problems.append(f"chapter {number} missing map: {file_path}")
        chapters.append({"chapter": number, "map_id": map_id,
                         "map_file": file_path, "map_file_exists": exists,
                         "scene_art_accepted": False})
    for rel in INTERIORS:
        if not (ROOT / rel).is_file():
            problems.append("missing first-act interior: " + rel)

    all_slots = {}
    risky_aliases = []
    for theme in themes:
        for slot_id, entry in theme.get("slots", {}).items():
            if slot_id in all_slots:
                problems.append("duplicate semantic ID " + slot_id)
                continue
            source_path = str(entry.get("source", ""))
            if not source_path.startswith("res://assets/art/runtime/") or ".." in source_path:
                problems.append("unsafe runtime path for " + slot_id)
                image_state = "forbidden_source"
            else:
                image_state = image_probe(ROOT / source_path[6:])
                if image_state != "source_present":
                    problems.append(f"{slot_id}: {image_state}: {source_path}")
            stage = entry.get("stage", "unreviewed")
            if stage not in ALLOWED_STAGES:
                warnings.append("unreviewed or unknown stage " + slot_id + ": " + str(stage))
            all_slots[slot_id] = {
                "semantic_id": slot_id,
                "category": entry.get("category", "unknown"),
                "source_path": source_path,
                "required": bool(entry.get("required", False)),
                "source_check": image_state,
                "declared_stage": stage,
                "scene_binding": "unverified_not_automatically_inferred",
                "human_visual_acceptance": stage in ("visual_accepted", "commercial_visual_accepted"),
            }
        for alias, target in theme.get("aliases", {}).items():
            if target not in theme.get("slots", {}) or alias in theme.get("slots", {}):
                problems.append(f"invalid semantic alias {alias} -> {target}")
                continue
            if stem(alias) != stem(target):
                risky_aliases.append({"alias": alias, "maps_to": target,
                    "reason": "object_identity_differs_requires_art_director_review"})
    # Real explicit data-to-texture bindings, not inferred from matching names.
    tavern = load("data/levels/v4/interiors/map_coast_02__tavern.json")
    tavern_slots = set()
    if tavern.get("art_profile") != "coast_act01_tavern_v1":
        problems.append("Black Sail tavern profile is not the live Act-I profile")
    for row in tavern.get("visuals", []):
        ident = "interior.tavern." + str(row.get("asset", ""))
        record = all_slots.get(ident)
        if record is None:
            problems.append("Black Sail furniture absent from canonical V2 theme: " + ident)
            continue
        if record["category"] != "tavern_interior":
            problems.append("Black Sail furniture mapped to wrong category: " + ident)
        record["scene_binding"] = "explicit_v4_tavern_visual"
        tavern_slots.add(ident)
    atlas = "interior.tavern.tavern_wood_atlas"
    if tavern.get("art_tileset") != all_slots.get(atlas, {}).get("source_path"):
        problems.append("Black Sail floor atlas differs from the canonical art slot")
    else:
        all_slots[atlas]["scene_binding"] = "explicit_v4_tavern_atlas"
        tavern_slots.add(atlas)

    hd2d = load("data/assets/c_act01_hd2d_v18.json")
    by_source = {v["source_path"]: v for v in all_slots.values()}
    bound_hd2d = set()
    unregistered_live_hd2d = set()
    for placement in hd2d.get("placements", []):
        source_path = str(placement.get("source", ""))
        map_id = str(placement.get("map_id", ""))
        if map_id not in set(CHAPTER_MAPS):
            problems.append("V18 placement outside Act-I playable maps: " + map_id)
        if source_path not in by_source:
            unregistered_live_hd2d.add(source_path)
        else:
            by_source[source_path]["scene_binding"] = "explicit_v18_world_placement"
            bound_hd2d.add(source_path)
    if unregistered_live_hd2d:
        warnings.append(f"{len(unregistered_live_hd2d)} playable V18 prop textures have no V2 theme slot: theme swap is not complete")
    for material_path in hd2d.get("materials", {}).values():
        record = by_source.get(str(material_path))
        if record:
            record["scene_binding"] = "explicit_v18_map_material"

    allocation_state = Counter(str(row.get("state", "unknown")) for row in allocation.get("rows", []))
    external_states = Counter(str(row.get("status", "unknown")) for row in external.get("rows", []))
    source_states = Counter(str(row.get("state", "unknown")) for row in source.get("rows", []))
    runtime_complete = sum(s["source_check"] == "source_present" for s in all_slots.values())
    visually_accepted = sum(s["human_visual_acceptance"] for s in all_slots.values())
    return {
        "schema": "starlit.art_pipeline.audit.v3",
        "authoritative_theme_manifest": THEME,
        "meaning": "A generated read-only crosswalk; no automatic semantic approval or placement claim",
        "counts": {
            "registered_semantic_slots": len(all_slots),
            "verified_runtime_source_files": runtime_complete,
            "required_runtime_source_files": sum(s["required"] for s in all_slots.values()),
            "visually_approved_slots_from_manifest": visually_accepted,
            "allocation_rows": len(allocation.get("rows", [])),
            "source_only_rows": len(source.get("rows", [])),
            "external_rows": len(external.get("rows", [])),
            "risky_aliases": len(risky_aliases),
            "act01_chapters": len(chapters),
            "verified_scene_visible_slots": None,
            "explicit_tavern_bound_slots": len(tavern_slots),
            "explicit_v18_bound_props_registered_to_theme": len(bound_hd2d),
            "live_v18_prop_paths_not_in_theme": len(unregistered_live_hd2d),
        },
        "allocation_by_state": dict(sorted(allocation_state.items())),
        "external_by_state": dict(sorted(external_states.items())),
        "source_by_state": dict(sorted(source_states.items())),
        "chapter_contracts": chapters,
        "interior_contracts": list(INTERIORS),
        "alias_review_queue": risky_aliases,
        "unregistered_live_v18_props": sorted(unregistered_live_hd2d),
        "semantic_slots": all_slots,
        "warnings": warnings,
        "errors": problems,
        "release_visual_approval": False,
    }


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--strict", action="store_true",
                        help="Fail on broken files/identity, not on intentionally pending visual QA")
    parser.add_argument("--out", type=Path,
                        default=Path("build/art-theme-v3/audit.json"))
    args = parser.parse_args()
    report = audit()
    target = args.out if args.out.is_absolute() else ROOT / args.out
    target.parent.mkdir(parents=True, exist_ok=True)
    target.write_text(json.dumps(report, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(json.dumps({"output": str(target), "counts": report["counts"],
                      "errors": report["errors"][:20],
                      "alias_review_queue": report["alias_review_queue"]},
                     ensure_ascii=False))
    if args.strict and report["errors"]:
        raise SystemExit(1)


if __name__ == "__main__":
    main()
