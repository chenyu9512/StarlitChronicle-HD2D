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
    semantic_count=0
    semantic_manifest=root/(ROOT+"semantic_generated_v1/manifest.json")
    if semantic_manifest.is_file():
        semantic=load(root,ROOT+"semantic_generated_v1/manifest.json")
        if semantic.get("schema")!="starlit.semantic_generated.v1":
            errors.append("Invalid generated scene-detail schema")
        semantic_routes=semantic.get("routes",{})
        semantic_count=len(semantic_routes)
        if semantic_count != semantic.get("count") or semantic_count < 9:
            errors.append("Incomplete canonical scene-detail sprites")
        for name,record in semantic_routes.items():
            register(str(record.get("source","")).removeprefix("res://"),record.get("sha256"))
    allocated_count=0
    allocated_file=root/(ROOT+"allocated_decor_generated_v1/manifest.json")
    if allocated_file.is_file():
        alloc=load(root,ROOT+"allocated_decor_generated_v1/manifest.json")
        if alloc.get("schema")!="starlit.allocated_decor_generated.v1":
            errors.append("Invalid generated world-prop manifest")
        records=alloc.get("assets",{})
        allocated_count=len(records)
        if allocated_count!=25:
            errors.append("Expected 25 allocated 32px generated props")
        for item in records.values():
            register(str(item.get("source","")).removeprefix("res://"),item.get("sha256"))
    # V10 adds exactly named replacement PNGs for legacy canonical slot gaps.
    # The optional layer must be registered and hashed, never treated as an
    # untracked backup simply because it arrived after the V3 factory.
    v10_count = 0
    v10_manifest = ROOT + "generated_gaps_v10/manifest.json"
    if (root / v10_manifest).is_file():
        v10 = load(root, v10_manifest)
        if v10.get("schema") != "starlit.main2.gap_fill.v10":
            errors.append("Invalid V10 generated-gap manifest schema")
        records = v10.get("assets", {})
        if not isinstance(records, dict):
            errors.append("Invalid V10 generated-gap asset table")
            records = {}
        v10_count = len(records)
        if v10.get("generated_count") != v10_count or v10_count < 109:
            errors.append("Incomplete V10 generated-gap materialization")
        registry_path = root / "data/assets/c_art_runtime_registry_v1.json"
        registry = load(root, "data/assets/c_art_runtime_registry_v1.json") if registry_path.is_file() else {}
        canonical = registry.get("canonical_slots", {})
        ui_sources = set(registry.get("ui", {}).values())
        for slot, entry in records.items():
            source = str(entry.get("source", "")).removeprefix("res://")
            if not source.startswith(ROOT + "generated_gaps_v10/") or ".." in Path(source).parts:
                errors.append("Unsafe generated-gap source: " + slot)
                continue
            if slot.startswith("ui.extra."):
                if "res://" + source not in ui_sources:
                    errors.append("Unbound generated UI icon: " + slot)
            elif canonical.get(slot, {}).get("source") != "res://" + source:
                errors.append("Unbound canonical art gap: " + slot)
            register(source, entry.get("sha256"))
    gap_count=0
    gap_file=root/(ROOT+"generated_gaps_v10/manifest.json")
    if gap_file.is_file():
        gap=load(root,ROOT+"generated_gaps_v10/manifest.json")
        if gap.get("schema")!="starlit.main2.gap_fill.v10":
            errors.append("Generated-gaps V10 schema invalid")
        entries=gap.get("assets",{})
        gap_count=len(entries)
        if gap_count!=116 or gap.get("generated_count")!=gap_count:
            errors.append("Expected 109 canonical gap PNGs plus 7 UI icons")
        for item in entries.values():
            register(str(item.get("source","")).removeprefix("res://"),item.get("sha256"))
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
        "generated_v10_gap_fill":v10_count,
        "generated_semantic_scene_props":semantic_count,
        "generated_allocated_region_props":allocated_count,
        "generated_gap_and_ui_assets":gap_count,
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
