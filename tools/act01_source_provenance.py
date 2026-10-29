#!/usr/bin/env python3
"""Verify retained Act I PNG bytes against immutable historical Git blob IDs.

Main2 intentionally deleted the bulky source_packs directory. Runtime
artwork still has a verifiable origin in commit 9dffb854... . This helper
refuses altered runtime bytes even when their historical source no longer
exists in this checkout. Passing byte provenance never implies visual QA.
"""
from __future__ import annotations

import hashlib
import json
from functools import lru_cache
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
MANIFEST = ROOT / "data/assets/c_act01_source_blob_provenance_v1.json"
SOURCE_COMMIT = "9dffb854fd6f0461805440061c5cd5d5e8838df4"
PNG_HEADER = b"\x89PNG\r\n\x1a\n"


def git_blob_sha(blob: bytes) -> str:
    return hashlib.sha1(b"blob " + str(len(blob)).encode("ascii") + b"\x00" + blob).hexdigest()


@lru_cache(maxsize=1)
def registry() -> dict:
    data = json.loads(MANIFEST.read_text(encoding="utf-8"))
    if data.get("schema") != "starlit.act01.source_blob_provenance.v1":
        raise ValueError("Act I provenance schema changed")
    if data.get("source_commit") != SOURCE_COMMIT:
        raise ValueError("Act I historic source commit mismatch")
    if not isinstance(data.get("runtime"), dict) or len(data["runtime"]) != 79:
        raise ValueError("Act I 79-source provenance incomplete")
    return data["runtime"]


def verify_art(relative_path: str | Path, expected_original: str | Path | None = None) -> dict:
    relative = Path(relative_path)
    if relative.is_absolute() or ".." in relative.parts:
        raise ValueError("Invalid art path: " + str(relative_path))
    name = relative.as_posix()
    entry = registry().get(name)
    if entry is None:
        raise ValueError("Unregistered Act I source identity: " + name)
    origin = str(entry.get("original_source", ""))
    if not origin.startswith("assets/art/source_packs/") or ".." in Path(origin).parts:
        raise ValueError("Untrusted original art path: " + name)
    if expected_original is not None and Path(expected_original).as_posix() != origin:
        raise ValueError("Wrong historical object assigned to " + name)
    expected = str(entry.get("git_blob_sha", ""))
    if len(expected) != 40 or any(c not in "0123456789abcdef" for c in expected):
        raise ValueError("Invalid pinned Git blob: " + name)
    target = ROOT / relative
    if not target.is_file():
        raise ValueError("Missing real runtime image: " + name)
    blob = target.read_bytes()
    if not blob.startswith(PNG_HEADER) or len(blob) < 24:
        raise ValueError("Invalid runtime PNG: " + name)
    actual = git_blob_sha(blob)
    if actual != expected:
        raise ValueError("Runtime image differs from historic source Git blob: " + name)
    original = ROOT / origin
    if original.is_file() and original.read_bytes() != blob:
        raise ValueError("Present original art does not match runtime source: " + name)
    return {"path": name, "original": origin, "sha": actual, "bytes": len(blob)}


def verify_registry() -> dict:
    valid = [verify_art(path) for path in sorted(registry())]
    return {"source_commit": SOURCE_COMMIT, "verified_pngs": len(valid),
            "visual_acceptance": "not_tested"}


if __name__ == "__main__":
    print(json.dumps(verify_registry(), ensure_ascii=False))
