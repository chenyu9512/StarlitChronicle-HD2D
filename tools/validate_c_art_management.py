#!/usr/bin/env python3
"""Verify source + external + V2 runtime tiers, not a retired 2026-10-26 gallery snapshot."""
import json
from pathlib import Path
from art_migration_validation_v2 import ROOT,migration_index,exists_or_migrated
SUFFIXES={".png",".jpg",".jpeg",".webp",".svg",".gif"}
def read(path):
    return json.loads((ROOT/path).read_text(encoding="utf-8"))
def run():
    gallery=read("data/assets/c_art_catalog.json")
    selection=read("data/assets/c_art_selection.json")
    old_ext=read("data/assets/external_cc0_named_index.json")
    old_originals=read("data/assets/c_art_source_originals.json")
    themes=read("data/assets/art_theme_v2.json")
    migrated=migration_index()
    errors=[]
    entries=[x["id"] for x in gallery["assets"]]
    all_selected=selection["primary"]+selection["reserve_core"]+selection["reserve_external"]
    originals=[x["path"] for x in old_originals["files"]]
    external=[x["id"] for x in old_ext["assets"]]
    if len(entries)!=gallery["count"] or len(entries)!=len(set(entries)) or set(entries)!=set(all_selected):
        errors.append("Gallery tier or selection mismatch")
    if len(originals)!=old_originals["count"] or len(originals)!=len(set(originals)):
        errors.append("Legacy source-original index inconsistent")
    if len(external)!=old_ext["count"] or len(external)!=len(set(external)) or set(external)!=set(selection["reserve_external"]):
        errors.append("External named index inconsistent")
    for p in originals:
        if not p.startswith("assets/art/source_packs/") or not (ROOT/p).is_file():
            errors.append("Missing actual source original: "+p)
    for p in entries:
        if not exists_or_migrated(p,migrated):
            errors.append("Unresolved gallery redirect: "+p)
    for p in external:
        if not (ROOT/p).is_file():
            errors.append("Missing named external image: "+p)
    for t in themes["themes"]:
        for key,slot in t["slots"].items():
            path=slot["source"].removeprefix("res://")
            if not path.startswith("assets/art/runtime/") or not (ROOT/path).is_file():
                errors.append("V2 runtime source absent: "+key)
    if not set(selection["runtime_explicit"]).issubset(set(selection["primary"])):
        errors.append("Runtime priority set not included in primary")
    for p in selection["removed_paths"]:
        if (ROOT/p).exists():
            errors.append("Retired physical file returned: "+p)
    if "ArtOverrides.list_assets()" not in (ROOT/"scripts/art_gallery.gd").read_text(encoding="utf-8"):
        errors.append("Parallel art gallery bypasses central loader")
    for e in errors[:25]:
        print("ERROR:",e)
    print("C-Art current tiers: gallery=%d external=%d source-originals=%d errors=%d; visual QA separate"%(len(entries),len(external),len(originals),len(errors)))
    return int(bool(errors))
if __name__=="__main__":
    raise SystemExit(run())
