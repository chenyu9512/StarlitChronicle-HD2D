#!/usr/bin/env python3
"""Phase15 city and distributed lanterns static source verification.
Does not run Godot, build map nodes or prove CI success.
"""
import json
from pathlib import Path
R=Path(__file__).resolve().parents[1]/"story"
def load(p):return json.loads((R/p).read_text(encoding="utf-8"))
errors=[]
def assert_ok(check,message):
    if not check:errors.append(message)
act=load("campaign/act_10.json")
scenes=load("data/phase15_act10_optional_scenes.json")
responses=load("data/phase15_act10_choice_reactions.json")
plan=load("data/phase15_act10_production_plan.json")
chs=act["chapters"]
assert_ok([c["id"] for c in chs]==[f"ch{x:03}" for x in range(55,61)],"chapter coverage/order")
assert_ok(act["phase15_revision"]["new_lines"]==120,"phase revision 120")
alllines={}
for c in chs:
    assert_ok(len(c["scenes"])==4,"four original scenes "+c["id"])
    assert_ok(c["phase15_revision"]["new_lines"]==20,"20 lines "+c["id"])
    assert_ok(c["required_flags"]==[f"story.ch{c['number']-1:03}.done"],"entry flag "+c["id"])
    for s in c["scenes"]:
        assert_ok(len([d for d in s["dialogue"] if ".p15." in d["id"]])==5,"five new "+s["id"])
        assert_ok(bool(s.get("direction",{}).get("phase15_focus")),"direction "+s["id"])
        for d in s["dialogue"]:
            assert_ok(d["id"] not in alllines,"duplicate main "+d["id"])
            assert_ok(bool(d["speaker"] and d["text"]),"empty main "+d["id"])
            alllines[d["id"]]=d
    cflags=[e for e in c["scenes"][-1]["effects"] if e.get("type")=="set_flag"]
    assert_ok(any(e.get("key")==f"story.{c['id']}.done" for e in cflags),"completion "+c["id"])
    decision=c["scenes"][2].get("choice",{})
    assert_ok(decision.get("id")==f"{c['id']}.choice" and
        {o["id"] for o in decision.get("options",[])}=={"hear","protect"},"choice "+c["id"])
assert_ok(len(alllines)==287,"287 main lines")
assert_ok(chs[2]["scenes"][2].get("encounter") is None,"festival must have no Boss")
assert_ok(any("正式加入队伍" in d["text"] for d in chs[3]["scenes"][3]["dialogue"]),"Weisha join ch058 resolve")
assert_ok(all(d["speaker"]!="维莎" for c in chs[:3] for s in c["scenes"] for d in s["dialogue"]),
          "Weisha premature appearance")
network_flag="world.distributed_network"
for c in chs[:5]:
    assert_ok(all(e.get("key")!=network_flag for s in c["scenes"] for e in s["effects"]),
              "network granted prematurely "+c["id"])
assert_ok(any(e.get("type")=="set_flag" and e.get("key")==network_flag and e.get("value") is True
              for e in chs[-1]["scenes"][-1]["effects"]),"missing true network grant at ch060.resolve")
assert_ok(not any(e.get("key") in ("world.all_twelve_pages","world.seven_lanterns")
              for c in chs for s in c["scenes"] for e in s["effects"]),"accidental ending flags")
assert_ok(len(scenes["scenes"])==12 and len(responses["followups"])==12,"12+12 content")
assert_ok(scenes["status"]=="text_only_not_runtime_bound" and
          responses["status"]=="text_only_not_runtime_bound","optional marked runtime")
assert_ok(plan["status"]=="production_design_only_not_runtime_bound","plan marked runtime")
by={c["id"]:c for c in chs}
more=set()
for s in scenes["scenes"]:
    ch=by[s["chapter_id"]]
    assert_ok(s["insert_after_scene_id"] in {q["id"] for q in ch["scenes"]},
              "orphan optional "+s["id"])
    required=s["chapter_id"]+(".started" if s["kind"]=="town" else ".evidence")
    assert_ok(s["required_flags"]==[required],"optional required "+s["id"])
    assert_ok(len(s["dialogue"])==6,"six optional lines "+s["id"])
    for line in s["dialogue"]:
        assert_ok(line["id"] not in alllines and line["id"] not in more,
                  "optional collision "+line["id"])
        more.add(line["id"])
for reaction in responses["followups"]:
    ch=by[reaction["chapter_id"]]
    options=[o for s in ch["scenes"] if s.get("choice",{}).get("id")==reaction["after_choice_id"]
             for o in s["choice"]["options"] if o["id"]==reaction["choice_option_id"]]
    assert_ok(len(options)==1,"choice orphan "+reaction["id"])
    if options:assert_ok(options[0]["sets"]==reaction["condition"],"choice condition "+reaction["id"])
    assert_ok(len(reaction["dialogue"])==3,"three choice lines "+reaction["id"])
    for line in reaction["dialogue"]:
        assert_ok(line["id"] not in alllines and line["id"] not in more,
                  "choice line collision "+line["id"])
        more.add(line["id"])
assert_ok(len(more)==108,"optional+choice 108 dialogue lines")
assert_ok({x["id"] for x in plan["event_plan"]}=={x["id"] for x in scenes["scenes"]},
          "event plan coverage")
assert_ok({x["id"] for x in plan["choice_reaction_plan"]}=={x["id"] for x in responses["followups"]},
          "choice plan coverage")
assert_ok(all(x["production"]["runtime_registered"] is False for x in plan["event_plan"]),
          "false runtime scene")
assert_ok(all(x["runtime_registered"] is False for x in plan["choice_reaction_plan"]),
          "false runtime reaction")
nodes=plan["setpiece_design"]["distributed_light_network"]["nodes"]
assert_ok(len(nodes)==12 and all(n["runtime_registered"] is False for n in nodes),
          "twelve conceptual nodes")
md=(R/"screenplay/act_10_phase15_full.md").read_text(encoding="utf-8")
assert_ok(all(d["text"] in md for d in alllines.values()),"reading text coverage")
index=(R/"SCREENPLAY_CURRENT_INDEX.md").read_text(encoding="utf-8")
assert_ok("act_10_phase15_full.md" in index,"reading index")
print(f"Phase15 Main={len(alllines)} Optional={len(more)} Nodes={len(nodes)} Errors={len(errors)}")
if errors:
    print("FAIL:",*errors,sep="\n - ")
    raise SystemExit(1)
print("PASS: static source contracts, not Godot runtime QA")
