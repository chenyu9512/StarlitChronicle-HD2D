#!/usr/bin/env python3
"""Validate real Main2 source masters, redirect-only legacy runtime, and DLC references."""
import json
from pathlib import Path
from art_migration_validation_v2 import ROOT,migration_index,exists_or_migrated

def read(p):
    return json.loads((ROOT/p).read_text(encoding="utf-8"))
def validate():
    mapping=migration_index()
    art=ROOT/"assets/art"
    assert (art/"source_packs/.gdignore").is_file()
    assert (art/"candidates/.gdignore").is_file()
    candidates=read("assets/art/candidates/manifest.json")
    rows=candidates["entries"]
    assert len(rows)==candidates["images"] and len(rows)>=746
    originals=read("data/assets/c_art_source_originals.json")
    original_paths={"res://"+x["path"] for x in originals["files"]}
    candidate_paths={x["source"] for x in rows}
    assert len(original_paths)==originals["count"] and candidate_paths==original_paths
    for row in rows:
        assert exists_or_migrated(row["source"],mapping), row["source"]
        assert row["runtime_binding"] is None
    runtime=read("assets/art/runtime/manifest.json")["entries"]
    assert len(runtime)>=101
    for record in runtime:
        slot=record["path"]
        if not exists_or_migrated(slot,mapping):
            assert exists_or_migrated(record.get("source_path",""),mapping), "Unresolved runtime alias: "+slot
            assert record.get("load_contract")=="CArtOverrides.texture(legacy_slot)", slot
    slots={x["path"] for x in read("data/assets/c_art_catalog.json")["assets"]}
    packs=read("data/assets/c_art_packs.json")["packs"]
    ids=set()
    for pack in packs:
        assert pack["id"] not in ids
        ids.add(pack["id"])
        targets=set()
        for pair in pack["mappings"]:
            assert pair["target"] in slots and pair["target"] not in targets
            targets.add(pair["target"])
            assert exists_or_migrated(pair["source"],mapping), "DLC source absent: "+pair["source"]
    print("PASS: %d source masters, %d traced runtime aliases, %d DLC presets; migration identity and visual QA distinct"%(len(rows),len(runtime),len(packs)))
if __name__=="__main__":
    validate()
