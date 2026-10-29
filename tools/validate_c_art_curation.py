#!/usr/bin/env python3
"""Validate legacy gallery identity after explicit, tracked Main2 source migration."""
import json
from pathlib import Path
from art_migration_validation_v2 import ROOT, migration_index, exists_or_migrated

def run():
    data=json.loads((ROOT/"data/assets/c_art_selection.json").read_text(encoding="utf-8"))
    gallery=json.loads((ROOT/"data/assets/c_art_catalog.json").read_text(encoding="utf-8"))
    mapping=migration_index()
    entries=data["primary"]+data["reserve_core"]+data["reserve_external"]
    registered=[v["id"] for v in gallery["assets"]]
    errors=[]
    if len(entries)!=len(set(entries)) or set(entries)!=set(registered):
        errors.append("Selection and catalog identities disagree")
    if len(registered)!=len(set(registered)) or len(registered)!=gallery["count"]:
        errors.append("Gallery has duplicate IDs or wrong count")
    for p in entries:
        if not exists_or_migrated(p,mapping):
            errors.append("Unresolved legacy record: "+p)
    for p in data["removed_paths"]:
        if (ROOT/p).exists() or p in registered:
            errors.append("Explicitly retired file returned: "+p)
    if not set(data["runtime_explicit"]).issubset(set(data["primary"])):
        errors.append("Runtime priority set differs from primary")
    for x in errors[:30]:
        print("FAIL:",x)
    print("C art curation: %d gallery records, %d migration redirects, %d unresolved"%(len(entries),len(mapping),len(errors)))
    return int(bool(errors))
if __name__=="__main__":
    raise SystemExit(run())
