#!/usr/bin/env python3
"""Read-only source-of-truth audit before removing original generated artwork.

Stdlib only. Does not modify assets, the Godot project or old art.
Usage:
    python tools/audit_uploaded_only_art.py --out /tmp/starlit-art-deps.json
    python tools/audit_uploaded_only_art.py --require-no-old
"""
from __future__ import annotations

import argparse
import hashlib
import json
import re
from pathlib import Path

EXTS = {".png", ".jpg", ".jpeg", ".webp", ".svg"}
UPLOADED = (
    "assets/art/source_packs/",
    "assets/art/external/cc0_named_v1/",
)
IMAGE_PATH = re.compile(r'res://assets/[^"\'\s]+?\.(?:png|jpe?g|webp|svg)', re.I)
DYNAMIC = re.compile(r'res://assets/[^"\'\s]*%[sdi][^"\'\s]*', re.I)
PACK_ID = "uploaded_later_v1"


def git_blob_id(path: Path) -> str:
    data = path.read_bytes()
    return hashlib.sha1(b"blob " + str(len(data)).encode() + b"\0" + data).hexdigest()


def source_inputs(root: Path):
    for group in ("scripts", "scenes", "data/levels", "story"):
        base = root / group
        if not base.exists():
            continue
        for path in base.rglob("*"):
            if not path.is_file() or path.suffix.lower() not in {".gd", ".tscn", ".tres", ".json"}:
                continue
            if ".godot" in path.parts:
                continue
            yield path
    project = root / "project.godot"
    if project.is_file():
        yield project


def audit(root: Path, verify_blobs: bool = False) -> dict:
    root = root.resolve()
    assert (root / "project.godot").exists(), "Not a Godot repository root"
    snapshot_path = root / "data/assets/c_uploaded_only_full_audit_2026_10_27.json"
    raw = json.loads(snapshot_path.read_text(encoding="utf-8"))
    rows = raw["rows"]
    manifest = json.loads((root / "data/assets/c_art_packs.json").read_text(encoding="utf-8"))
    pack = next((p for p in manifest["packs"] if p.get("id") == PACK_ID), None)
    if pack is None:
        raise ValueError("Builtin later-upload art pack is absent")
    mappings = {
        m["target"].removeprefix("res://"): m["source"].removeprefix("res://")
        for m in pack.get("mappings", [])
        if isinstance(m, dict) and isinstance(m.get("target"), str)
        and isinstance(m.get("source"), str)
    }
    found = set()
    for item in (root / "assets").rglob("*"):
        if item.is_file() and item.suffix.lower() in EXTS:
            found.add(item.relative_to(root).as_posix())
    icon = root / "icon.png"
    if icon.is_file():
        found.add("icon.png")
    known = {row["path"] for row in rows}
    new = sorted(found - known)
    missing = sorted(known - found)
    hash_errors = []
    if verify_blobs:
        for row in rows:
            path = row["path"]
            if path not in found:
                continue
            if git_blob_id(root / path) != row["blob"]:
                hash_errors.append(path)

    direct = {}
    dynamics = []
    scanned = []
    for file in source_inputs(root):
        text = file.read_text(encoding="utf-8", errors="replace")
        rel = file.relative_to(root).as_posix()
        scanned.append(rel)
        for found_ref in set(IMAGE_PATH.findall(text)):
            path = found_ref.removeprefix("res://")
            direct.setdefault(path, []).append(rel)
        for m in DYNAMIC.findall(text):
            dynamics.append({"file": rel, "pattern": m[:200]})

    imported_sources = set(p for p in found if p.startswith(UPLOADED))
    check_mappings = []
    for target, source in sorted(mappings.items()):
        check_mappings.append({
            "target": target,
            "source": source,
            "target_exists": target in found,
            "source_exists": source in found,
            "from_uploaded_set": source in imported_sources,
            "in_literal_code": bool(direct.get(target)),
            "runtime_dimensions": "not_tested",
            "in_game_appearance": "not_tested",
        })
    legacy = []
    for row in rows:
        path = row["path"]
        if path.startswith(UPLOADED):
            continue
        matching_dynamic = sorted({
            rec["file"] for rec in dynamics
            if path.startswith(rec["pattern"].removeprefix("res://").split("%", 1)[0])
        })
        legacy.append({
            "path": path, "blob": row["blob"],
            "replacement_source": mappings.get(path),
            "direct_references": sorted(set(direct.get(path, []))),
            "possible_dynamic_references": matching_dynamic,
            "safe_to_delete": False,  # Needs Godot evidence + dynamic review first.
            "status": "mapped_pending_godot" if path in mappings else "needs_uploaded_replacement",
        })
    return {
        "schema": "starlit.c_art_live_dependency_audit.v1",
        "source_snapshot_sha": raw["source_tree_sha"],
        "scanned_text_file_count": len(scanned),
        "recorded_images": len(known),
        "current_image_count": len(found),
        "new_since_snapshot": new,
        "missing_since_snapshot": missing,
        "blob_mismatch": hash_errors,
        "pack_mapping_count": len(mappings),
        "invalid_mappings": [
            m for m in check_mappings
            if not(m["target_exists"] and m["source_exists"] and m["from_uploaded_set"])
        ],
        "legacy_total": len(legacy),
        "legacy_still_pending": sum(1 for m in legacy if not m["replacement_source"]),
        "legacy_direct_runtime_refs": sum(1 for m in legacy if m["direct_references"]),
        "legacy_dynamic_risks": sum(1 for m in legacy if m["possible_dynamic_references"]),
        "safe_to_delete": 0,
        "mappings": check_mappings,
        "dynamic_patterns": dynamics,
        "legacy": legacy,
        "scope": "Read-only: text references are not proof of Godot display; missing dynamic references are possible.",
    }


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--root", type=Path, default=Path(__file__).resolve().parents[1])
    parser.add_argument("--out", type=Path)
    parser.add_argument("--verify-blobs", action="store_true")
    parser.add_argument("--require-no-old", action="store_true",
                        help="Nonzero exit until every legacy image is fully retired")
    args = parser.parse_args()
    result = audit(args.root, args.verify_blobs)
    print(json.dumps({k: v for k, v in result.items() if k not in
                      {"legacy", "mappings", "dynamic_patterns"}}, ensure_ascii=False, indent=2))
    if args.out:
        args.out.parent.mkdir(parents=True, exist_ok=True)
        args.out.write_text(json.dumps(result, ensure_ascii=False, indent=2) + "\n",
                            encoding="utf-8")
    if result["invalid_mappings"] or result["blob_mismatch"]:
        return 1
    if args.require_no_old and result["legacy_still_pending"]:
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
