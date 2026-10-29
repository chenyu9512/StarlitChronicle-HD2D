#!/usr/bin/env python3
"""Run every Godot smoke_*.gd without early abort, shardable for GitHub Actions.
Only process-local user:// save sandboxes are used by each smoke.
This runner never modifies repository source or authentic user saves.
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

def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--godot", default=os.environ.get("GODOT_BIN","./Godot_v4.7.2-stable_linux.x86_64"))
    parser.add_argument("--shard",type=int,required=True)
    parser.add_argument("--shards",type=int,default=4)
    parser.add_argument("--timeout",type=int,default=180)
    parser.add_argument("--output",default="qa-full-results")
    args = parser.parse_args()
    if args.shard < 0 or args.shards < 1 or args.shard >= args.shards:
        parser.error("invalid shard range")
    tests=sorted(Path("tools").rglob("smoke_*.gd"))
    tests=[t for i,t in enumerate(tests) if i%args.shards==args.shard]
    dest=Path(args.output)
    logs=dest/"logs"
    logs.mkdir(parents=True,exist_ok=True)
    outcomes=[]
    print(f"Full-suite shard {args.shard}/{args.shards}; {len(tests)} smoke scripts",flush=True)
    for i,path in enumerate(tests,1):
        start=time.monotonic()
        cmd=[args.godot,"--headless","--path",".","--script","res://"+path.as_posix()]
        print(f"[{i}/{len(tests)}] RUN {path}",flush=True)
        # These two real 40-sector/120-quest integration scenarios take much
        # longer than unit smokes; keep all assertions and allow completion.
        long_world = path.name in {"smoke_story_world_phase19_2.gd",
                                   "smoke_world_story_interactions.gd"}
        case_timeout = max(args.timeout, 600) if long_world else args.timeout
        try:
            done=subprocess.run(cmd,capture_output=True,text=True,errors="replace",timeout=case_timeout)
            out=(done.stdout or "") + ("\n"+done.stderr if done.stderr else "")
            duration=round(time.monotonic()-start,2)
            bad_parse=bool(re.search(r"SCRIPT ERROR:|Parse Error:|Failed to load script",out,re.I))
            status="PASS" if done.returncode==0 and not bad_parse else "FAIL"
            rc=done.returncode
        except subprocess.TimeoutExpired as e:
            duration=round(time.monotonic()-start,2)
            out=((e.stdout or b"").decode(errors="replace") if isinstance(e.stdout,bytes) else (e.stdout or "")) + "\n[TIMEOUT]"
            status="TIMEOUT"
            rc=124
        except OSError as e:
            duration=round(time.monotonic()-start,2)
            out=str(e)
            status="ERROR"
            rc=127
        logfile=logs/(path.as_posix().replace("/","__").replace(".gd",".log"))
        logfile.write_text(out,encoding="utf-8")
        record={"path":path.as_posix(),"status":status,"exit_code":rc,
            "duration_seconds":duration,"log":str(logfile)}
        outcomes.append(record)
        print(f"{status} {path}: rc={rc} in {duration}s",flush=True)
        if status!="PASS":
            print("---- excerpt ----\n"+out[-14000:]+"\n---- end excerpt ----",flush=True)
    passed=sum(x["status"]=="PASS" for x in outcomes)
    summary={"shard":args.shard,"shards":args.shards,"total":len(outcomes),
        "passed":passed,"failed":len(outcomes)-passed,"results":outcomes}
    (dest/f"shard-{args.shard}.json").write_text(json.dumps(summary,ensure_ascii=False,indent=2)+"\n",encoding="utf-8")
    print(f"QA_RESULT shard={args.shard}: {passed}/{len(outcomes)} passed; {len(outcomes)-passed} failed",flush=True)
    return 0 if len(outcomes)==passed and len(outcomes)>0 else 1

if __name__=="__main__":
    sys.exit(main())
