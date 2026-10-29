#!/usr/bin/env python3
"""Local fallback for Phase 19 acceptance when GitHub Actions jobs cannot start.

Example (Windows):
  py -3 tools/run_phase19_acceptance.py --godot "C:\\Godot\\Godot_v4.7.2-stable_win64_console.exe"

Writes only ignored /logs/phase19_acceptance/ reports and full stdout/stderr.
Does not create branches, delete saves, or alter gameplay sources.
"""
from __future__ import annotations
import argparse
import json
import os
import shutil
import subprocess
import sys
from datetime import datetime, timezone
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
STATIC = (
    "tools/validate_phase19_world_anchors.py",
    "tools/validate_phase19_scene_dressing.py",
    "tools/validate_phase19_lost_page_rooms.py",
    "tools/validate_phase19_lost_page_puzzles.py",
    "tools/validate_phase19_life_rooms.py",
    "tools/validate_phase19_companion_regional_rooms.py",
)
GODOT = (
    "tools/smoke_story_side_quests.gd",
    "tools/smoke_branch_story_phase19.gd",
    "tools/smoke_story_world_phase19_2.gd",
    "tools/smoke_phase19_lost_page_rooms.gd",
    "tools/smoke_phase19_lost_page_puzzles.gd",
    "tools/smoke_phase19_life_rooms.gd",
    "tools/smoke_phase19_companion_regional_rooms.gd",
    "tools/smoke_campaign_72.gd",
)

def main() -> int:
    parser = argparse.ArgumentParser(description="Phase19 120-quest static and Godot regression")
    parser.add_argument("--godot", default=os.environ.get("GODOT", ""),
                        help="Path to official Godot 4.7.2 console executable or command in PATH")
    parser.add_argument("--skip-godot", action="store_true",
                        help="Run static checks only; do not mark as playable-engine acceptance")
    parser.add_argument("--out", default=str(ROOT / "logs" / "phase19_acceptance"))
    args = parser.parse_args()
    out = Path(args.out).resolve()
    out.mkdir(parents=True, exist_ok=True)
    executable = args.godot or shutil.which("godot") or shutil.which("godot4")
    report: dict = {
        "created_utc": datetime.now(timezone.utc).isoformat(),
        "root": str(ROOT), "engine": executable,
        "engine_tests_executed": False, "checks": [],
        "final_status": "incomplete",
    }
    def run_one(name: str, argv: list[str], timeout: int) -> bool:
        print("RUN", name, flush=True)
        entry = {"name": name, "argv": argv, "status": "failed", "exit_code": None}
        safe_name = name.replace("/", "_").replace(".", "_")
        try:
            done = subprocess.run(argv, cwd=ROOT, text=True, encoding="utf-8",
                                  errors="replace", stdout=subprocess.PIPE,
                                  stderr=subprocess.STDOUT, timeout=timeout,
                                  check=False)
            entry["exit_code"] = done.returncode
            entry["status"] = "pass" if done.returncode == 0 else "failed"
            (out / (safe_name + ".log")).write_text(done.stdout, encoding="utf-8")
            if done.returncode != 0:
                print("FAIL", name, "exit", done.returncode)
                print("\n".join(done.stdout.splitlines()[-14:]))
            else:
                print("PASS", name)
        except (OSError, subprocess.TimeoutExpired) as error:
            entry["error"] = str(error)
            (out / (safe_name + ".log")).write_text(str(error), encoding="utf-8")
            print("FAIL", name, str(error))
        report["checks"].append(entry)
        (out / "summary.json").write_text(
            json.dumps(report, ensure_ascii=False, indent=2) + "\n", encoding="utf-8"
        )
        return entry["status"] == "pass"

    for path in STATIC:
        if not run_one(path, [sys.executable, str(ROOT / path)], 50):
            report["final_status"] = "static_failed"
            break
    else:
        if args.skip_godot:
            report["final_status"] = "static_only_engine_unverified"
        elif not executable:
            print("Godot not found. Pass --godot path/to/Godot_v4.7.2 console executable.")
            report["final_status"] = "missing_godot"
        elif run_one("godot_import", [executable, "--headless", "--path",
                                     str(ROOT), "--editor", "--quit"], 200):
            report["engine_tests_executed"] = True
            report["final_status"] = "pass"
            for path in GODOT:
                if not run_one(path, [executable, "--headless", "--path", str(ROOT),
                                      "--script", "res://" + path], 240):
                    report["final_status"] = "godot_failed"
                    break
        else:
            report["final_status"] = "godot_import_failed"
    (out / "summary.json").write_text(
        json.dumps(report, ensure_ascii=False, indent=2) + "\n", encoding="utf-8"
    )
    print("RESULT", report["final_status"], "REPORT", out / "summary.json")
    return 0 if report["final_status"] in ("pass", "static_only_engine_unverified") else 1

if __name__ == "__main__":
    raise SystemExit(main())
