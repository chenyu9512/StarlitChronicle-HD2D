#!/usr/bin/env python3
"""Unified Main2 CI: exactly one Godot import and no duplicate test executions."""
from __future__ import annotations
import argparse
import json
import os
from pathlib import Path
import re
import subprocess
import sys
import time

ROOT = Path(__file__).resolve().parents[2]
STATIC = {
    "base": ["tools/d_control/test_main2_ci_plan.py", "tools/validate_project.py", "tools/validate_global_runtime_contract.py", "tools/validate_first_act.py", "tools/validate_act01_canonical_routes.py", "tools/validate_release_no_cheats.py"],
    "map": ["tools/validate_act01_distinct_layouts.py", "tools/validate_no_fog_local_map.py", "tools/validate_b_world_spatial_integrity.py"],
    "art": ["tools/validate_art_theme_v2.py", "tools/validate_nonrandom_atlas_v2.py", "tools/audit_art_pipeline_v3.py", "tools/validate_c_act01_global_art_v14.py", "tools/validate_c_act01_semantic_v17.py", "tools/validate_c_act01_hd2d_v18.py", "tools/validate_c_act01_matched_props_v16.py", "tools/audit_act01_third_party_art.py"],
    "systems": ["tools/validate_release_gate.py", "tools/validate_story.py"],
}
SMOKES = {
    "base": ["tools/smoke_first_act.gd", "tools/smoke_first_act_flow.gd", "tools/smoke_act01_six_chapters_normal.gd", "tools/smoke_b_act01_physical_reachability.gd", "tools/smoke_save_integrity.gd"],
    "map": ["tools/smoke_map_ui.gd", "tools/smoke_no_fog_local_map.gd", "tools/smoke_all_maps_minimap.gd", "tools/smoke_world_production.gd", "tools/smoke_act01_distinct_world_layouts.gd", "tools/smoke_town_entrances.gd", "tools/smoke_b_home_runtime_geometry.gd", "tools/smoke_b_act01_coastal_landmarks.gd", "tools/smoke_b_line_integrity.gd", "tools/smoke_dungeon_puzzles_v7.gd", "tools/smoke_world_discoveries.gd"],
    "art": ["tools/smoke_c_art_theme_v2.gd", "tools/smoke_c_art_packs.gd", "tools/smoke_c_shared_terrain_v8.gd", "tools/smoke_c_uploaded_later_pack.gd", "tools/smoke_art_theme_browser_v3.gd", "tools/smoke_c_main2_art_runtime.gd", "tools/smoke_c_act01_hd2d_v18.gd", "tools/smoke_c_act01_semantic_v17.gd", "tools/smoke_main2_act01_harbor_rooms_visual.gd", "tools/smoke_c_dew_signatures.gd", "tools/smoke_coastal_exterior.gd", "tools/smoke_coastal_interiors.gd"],
    "systems": ["tools/smoke_rpg_core.gd", "tools/smoke_battle_actors.gd", "tools/d_control/smoke_live_battle_v3_transaction.gd", "tools/smoke_b_act01_journey.gd", "tools/d_control/smoke_m01_transaction_wiring.gd", "tools/d_control/smoke_m01_service_transactions.gd", "tools/d_control/smoke_main2_act01_route_and_room_transactions.gd", "tools/smoke_branch_story_phase19.gd", "tools/d_control/smoke_ch021_direction_gate.gd"],
}
RELEASE_DIRS = ("scripts/", "scenes/", "story/", "data/", "assets/art/runtime/", "assets/art/external/", "assets/audio/", "assets/shaders/", "assets/fx/", "assets/enemies/")
RELEASE_FILES = {"project.godot", "tools/build_runtime_snapshot.py", "tools/verify_runtime_snapshot.py", "tools/validate_c_act01_matched_props_v16.py", "tools/validate_c_act01_global_art_v14.py", "tools/validate_act01_canonical_routes.py", "tools/validate_c_act01_semantic_v17.py", "tools/smoke_b_act01_journey.gd", "tools/smoke_main2_act01_canonical_chapter_routes.gd"}
CI_FILES = {".github/workflows/main2-ci.yml", ".github/workflows/main2-to-runtime.yml", "tools/d_control/run_main2_ci.py"}
PARSE = re.compile(r"(?:SCRIPT ERROR:|Parse Error:|ERROR: Failed to load script)", re.I)

