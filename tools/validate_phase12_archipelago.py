#!/usr/bin/env python3
"""Act V phase12 narrative consistency, 25-30. Source checks, not Godot simulation."""
import json
from pathlib import Path

ROOT=Path(__file__).resolve().parents[1]/"story"
errors=[]
def data(path):
    return json.loads((ROOT/path).read_text(encoding="utf-8"))
def check(condition,msg):
    if not condition: errors.append(msg)

act=data("campaign/act_05.json")
chapters=act["chapters"]
check([x["id"] for x in chapters]==[f"ch{i:03}" for i in range(25,31)],"chapter range/order")
check(act.get("phase12_revision",{}).get("new_lines")==120,"phase12 revision count")
dialogue=[]
seen=set()
for ch in chapters:
    cid=ch["id"]
    check(len(ch["scenes"])==4,"four scenes: "+cid)
    check(ch.get("phase12_revision",{}).get("new_lines")==20,"twenty added: "+cid)
    check(ch["required_flags"]==[f"story.ch{ch['number']-1:03}.done"],"prerequisites: "+cid)
    check([s["id"] for s in ch["scenes"]]==[f"{cid}.{p}" for p in ("opening","investigate","crisis","resolve")],"scene order: "+cid)
    for scene in ch["scenes"]:
        sid=scene["id"]
        check(len([x for x in scene["dialogue"] if ".p12." in x["id"]])==5,"five added lines: "+sid)
        check(bool(scene.get("direction",{}).get("phase12_director_focus")),"missing direction: "+sid)
        for line in scene["dialogue"]:
            did=line["id"]
            check(bool(did) and did not in seen,"duplicate line: "+did)
            check(bool(line.get("speaker")) and bool(line.get("text")),"empty text: "+did)
            seen.add(did)
            dialogue.append(line)
    check(any(e.get("type")=="set_flag" and e.get("key")==f"story.{cid}.done"
              for e in ch["scenes"][-1].get("effects",[])),"completion: "+cid)
    choice=ch["scenes"][2].get("choice",{})
    check(choice.get("id")==f"{cid}.choice" and {o.get("id") for o in choice.get("options",[])}=={"listen","act"},"A/B choice damaged: "+cid)
check(len(dialogue)==288,"main act V dialogue not 288")

c26=chapters[1]
check("第一张失落航页" not in c26.get("summary",""),"ch026 summary falsely first page")
check(all("第一张失落航页" not in l.get("text","") for s in c26["scenes"] for l in s["dialogue"]),"ch026 falsely first page in dialogue")
check("不把它算成" in " ".join(l["text"] for l in c26["scenes"][-1]["dialogue"]),"ch026 must distinguish evidence from collectible pages")
check(all(not(e.get("type")=="set_flag" and e.get("key","").startswith("world.page_"))
              for s in c26["scenes"] for e in s.get("effects",[])),"ch026 newly grants a collectible page")
side=data("data/side_quests.json")
pages=[q for q in side.get("quests",[]) if q.get("type")=="lost_page"]
check(len(pages)==12,"lost page quest total")
check({q["id"] for q in pages}=={f"sq_page_{i:02}" for i in range(1,13)},"page quest numbering")
check("伊泽" not in [l.get("speaker") for c in chapters[:2] for s in c["scenes"] for l in s["dialogue"]],"Ize appeared before ch027")
check(any(l["speaker"]=="伊泽" for s in chapters[2]["scenes"] for l in s["dialogue"]),"Ize not introduced ch027")
check("正式加入" not in " ".join(l["text"] for s in chapters[2]["scenes"] for l in s["dialogue"]),"Ize joined too early")
check("正式加入" in " ".join(l["text"] for l in chapters[3]["scenes"][-1]["dialogue"]),"Ize didn't join in ch028")
check("phase12_cast_contract" in chapters[2]["scenes"][0].get("direction",{}),"ch027 cast contract missing")
check("phase12_page_contract" in c26["scenes"][-1].get("direction",{}),"ch026 page contract missing")

scenes=data("data/phase12_act05_optional_scenes.json")
followups=data("data/phase12_act05_choice_reactions.json")
plan=data("data/phase12_act05_production_plan.json")
check(scenes["status"]=="text_only_not_runtime_bound","optional falsely runtime-bound")
check(followups["status"]=="text_only_not_runtime_bound","replies falsely runtime-bound")
check(plan["status"]=="production_design_only_not_runtime_bound","plan falsely runtime-bound")
check(len(scenes["scenes"])==12 and len(followups["followups"])==12,"missing optional/reactions")
check(len(plan["event_plan"])==12 and len(plan["reaction_plan"])==12,"production plan coverage")
idx={c["id"]:c for c in chapters}
extra=set()
for scene in scenes["scenes"]:
    c=idx.get(scene["chapter_id"],{})
    check(any(s["id"]==scene["insert_after_scene_id"] for s in c.get("scenes",[])),"optional anchor: "+scene["id"])
    expected=scene["chapter_id"]+("."+"started" if scene["kind"]=="town" else ".evidence")
    check(scene["required_flags"]==[expected],"optional flag: "+scene["id"])
    check(len(scene["dialogue"])==6,"optional count: "+scene["id"])
    for line in scene["dialogue"]:
        check(line["id"] not in seen and line["id"] not in extra,"duplicate optional "+line["id"])
        extra.add(line["id"])
for reply in followups["followups"]:
    c=idx.get(reply["chapter_id"],{})
    options=[o for s in c.get("scenes",[]) if s.get("choice",{}).get("id")==reply["after_choice_id"] for o in s["choice"]["options"] if o["id"]==reply["choice_option_id"]]
    check(len(options)==1,"reaction option invalid: "+reply["id"])
    if options: check(options[0]["sets"]==reply["condition"],"reaction state mismatch: "+reply["id"])
    check(len(reply["dialogue"])==3,"reaction line count: "+reply["id"])
    for line in reply["dialogue"]:
        check(line["id"] not in seen and line["id"] not in extra,"duplicate reaction "+line["id"])
        extra.add(line["id"])
check(len(extra)==108,"expected 108 extra lines")
check({e["id"] for e in plan["event_plan"]}=={s["id"] for s in scenes["scenes"]},"plan optional coverage")
check({r["id"] for r in plan["reaction_plan"]}=={r["id"] for r in followups["followups"]},"plan reaction coverage")
for item in plan["event_plan"]:
    check(item["production"]["runtime_registered"] is False,"event claims runtime: "+item["id"])
    check(len(item["player_actions"])==3 and item["trigger_contract"]["skippable"],"event operations: "+item["id"])
for item in plan["reaction_plan"]:
    check(item["runtime_registered"] is False,"reaction claims runtime: "+item["id"])
beacons=plan["major_setpieces"]["ch029_six_beacons"]["beacons"]
check(len(beacons)==6 and all(b["runtime_registered"] is False for b in beacons),"six beacon design contract")
reading=(ROOT/"screenplay/act_05_phase12_full.md").read_text(encoding="utf-8")
for line in dialogue: check(line["text"] in reading,"missing in manuscript: "+line["id"])
index=(ROOT/"SCREENPLAY_CURRENT_INDEX.md").read_text(encoding="utf-8")
check("act_05_phase12_full.md" in index,"active script index wrong")

print(f"ActVChapters={len(chapters)} MainLines={len(dialogue)} OptionalLines={len(extra)} BeaconDesign={len(beacons)} Errors={len(errors)}")
if errors:
    print("FAIL",*errors,sep="\n - ")
    raise SystemExit(1)
print("PASS: phase12 static consistency (NOT Godot scene runtime)")
