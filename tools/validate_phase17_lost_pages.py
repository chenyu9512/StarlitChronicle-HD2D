#!/usr/bin/env python3
"""Phase17 batch01 authored lost-page A/B routes, narrative only.
Checks original save/reward compatibility; does NOT verify runtime registration.
"""
from pathlib import Path
import json

R=Path(__file__).resolve().parents[1]/"story"
def read(p):
    return json.loads((R/p).read_text(encoding="utf-8"))
problems=[]
def check(value,description):
    if not value:problems.append(description)
src=read("data/side_quests.json")
regional=read("data/regional_quests_v2.json")
companion=read("data/companion_quests.json")
manifest=read("data/phase17_lost_pages_manifest.json")
paths=manifest["branch_files"]
packs=[read(p.removeprefix("story/")) for p in paths]
originals={q["id"]:q for q in src["quests"]}
all_quests=src["quests"]+regional["quests"]+companion["quests"]
check(len(src["quests"])==36 and len(regional["quests"])==36 and len(companion["quests"])==48,
      "quest baseline is 36 original +36 regional +48 companion =120")
check(len(all_quests)==120 and len({q["id"] for q in all_quests})==120,
      "120 unique quest IDs")
check(len(manifest["entries"])==12,"twelve manifest entries")
check(len(packs)==3 and all(len(pack["quests"])==4 for pack in packs),"3x4 branch packs")
check(manifest["status"]=="72_authored_postquest_events_not_runtime_registered",
      "branch events must not claim gameplay-ready")
check(manifest["counts"]==dict(quests=12,branches=24,optional_stages=72,new_dialogues=216),
      "manifest authored totals")
check(all(pack["status"]=="authored_branch_arcs_not_runtime_bound" for pack in packs),
      "branch packs must stay unbound")
page_src={q["id"]:q for q in src["quests"] if q["type"]=="lost_page"}
check(len(page_src)==12,"lost page quest count")
check({q["id"] for q in page_src.values()}=={f"sq_page_{i:02}" for i in range(1,13)},
      "page IDs contiguous")
qmanifest={q["id"]:q for q in manifest["entries"]}
check(len(qmanifest)==12,"unique manifest quest ids")
authored={q["id"]:q for pack in packs for q in pack["quests"]}
check(set(qmanifest)==set(authored)==set(page_src),"branch, original and manifest coverage")

seen=set()
total_stages=total_lines=0
for qid in sorted(page_src):
    old=page_src[qid]
    entry=qmanifest[qid]
    arc=authored[qid]
    number=int(qid[-2:])
    page=f"world.page_{number:02}"
    done=f"side.{qid}.done"
    approach=f"side.{qid}.approach"
    choice_stage=next((s for s in old["stages"] if s.get("choice")),None)
    check(choice_stage is not None,"no original choice "+qid)
    if choice_stage is None:continue
    choice=choice_stage["choice"]
    options={o["id"]:o for o in choice["options"]}
    check(set(options)=={"a","b"},"original A/B change "+qid)
    check(all(o["sets"]=={approach:bid} for bid,o in options.items()),"choice semantics "+qid)
    check(len(old["stages"])==5,"original five stages "+qid)
    check(old["completion_flag"]==done,"completion flag "+qid)
    check(old["rewards"].get("lost_page")==f"page_{number:02}","page reward "+qid)
    finish=old["stages"][-1]
    effects=finish["effects"]
    check(finish["id"]==f"{qid}.finish","original finish id "+qid)
    check(sum(e.get("type")=="set_flag" and e.get("key")==page and e.get("value") is True
              for e in effects)==1,"page grant once in original finish "+qid)
    check(any(e.get("type")=="set_flag" and e.get("key")==done and e.get("value") is True
              for e in effects),"original finish completion flag "+qid)
    check(entry["existing_completion_flag"]==done and entry["existing_finish_flag"]==page,
          "manifest reward contract "+qid)
    check(entry["existing_five_stages"]==[s["id"] for s in old["stages"]],
          "original stage list changed "+qid)
    late=arc["late_chapter"]
    check(late==entry["late_revisit_chapter"],"revisit mismatch "+qid)
    check(1<=int(late[-3:])<=72 and int(late[-3:])>=int(old["required_chapter"][-3:]),
          "revisit chapter timing "+qid)
    for bid in ("a","b"):
        stages=arc["arms"][bid]
        contract=entry["branches"][bid]
        check(len(stages)==len(contract["stages"])==3,"three branch stages "+qid+bid)
        check(contract["requires_original_choice"]=={approach:bid},"choice flag "+qid+bid)
        check(contract["choice_option_id"]==bid,"choice option ID "+qid+bid)
        check(contract["original_choice_label"]==options[bid]["label"],"choice label "+qid+bid)
        for k,(stage,cond) in enumerate(zip(stages,contract["stages"])):
            kind=["followup","community","revisit"][k]
            stage_id=f"{qid}.p17.{bid}.{kind}"
            check(stage["kind"]==kind and cond["id"]==stage_id,
                  "branch stage ID "+stage_id)
            check(len(stage["dialogue"])==3 and len(cond["player_actions"])==2,
                  "stage dialogue/actions "+stage_id)
            check(cond["required_runtime_flags"].get(done) is True and
                  cond["required_runtime_flags"].get(approach)==bid,
                  "original gate missing "+stage_id)
            check((f"story.{late}.done" in cond["required_runtime_flags"])==(kind=="revisit"),
                  "late chapter gate "+stage_id)
            check(cond["optional_for_original_rewards"] is True and
                  cond["missable"] is False and cond["repeatable"] is False,
                  "branch optional/replay contract "+stage_id)
            check(cond["existing_dialogue_ids"]==[d["id"] for d in stage["dialogue"]],
                  "dialogue reference mismatch "+stage_id)
            previous=None if k==0 else f"{qid}.p17.{bid}.{['followup','community'][k-1]}"
            check(cond["must_follow"]==previous,"stage ordering "+stage_id)
            total_stages+=1
            for d in stage["dialogue"]:
                total_lines+=1
                check(d["id"] not in seen,"duplicate branch dialogue "+d["id"])
                seen.add(d["id"])
                check(d["id"].startswith(stage_id+".") and d["speaker"] and d["text"],
                      "invalid branch line "+d["id"])
        check(contract["long_term_npc"]["text"]==stages[-1]["dialogue"][0]["text"],
              "npc revisit contract "+qid+bid)
    check(arc["arms"]["a"][-1]["dialogue"]!=arc["arms"]["b"][-1]["dialogue"],
          "A/B revisit scenes must actually differ "+qid)
check(total_stages==72 and total_lines==216 and len(seen)==216,
      "72 stages and 216 distinct new lines")
milestone=src["global_milestone"]
check(milestone["flag"]=="world.all_twelve_pages" and
      set(milestone["requires_flags"])=={f"world.page_{i:02}" for i in range(1,13)},
      "ending C lost pages milestone unchanged")
endings=read("data/endings.json")
endingC=next(e for e in endings["endings"] if e["id"]=="C")
check({"story.ch072.done","ch071.battle_won","world.all_twelve_pages",
       "world.distributed_network","world.seven_lanterns"}<=set(endingC["requirements"]),
      "ending C requirements affected")
print(f"Phase17 originals=36 regional=36 companions=48 total=120 "
      f"page_quests={len(page_src)} branches=24 extra_stages={total_stages} "
      f"new_lines={total_lines} issues={len(problems)}")
if problems:
    print("FAIL:",*problems,sep="\n - ")
    raise SystemExit(1)
print("PASS: authored branch conditions and legacy collectible contract. NOT runtime/playtest.")
