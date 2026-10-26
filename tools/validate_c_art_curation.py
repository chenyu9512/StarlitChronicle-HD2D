#!/usr/bin/env python3
"""Verify C-line art selection, gallery coherence, and redundant asset removal."""
import json
from pathlib import Path
R=Path(__file__).resolve().parents[1]
def run():
    d=json.loads((R/"data/assets/c_art_selection.json").read_text("utf-8"))
    c=json.loads((R/"data/assets/c_art_catalog.json").read_text("utf-8"))
    errors=[]
    selected=d["primary"]+d["reserve_core"]+d["reserve_external"]
    registered=[x["id"] for x in c["assets"]]
    if set(selected)!=set(registered) or len(selected)!=len(set(selected)):errors.append("selection and catalog differ")
    if len(registered)!=len(set(registered)) or len(registered)!=c["count"]:errors.append("catalog count/uniqueness")
    for p in selected:
        if not (R/p).is_file():errors.append("missing asset: "+p)
    for p in d["removed_paths"]:
        if (R/p).exists():errors.append("redundant file still exists: "+p)
        if p in registered:errors.append("removed file listed: "+p)
    if not set(d["runtime_explicit"])<=set(d["primary"]):errors.append("runtime path missing from primary")
    for x in errors[:40]:print("FAIL",x)
    print("C art curated:",len(selected),"primary:",len(d["primary"]),"removed:",len(d["removed_paths"]),"errors:",len(errors))
    return int(bool(errors))
if __name__=="__main__":raise SystemExit(run())
