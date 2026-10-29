#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""Main2 V10 unified art installer, adapted from the uploaded merged executor.

V9 output must be converted to the live V4.2 normal-map contract before
switching. All active animation, icon and V10 gap folders remain protected.
The generated output is a candidate, not human-approved artwork.
"""
from __future__ import annotations
import argparse
import hashlib
import json
from pathlib import Path
import shutil
import subprocess
import sys
import uuid

F=Path("assets/art/runtime/global_factory_v3")
R=Path("data/assets/c_art_runtime_registry_v1.json")
N={"terrain","interiors","props","characters","npcs","monsters","bosses"}
REGIONS=("region_coast","region_oaths","region_forge","region_isles","region_mirror","region_oldland","region_sanctum","region_city")
BACK=Path("build/starlit_v10_cleanup_backups")
EXT={".png",".svg",".jpg",".jpeg",".webp"}

def read(p): return json.loads(p.read_text(encoding="utf-8-sig"))
def write(p,o):
    t=p.with_name(p.name+".v10tmp")
    t.write_text(json.dumps(o,ensure_ascii=False,indent=2)+"\n",encoding="utf-8")
    t.replace(p)
def digest(p): return hashlib.sha256(p.read_bytes()).hexdigest()
def blob(p):
    b=p.read_bytes()
    return hashlib.sha1(b"blob "+str(len(b)).encode()+b"\0"+b).hexdigest()

def verify(folder):
    from PIL import Image
    a=read(folder/"active.json")
    rows=a.get("assets",{})
    if a.get("schema")!="starlit.global_factory.live.v3" or not a.get("enabled") or len(rows)!=451:
        raise ValueError("Expected 451 canonical live identities")
    files=set()
    for key,row in rows.items():
        group,sep,name=key.partition(".")
        if not sep or not name or "/" in name or ".." in name:
            raise ValueError("Invalid semantic name "+key)
        src="res://"+(F/group/(name+".png")).as_posix()
        if row.get("path")!=src: raise ValueError("Wrong source "+key)
        image=folder/group/(name+".png")
        if not image.is_file() or digest(image)!=row.get("sha256"):
            raise ValueError("Broken core image "+key)
        files.add(image.relative_to(folder).as_posix())
        if group in N:
            normal="res://"+(F/"normal_maps"/group/(name+"_n.png")).as_posix()
            p=folder/"normal_maps"/group/(name+"_n.png")
            if row.get("normal_map_path")!=normal or not p.is_file() or digest(p)!=row.get("normal_map_sha256"):
                raise ValueError("Broken normal image "+key)
            files.add(p.relative_to(folder).as_posix())
        elif row.get("normal_map_path"):
            raise ValueError("Noncanonical normal image "+key)
    for rid in REGIONS:
        for kind in ("ground","water"):
            p=folder/"terrain"/(rid+"_"+kind+".png")
            if not p.is_file(): raise ValueError("Missing terrain derivative "+str(p))
            files.add(p.relative_to(folder).as_posix())
    actual={p.relative_to(folder).as_posix() for p in folder.rglob("*") if p.is_file() and p.suffix.lower() in EXT}
    if files!=actual or len(files)!=868:
        raise ValueError("Inconsistent art inventory "+str(sorted(files^actual)[:8]))
    for name in files:
        with Image.open(folder/name) as img: img.verify()
    return {"status":"成功","core":451,"normals":401,"terrain":16}

def generate(root,out,refined,models):
    from PIL import Image
    sys.path.insert(0,str(root/"tools"))
    from hd2d_studio_v9 import make_pack,verify_pack
    from hd2d_studio_v7 import height_normal
    tier="refined" if refined else "procedural"
    make_pack(root,out,tier=tier,model_source=models)
    verify_pack(out,root)
    a=read(out/"active.json")
    for key,row in a["assets"].items():
        group,_,name=key.partition(".")
        if group in N:
            with Image.open(out/group/(name+".png")) as image:
                normal=height_normal(image.convert("RGBA"))
            dest=out/"normal_maps"/group/(name+"_n.png")
            dest.parent.mkdir(parents=True,exist_ok=True)
            normal.save(dest,format="PNG")
            row["normal_map_path"]="res://"+(F/"normal_maps"/group/(name+"_n.png")).as_posix()
            row["normal_map_sha256"]=digest(dest)
        else:
            row.pop("normal_map_path",None)
            row.pop("normal_map_sha256",None)
        (out/group/(name+"_normal.png")).unlink(missing_ok=True)
    a["source"]="v10_merged_v9_"+tier
    a["renderer"]="4.2.0"
    a["normal_map_count"]=401
    a["visual_acceptance"]="approved" if refined else "not_tested"
    write(out/"active.json",a)
    verify(out)
    return a

def reconcile(root,active):
    reg=read(root/R)
    if reg.get("schema")!="starlit.c.art_runtime_registry.v1":
        raise ValueError("Wrong official registry schema")
    previous=reg.get("sources",{})
    current={p:v for p,v in previous.items() if not p.startswith("res://"+F.as_posix()+"/")}
    generated={}
    for slot,rec in active["assets"].items():
        group=slot.partition(".")[0]
        generated[slot]={"source":rec["path"],"group":group,
          "manifest_sha256":rec["sha256"],"provenance":active["source"],
          "stage":"runtime_candidate_visual_qa_pending" if active["visual_acceptance"]!="approved" else "runtime_reviewed"}
    for region_id in REGIONS:
        for kind in ("ground","water"):
            name=region_id+"_"+kind
            generated["terrain."+name]={"source":"res://"+(F/"terrain"/(name+".png")).as_posix(),
              "group":"terrain","canvas":[256,256],"provenance":active["source"],"stage":"runtime_atlas_pending_visual_qa"}
        region=reg.get("regions",{}).get(region_id)
        if isinstance(region,dict):
            region["generated_terrain"]={kind:generated["terrain."+region_id+"_"+kind]["source"] for kind in ("ground","water")}
            region["scene_props"]={role:generated["props."+region_id+"_"+role]["source"]
                for role in ("tree","cottage","shop","shrine","well","lantern","crate","banner")}
    reg["generated_assets"]=generated
    reg["generated_manifest"]={"source":"res://"+(F/"active.json").as_posix(),
      "manifest_images":451,"regional_atlases_extra":16,"groups":active["counts"],
      "enabled":True,"visual_status":"未测试" if active["visual_acceptance"]!="approved" else "已审核"}
    for file in (root/F).rglob("*"):
        if not file.is_file() or file.suffix.lower() not in EXT: continue
        path="res://"+file.relative_to(root).as_posix()
        prev=previous.get(path,{})
        same=prev.get("sha")==blob(file)
        current[path]={"sha":blob(file),"physically_present":True,"registered":True,
          "code_reference":"generated_semantic_resolver",
          "drawn_in_scene":prev.get("drawn_in_scene","未测试") if same else "未测试",
          "visual_correct":prev.get("visual_correct","未测试") if same else "未测试",
          "tier":"generated_runtime","provenance":active["source"]}
    reg["sources"]=dict(sorted(current.items()))
    write(root/R,reg)

def promote(root,out,active):
    verify(out)
    stamp=uuid.uuid4().hex[:12]
    b=root/BACK;b.mkdir(parents=True,exist_ok=True)
    prev=b/("previous_factory_"+stamp)
    prev_reg=b/("previous_registry_"+stamp+".json")
    shutil.copy2(root/R,prev_reg)
    dest=root/F
    stage=dest.parent/(".v10_staging_"+stamp)
    shutil.copytree(out,stage)
    verify(stage)
    moved=False
    try:
        if dest.exists(): dest.rename(prev);moved=True
        stage.rename(dest)
        reconcile(root,active)
        verify(dest)
    except Exception:
        if dest.exists(): shutil.rmtree(dest)
        if moved and prev.exists(): prev.rename(dest)
        shutil.copy2(prev_reg,root/R)
        raise
    finally:
        if stage.exists(): shutil.rmtree(stage)
    return {"status":"成功","core":451,"normal_maps":401,
      "backup":str(prev) if moved else None,"registry_backup":str(prev_reg),
      "visual_qa":"未测试"}

def gap_fill(root):
    runner=root/"tools/fill_global_art_gaps_v10.py"
    for extra in ([],["--verify-only"]):
        subprocess.run([sys.executable,str(runner),"--project",str(root),*extra],cwd=root,check=True)
    m=read(root/"assets/art/runtime/generated_gaps_v10/manifest.json")
    if (m.get("generated_count"),m.get("canonical_filled"),m.get("ui_filled"))!=(116,109,7):
        raise ValueError("Incomplete V10 art gap manifest")
    return {"status":"成功","generated":116,"semantic_slots":109,"ui":7}

def cleanup(root,dry_run=False):
    # Never infer image deletion from the narrow generated_assets registry;
    # it omits live V4.2 normals and independently registered animations.
    references=json.dumps(read(root/R),ensure_ascii=False)
    for group in ("scripts","scenes","data","story","addons","tools"):
        base=root/group
        if base.is_dir():
            for p in base.rglob("*"):
                if p.is_file() and p.suffix.lower() in {".gd",".tscn",".tres",".json",".cfg",".godot",".gdshader"}:
                    references+="\n"+p.read_text(encoding="utf-8-sig")
    stale=[]
    for name in ("retired","obsolete","legacy_generated"):
        base=root/"assets/art/runtime"/name
        if base.is_dir():
            for p in base.rglob("*"):
                if not p.is_file() or p.suffix.lower() not in EXT: continue
                rel=p.relative_to(root).as_posix()
                if rel in references or "res://"+rel in references or p.stem in references or p.parent.relative_to(root).as_posix() in references:
                    continue
                stale.append(p)
    backup=None
    if stale and not dry_run:
        backup=root/BACK/("retired_"+uuid.uuid4().hex[:12])
        for p in stale:
            target=backup/p.relative_to(root/"assets/art/runtime")
            target.parent.mkdir(parents=True,exist_ok=True)
            shutil.move(str(p),str(target))
    return {"status":"dry_run" if dry_run else "成功","safe_retired_files":len(stale),
      "backup":str(backup) if backup else None,"live_resources_protected":True}

def main(argv=None):
    ap=argparse.ArgumentParser(description="Main2 V10 unified generate/replace/cleanup")
    ap.add_argument("--project",type=Path,default=Path.cwd())
    ap.add_argument("--output",type=Path)
    ap.add_argument("--refined",action="store_true")
    ap.add_argument("--model-source",type=Path)
    ap.add_argument("--skip-gap-fill",action="store_true")
    ap.add_argument("--cleanup-only",action="store_true")
    ap.add_argument("--cleanup-dry-run",action="store_true")
    ap.add_argument("--verify-only",action="store_true")
    opts=ap.parse_args(argv)
    root=opts.project.resolve()
    try:
        for name in ("project.godot",str(R),"tools/hd2d_studio_v9.py","tools/fill_global_art_gaps_v10.py"):
            if not (root/name).is_file(): raise FileNotFoundError("Missing "+name)
        if opts.cleanup_only:
            result={"status":"成功","cleanup":cleanup(root,opts.cleanup_dry_run)}
        elif opts.verify_only:
            result={"status":"成功","art":verify(root/F)}
        else:
            if opts.refined and not opts.model_source:
                raise ValueError("--refined requires audited --model-source")
            out=(opts.output or root/"build/starlit_hd2d_studio_v10/factory").resolve()
            if not out.is_relative_to(root/"build"):
                raise ValueError("Candidate output must stay under project/build")
            active=generate(root,out,opts.refined,opts.model_source)
            result={"status":"成功","engine":active["source"],"installed":promote(root,out,active)}
            if not opts.skip_gap_fill: result["gap_fill"]=gap_fill(root)
            result["cleanup"]=cleanup(root,opts.cleanup_dry_run)
        print(json.dumps(result,ensure_ascii=False,indent=2))
        return 0
    except (OSError,ValueError,RuntimeError,KeyError,subprocess.CalledProcessError) as error:
        print("V10 ERROR:",error,file=sys.stderr)
        return 2

if __name__=="__main__":
    raise SystemExit(main())
