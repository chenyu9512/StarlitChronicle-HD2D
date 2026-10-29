#!/usr/bin/env python3
"""Resolve original logical art IDs to real Main2 third-party physical assets.

Used by repository validators only. Existence here does NOT certify that the
replacement is the right subject, dimensions, animation sheet or visual quality.
"""
from functools import lru_cache
from pathlib import Path
import json

ROOT=Path(__file__).resolve().parents[1]
MIGRATION=ROOT/"data/assets/c_third_party_only_migration_v1.json"

@lru_cache(maxsize=1)
def _mapping():
    if not MIGRATION.is_file():
        return {}
    data=json.loads(MIGRATION.read_text(encoding="utf-8"))
    records={}
    for entry in data.get("mappings",[]):
        old=str(entry.get("old_path",""))
        new=str(entry.get("new_source",""))
        if not old or not new:
            continue
        if old in records:
            raise ValueError("Duplicated old art path: "+old)
        if not new.startswith("assets/art/external/cc0_named_v1/") or ".." in Path(new).parts:
            raise ValueError("Unsafe migrated physical art path: "+old+" -> "+new)
        records[old]=new
    return records

def resolve(logical):
    name=str(logical).removeprefix("res://")
    if Path(name).is_absolute() or ".." in Path(name).parts or not name.startswith("assets/"):
        raise ValueError("Invalid logical art path: "+str(logical))
    physical=ROOT/name
    if physical.is_file():
        return physical
    source=_mapping().get(name)
    if source is None:
        raise FileNotFoundError("Missing original and migrated art: "+name)
    actual=ROOT/source
    if not actual.is_file():
        raise FileNotFoundError("Missing mapped third-party art: "+name+" -> "+source)
    if actual.suffix.lower() not in (".png",".jpg",".jpeg",".webp"):
        raise ValueError("Third-party art must be a physical raster source: "+source)
    return actual

def available(logical):
    try:
        return resolve(logical).is_file()
    except (ValueError,FileNotFoundError):
        return False
