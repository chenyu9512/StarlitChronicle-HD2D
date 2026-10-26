#!/usr/bin/env python3
"""One-source-of-truth check for C art. Static only, not a Godot visual test."""
import json
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
EXT={".png",".jpg",".jpeg",".webp",".svg"}
def run():
    c=json.loads((ROOT/"data/assets/c_art_catalog.json").read_text(encoding="utf-8"))
    s=json.loads((ROOT/"data/assets/c_art_selection.json").read_text(encoding="utf-8"))
    e=json.loads((ROOT/"data/assets/external_cc0_named_index.json").read_text(encoding="utf-8"))
    error=[]
    found={p.relative_to(ROOT).as_posix() for p in (ROOT/"assets").rglob("*") if p.is_file() and p.suffix.lower() in EXT}
    registered=[v.get("id","") for v in c.get("assets",[])]
    selection=s["primary"]+s["reserve_core"]+s["reserve_external"]
    external=[v.get("id","") for v in e.get("assets",[])]
    if set(found)!=set(registered):error.append("Gallery does not match files: missing=%d stale=%d"%(len(found-set(registered)),len(set(registered)-found)))
    if len(registered)!=len(set(registered)) or len(registered)!=c["count"]:error.append("Gallery count/duplicates")
    if len(selection)!=len(set(selection)) or set(selection)!=set(registered):error.append("Selection differs from gallery")
    if len(external)!=len(set(external)) or len(external)!=e["count"]:error.append("External index count/duplicates")
    if set(external)!=set(s["reserve_external"]):error.append("External index differs from gallery's external reserve tier")
    if not set(s["runtime_explicit"]).issubset(set(s["primary"])):error.append("Runtime set differs from primary")
    for path in s["removed_paths"]:
        if (ROOT/path).exists():error.append("Old asset returned: "+path)
    obsolete=[ROOT/"data/assets/external_cc0_20261026_staging.json",*(ROOT/"data/assets/external_art_uploads").glob("*.json")]
    for p in obsolete:
        if p.exists():error.append("Retired manifest still active: "+p.as_posix())
    if "ArtOverrides.list_assets()" not in (ROOT/"scripts/art_gallery.gd").read_text(encoding="utf-8"):error.append("Developer gallery uses parallel manifest")
    for issue in error[:50]:print("ERROR:",issue)
    print("C-Art static audit: %d registered, %d external, errors=%d; Godot runtime untested"%(len(registered),len(external),len(error)))
    return int(bool(error))
if __name__=="__main__":raise SystemExit(run())
