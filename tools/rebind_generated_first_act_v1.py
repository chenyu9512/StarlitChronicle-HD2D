#!/usr/bin/env python3
"""Rebind first-act renderer source tables to V10 original generated art.

Preserves layout, logical IDs, collision, saves, placement coordinates and
sprite contracts. Only the source paths are rewritten to verified PNGs.
"""
from __future__ import annotations
import argparse
import hashlib
import json
from pathlib import Path

GAP="assets/art/runtime/generated_gaps_v10/manifest.json"
V14="data/assets/c_act01_global_distribution_v14.json"
V18="data/assets/c_act01_hd2d_v18.json"

def load(root,name):
    return json.loads((root/name).read_text(encoding="utf-8-sig"))

def save(root,name,obj):
    (root/name).write_text(json.dumps(obj,ensure_ascii=False,indent=2)+"\n",encoding="utf-8")

def execute(root):
    gap=load(root,GAP)
    if gap.get("schema")!="starlit.main2.gap_fill.v10" or len(gap.get("assets",{}))!=116:
        raise ValueError("All 116 V10 generated art slots must exist")
    routes=gap["assets"]
    def source(slot):
        row=routes.get(slot)
        if not row: raise ValueError("Unmatched canonical generated slot "+slot)
        p=row["source"]
        if not p.startswith("res://assets/art/runtime/generated_gaps_v10/"):
            raise ValueError("Unexpected source path for "+slot)
        file=root/p.removeprefix("res://")
        if not file.is_file() or hashlib.sha256(file.read_bytes()).hexdigest()!=row["sha256"]:
            raise ValueError("Unverified generated source "+slot)
        return p
    v14=load(root,V14)
    if v14.get("schema")!="starlit.c.act01_global_distribution.v14":
        raise ValueError("Unexpected V14 map art registry")
    runtime=v14["runtime"]
    for kind in runtime.get("props",{}):
        runtime["props"][kind]=source("prop.coast."+kind)
    for kind in runtime.get("scenery",{}):
        runtime["scenery"][kind]=source("landmark.coast."+kind)
    for monster in runtime.get("monsters",{}):
        runtime["monsters"][monster]=source("monster.coast."+monster)
    for boss in runtime.get("boss_candidates",{}):
        runtime["boss_candidates"][boss]=source("boss.coast.chapter_"+str(boss).split("ch")[-1].lstrip("0"))
    for map_id,terrain in runtime.get("terrain",{}).items():
        ordinal=int(map_id.rsplit("_",1)[1])
        for material in ("ground","water"):
            terrain[material]=source(f"terrain.coast.map_{ordinal}_{material}")
    for map_id in runtime.get("backgrounds",{}):
        ordinal=int(map_id.rsplit("_",1)[1])
        runtime["backgrounds"][map_id]=source(f"background.coast.map_{ordinal}")
    for name in runtime.get("ui",{}):
        runtime["ui"][name]=source("ui.game."+name)
    v18=load(root,V18)
    if v18.get("schema")!="starlit.c.act01_hd2d_v18":
        raise ValueError("Unexpected first-act HD2D source registry")
    for kind in v18["materials"]:
        v18["materials"][kind]=source("material.coast."+kind)
    for row in v18["placements"]:
        row["source"]=source("prop.hd2d."+row["kind"])
    save(root,V14,v14)
    save(root,V18,v18)
    return {"status":"bound","v14_nonempty":sum(bool(v) for part in (runtime["props"],runtime["scenery"],runtime["monsters"],runtime["boss_candidates"],runtime["backgrounds"],runtime["ui"]) for v in part.values())+sum(sum(bool(v) for v in x.values()) for x in runtime["terrain"].values()),"v18_materials":len(v18["materials"]),"v18_placements":len(v18["placements"])}

def main():
    parser=argparse.ArgumentParser()
    parser.add_argument("--project",type=Path,default=Path(__file__).resolve().parents[1])
    args=parser.parse_args()
    print(json.dumps(execute(args.project.resolve()),ensure_ascii=False,indent=2))
if __name__=="__main__": main()
