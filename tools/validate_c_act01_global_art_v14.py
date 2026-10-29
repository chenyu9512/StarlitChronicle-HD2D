#!/usr/bin/env python3
"""Act I global art distribution: verify real sources, exact SHA aliases, map coverage."""
import hashlib
import json
from pathlib import Path

root = Path(__file__).resolve().parent.parent
manifest = json.loads((root / "data/assets/c_act01_global_distribution_v14.json").read_text("utf-8"))
assert manifest["schema"] == "starlit.c.act01_global_distribution.v14"
rows = manifest["source_index"]
assert len(rows) == manifest["counts"]["source_files"]
assert len({r["source"] for r in rows}) == len(rows)
# Several reused originals intentionally have more than one authored runtime alias.
# Count all distinct export paths rather than counting source records (which are deduplicated).
runtime_manifest = manifest["runtime"]
def paths_of(obj):
    if isinstance(obj, str):
        return {obj} if obj.startswith("res://assets/art/runtime/act01_global_v14/") else set()
    if isinstance(obj, dict):
        return set().union(*(paths_of(v) for v in obj.values())) if obj else set()
    if isinstance(obj, list):
        return set().union(*(paths_of(v) for v in obj)) if obj else set()
    return set()
runtime_paths = paths_of(runtime_manifest)
assert len(runtime_paths) == manifest["counts"]["physical_aliases"]
# The migration index predates an archive cleanup. Keep its original count
# and source IDs for provenance, but reject actual missing art independently
# from removable Finder/WebDAV ZIP metadata. Never relax an image check.
def is_archive_metadata(source):
    path = Path(source)
    return ("__MACOSX" in path.parts or "._DAV" in path.parts or
        path.name == ".DS_Store" or path.name.startswith("._"))

real_sources = [row for row in rows if not is_archive_metadata(row["source"])]
source_shas = {r["sha"] for r in real_sources}
assert set(manifest["maps"]) == {f"map_coast_{i:02d}" for i in range(1,6)}
assert set(c["chapter"] for c in manifest["chapter_routes"]) == set(range(1,7))
for row in rows:
    source = root / row["source"]
    if is_archive_metadata(row["source"]):
        # These Finder-generated sidecars were explicitly removed from Main2;
        # retaining their historic SHA references must not block Runtime.
        assert not source.exists(), f"Obsolete macOS archive metadata still tracked: {source}"
        continue
    assert source.is_file(), f"Missing real art/source: {source}"
for path in sorted(runtime_paths):
    target = root / path.removeprefix("res://")
    assert target.is_file(), f"Missing imported runtime: {target}"
    blob = target.read_bytes()
    checksum = hashlib.sha1(b"blob " + str(len(blob)).encode("ascii") + b"\x00" + blob).hexdigest()
    assert checksum in source_shas, f"Runtime image does not match a source Git blob: {target}"
for section in ["props", "scenery", "monsters", "boss_candidates"]:
    for name,path in manifest["runtime"][section].items():
        assert (root / path.removeprefix("res://")).is_file(), (section,name)
print(f"PASS: Act I {len(real_sources)} actual sources, {len(rows)-len(real_sources)} retired OS sidecars, runtime aliases, chapter/map coverage and image SHA integrity.")