def diff(before, head):
    if not before or before == "0" * 40:
        return None
    try:
        # Deleted assets/scripts are release changes too; never hide them from QA.
        p = subprocess.run(["git", "diff", "--name-only", "--diff-filter=ACMRTD", before, head],
                           cwd=ROOT, capture_output=True, text=True, check=True, timeout=30)
        return [s for s in p.stdout.splitlines() if s]
    except (OSError, subprocess.SubprocessError):
        return None

def last_published_runtime_source():
    """Find the last actually published Main2 tree, not the previous push.

    A code commit's QA can be cancelled by a later test-only commit. Comparing
    only github.event.before would then skip the never-published code change.
    The Runtime bot commit records its verified Main2 source SHA explicitly.
    """
    try:
        subprocess.run(
            ["git", "fetch", "--no-tags", "--depth=1", "origin",
             "refs/heads/StarlitChronicle-Runtime:refs/remotes/origin/StarlitChronicle-Runtime"],
            cwd=ROOT, capture_output=True, text=True, check=True, timeout=45)
        p = subprocess.run(
            ["git", "log", "-1", "--format=%s", "refs/remotes/origin/StarlitChronicle-Runtime"],
            cwd=ROOT, capture_output=True, text=True, check=True, timeout=15)
        match = re.fullmatch(
            r"build\(runtime\): playable Main2 snapshot ([0-9a-f]{40})",
            p.stdout.strip())
        if not match:
            return None
        source = match.group(1)
        # A depth-2 checkout usually cannot diff against an older release.
        # Fetch its tree explicitly; git diff works with shallow endpoints.
        subprocess.run(["git", "fetch", "--no-tags", "--depth=1", "origin", source],
                       cwd=ROOT, capture_output=True, text=True, check=True, timeout=60)
        return source
    except (OSError, subprocess.SubprocessError):
        return None


def make_plan(before, head):
    files = diff(before, head)
    published_source = last_published_runtime_source()
    unpublished = diff(published_source, head) if published_source else None
    groups = {"base"}
    if files is None or any(p in CI_FILES for p in files):
        groups.update(("map", "art", "systems"))
    else:
        for p in files:
            if p.startswith(("data/levels/", "scenes/")) or any(x in p for x in ("map", "world", "town", "coast", "interior")):
                groups.add("map")
            if p.startswith(("data/assets/", "assets/", "scenes/")) or any(x in p for x in ("art", "sprite", "material", "tileset")):
                groups.add("art")
            if p.startswith(("story/", "scripts/", "data/")):
                groups.add("systems")
            if p.startswith("tools/") and p not in RELEASE_FILES and p not in CI_FILES:
                groups.update(("map", "art", "systems"))
        if groups == {"base"} and any(p.startswith(("scripts/", "scenes/", "data/", "assets/")) for p in files):
            groups.update(("map", "art", "systems"))
    # Fail closed if Runtime history is unavailable: require full QA instead
    # of incorrectly treating a test-only tip as proof that code was shipped.
    release = unpublished is None or any(
        p in RELEASE_FILES or p.startswith(RELEASE_DIRS) for p in unpublished)
    # Release approval must cover ALL critical domains, including pre-existing
    # defects outside the latest file diff. Selective checks alone cannot publish.
    if release:
        groups.update(("map", "art", "systems"))
    return {"sha": head, "before": before, "changed_files": files,
            "runtime_source_sha": published_source, "unpublished_game_files": unpublished,
            "groups": [g for g in ("base", "map", "art", "systems") if g in groups],
            "release_needed": release}

