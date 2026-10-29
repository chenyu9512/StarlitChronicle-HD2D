#!/usr/bin/env python3
"""Remove manually imported/third-party images from Main2 after generating replacements.

The replacement generator is run by the online GitHub Actions job BEFORE this
script. Everything in assets/art outside explicitly authored or generator-owned
live directories is retired. Files are removed from the Git working tree and
the job commits them as one online branch change. No developer PC is involved.
"""
from __future__ import annotations
import argparse
import hashlib
import json
from pathlib import Path
from PIL import Image

KEEP = (
    "assets/art/runtime/global_factory_v3/",
    "assets/art/runtime/content_icons_v1/",
    "assets/art/runtime/boss_motion_v1/",
    "assets/art/runtime/shore_waves_v1/",
    "assets/art/runtime/scene_details_v1/",
)
IMAGES = {".png",".jpg",".jpeg",".webp",".svg",".bmp",".gif",".tga"}
OLD_MANIFESTS = (
    "assets/art/runtime/manifest.json",
    "assets/art/art_manifest.json",
)
PURGE_INDEX = {
    "data/assets/external_cc0_named_index.json",
    "data/assets/c_third_party_only_migration_v1.json",
    "data/assets/c_art_usage_external_v12.json",
    "data/assets/c_art_usage_source_v12.json",
    "data/assets/c_art_source_originals.json",
    "data/assets/c_act01_source_blob_provenance_v1.json",
}

def relative(path: Path, root: Path) -> str:
    return path.relative_to(root).as_posix()

def allowed_image(path: str) -> bool:
    return any(path.startswith(p) for p in KEEP)

def read(path: Path) -> dict:
    return json.loads(path.read_text(encoding="utf-8-sig"))

