#!/usr/bin/env python3
"""Strict full-game generated-only image inventory for Main2.

Does not claim art-direction or Godot rendering acceptance. Fails on all
untracked/orphan or retired source images and checks each manifest SHA.
"""
from __future__ import annotations

import argparse
import hashlib
import json
import sys
from pathlib import Path
from PIL import Image

ART="assets/art/"
ROOT="assets/art/runtime/"
FACTORY=ROOT+"global_factory_v3/"
TERRAIN_IDS=("region_coast","region_oaths","region_forge","region_isles",
             "region_mirror","region_oldland","region_sanctum","region_city")

def load(root, relative):
    return json.loads((root/relative).read_text(encoding="utf-8-sig"))

def checksum(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()

def audit(root):
    root=root.resolve()
    errors=[]
    available={
        p.relative_to(root).as_posix():p
        for p in (root/ART).rglob("*") if p.is_file()
        and p.suffix.lower() in (".png",".svg",".jpg",".jpeg",".webp")
    }
    if not available:
        raise ValueError("No game art present")
    outside=[p for p in available if not p.startswith(ROOT)]
    if outside:
        errors.append("Non-runtime legacy or uploaded files remain: "+str(outside[:10]))
    live=load(root,FACTORY+"active.json")
    if live.get("schema")!="starlit.global_factory.live.v3" or not live.get("enabled"):
        errors.append("Canonical runtime generator is not active")
    declared={}
    def register(path,sha=None):
        if path in declared:
            errors.append("Duplicate generated path: "+path)
        declared[path]=sha
    assets=live.get("assets",{})
    if len(assets)!=live.get("asset_count"):
        errors.append("Canonical asset count mismatch")
    for slot,row in assets.items():
        group,sep,identity=slot.partition(".")
        path=str(row.get("path","")).removeprefix("res://")
        if not sep or path!=FACTORY+group+"/"+identity+".png":
            errors.append("Invalid canonical group/ID mapping "+slot)
        register(path,row.get("sha256"))
        normal=row.get("normal_map_path")
        if normal:
            expected=FACTORY+"normal_maps/"+group+"/"+identity+"_n.png"
            if normal.removeprefix("res://")!=expected:
                errors.append("Invalid normal-map mapping "+slot)
            register(expected,row.get("normal_map_sha256"))
    for region in TERRAIN_IDS:
        for kind in ("ground","water"):
            register(FACTORY+"terrain/"+region+"_"+kind+".png")
    mappings=((ROOT+"content_icons_v1/manifest.json","assets","source","sha256",288),
              (ROOT+"boss_motion_v1/manifest.json","assets","source","sha256",66),
              (ROOT+"shore_waves_v1/manifest.json","assets","source","sha256",8))
    for document,key,path_key,hash_key,expect in mappings:
        data=load(root,document)
        entries=data.get(key,{})
        if len(entries)!=expect:
            errors.append("Generated effect/animation manifest count wrong: "+document)
        for name,item in entries.items():
            target=str(item.get(path_key,"")).removeprefix("res://")
            register(target,item.get(hash_key))
    # Original project-authored SVGs of local scene detailing remain valid,
    # and must not be misreported as uploaded third-party source files.
    scene=load(root,ROOT+"scene_details_v1/manifest.json")
    for p in available:
        if p.startswith(ROOT+"scene_details_v1/"):
            register(p)
    missing=sorted(set(declared)-set(available))
    orphan=sorted(set(available)-set(declared))
    if missing: errors.append("Generated manifest image missing: "+str(missing[:12]))
    if orphan: errors.append("Images without generated-role coverage: "+str(orphan[:12]))
    for name, expected_hash in declared.items():
        file=available.get(name)
        if not file:continue
        if expected_hash and checksum(file)!=expected_hash:
            errors.append("Generated image SHA mismatch: "+name)
        if file.suffix.lower()==".png":
            try:
                with Image.open(file) as image:
                    image.verify()
            except Exception as error:
                errors.append("Generated image unreadable: "+name+" "+str(error))
    report={
        "schema":"starlit.generated_only_inventory.v1",
        "status":"success" if not errors else "failed",
        "generated_main":len(assets),
        "generated_normal_maps":sum(bool(x.get("normal_map_path")) for x in assets.values()),
        "generated_terrain_derivatives":16,
        "generated_icons":288,
        "generated_boss_motion":66,
        "generated_shore_waves":8,
        "retained_authored_scene_svg":len([p for p in available if p.startswith(ROOT+"scene_details_v1/")]),
        "total_image_assets":len(available),
        "non_runtime_images":len(outside),
        "orphaned_images":len(orphan),
        "missing_images":len(missing),
        "errors":errors[:40],
        "godot_visual_acceptance":"not_tested"
    }
    return report

def main():
    p=argparse.ArgumentParser()
    p.add_argument("--project",type=Path,default=Path(__file__).resolve().parents[1])
    p.add_argument("--report",type=Path)
    opts=p.parse_args()
    result=audit(opts.project)
    print(json.dumps(result,ensure_ascii=False,indent=2))
    if opts.report:
        opts.report.parent.mkdir(parents=True,exist_ok=True)
        opts.report.write_text(json.dumps(result,ensure_ascii=False,indent=2)+"\n")
    return 0 if result["status"]=="success" else 1

if __name__=="__main__":
    sys.exit(main())
