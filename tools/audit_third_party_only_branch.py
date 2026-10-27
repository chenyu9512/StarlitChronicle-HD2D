#!/usr/bin/env python3
"""Read-only audit of the third-party-only art migration (stdlib only)."""
from __future__ import annotations

import argparse
import hashlib
import json
import re
import struct
from collections import defaultdict
from pathlib import Path

INDEX = "data/assets/c_third_party_only_migration_v1.json"
UPLOADS = "assets/art/external/cc0_named_v1/"
DIM = re.compile(r"(\d{2,4})x(\d{2,4})\.png$", re.I)
SVG = re.compile(r"res://assets/[A-Za-z0-9_./%-]+\.svg", re.I)
DYNAMIC = re.compile(r"res://assets/[^\s\"']*(?:%[sdi]|\{[^}]+\})", re.I)
SKIP = {INDEX, "data/assets/c_uploaded_only_full_audit_2026_10_27.json",
        "data/assets/c_art_catalog.json", "data/assets/c_art_source_originals.json"}


def git_blob_sha(data):
    return hashlib.sha1(b"blob " + str(len(data)).encode() + b"\0" + data).hexdigest()


def png_size(data):
    if len(data) < 24 or data[:8] != b"\x89PNG\r\n\x1a\n" or data[12:16] != b"IHDR":
        return None
    return struct.unpack(">II", data[16:24])


def source_files(root):
    for folder in ("scripts", "scenes", "data", "story"):
        base = root / folder
        if not base.is_dir():
            continue
        for path in base.rglob("*"):
            if path.is_file() and path.suffix.lower() in {".gd", ".tscn", ".tres", ".json", ".cfg"}:
                rel = path.relative_to(root).as_posix()
                if rel not in SKIP and "/source_packs/" not in rel and "/_archive/" not in rel:
                    yield path
    if (root / "project.godot").is_file():
        yield root / "project.godot"


def audit(root):
    entries = json.loads((root / INDEX).read_text(encoding="utf-8"))["mappings"]
    out = {"schema": "starlit.third_party_only_audit.v1",
           "errors": [], "risks": [], "dimensions": [], "duplicate_characters": [],
           "deleted_svg_references": [], "dynamic_paths": [], "summary": {}}
    errors, risks = out["errors"], out["risks"]
    blobs, seen, sources, deleted, action_count = {}, set(), set(), set(), defaultdict(int)
    character_sources = defaultdict(set)

    def content(rel):
        if rel not in blobs:
            blobs[rel] = (root / rel).read_bytes()
        return blobs[rel]

    for item in entries:
        old, new, action = (item.get(k, "") for k in ("old_path", "new_source", "action"))
        if not all(isinstance(v, str) for v in (old, new, action)):
            errors.append({"type": "non_string_path", "entry": str(item)[:120]})
            continue
        if old in seen:
            errors.append({"type": "repeated_old_path", "path": old})
        seen.add(old)
        action_count[action] += 1
        if (not old.startswith("assets/") and old != "icon.png") or ".." in Path(old).parts:
            errors.append({"type": "invalid_old_path", "path": old})
            continue
        if not new.startswith(UPLOADS) or ".." in Path(new).parts or not new.endswith(".png"):
            errors.append({"type": "invalid_third_party_source", "old": old, "source": new})
            continue
        sources.add(new)
        if not (root / new).is_file():
            errors.append({"type": "uploaded_source_missing", "old": old, "source": new})
            continue
        new_blob = git_blob_sha(content(new))
        if new_blob != item.get("new_sha"):
            errors.append({"type": "source_sha_mismatch", "old": old, "source": new})
        if action == "delete_original_svg_redirect_to_png":
            deleted.add(old)
            if (root / old).exists():
                errors.append({"type": "deleted_svg_still_exists", "path": old})
        elif action == "replace_original_binary_in_place":
            if not (root / old).is_file():
                errors.append({"type": "replacement_missing", "path": old})
                continue
            binary = content(old)
            current_sha = git_blob_sha(binary)
            if current_sha != new_blob:
                errors.append({"type": "replacement_not_third_party_blob", "path": old})
            if current_sha == item.get("old_sha"):
                errors.append({"type": "retired_blob_still_used", "path": old})
            named = DIM.search(old)
            actual = png_size(binary)
            if named and actual and (int(named.group(1)), int(named.group(2))) != actual:
                out["dimensions"].append({
                    "path": old, "nominal": [int(named.group(1)), int(named.group(2))],
                    "actual": list(actual), "source": new})
        else:
            errors.append({"type": "unknown_migration_action", "path": old, "action": action})
        match = re.search(r"assets/art/(?:b02/characters/(?:main|npc)/|characters/)([^/]+)/", old)
        if match:
            character_sources[new].add(match.group(1))

    for source, identities in sorted(character_sources.items()):
        if len(identities) > 1:
            out["duplicate_characters"].append({
                "source": source, "identities": sorted(identities), "count": len(identities)})

    dead_svg_references, dynamic_count = 0, 0
    for file in source_files(root):
        rel = file.relative_to(root).as_posix()
        for lineno, line in enumerate(file.read_text(encoding="utf-8", errors="replace").splitlines(), 1):
            for match in SVG.finditer(line):
                if match.group(0).removeprefix("res://") in deleted:
                    dead_svg_references += 1
                    if len(out["deleted_svg_references"]) < 120:
                        out["deleted_svg_references"].append({"file": rel, "line": lineno, "path": match.group(0)})
            if DYNAMIC.search(line):
                dynamic_count += 1
                if len(out["dynamic_paths"]) < 100:
                    out["dynamic_paths"].append({"file": rel, "line": lineno})
    for key, reason in (
        ("dimensions", "Nominal pixel contracts changed; rebuild target render/atlas geometry"),
        ("duplicate_characters", "Different character IDs share a single identity illustration"),
        ("deleted_svg_references", "Check each deleted SVG reference uses the third-party resolver"),
        ("dynamic_paths", "Statically generated paths require runtime-path coverage"),
    ):
        count = len(out[key]) if key not in ("deleted_svg_references", "dynamic_paths") else (
            dead_svg_references if key == "deleted_svg_references" else dynamic_count)
        if count:
            risks.append({"type": key, "count": count, "reason": reason})
    out["summary"] = {
        "mapping_rows": len(entries), "old_paths": len(seen), "uploaded_sources": len(sources),
        "actions": dict(action_count), "old_svg_path_count": len(deleted),
        "deleted_svg_reference_occurrences": dead_svg_references,
        "dynamic_path_occurrences": dynamic_count,
        "structural_error_count": len(errors), "unresolved_risk_categories": len(risks)}
    return out


def main():
    cli = argparse.ArgumentParser(description=__doc__)
    cli.add_argument("--root", type=Path, default=Path("."))
    cli.add_argument("--out", type=Path)
    cli.add_argument("--strict", action="store_true")
    args = cli.parse_args()
    root = args.root.resolve()
    if not (root / INDEX).is_file() or not (root / "project.godot").is_file():
        cli.error("Run from the Godot project root on the migration branch")
    result = audit(root)
    if args.out:
        args.out.write_text(json.dumps(result, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(json.dumps(result["summary"], ensure_ascii=False, indent=2))
    if result["errors"]:
        print("Structural errors:", json.dumps(result["errors"][:5], ensure_ascii=False))
    if result["risks"]:
        print("Unresolved risks:", json.dumps(result["risks"], ensure_ascii=False))
    return 1 if args.strict and (result["errors"] or result["risks"]) else 0


if __name__ == "__main__":
    raise SystemExit(main())
