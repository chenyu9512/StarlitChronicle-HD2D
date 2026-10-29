#!/usr/bin/env python3
"""Read-only audit. Identical tracked files are NOT automatically unused."""
from __future__ import annotations
import argparse
import hashlib
import json
import subprocess
from collections import defaultdict
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
REMOVED = ["GITHUB_FIRST_PUSH.md", "PUBLISH_TO_GITHUB.ps1",
           "assets/art/_spec/preview_batch_0_3.png", "tools/art_style_v5.py"]
REQUIRED = ["scripts/game_state.gd", "scripts/first_act_state.gd",
            "scenes/first_act.tscn", "tools/smoke_legacy_ending.gd",
            "tools/generate_art.py", "tools/global_art_factory_v3.py",
            "tools/art_style_v6.py", "tools/art_style_v7.py",
            "tools/art_style_v8.py", "tools/install_global_factory_v3.py"]

def audit() -> dict:
    ls = subprocess.run(["git", "-C", str(ROOT), "ls-files", "-z"],
                        capture_output=True, check=True).stdout
    names = sorted(x.decode("utf-8") for x in ls.split(b"\0") if x)
    tracked = set(names)
    groups = defaultdict(list)
    absent = []
    folders = defaultdict(int)
    for name in names:
        path = ROOT / name
        if not path.is_file():
            absent.append(name)
            continue
        groups[hashlib.sha256(path.read_bytes()).hexdigest()].append(name)
        folders[name.split("/")[0]] += 1
    duplicates = sorted(
        (sorted(paths) for paths in groups.values() if len(paths) > 1),
        key=lambda x: (-len(x), x[0]))
    cfg = (ROOT / "project.godot").read_text(encoding="utf-8")
    violations = []
    if tracked.intersection(REMOVED):
        violations.append("obsolete first-push guide/script or preview still tracked")
    if set(REQUIRED).difference(tracked):
        violations.append("protected current/legacy save or regression file missing")
    tracked_backup = [n for n in names if n.endswith(
        (".bak", ".backup", ".orig", ".rej", ".tmp", ".swp", ".swo", ".pyc"))]
    if tracked_backup:
        violations.append("disposable backup/cache files still tracked: " +
                          ", ".join(tracked_backup[:12]))
    launcher = ROOT / "tools/generate_art.py"
    if launcher.exists() and "--legacy" in launcher.read_text("utf-8"):
        violations.append("retired fixed-size art demo still embedded in official generator")
    if 'run/main_scene="res://scenes/first_act.tscn"' not in cfg:
        violations.append("production entry changed")
    if 'State="*res://scripts/game_state.gd"' not in cfg:
        violations.append("V1 autoload changed; require migration review")
    return {
        "tracked_files": len(names), "sections": dict(folders),
        "smoke_test_validation_files": sum(
            n.startswith("tools/") and
            any(tag in n for tag in ("smoke_", "test_", "validate_"))
            for n in names),
        "duplicate_byte_groups": len(duplicates),
        "paths_in_duplicate_groups": sum(len(g) for g in duplicates),
        "duplicate_extra_copies": sum(len(g) - 1 for g in duplicates),
        "duplicate_groups_for_manual_review_only": duplicates,
        "tracked_backup_files": tracked_backup,
        "missing_worktree_files": absent, "violations": violations,
        "warning": "Godot dynamic resource paths and save-compatibility prohibit automatic removal.",
    }

if __name__ == "__main__":
    p = argparse.ArgumentParser()
    p.add_argument("--json", action="store_true")
    a = p.parse_args()
    r = audit()
    if a.json:
        print(json.dumps(r, ensure_ascii=False, indent=2))
    else:
        for k in ("tracked_files", "smoke_test_validation_files",
                  "duplicate_byte_groups", "duplicate_extra_copies"):
            print(f"{k}: {r[k]}")
        print("Read-only; use --json to review paths. No file is deleted.")
        for x in r["violations"]:
            print("ERROR:", x)
    raise SystemExit(1 if r["violations"] or r["missing_worktree_files"] else 0)
