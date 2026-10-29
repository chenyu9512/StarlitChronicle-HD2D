#!/usr/bin/env python3
"""Main2 art V2 coverage: separate inventory, assignment, runtime links and QA."""
from __future__ import annotations
import json
from collections import Counter
from pathlib import Path

ROOT=Path(__file__).resolve().parent.parent

def load(relative):
    return json.loads((ROOT/relative).read_text(encoding="utf-8"))

def audit():
    theme=load("data/assets/art_theme_v2.json")["themes"][0]
    slots=theme["slots"]
    assigned=load("data/assets/c_art_allocation_v6.json")
    external=load("data/assets/c_art_usage_external_v12.json")
    src=load("data/assets/c_art_usage_source_v12.json")
    counts=Counter(x.get("state","unclassified") for x in assigned["rows"])
    roles=Counter(x.get("category","unclassified") for x in slots.values())
    external_status=external.get("status_counts",{})
    preview=[
        {"chapter":1,"scene":"晨露村 / 澄舟旧屋","result":"visual_signoff_unverified"},
        {"chapter":2,"scene":"白砂港 / 收容所","result":"visual_signoff_unverified"},
        {"chapter":3,"scene":"断桅海蚀洞","result":"visual_signoff_unverified"},
        {"chapter":4,"scene":"黑帆酒馆","result":"visual_signoff_unverified"},
        {"chapter":5,"scene":"鲸骨浅滩","result":"visual_signoff_unverified"},
        {"chapter":6,"scene":"潮歌灯塔","result":"visual_signoff_unverified"},
    ]
    return {
        "schema":"starlit.art_coverage.v2",
        "meaning":"Static inventory and runtime semantic slot counts; no commercial completion is implied.",
        "registry":{"theme":theme["id"],"slots":len(slots),"required":sum(bool(x.get("required")) for x in slots.values()),
                    "by_category":dict(roles),"commercial_visual_signoff":False},
        "allocation":{"rows":len(assigned["rows"]),"by_state":dict(counts),
                      "note":"allocated != scene-visible"},
        "third_party":{"external_images":external.get("image_count"),"source_images_indexed":src.get("image_count"),
                       "external_status":external_status},
        "act01_chapters":preview,
        "approved_act01_completion_percent":None,
        "release_decision":"BLOCK until 6/6 in-engine screenshot human signoff and same-SHA CI green",
    }

if __name__=="__main__":
    x=audit()
    out=ROOT/"build/art-theme-v2/coverage.json"
    out.parent.mkdir(parents=True,exist_ok=True)
    out.write_text(json.dumps(x,ensure_ascii=False,indent=2)+"\n",encoding="utf-8")
    print(json.dumps(x,ensure_ascii=False,indent=2))
