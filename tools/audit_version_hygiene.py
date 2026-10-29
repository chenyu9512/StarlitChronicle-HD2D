#!/usr/bin/env python3
"""Whole-repository version/path inventory. Read-only; safe for Main2 CI."""
from __future__ import annotations

import argparse
import collections
import json
import re
import subprocess
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
VERSION = re.compile(r"(?<![A-Za-z0-9])v(?P<number>\d{1,2})(?:[._-]\d+)*(?!\d)", re.I)
DISPOSABLE = re.compile(r"(?:\.translation|\.bak|\.backup|\.orig|\.rej|\.tmp|\.swp|\.swo|\.pyc)$", re.I)
CODE_EXT = {".py", ".gd", ".sh", ".ps1", ".yaml", ".yml", ".toml", ".cfg", ".godot", ".ts", ".js"}
TEXT_EXT = CODE_EXT | {".json", ".md", ".txt", ".csv", ".tscn", ".tres", ".ini", ".gitignore"}
GENERATOR = "tools/generate_art.py"
EXPECTED_BRANCH = "Main2美术优化版"

def tracked_files() -> dict[str, str]:
    result = subprocess.run(
        ["git", "-C", str(ROOT), "ls-files", "--stage", "-z"],
        capture_output=True, check=True,
    ).stdout
    output = {}
    for entry in result.split(b"\0"):
        if not entry:
            continue
        metadata, path = entry.split(b"\t", 1)
        fields = metadata.decode("ascii").split()
        output[path.decode("utf-8")] = fields[1]
    return output

def category(path: str) -> str:
    if path.startswith("docs/history/"):
        return "history"
    if path.startswith("assets/art/runtime/"):
        return "runtime_assets"
    if path.startswith("data/levels/v3/") or path.startswith("data/levels/v4/"):
        return "map_schema"
    if path.startswith(".github/workflows/"):
        return "workflows"
    if path.startswith("scripts/") or path.startswith("tools/") or "/" not in path and path.endswith(".py"):
        return "source"
    if path.startswith("data/assets/"):
        return "asset_contracts"
    if path.startswith("docs/"):
        return "documentation"
    return "other"

def inventory() -> dict:
    tracked = tracked_files()
    roots = collections.Counter()
    version_counts = collections.Counter()
    version_categories = collections.Counter()
    versioned = []
    sha_paths = collections.defaultdict(list)
    disposable = []
    missing = []
    versioned_code = []
    for name, blob_sha in tracked.items():
        roots[name.split("/", 1)[0]] += 1
        sha_paths[blob_sha].append(name)
        if not (ROOT / name).is_file():
            missing.append(name)
        if DISPOSABLE.search(name):
            disposable.append(name)
        matches = {int(m.group("number")) for m in VERSION.finditer(name)}
        if matches:
            versioned.append(name)
            cls = category(name)
            version_categories[cls] += 1
            for number in matches:
                version_counts[f"v{number}"] += 1
            if cls in ("source", "workflows") and Path(name).suffix.lower() in CODE_EXT:
                versioned_code.append(name)

    duplicates = sorted(
        (sorted(paths) for paths in sha_paths.values() if len(paths) > 1),
        key=lambda x: (-len(x), x[0]),
    )
    # Search exact filename/path references in all text-based tracked sources.
    # This is intentionally not a proof of runtime liveness: generated paths can be dynamic.
    identifiers = {name: [name, Path(name).name] for name in versioned_code}
    reference_hits = collections.defaultdict(list)
    sources_scanned = 0
    for name in tracked:
        p = ROOT / name
        if p.suffix.lower() not in TEXT_EXT and p.name not in (".gitignore",):
            continue
        if not p.is_file() or p.stat().st_size > 2_000_000:
            continue
        body = p.read_text(encoding="utf-8", errors="replace")
        sources_scanned += 1
        for candidate, needles in identifiers.items():
            if candidate == name:
                continue
            if any(needle in body for needle in needles):
                reference_hits[candidate].append(name)

    unresolved = [
        name for name in versioned_code if name not in reference_hits
    ]
    return {
        "branch_policy": EXPECTED_BRANCH,
        "total_tracked_files": len(tracked),
        "top_level_counts": dict(sorted(roots.items())),
        "versioned_path_count": len(versioned),
        "counts_by_version": dict(sorted(version_counts.items(), key=lambda x: int(x[0][1:]))),
        "counts_by_role": dict(sorted(version_categories.items())),
        "duplicate_blob_groups": len(duplicates),
        "paths_in_duplicate_groups": sum(map(len, duplicates)),
        "extra_duplicate_path_aliases": sum(len(group)-1 for group in duplicates),
        "duplicate_groups": duplicates,
        "disposable_files": sorted(disposable),
        "versioned_source_or_workflow": sorted(versioned_code),
        "source_reference_hits": dict(sorted(reference_hits.items())),
        "versioned_source_without_literal_reference": sorted(unresolved),
        "text_sources_scanned": sources_scanned,
        "missing_worktree_files": sorted(missing),
        "canonical_generator_exists": GENERATOR in tracked,
        "warnings": [
            "Identical SHA files may be required aliases, not redundant runtime assets.",
            "V3 maps/V4 interiors and save migrations are schema contracts, not obsolete revisions.",
            "A lack of literal references does not prove safety to delete dynamic Godot resources.",
            "Archived reports and Git commit history are intentionally retained.",
        ],
    }

def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--json", action="store_true", help="Emit complete machine-readable inventory")
    parser.add_argument("--output", type=Path, help="Write complete JSON to a file")
    parser.add_argument("--strict", action="store_true", help="Fail on disposable tracked files / missing canonical generator")
    args = parser.parse_args()
    data = inventory()
    payload = json.dumps(data, ensure_ascii=False, indent=2) + "\n"
    if args.output:
        args.output.parent.mkdir(parents=True, exist_ok=True)
        args.output.write_text(payload, encoding="utf-8")
    if args.json:
        print(payload, end="")
    else:
        for name in ("total_tracked_files", "versioned_path_count", "duplicate_blob_groups",
                     "extra_duplicate_path_aliases", "text_sources_scanned"):
            print(f"{name}: {data[name]}")
        print("versions:", data["counts_by_version"])
        print("roles:", data["counts_by_role"])
        print("disposable files:", len(data["disposable_files"]))
        print("versioned executable/workflow paths:", len(data["versioned_source_or_workflow"]))
        print("Use --json or --output to get full paths/references (read-only).")
    fail = bool(data["disposable_files"] or data["missing_worktree_files"]
                or not data["canonical_generator_exists"])
    return 1 if args.strict and fail else 0

if __name__ == "__main__":
    raise SystemExit(main())
