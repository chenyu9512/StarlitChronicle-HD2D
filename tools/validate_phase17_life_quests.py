#!/usr/bin/env python3
"""Validate the 24 authored life quest A/B branches, NOT runtime playability."""
from pathlib import Path
import json

ROOT=Path(__file__).resolve().parents[1]/"story"
def load(path):
    return json.loads((ROOT/path).read_text(encoding="utf-8"))
def check(value,message):
    if not value:problems.append(message)

problems=[]
source=load("data/side_quests.json")
regional=load("data/regional_quests_v2.json")
companion=load("data/companion_quests.json")
manifest=load("data/phase17_life_manifest.json")
packs=[load(path.removeprefix("story/")) for path in manifest["source_files"]]
quests={q["id"]:q for q in source["quests"]}
original_life={k:v for k,v in quests.items() if k.startswith("sq_life_")}
authored={q["id"]:q for p in packs for q in p["quests"]}
contracts={q["id"]:q for q in manifest["entries"]}
all_q=source["quests"]+regional["quests"]+companion["quests"]
check(len(source["quests"])==36 and len(regional["quests"])==36 and
      len(companion["quests"])==48,"original 36+36+48 task groups")
check(len(all_q)==120 and len({q["id"] for q in all_q})==120,"120 unique quest IDs")
check(len(original_life)==24,"24 life quests")
check(set(original_life)=={f"sq_life_{i:02}" for i in range(1,25)},"contiguous life quest names")
check(len(packs)==8 and all(p["status"]=="authored_branch_arcs_not_runtime_bound"
                           and len(p["quests"])==3 for p in packs),"8 authored packs of three")
check(set(authored)==set(original_life)==set(contracts),"authored and manifest coverage")
check(manifest["status"]=="authored_only_144_optional_stages_not_runtime_registered",
      "must remain authored-only")
check(manifest["counts"]==dict(quests=24,branches=48,optional_scenes=144,new_dialogues=432),
      "manifest totals")
check(len(manifest["source_files"])==8,"all branch files registered")
check(manifest["authoritative_original"]=="story/data/side_quests.json","original source")

original_ids=set()
for q in all_q:
    for s in q["stages"]:
        for d in s.get("dialogue",[]):
            check(d["id"] not in original_ids,"duplicate original dialogue "+d["id"])
            original_ids.add(d["id"])
        for option in s.get("choice",{}).get("options",[]):
            for d in option.get("branch_dialogue",[]):
                check(d["id"] not in original_ids,"duplicate original choice dialogue "+d["id"])
                original_ids.add(d["id"])
