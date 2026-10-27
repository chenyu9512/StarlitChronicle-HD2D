#!/usr/bin/env python3
"""P0-P3 cinematic content contract: ten opening cues and 72 canon transitions."""
import json
from pathlib import Path

ROOT=Path(__file__).resolve().parents[1]
MIGRATIONS_PATH=ROOT/"data/assets/c_third_party_only_migration_v1.json"

def resolved_cinematic_art(resource):
    """Validate the physical source selected by Main2's runtime art resolver."""
    assert resource.startswith("res://assets/art/"),resource
    logical=resource.removeprefix("res://")
    direct=ROOT/logical
    if direct.is_file():
        return direct
    assert MIGRATIONS_PATH.is_file(),("missing migration register",resource)
    migration=json.loads(MIGRATIONS_PATH.read_text(encoding="utf-8"))
    matched=[m["new_source"] for m in migration.get("mappings",[])
             if m.get("old_path")==logical]
    assert len(matched)==1,(resource,"missing or ambiguous migration")
    replacement=matched[0]
    assert replacement.startswith("assets/art/external/cc0_named_v1/") and ".." not in Path(replacement).parts,resource
    physical=ROOT/replacement
    assert physical.is_file(),(resource,replacement,"migrated source missing")
    assert physical.suffix.lower() in {".png",".webp",".jpg",".jpeg"},(resource,replacement)
    return physical

def read(path):
    return json.loads((ROOT/path).read_text(encoding="utf-8"))

def main():
    prologue=read("story/campaign/prologue.json")
    story=read("data/cinematics/prologue.json")
    chapters=read("data/cinematics/chapter_transitions.json")
    blocking=read("data/cinematics/scene_blocking.json")
    assert story["schema"]=="starlit.cinematic.timeline.v1"
    assert chapters["schema"]=="starlit.cinematic.transitions.v1"
    assert len(prologue["scenes"])==9 and len(story["beats"])==10
    assert "cold_open" in story["beats"]
    assert len(chapters["acts"])==12 and len(chapters["chapters"])==72
    required={"title","sub","image","tone","lines"}
    for cue_id,rec in story["beats"].items():
        assert required.issubset(rec),cue_id
        assert rec["lines"] and all(isinstance(x,list) and len(x)==2 and all(x) for x in rec["lines"]),cue_id
        picture=resolved_cinematic_art(rec["image"])
        assert picture.stat().st_size>0,(cue_id,picture)
    for i,sc in enumerate(prologue["scenes"]):
        assert story["beats"][f"prologue_{i}"]["title"],sc["id"]
        assert sc["dialogue"] and "objective" in sc,sc["id"]
    canon=[]
    for act in range(1,13):
        a=read(f"story/campaign/act_{act:02d}.json")
        assert len(a["chapters"])==6
        canon.extend((int(c["number"]),c["title"]) for c in a["chapters"])
        assert chapters["acts"][act-1]["title"]==a["title"]
    assert blocking["schema"]=="starlit.cinematic.blocking.v1"
    scene_contract={}
    for act in range(1,13):
        a=read(f"story/campaign/act_{act:02d}.json")
        for chapter in a["chapters"]:
            for i,scene in enumerate(chapter["scenes"]):
                scene_contract[scene["id"]]=(int(chapter["number"]),i)
    assert len(scene_contract)==289 and len(blocking["scenes"])==289
    for event_id,(chapter,index) in scene_contract.items():
        record=blocking["scenes"].get(event_id)
        assert record and record["chapter"]==chapter and record["scene_index"]==index, event_id
        assert record["camera"] in {"establish","detail","confrontation","recenter","reveal"},event_id
    assert len(canon)==72
    for i,(n,title) in enumerate(canon):
        assert chapters["chapters"][i]["number"]==n and chapters["chapters"][i]["title"]==title
        assert chapters["chapters"][i]["act"]==(i//6)+1
    print("PASS: 10 intro cues (9 original playable scenes), 289 individually authored camera stage records, 72 exact canon chapter cards and 12 acts, art resources and dialogue payloads")

if __name__=="__main__":
    main()
