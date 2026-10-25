#!/usr/bin/env python3
"""Static phase 13 narrative validation. Does not run Godot scenes or maps."""
import json
from pathlib import Path

ROOT=Path(__file__).resolve().parents[1]/"story"
problems=[]
def read(rel):
    return json.loads((ROOT/rel).read_text(encoding="utf-8"))
def need(b,msg):
    if not b: problems.append(msg)

act=read("campaign/act_06.json")
chapters=act["chapters"]
need([c["id"] for c in chapters]==[f"ch{i:03}" for i in range(31,37)],"chapter order")
need(act.get("phase13_revision",{}).get("new_lines")==120,"new line count")
main={}
for c in chapters:
    cid=c["id"]
    need(len(c["scenes"])==4,"stage count: "+cid)
    need(c.get("phase13_revision",{}).get("new_lines")==20,"added lines: "+cid)
    need(c.get("required_flags")==[f"story.ch{c['number']-1:03}.done"],"required flags: "+cid)
    need([s["id"] for s in c["scenes"]]==[f"{cid}.{name}" for name in ("opening","investigate","crisis","resolve")],"scene topology: "+cid)
    for s in c["scenes"]:
        need(len([l for l in s["dialogue"] if ".p13." in l["id"]])==5,"phase 13 five lines: "+s["id"])
        need(bool(s.get("direction",{}).get("phase13_focus")),"direction: "+s["id"])
        for l in s["dialogue"]:
            key=l["id"]
            need(key not in main,"duplicate mainline "+key)
            need(bool(l.get("speaker")) and bool(l.get("text")),"empty line "+key)
            main[key]=l
    done=c["scenes"][-1].get("effects",[])
    need(any(x.get("type")=="set_flag" and x.get("key")==f"story.{cid}.done" for x in done),"completion: "+cid)
    choice=c["scenes"][2].get("choice",{})
    need(choice.get("id")==f"{cid}.choice" and {o["id"] for o in choice.get("options",[])}=={"listen","act"},"choice structure: "+cid)
need(len(main)==296,"main dialogue total")

# Mirror world: first autonomous appearance at ch032; formally joins at ch034 resolve.
need(all(l["speaker"]!="玄璃" for s in chapters[0]["scenes"] for l in s["dialogue"]),"Xuanli spoke early in ch031")
need(any(l["speaker"]=="玄璃" for s in chapters[1]["scenes"] for l in s["dialogue"]),"Xuanli missing ch032")
need("正式成为同行者" in " ".join(l["text"] for l in chapters[3]["scenes"][-1]["dialogue"]),"Xuanli join not in ch034 resolve")
need("phase13_party_contract" in chapters[1]["scenes"][0].get("direction",{}),"ch032 early encounter contract missing")
need("phase13_world_contract" in chapters[5]["scenes"][0].get("direction",{}),"world mirror rule missing")

extras=read("data/phase13_act06_optional_scenes.json")
reactions=read("data/phase13_act06_choice_reactions.json")
plan=read("data/phase13_act06_production_plan.json")
need(extras.get("status")=="text_only_not_runtime_bound","optional marked runnable")
need(reactions.get("status")=="text_only_not_runtime_bound","reactions marked runnable")
need(plan.get("status")=="production_design_only_not_runtime_bound","plan marked runnable")
need(len(extras["scenes"])==12,"12 optional scenes")
need(len(reactions["followups"])==12,"12 choice responses")
need(len(plan["event_plan"])==12 and len(plan["choice_reaction_plan"])==12,"plan missing items")
need(len(plan.get("puzzle_design",{}))==6,"six mirror puzzle types")
by={c["id"]:c for c in chapters}
extra_ids=set()
for scene in extras["scenes"]:
    cid=scene["chapter_id"]
    c=by.get(cid,{})
    need(any(s["id"]==scene["insert_after_scene_id"] for s in c.get("scenes",[])),"optional anchor: "+scene["id"])
    expected=cid+(".started" if scene["kind"]=="town" else ".evidence")
    need(scene["required_flags"]==[expected],"optional required flag: "+scene["id"])
    need(len(scene["dialogue"])==6,"optional six lines: "+scene["id"])
    for l in scene["dialogue"]:
        need(l["id"] not in main and l["id"] not in extra_ids,"duplicate optional: "+l["id"])
        extra_ids.add(l["id"])
for response in reactions["followups"]:
    cid=response["chapter_id"]
    c=by[cid]
    match=[o for s in c["scenes"] if s.get("choice",{}).get("id")==response["after_choice_id"]
           for o in s["choice"]["options"] if o["id"]==response["choice_option_id"]]
    need(len(match)==1,"response choice anchor: "+response["id"])
    if match: need(response["condition"]==match[0]["sets"],"response flags: "+response["id"])
    need(len(response["dialogue"])==3,"three response lines: "+response["id"])
    for l in response["dialogue"]:
        need(l["id"] not in main and l["id"] not in extra_ids,"duplicate response: "+l["id"])
        extra_ids.add(l["id"])
need(len(extra_ids)==108,"108 added option and choice lines")
need({s["id"] for s in extras["scenes"]}=={s["id"] for s in plan["event_plan"]},"event plan coverage")
need({r["id"] for r in reactions["followups"]}=={r["id"] for r in plan["choice_reaction_plan"]},"choice plan coverage")
for e in plan["event_plan"]:
    need(len(e["player_actions"])==3,"event no player actions "+e["id"])
    need(e["trigger_contract"]["skippable"] and e["trigger_contract"]["once_only"],"non-optional event "+e["id"])
    need(e["production"]["runtime_registered"] is False,"event wrongly marked runnable "+e["id"])
for r in plan["choice_reaction_plan"]:
    need(r["runtime_registered"] is False,"choice wrongly marked runnable "+r["id"])

reading=(ROOT/"screenplay/act_06_phase13_full.md").read_text(encoding="utf-8")
for l in main.values():
    need(l["text"] in reading,"reading manuscript missing "+l["id"])
index=(ROOT/"SCREENPLAY_CURRENT_INDEX.md").read_text(encoding="utf-8")
need("act_06_phase13_full.md" in index,"current screenplay index")

print(f"ActVIChapters={len(chapters)} MainLines={len(main)} OptionalLines={len(extra_ids)} PuzzleTypes={len(plan.get('puzzle_design',{}))} Errors={len(problems)}")
if problems:
    print("FAIL:",*problems,sep="\n - ")
    raise SystemExit(1)
print("PASS: phase13 static text and condition contracts (NOT Godot runtime)")