new_ids=set()
n_stages=n_lines=n_actions=0
for qid in sorted(original_life):
    origin=original_life[qid]
    arc=authored[qid]
    item=contracts[qid]
    done=origin["completion_flag"]
    approach=f"side.{qid}.approach"
    stages=origin["stages"]
    check(len(stages)==5 and stages[-1]["id"]==f"{qid}.finish","original five stages "+qid)
    check(done==f"side.{qid}.done","original completion flag "+qid)
    check(len(origin["rewards"])==2 and
          set(origin["rewards"])=={"xp","gold"},"original reward XP and gold "+qid)
    check(any(e.get("key")==done and e.get("value") is True for e in stages[-1]["effects"]),
          "original done effect "+qid)
    choice=next((s.get("choice") for s in stages if s.get("choice")),None)
    check(choice is not None,"original choice missing "+qid)
    if choice is None:continue
    options={o["id"]:o for o in choice["options"]}
    check(set(options)=={"a","b"},"original A/B selection "+qid)
    check(all(o["sets"]=={approach:b} for b,o in options.items()),"original choice semantics "+qid)
    check(item["original_completion_flag"]==done,"manifest completion "+qid)
    check(item["original_rewards"]==origin["rewards"],"manifest reward drift "+qid)
    check(item["original_five_stages"]==[s["id"] for s in stages],"manifest five stages "+qid)
    check(item["original_npc_after"]==origin["npc_after"],"original post quest NPC changed "+qid)
    check(item["title"]==origin["title"] and item["region"]==origin["region"],
          "title/region reference drift "+qid)
    check(item["late_revisit_chapter"]==arc["late_chapter"],"revisit chapter drift "+qid)
    start=int(origin["required_chapter"][-3:])
    late=int(arc["late_chapter"][-3:])
    check(start<late<=72,"revisit should be later than original unlock "+qid)
    for b in ("a","b"):
        orig=options[b]
        contract=item["branches"][b]
        check(contract["original_choice_flags"]==orig["sets"] and
              contract["original_choice_label"]==orig["label"],"option reference "+qid+b)
        scripted=arc["arms"][b]
        planned=contract["stages"]
        check(len(scripted)==len(planned)==3,"3 independent A/B stages "+qid+b)
        for i,(scene,planned_scene) in enumerate(zip(scripted,planned)):
            kind=("followup","community","revisit")[i]
            identifier=f"{qid}.p17.{b}.{kind}"
            check(scene["kind"]==kind and planned_scene["id"]==identifier,
                  "branch scene identity "+identifier)
            expected_gate={done:True,approach:b}
            if kind=="revisit":
                expected_gate[f"story.{arc['late_chapter']}.done"]=True
            check(planned_scene["required_flags"]==expected_gate,
                  "gate contract mismatch "+identifier)
            previous=None if i==0 else f"{qid}.p17.{b}.{('followup','community')[i-1]}"
            check(planned_scene["previous_optional_stage"]==previous,
                  "branch scene ordering "+identifier)
            check(planned_scene["proposed_seen_flag"]==f"side.{qid}.p17.{b}.{kind}.seen",
                  "optional flag naming "+identifier)
            check(planned_scene["after_original_stage"]==f"{qid}.finish",
                  "original completion anchor "+identifier)
            check(planned_scene["once_only"] is True and
                  planned_scene["can_delay"] is True and
                  planned_scene["required_for_original_quest"] is False and
                  planned_scene["repeat_original_reward"] is False and
                  planned_scene["runtime_registered"] is False,
                  "legacy save/reward/runtime status "+identifier)
            check(len(scene["dialogue"])==3 and
                  planned_scene["source_dialogue_ids"]==[l["id"] for l in scene["dialogue"]],
                  "3 dialogue lines and references "+identifier)
            check(bool(planned_scene["player_action"]),"missing player action "+identifier)
            n_stages+=1
            n_actions+=1
            for line in scene["dialogue"]:
                check(line["id"].startswith(identifier+".l") and
                      line["id"] not in new_ids and line["id"] not in original_ids,
                      "duplicate or invalid new line "+line["id"])
                check(bool(line.get("speaker") and line.get("text")),
                      "empty dialogue "+line["id"])
                new_ids.add(line["id"])
                n_lines+=1
        check(contract["long_term_revisit"]==
              {"speaker":scripted[2]["dialogue"][0]["speaker"],
               "text":scripted[2]["dialogue"][0]["text"]},
              "revisit NPC long-term response "+qid+b)
    check(arc["arms"]["a"][2]["dialogue"]!=arc["arms"]["b"][2]["dialogue"],
          "A/B scenes must have distinct consequence text "+qid)
check(n_stages==144 and n_lines==432 and n_actions==144 and len(new_ids)==432,
      "authored 144 events, 432 unique dialogues")
reading=(ROOT/"screenplay/phase17_life_all_branches.md").read_text(encoding="utf-8")
for q in authored.values():
    for b in ("a","b"):
        for scene in q["arms"][b]:
            check(scene["title"] in reading,"reading missing title "+q["id"])
            for line in scene["dialogue"]:
                check(line["text"] in reading,"reading missing line "+line["id"])
check(manifest["gate_contract"]["old_saves"]=="never guess missing choice or regrant xp/gold",
      "legacy save option preservation")
page_manifest=load("data/phase17_lost_pages_manifest.json")
check(page_manifest["counts"]["quests"]==12,"prior 12 page quests retained")
source_pages=source["global_milestone"]
check(source_pages["flag"]=="world.all_twelve_pages" and
      set(source_pages["requires_flags"])=={f"world.page_{i:02}" for i in range(1,13)},
      "lost-page ending C milestone")
endings=load("data/endings.json")
ending_c=next(x for x in endings["endings"] if x["id"]=="C")
check({"story.ch072.done","ch071.battle_won","world.all_twelve_pages",
       "world.distributed_network","world.seven_lanterns"}<=set(ending_c["requirements"]),
      "ending C unchanged")

print(f"Phase17Life quests=24 routes=48 optional_scenes={n_stages} "
      f"new_dialogues={n_lines} actions={n_actions} error_count={len(problems)}")
if problems:
    print("FAIL:",*problems,sep="\n - ")
    raise SystemExit(1)
print("PASS: source, branch and save/reward narrative contracts; NOT Godot runtime.")