def purge(root: Path) -> dict:
    root = root.resolve()
    image_root = root / "assets/art"
    active = read(root / "assets/art/runtime/global_factory_v3/active.json")
    if active.get("schema") != "starlit.global_factory.live.v3" or not active.get("enabled"):
        raise RuntimeError("Refusing to delete without verified active generator images")
    if int(active.get("asset_count",0)) < 451:
        raise RuntimeError("Generator did not cover 451 required canonical objects")
    for row in active["assets"].values():
        p = root / row["path"].removeprefix("res://")
        if not p.is_file() or not allowed_image(relative(p, root)):
            raise RuntimeError("Missing generated replacement: " + str(p))
        if hashlib.sha256(p.read_bytes()).hexdigest() != row["sha256"]:
            raise RuntimeError("Regenerated image checksum mismatch: " + str(p))
    icons = read(root / "assets/art/runtime/content_icons_v1/manifest.json")
    if icons.get("count") != 288:
        raise RuntimeError("Must regenerate 288 first-party content pictograms")
    if any("source_pictogram" in row or "owlish" in str(row).lower()
           for row in icons["assets"].values()):
        raise RuntimeError("Generated content icons still depend on third-party drawings")
    for row in icons["assets"].values():
        p = root / str(row["source"]).removeprefix("res://")
        if not p.is_file():
            raise RuntimeError("Missing newly drawn icon: " + str(p))
        if hashlib.sha256(p.read_bytes()).hexdigest() != row["sha256"]:
            raise RuntimeError("Content icon checksum mismatch")
    for expected,manifest in ((66,"boss_motion_v1"),(8,"shore_waves_v1")):
        info=read(root / f"assets/art/runtime/{manifest}/manifest.json")
        if info.get("count") != expected:
            raise RuntimeError(f"Generated {manifest} is incomplete")
    details=read(root / "assets/art/runtime/scene_details_v1/manifest.json")
    if details.get("source") != "new_original_vector_art":
        raise RuntimeError("Scene details provenance is not native original art")

    removed = []
    removed_image_count = 0
    for p in sorted(image_root.rglob("*")):
        if not p.is_file():
            continue
        rel = relative(p,root)
        if allowed_image(rel):
            continue
        if p.suffix.lower() in IMAGES:
            removed_image_count += 1
        p.unlink()
        removed.append(rel)
    if not removed:
        raise RuntimeError("Nothing purged; review whether the online branch was already cleaned")
    if not any(p.startswith("assets/art/external/") for p in removed):
        raise RuntimeError("Expected imported third-party images were not found")
    stale = set(removed)
    # Supersede obsolete import & backup indexes, not the game's canonical
    # campaign, quests, map footprints, NPC IDs or combat state.
    for path in OLD_MANIFESTS:
        p=root/path
        if p.exists():
            p.unlink()
    indexes=[]
    for path in sorted(PURGE_INDEX):
        p=root/path
        if p.exists():
            p.unlink()
            indexes.append(path)
    # Replace remaining historical material-path references in asset metadata.
    # Preserve schemas, IDs and structure; removed external files never remain
    # visible as active/reserve allocations or source entries.
    sanitized={}
    def scrub(value):
        if isinstance(value,str):
            raw=value.removeprefix("res://")
            if raw in stale or raw.startswith(("assets/art/external/","assets/art/source_packs/")):
                return ""
            return value
        if isinstance(value,list):
            return [scrub(x) for x in value if not (
                isinstance(x,dict) and isinstance(x.get("source_path"),str)
                and x.get("source_path","").removeprefix("res://") in stale)]
        if isinstance(value,dict):
            return {k:scrub(v) for k,v in value.items()
                    if str(k).removeprefix("res://") not in stale}
        return value
    for p in sorted((root/"data/assets").glob("*.json")):
        doc=read(p)
        changed=scrub(doc)
        name=relative(p,root)
        if name.endswith("c_art_selection.json"):
            for key in ("primary","runtime_explicit","reserve_core","reserve_external"):
                if key in changed and isinstance(changed[key],list):
                    changed[key]=[]
            if "summary" in changed:
                changed["summary"]={"third_party_assets":0,"status":"purged_generated_only"}
        if name.endswith("c_art_catalog.json"):
            changed["assets"]=[]
            changed["replaced_by"]="res://assets/art/runtime/global_factory_v3/active.json"
        if name.endswith("c_art_packs.json"):
            changed["packs"]=[]
            changed["readme"]="Imported third-party DLC packs purged. Generator is authoritative."
        if name.endswith("c_art_runtime_registry_v1.json"):
            changed["verified_legacy_redirects"]={}
            changed["source_candidate_pool"]={}
            changed["sources"]={k:v for k,v in changed.get("sources",{}).items()
                                if isinstance(k,str) and allowed_image(k.removeprefix("res://"))}
        original=json.dumps(doc,ensure_ascii=False,sort_keys=True)
        updated=json.dumps(changed,ensure_ascii=False,sort_keys=True)
        if updated!=original:
            p.write_text(json.dumps(changed,ensure_ascii=False,indent=2)+"\n",encoding="utf-8")
            sanitized[name]=True
    # Old explicit third-party assignments outside data/assets cannot remain
    # authoritative; retain logs/docs for traceability, not runtime selection.
    kept=[relative(p,root) for p in image_root.rglob("*")
          if p.is_file() and p.suffix.lower() in IMAGES]
    if any(not allowed_image(p) for p in kept):
        raise RuntimeError("External image remains after purge")
    proof={"schema":"starlit.generator_only.online_purge.v1",
           "branch":"Main2美术优化版",
           "policy":"no user-uploaded or imported third-party imagery retained",
           "removed_image_count":removed_image_count,
           "removed_legacy_files_total":len(removed),
           "removed_images":removed,
           "purged_source_indexes":indexes,
           "sanitized_registry_files":sorted(sanitized),
           "generated_canonical_assets":active["asset_count"],
           "new_original_content_icons":icons["count"],
           "generated_boss_motion_sheets":66,
           "generated_shore_wave_sheets":8,
           "retained_generated_or_original_images":len(kept),
           "visual_acceptance":"not_tested"}
    out=root/"docs/audits/MAIN2_GENERATOR_ONLY_PURGE.json"
    out.parent.mkdir(parents=True,exist_ok=True)
    out.write_text(json.dumps(proof,ensure_ascii=False,indent=2)+"\n",encoding="utf-8")
    return proof

if __name__=="__main__":
    ap=argparse.ArgumentParser()
    ap.add_argument("--project",type=Path,default=Path(__file__).resolve().parents[1])
    args=ap.parse_args()
    x=purge(args.project)
    print(json.dumps({k:v for k,v in x.items() if k!="removed_images"},
                     ensure_ascii=False,indent=2))
