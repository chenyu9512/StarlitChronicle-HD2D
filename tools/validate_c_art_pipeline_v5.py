#!/usr/bin/env python3
"""C-line V5 art stages / DLC mapping validation, read-only. Python 3.10+."""
from __future__ import annotations
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
ART = ROOT / "assets/art"
PACK_INDEX = ROOT / "data/assets/c_art_packs.json"
CATALOG = ROOT / "data/assets/c_art_catalog.json"
CANDIDATES = ART / "candidates/manifest.json"
RUNTIME = ART / "runtime/manifest.json"

def load(path: Path) -> dict:
    with path.open("r", encoding="utf-8") as fh:
        value = json.load(fh)
    assert isinstance(value, dict), f"JSON document is not an object: {path}"
    return value

def res_path(name: str) -> Path:
    assert name.startswith("res://assets/"), f"Unsafe game asset path: {name}"
    relative = name[6:]
    assert ".." not in Path(relative).parts
    return ROOT / relative

def validate() -> None:
    assert not (ART / "备份区").exists(), "Unmigrated old backup directory"
    assert not (ART / "external/imported").exists(), "Uncleaned duplicate import directory"
    candidates = load(CANDIDATES)
    files = candidates["entries"]
    assert len(files) == candidates["images"], "Candidate manifest count mismatch"
    assert len(files) >= 756, "Source pack candidates missing"
    names = set()
    for row in files:
        path = res_path(row["source"])
        assert path.is_file(), f"Candidate source missing: {path}"
        assert str(path).find("/source_packs/") >= 0 or "source_packs" in path.parts
        assert row["source"] not in names, "Candidate has duplicate path"
        names.add(row["source"])
        assert row["runtime_binding"] is None, "Candidate was bound without a review"
    runtime = load(RUNTIME)["entries"]
    for record in runtime:
        assert res_path(record["path"]).is_file(), f"Runtime image missing: {record['path']}"
    catalog = load(CATALOG)
    slots = {row["path"] for row in catalog["assets"]}
    packs = load(PACK_INDEX)["packs"]
    seen_pack_ids = set()
    assert packs, "No art DLC theme available"
    for pack in packs:
        pid = pack["id"]
        assert pid not in seen_pack_ids, "Duplicate DLC id"
        seen_pack_ids.add(pid)
        targets = set()
        for row in pack["mappings"]:
            assert row["target"] in slots, f"Unregistered runtime DLC slot: {row['target']}"
            assert row["target"] not in targets, f"Duplicate DLC target: {row['target']}"
            targets.add(row["target"])
            assert res_path(row["source"]).is_file(), f"DLC source missing: {row['source']}"
    assert len(runtime) >= 101
    print(f"SUCCESS: {len(files)} candidates, {len(runtime)} runtime paths, {len(packs)} themes, {sum(len(p['mappings']) for p in packs)} DLC mappings")

if __name__ == "__main__":
    validate()
