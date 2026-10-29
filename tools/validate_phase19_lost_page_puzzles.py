#!/usr/bin/env python3
"""Phase19-5: verify the optional 12-case inference game remains canon and save safe."""
from pathlib import Path
import json
R = Path(__file__).resolve().parents[1]
def load(path):
    return json.loads((R / path).read_text(encoding="utf-8"))
src = {q["id"]:q for q in load("story/data/side_quests.json")["quests"] if q["id"].startswith("sq_page_")}
submaps={q["quest_id"]:q for q in load("story/data/phase19_lost_page_submaps.json")["quests"]}
data=load("story/data/phase19_lost_page_puzzles.json")
issues=[]
def check(ok,msg):
    if not ok: issues.append(msg)
unique=set()
titles=set()
for item in data["quests"]:
    id=item["quest_id"]
    check(id in src and id in submaps and id not in unique, "unique canonical ID "+id)
    unique.add(id)
    check(item["mechanic"] not in titles and len(item["mechanic"])>=4,"unique puzzle mechanic "+id)
    titles.add(item["mechanic"])
    options=item.get("options",[])
    check(len(options)==3 and len({v["id"] for v in options})==3,"three player outcomes "+id)
    check(item["correct_option_id"] in [v["id"] for v in options],"one correct conclusion "+id)
    check(item["required_observations"]==["0","1"],"cross evidence first "+id)
    check(item["outcome_flag"]==f"rpg.quest_puzzles.{id}.solved","scoped save flag "+id)
    check(item["rewards"]=={"xp":0,"gold":0,"bond":0},"no repeat original rewards "+id)
    check(len(item["prompt"])>=15 and len(item["success"])>=10 and len(item["retry"])>=10,
          "usable scene dialogue "+id)
    original="".join(x.get("text","") for stage in src[id]["stages"] for x in stage.get("dialogue",[]))
    check(len(original)>40,"original canon dialogue retained "+id)
check(len(unique)==len(src)==len(submaps)==12,"12 distinct canon scenes")
check(data["rules"]["unlocks_original_quest"] is False and
    data["rules"]["repeat_original_rewards"] is False,"optional non-farming puzzles")
print(f"Phase19Puzzles count={len(unique)} mechanics={len(titles)} errors={len(issues)}")
if issues:
    print("FAIL:",*issues,sep="\n - ")
    raise SystemExit(1)
print("PASS: 12 authored evidence deductions, canonical chapter locations and save isolation.")