def test(name, command, dest, timeout):
    started = time.monotonic()
    try:
        p = subprocess.run(command, cwd=ROOT, capture_output=True, text=True,
                           errors="replace", timeout=timeout)
        output, rc = (p.stdout or "") + "\n" + (p.stderr or ""), p.returncode
        verdict = "PASS" if rc == 0 and not PARSE.search(output) else "FAIL"
    except subprocess.TimeoutExpired:
        verdict, rc, output = "TIMEOUT", 124, "Exceeded timeout "+str(timeout)
    except OSError as e:
        verdict, rc, output = "ERROR", 127, str(e)
    log = dest / (name.replace("/", "__").replace(".", "_") + ".log")
    log.write_text(output, encoding="utf-8")
    row = {"name": name, "status": verdict, "exit_code": rc,
           "seconds": round(time.monotonic()-started, 2), "log": str(log)}
    print(verdict, name, rc, flush=True)
    if verdict != "PASS":
        print(output[-5000:], flush=True)
    return row

def run(cfg, godot, folder):
    folder.mkdir(parents=True, exist_ok=True)
    rows, seen = [], set()
    for group in cfg["groups"]:
        for name in STATIC[group]:
            if name not in seen:
                seen.add(name)
                rows.append(test(name, [sys.executable, name] + (["--strict"] if name == "tools/audit_art_pipeline_v3.py" else []), folder, 180))
    imported = test("godot-import", [godot, "--headless", "--path", ".", "--editor", "--import", "--quit"], folder, 240)
    rows.append(imported)
    if imported["status"] == "PASS":
        for group in cfg["groups"]:
            for name in SMOKES[group]:
                if name not in seen:
                    seen.add(name)
                    rows.append(test(name, [godot, "--headless", "--path", ".", "--script", "res://"+name], folder, 180))
    passed = sum(r["status"] == "PASS" for r in rows)
    result = {"sha": cfg["sha"], "groups": cfg["groups"], "release_needed": cfg["release_needed"],
              "total": len(rows), "passed": passed, "failed": len(rows)-passed, "results": rows}
    (folder / "summary.json").write_text(json.dumps(result, ensure_ascii=False, indent=2)+"\n", encoding="utf-8")
    print("MAIN2_QA_RESULT", passed, "/", len(rows), flush=True)
    return 0 if rows and passed == len(rows) else 1

def main():
    p = argparse.ArgumentParser()
    p.add_argument("--plan", action="store_true")
    p.add_argument("--run", action="store_true")
    p.add_argument("--before", default="")
    p.add_argument("--sha", default=os.environ.get("GITHUB_SHA", ""))
    p.add_argument("--config", default="main2-ci-plan.json")
    p.add_argument("--godot", default=".ci-cache/godot/4.7.2/Godot_v4.7.2-stable_linux.x86_64")
    p.add_argument("--results", default="main2-ci-results")
    a = p.parse_args()
    if a.plan == a.run:
        p.error("Select exactly one of --plan or --run")
    if a.plan:
        cfg = make_plan(a.before, a.sha)
        Path(a.config).write_text(json.dumps(cfg, ensure_ascii=False, indent=2)+"\n", encoding="utf-8")
        print(json.dumps(cfg, ensure_ascii=False))
        if os.environ.get("GITHUB_OUTPUT"):
            with open(os.environ["GITHUB_OUTPUT"], "a", encoding="utf-8") as f:
                f.write("release_needed="+str(cfg["release_needed"]).lower()+"\n")
        return 0
    cfg = json.loads(Path(a.config).read_text(encoding="utf-8"))
    if cfg["sha"] != a.sha:
        raise SystemExit("QA plan source SHA mismatch")
    return run(cfg, a.godot, Path(a.results))

if __name__ == "__main__":
    sys.exit(main())
