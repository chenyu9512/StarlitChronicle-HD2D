#!/usr/bin/env python3
"""Phase14 ch037-042 static script and optional event verification. No Godot runtime."""
import json
from pathlib import Path

S=Path(__file__).resolve().parents[1]/"story"
def read(p):return json.loads((S/p).read_text(encoding="utf8"))
a=read("campaign/act_07.json")
o=read("data/phase14_act07_optional_scenes.json")
r=read("data/phase14_act07_choice_reactions.json")
p=read("data/phase14_act07_production_plan.json")
errors=[]
def check(c,m):
    if not c:errors.append(m)
by={c["id"]:c for c in a["chapters"]}
check(set(by)=={f"ch{n:03}" for n in range(37,43)},"chapter coverage")
check(len(o["scenes"])==12 and len(r["followups"])==12,"optional count")
check(len(p["event_plan"])==12 and len(p["choice_reaction_plan"])==12,"production coverage")
ids=set()
main=[]
for c in a["chapters"]:
    check(len(c["scenes"])==4 and c["phase14_revision"]["new_lines"]==20,"chapter layout "+c["id"])
    check(c["required_flags"]==[f"story.ch{c['number']-1:03}.done"],"chapter prerequisite "+c["id"])
    for s in c["scenes"]:
        check(len([x for x in s["dialogue"] if ".p14." in x["id"]])==5,"five new lines "+s["id"])
        for x in s["dialogue"]:
            check(x["id"] not in ids and bool(x["text"]),"main ID "+x["id"])
            ids.add(x["id"]);main.append(x)
        if s.get("choice"):
            check(len(s["choice"]["options"])==2,"two options "+s["id"])
check(len(main)==293,"293 lines act VII")
for scene in o["scenes"]:
    c=by[scene["chapter_id"]]
    check(scene["insert_after_scene_id"] in {s["id"] for s in c["scenes"]},"scene anchor "+scene["id"])
    check(len(scene["dialogue"])==6,"six optional lines "+scene["id"])
    for x in scene["dialogue"]:
        check(x["id"] not in ids,"duplicate optional "+x["id"]);ids.add(x["id"])
for f in r["followups"]:
    choices=[x for s in by[f["chapter_id"]]["scenes"] if s.get("choice",{}).get("id")==f["after_choice_id"]
             for x in s["choice"]["options"] if x["id"]==f["choice_option_id"]]
    check(len(choices)==1,"choice anchor "+f["id"])
    if choices:check(choices[0]["sets"]==f["condition"],"choice conditions "+f["id"])
    check(len(f["dialogue"])==3,"response lines "+f["id"])
    for x in f["dialogue"]:
        check(x["id"] not in ids,"duplicate response "+x["id"]);ids.add(x["id"])
check(len(ids)==293+72+36,"all phase14 IDs")
check(o["status"]=="text_only_not_runtime_bound" and r["status"]=="text_only_not_runtime_bound","optional status")
check(p["status"]=="production_design_only_not_runtime_bound","design status")
check({e["id"] for e in p["event_plan"]}=={e["id"] for e in o["scenes"]},"event plan IDs")
check({x["id"] for x in p["choice_reaction_plan"]}=={x["id"] for x in r["followups"]},"choice plan IDs")
check(all(x["production"]["runtime_registered"] is False for x in p["event_plan"]),"falsely playable")
check("world.distributed_network" not in {e.get("key") for s in by["ch041"]["scenes"] for e in s.get("effects",[])},"premature network")
check(all(x["speaker"]!="成年诺依" for s in by["ch039"]["scenes"] for x in s["dialogue"]),"adult Noi in ch39")
reading=(S/"screenplay/act_07_phase14_full.md").read_text(encoding="utf8")
check(all(x["text"] in reading for x in main),"manuscript mismatch")
index=(S/"SCREENPLAY_CURRENT_INDEX.md").read_text(encoding="utf8")
check("act_07_phase14_full.md" in index,"not indexed")
print("Phase14",len(main),"main",len(o["scenes"]),"optional scenes",len(r["followups"]),"choice variants",len(errors),"errors")
if errors:
    print(*errors,sep="\n");raise SystemExit(1)
print("PASS: static narrative checks, not gameplay")
