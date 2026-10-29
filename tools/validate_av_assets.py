#!/usr/bin/env python3
"""C-line static coverage and safety audit; PASS means metadata structure only, never commercial QA."""
from __future__ import annotations
import argparse
import json
import struct
from collections import Counter
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
REGISTRY = ROOT / "data/assets/av_registry.json"
EXPECTED = {"regions": 8, "characters": 12, "npcs": 35, "monsters": 63, "bosses": 66, "weapons": 81, "armor": 54, "skills": 63}
ALLOWED_STATUSES = {"not_produced", "procedural_fallback_only", "runtime_bound", "imported", "license_reviewed", "qa_passed"}
SIGS = {".png": b"\x89PNG\r\n\x1a\n", ".ogg": b"OggS", ".wav": b"RIFF"}

def resolved(path: str) -> Path:
    if not path.startswith("res://") or ".." in Path(path[6:]).parts:
        raise ValueError("Unsafe or non-res path: " + path)
    return ROOT / path[6:]

def verify_file(path: str) -> list[str]:
    errors = []
    try:
        file = resolved(path)
    except ValueError as exc:
        return [str(exc)]
    if not file.is_file():
        return ["MISSING: " + path]
    header = file.open("rb").read(32)
    suffix = file.suffix.lower()
    if suffix in SIGS and not header.startswith(SIGS[suffix]):
        errors.append("BAD_HEADER: " + path)
    if suffix == ".png" and len(header) >= 24:
        width, height = struct.unpack(">II", header[16:24])
        if width <= 0 or height <= 0 or width > 16384 or height > 16384:
            errors.append("BAD_DIMENSIONS: " + path)
    if suffix == ".wav" and header[8:12] != b"WAVE":
        errors.append("BAD_WAVE: " + path)
    if file.stat().st_size == 0:
        errors.append("EMPTY: " + path)
    return errors

def audit() -> tuple[dict, list[str]]:
    reg = json.loads(REGISTRY.read_text(encoding="utf-8"))
    issues: list[str] = []
    counts = {}
    for key, expected in EXPECTED.items():
        entries = reg.get(key, [])
        counts[key] = len(entries)
        if len(entries) != expected:
            issues.append(f"COUNT {key}: expected {expected}, got {len(entries)}")
        ids = [item.get("id", "") for item in entries]
        if len(ids) != len(set(ids)) or not all(ids):
            issues.append("DUPLICATE_OR_EMPTY_ID: " + key)
    source = ROOT / "data/content"
    for key in ("regions", "characters", "monsters", "weapons", "armor", "skills"):
        original = json.loads((source / (key + ".json")).read_text(encoding="utf-8"))
        if {x["id"] for x in original["entries"]} != {x["id"] for x in reg[key]}:
            issues.append("CANONICAL_ID_MISMATCH: " + key)
    expected_bosses = [row.split(",", 1)[0].lstrip("\\ufeff") for row in (ROOT / "docs/art_audit/retained_data/boss_encounters_66.csv").read_text(encoding="utf-8-sig").splitlines()[1:] if row.strip()]
    if set(expected_bosses) != {x["id"] for x in reg["bosses"]}:
        issues.append("CANONICAL_ID_MISMATCH: bosses")
    checks = set()
    def check(path: str):
        if path and path not in checks:
            checks.add(path)
            issues.extend(verify_file(path))
    for r in reg["regions"]:
        for p in r["existing_tiles"]:
            check(p)
    for c in reg["characters"]:
        check(c["portrait_path"])
        check(c["fullbody_path"])
        check(c["existing_legacy_walk_path"])
    b02 = json.loads((ROOT / "assets/art/b02/MANIFEST.json").read_text(encoding="utf-8"))
    canonical_npc_ids = {item["id"] for item in b02["records"] if item["group"] != "main"}
    if canonical_npc_ids != {x["id"] for x in reg["npcs"]}:
        issues.append("B02_NPC_ID_MISMATCH")
    for npc in reg["npcs"]:
        check(npc["portrait_path"])
        check(npc["fullbody_path"])
    for b in reg["bosses"]:
        check(b["static_battle_path"])
    for m in reg["legacy_monster_prototypes"]:
        check(m["battle_path"])
        check(m["idle_path"])
    audio = reg.get("audio_events", [])
    ids = [x.get("id", "") for x in audio]
    if len(set(ids)) != len(ids):
        issues.append("DUPLICATE_AUDIO_ID")
    audio_state = Counter()
    for a in audio:
        audio_state[a.get("status", "unknown")] += 1
        if a.get("status") not in ALLOWED_STATUSES:
            issues.append("UNKNOWN_AUDIO_STATUS: " + str(a.get("id")))
        path = a.get("asset_path", "")
        if path:
            if not path.startswith("res://assets/audio/"):
                issues.append("NON_AUDIO_PATH: " + str(a.get("id")))
            check(path)
            if a.get("status") in ("runtime_bound", "qa_passed", "license_reviewed") and a.get("license_status") != "commercial_verified":
                issues.append("UNVERIFIED_LICENSE: " + str(a.get("id")))
        elif a.get("status") in ("imported", "runtime_bound", "license_reviewed", "qa_passed"):
            issues.append("MISSING_REAL_AUDIO: " + str(a.get("id")))
    for link in reg["event_bridge"]["mappings"]:
        aid = link["audio_id"]
        if ".by_" not in aid and aid not in ids:
            issues.append("MISSING_EVENT_AUDIO_ID: " + aid)
    report = {"schema": reg["schema"], "static_checks_only": True, "counts": counts,
              "audio": {"total": len(audio), "statuses": dict(audio_state), "imported_files": sum(bool(x.get("asset_path")) for x in audio)},
              "verified_declared_file_paths": len(checks),
              "commercial_qa_passed": False, "issues": issues}
    return report, issues

if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--json", action="store_true")
    args = parser.parse_args()
    result, errors = audit()
    if args.json:
        print(json.dumps(result, ensure_ascii=False, indent=2))
    else:
        print(f"AV inventory: {result['counts']}; checked files: {result['verified_declared_file_paths']}")
        for issue in errors:
            print("ERROR", issue)
        print("STATIC MANIFEST:", "FAIL" if errors else "PASS", "/ commercial QA: NOT RUN")
    raise SystemExit(1 if errors else 0)
