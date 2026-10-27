#!/usr/bin/env python3
"""Independent Batch0 acceptance for the seven D/A/B/C QA gates.
Run on the exact checkout SHA; never reads the user's actual save or alters main.
All tests are allowed to finish, with per-command logs and machine-readable verdicts.
"""
from __future__ import annotations

import argparse
import json
import os
from pathlib import Path
import re
import subprocess
import sys
import time

GROUPS = {
    "build": {
        "title": "最新main全库编译与启动检查",
        "python": ["tools/validate_no_fog_local_map.py", "tools/validate_project.py",
                   "tools/validate_first_act.py"],
        "godot": ["--editor --quit", "--quit-after 45"],
        "smoke": ["tools/check_combat_load.gd", "tools/smoke_first_act.gd",
                  "tools/smoke_title_foyer.gd"],
    },
    "reward": {
        "title": "奖励事务与重复回调集成",
        "smoke": [
            "tools/d_control/smoke_v3_reward_ledger.gd",
            "tools/d_control/smoke_live_battle_v3_transaction.gd",
            "tools/d_control/smoke_batch02_quest_and_b_outbox.gd",
            "tools/d_control/smoke_world_object_transactions.gd",
            "tools/d_control/smoke_m01_transaction_wiring.gd",
        ],
    },
    "rollback": {
        "title": "保存失败回滚与异常退出恢复",
        "smoke": [
            "tools/smoke_save_integrity.gd",
            "tools/d_control/smoke_atomic_story_save.gd",
            "tools/smoke_first_three_checkpoints.gd",
            "tools/smoke_world_checkpoints.gd",
            "tools/d_control/smoke_batch02_quest_and_b_outbox.gd",
        ],
    },
    "legacy": {
        "title": "旧档兼容与损坏存档安全回退",
        "smoke": [
            "tools/d_control/smoke_batch03_legacy_and_checkpoint_recovery.gd",
            "tools/smoke_legacy_ending.gd",
            "tools/smoke_b_story_transactions.gd",
            "tools/smoke_save_integrity.gd",
        ],
    },
    "combat": {
        "title": "战斗奖励与事务专项回归",
        "smoke": [
            "tools/smoke_a_line_reward_transactions.gd",
            "tools/d_control/smoke_live_battle_v3_transaction.gd",
            "tools/smoke_a_line_world_handoff.gd",
            "tools/smoke_battle_v3.gd",
            "tools/smoke_live_boss_matrix.gd",
            "tools/smoke_a_line_live_bosses.gd",
            "tools/smoke_first_three_playable.gd",
        ],
    },
    "quests": {
        "title": "任务状态与奖励不重复验证",
        "smoke": [
            "tools/smoke_b_story_transactions.gd",
            "tools/d_control/smoke_batch02_quest_and_b_outbox.gd",
            "tools/smoke_story_side_quests.gd",
            "tools/smoke_branch_story_phase19.gd",
            "tools/smoke_story_world_phase19_2.gd",
            "tools/smoke_b_coast_three_chapter_routes.gd",
        ],
    },
    "assets": {
        "title": "资源工程与运行素材校验",
        "python": ["tools/validate_c_art_catalog.py", "tools/validate_c_art_curation.py",
                   "tools/validate_c_art_management.py", "tools/validate_c_art_pipeline_v5.py",
                   "tools/qa_hd2d_refinement.py"],
        "smoke": [
            "tools/smoke_art_assets.gd",
            "tools/smoke_c_art_overrides.gd",
            "tools/smoke_c_art_packs.gd",
            "tools/smoke_c_coastal_render.gd",
            "tools/smoke_c_coast_monster_matrix.gd",
            "tools/smoke_c_visual_prompts.gd",
        ],
    },
}
HARD_ERRORS = re.compile(r"(?im)^\s*(?:SCRIPT ERROR:|Parse Error:|ERROR: Failed to load script|ERROR: Condition.*failed)")
BAD_SOURCE = re.compile(r"(?im)^\s*(?:Traceback \(most recent call last\)|AssertionError:|ImportError:)")

def execute(label: str, command: list[str], timeout: int, folder: Path) -> dict:
    key = re.sub(r"[^A-Za-z0-9_.-]", "_", label)
    start = time.monotonic()
    output = ""
    code = 127
    status = "FAIL"
    try:
        completed = subprocess.run(command, capture_output=True, text=True,
                                   errors="replace", timeout=timeout)
        output = (completed.stdout or "") + "\n" + (completed.stderr or "")
        code = completed.returncode
        status = "PASS" if code == 0 and not HARD_ERRORS.search(output) and not BAD_SOURCE.search(output) else "FAIL"
    except subprocess.TimeoutExpired as exc:
        code = 124
        status = "TIMEOUT"
        output = str(exc)
    except OSError as exc:
        output = str(exc)
    filename = folder / f"{key}.log"
    filename.write_text(output, encoding="utf-8")
    result = {"case": label, "status": status, "exit_code": code,
              "seconds": round(time.monotonic()-start, 2), "log": str(filename),
              "command": command}
    print(f"{status}: {label} (rc={code}, {result['seconds']}s)", flush=True)
    if status != "PASS":
        print(output[-7000:], flush=True)
    return result

def main() -> int:
    p = argparse.ArgumentParser()
    p.add_argument("--gate", choices=sorted(GROUPS), required=True)
    p.add_argument("--godot", default="./Godot_v4.7.2-stable_linux.x86_64")
    p.add_argument("--output", default="qa-seven-results")
    p.add_argument("--timeout", type=int, default=210)
    a = p.parse_args()
    gate = GROUPS[a.gate]
    folder = Path(a.output) / a.gate
    folder.mkdir(parents=True, exist_ok=True)
    rows = []
    for script in gate.get("python", []):
        rows.append(execute("python-"+Path(script).stem, [sys.executable,script],
                            a.timeout,folder))
    for cli in gate.get("godot", []):
        rows.append(execute("startup-"+cli.replace(" ","-"),
                            [a.godot,"--headless","--path",".",*cli.split()],
                            a.timeout,folder))
    for script in gate.get("smoke", []):
        rows.append(execute(Path(script).stem,
                            [a.godot,"--headless","--path",".","--script",
                             "res://"+script],
                            a.timeout,folder))
    passed = sum(x["status"] == "PASS" for x in rows)
    verdict = {"gate":a.gate, "title":gate["title"],"tested_sha":os.environ.get("GITHUB_SHA","unavailable"),
               "total":len(rows),"passed":passed,"failed":len(rows)-passed,
               "status":"PASS" if rows and passed==len(rows) else "FAIL","results":rows}
    target = Path(a.output)/f"{a.gate}.json"
    target.write_text(json.dumps(verdict, ensure_ascii=False, indent=2)+"\n",encoding="utf-8")
    print(f"SEVEN_GATE_RESULT {a.gate} {verdict['status']} {passed}/{len(rows)}",flush=True)
    return 0 if verdict["status"]=="PASS" else 1

if __name__ == "__main__":
    sys.exit(main())
