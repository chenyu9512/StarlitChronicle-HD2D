#!/usr/bin/env python3
"""Stage16 Act XI static text and canon checks (not a Godot runtime/playtest)."""
from pathlib import Path
import json
R=Path(__file__).resolve().parents[1]/"story"
def obj(p):return json.loads((R/p).read_text(encoding="utf-8"))
a=obj("campaign/act_11.json")
o=obj("data/phase16_act11_optional_scenes.json")
r=obj("data/phase16_act11_choice_reactions.json")
p=obj("data/phase16_act11_production_plan.json")
endings=obj("data/endings.json")
issues=[]
def check(ok,msg):
    if not ok:issues.append(msg)
cs=a["chapters"]
check([c["id"] for c in cs]==[f"ch{i:03}" for i in range(61,67)],"six chapters order")
check(a["phase16_revision"]["new_lines"]==120,"added 120 lines")
check(a["phase16_revision"]["original_lines"]==168,"source original 168 lines")
main={}
for c in cs:
    cid=c["id"]
    check(len(c["scenes"])==4,"4 original scenes "+cid)
    check(c.get("phase16_revision",{}).get("new_lines")==20,"20 new lines "+cid)
    check(c["required_flags"]==[f"story.ch{c['number']-1:03}.done"],"start flag "+cid)
    check([s["id"] for s in c["scenes"]]==[f"{cid}.{k}" for k in ("opening","investigate","crisis","resolve")],"scene order "+cid)
    for s in c["scenes"]:
        check(len([d for d in s["dialogue"] if ".p16." in d["id"]])==5,"5 added lines "+s["id"])
        check(bool(s.get("direction",{}).get("phase16_focus")),"director contract "+s["id"])
        for d in s["dialogue"]:
            check(d["id"] not in main,"duplicate main ID "+d["id"])
            check(bool(d.get("speaker") and d.get("text")),"empty main dialogue "+d["id"])
            main[d["id"]]=d
    done=c["scenes"][-1]["effects"]
    check(any(e.get("type")=="set_flag" and e.get("key")==f"story.{cid}.done" for e in done),"chapter completion "+cid)
    choice=c["scenes"][2].get("choice",{})
    check(choice.get("id")==f"{cid}.choice" and
          {q["id"] for q in choice.get("options",[])}=={"hear","protect"},"original A/B options "+cid)
check(len(main)==288,"288 main lines")
check("澄舟" in cs[2]["scenes"][0]["dialogue"][0]["text"],"Chengzhou workroom")
check("phase16_chengzhou_contract" in cs[2]["scenes"][0]["direction"],"not-resurrection contract")
for c in cs[:5]:
    check(all(e.get("key")!="world.seven_lanterns" for s in c["scenes"] for e in s["effects"]),"early seven lanterns "+c["id"])
check(any(e.get("type")=="set_flag" and e.get("key")=="world.seven_lanterns"
          and e.get("value") is True for e in cs[5]["scenes"][3]["effects"]),"last resolve seven lantern flag")
check(all(e.get("key")!="world.all_twelve_pages" for c in cs for s in c["scenes"] for e in s["effects"]),"accidental all-pages grant")
endC=next(e for e in endings["endings"] if e["id"]=="C")
check(set(["world.all_twelve_pages","world.distributed_network","world.seven_lanterns"])
      <=set(endC["requirements"]),"ending C hard conditions changed")
check(o["status"]=="text_only_not_runtime_bound","optional runtime status")
check(r["status"]=="text_only_not_runtime_bound","reactions runtime status")
check(p["status"]=="production_design_only_not_runtime_bound","plan runtime status")
check(len(o["scenes"])==12 and len(r["followups"])==12,"12+12 variants")
check(len(p["event_plan"])==12 and len(p["choice_reaction_plan"])==12,"plan coverage")
check(len(p["setpiece_design"])==6,"six setpiece designs")
by={c["id"]:c for c in cs}
extra=set()
for s in o["scenes"]:
    c=by[s["chapter_id"]]
    check(s["insert_after_scene_id"] in {q["id"] for q in c["scenes"]},"optional anchor "+s["id"])
    check(s["required_flags"]==[s["chapter_id"]+(".started" if s["kind"]=="town" else ".evidence")],"required flags "+s["id"])
    check(len(s["dialogue"])==6,"six optional lines "+s["id"])
    for l in s["dialogue"]:
        check(l["id"] not in main and l["id"] not in extra,"optional duplicate "+l["id"])
        extra.add(l["id"])
for q in r["followups"]:
    c=by[q["chapter_id"]]
    matches=[x for s in c["scenes"] if s.get("choice",{}).get("id")==q["after_choice_id"]
            for x in s["choice"]["options"] if x["id"]==q["choice_option_id"]]
    check(len(matches)==1,"reaction anchor "+q["id"])
    if matches:check(q["condition"]==matches[0]["sets"],"reaction condition "+q["id"])
    check(len(q["dialogue"])==3,"reaction count "+q["id"])
    for l in q["dialogue"]:
        check(l["id"] not in main and l["id"] not in extra,"reaction duplicate "+l["id"])
        extra.add(l["id"])
check(len(extra)==108,"extra 108 lines")
check({s["id"] for s in o["scenes"]}=={s["id"] for s in p["event_plan"]},"missing mapped optional event")
check({s["id"] for s in r["followups"]}=={s["id"] for s in p["choice_reaction_plan"]},"missing mapped choice")
check(all(e["production"]["runtime_registered"] is False for e in p["event_plan"]),"fictional runtime scenes")
check(all(e["runtime_registered"] is False for e in p["choice_reaction_plan"]),"fictional runtime reaction")
manuscript=(R/"screenplay/act_11_phase16_full.md").read_text(encoding="utf-8")
check(all(d["text"] in manuscript for d in main.values()),"markdown missing main line")
check("act_11_phase16_full.md" in (R/"SCREENPLAY_CURRENT_INDEX.md").read_text(encoding="utf-8"),"index mismatch")
print(f"Stage16 main={len(main)} optional={len(extra)} chapters={len(cs)} errors={len(issues)}")
if issues:
    print("FAIL",*issues,sep="\n - ")
    raise SystemExit(1)
print("PASS: static source contract only, not Godot runtime")
