#!/usr/bin/env python3
"""P0-P3 cinematic content contract: ten opening cues and 72 canon transitions."""
import json
from pathlib import Path

ROOT=Path(__file__).resolve().parents[1]
def read(path):
    return json.loads((ROOT/path).read_text(encoding="utf-8"))

def main():
    prologue=read("story/campaign/prologue.json")
    story=read("data/cinematics/prologue.json")
    chapters=read("data/cinematics/chapter_transitions.json")
    assert story["schema"]=="starlit.cinematic.timeline.v1"
    assert chapters["schema"]=="starlit.cinematic.transitions.v1"
    assert len(prologue["scenes"])==9 and len(story["beats"])==10
    assert "cold_open" in story["beats"]
    assert len(chapters["acts"])==12 and len(chapters["chapters"])==72
    required={"title","sub","image","tone","lines"}
    for cue_id,rec in story["beats"].items():
        assert required.issubset(rec),cue_id
        assert rec["lines"] and all(isinstance(x,list) and len(x)==2 and all(x) for x in rec["lines"]),cue_id
        assert (ROOT/rec["image"].removeprefix("res://")).is_file(),cue_id
    for i,sc in enumerate(prologue["scenes"]):
        assert story["beats"][f"prologue_{i}"]["title"],sc["id"]
        assert sc["dialogue"] and "objective" in sc,sc["id"]
    canon=[]
    for act in range(1,13):
        a=read(f"story/campaign/act_{act:02d}.json")
        assert len(a["chapters"])==6
        canon.extend((int(c["number"]),c["title"]) for c in a["chapters"])
        assert chapters["acts"][act-1]["title"]==a["title"]
    assert len(canon)==72
    for i,(n,title) in enumerate(canon):
        assert chapters["chapters"][i]["number"]==n and chapters["chapters"][i]["title"]==title
        assert chapters["chapters"][i]["act"]==(i//6)+1
    print("PASS: 10 intro cues (9 original playable scenes), 72 exact canon chapter cards and 12 acts, art resources and dialogue payloads")

if __name__=="__main__":
    main()
