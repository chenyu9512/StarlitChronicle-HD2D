#!/usr/bin/env python3
"""D-line: read-only, evidence-based cross-system audit. Python 3.10+; stdlib only."""
import argparse
from collections import Counter
import json
from pathlib import Path
import re
import sys

EXPECTED = {"chapter": 72, "boss": 66, "map": 40, "job": 20, "side_quest": 120}


def read(root, path):
    return json.loads((root / path).read_text(encoding="utf-8-sig"))


def duplicate_errors(entries, label, field="id"):
    ids = [str(x.get(field, "")) for x in entries]
    return ([f"{label}: missing ID" for x in ids if not x] +
            [f"{label}: duplicate ID {key}" for key, count in Counter(ids).items() if count > 1])


def record(kind, key, source, state, evidence, blockers):
    return {"kind": kind, "id": key, "source": source, "state": state,
            "evidence": evidence, "blockers": blockers}


def audit(root):
    matrix, errors, warnings = [], [], []
    try:
        acts = [read(root, f"story/campaign/act_{n:02d}.json") for n in range(1, 13)]
        prologue = read(root, "story/campaign/prologue.json")
        bosses = read(root, "story/data/bosses.json")["bosses"]
        mechanics = read(root, "data/gameplay/boss_mechanics.json")["entries"]
        layouts = read(root, "data/levels/world_levels_v3.json")["levels"]
        maps = read(root, "data/content/maps.json")["entries"]
        jobs = read(root, "story/data/jobs.json")["jobs"]
        profiles = read(root, "data/gameplay/vocation_profiles.json")["jobs"]
        families = [
            ("story/data/side_quests.json", read(root, "story/data/side_quests.json")["quests"]),
            ("story/data/regional_quests_v2.json", read(root, "story/data/regional_quests_v2.json")["quests"]),
            ("story/data/companion_quests.json", read(root, "story/data/companion_quests.json")["quests"]),
        ]
    except (OSError, ValueError, KeyError, TypeError) as exc:
        return {"status": "FAIL", "errors": [f"Required source invalid: {exc}"],
                "warnings": [], "counts": {}, "matrix": [], "save_review": {}, "resources": {}}

    chapters = [c for a in acts for c in a.get("chapters", [])]
    for label, elements, field in [
        ("chapters", chapters, "id"), ("bosses", bosses, "id"),
        ("boss mechanics", mechanics, "boss_id"), ("maps", maps, "id"), ("jobs", jobs, "id")]:
        errors.extend(duplicate_errors(elements, label, field))
    all_side = []
    for source, quests in families:
        errors.extend(duplicate_errors(quests, source))
        all_side.extend(quests)
    errors.extend(duplicate_errors(all_side, "all side quests"))

    produced = set()
    for scene in prologue.get("scenes", []):
        for effect in scene.get("effects", []):
            if effect.get("type") == "set_flag":
                produced.add(effect.get("key"))
    chapter_ids = {c["id"] for c in chapters}
    for number, c in enumerate(chapters, 1):
        cid = c["id"]
        if cid != f"ch{number:03d}":
            errors.append(f"{cid}: expected ch{number:03d} in sequence")
        missing = set(c.get("required_flags", [])) - produced
        if missing:
            errors.append(f"{cid}: unresolved chapter prerequisites: {sorted(missing)}")
        scenes = c.get("scenes", [])
        errors.extend(duplicate_errors(scenes, f"{cid} scenes"))
        local = set(produced)
        for scene in scenes:
            for req in scene.get("trigger", {}).get("requires_flags", []):
                if req not in local:
                    warnings.append(f"{cid}/{scene.get('id')}: scene flag not statically proven: {req}")
            for effect in scene.get("effects", []):
                if effect.get("type") == "set_flag":
                    local.add(effect.get("key"))
            for option in scene.get("choice", {}).get("options", []):
                local.update(option.get("sets", {}).keys())
        produced.update(local)
        produced.add(c.get("chapter_complete_flag", f"story.{cid}.done"))
        matrix.append(record("chapter", cid, f"story/campaign/act_{c['act']:02d}.json",
                     "authored_runtime_unverified" if scenes else "missing_scenes",
                     {"scene_count": len(scenes), "required_flags": c.get("required_flags", []),
                      "production_status": c.get("production_status")},
                     ["Real traversal and one-time settlement not verified"]))

    boss_by_id = {b["id"]: b for b in bosses}
    mechanics_by_id = {b["boss_id"]: b for b in mechanics}
    for bid, b in boss_by_id.items():
        mech = mechanics_by_id.get(bid)
        if b.get("chapter_id") not in chapter_ids:
            errors.append(f"{bid}: orphan story chapter {b.get('chapter_id')}")
        matrix.append(record("boss", bid, "story/data/bosses.json + data/gameplay/boss_mechanics.json",
                      "mechanics_authored_runtime_unverified" if mech is not None else "story_only",
                      {"story_status": b.get("implementation_status"),
                       "mechanics_status": mech.get("implementation_status") if mech else None,
                       "chapter_id": b.get("chapter_id")},
                      ["Real encounter victory/failure/retry/settlement unverified"]))
    for bid in sorted(set(boss_by_id) ^ set(mechanics_by_id)):
        errors.append(f"Boss story/mechanics ID mismatch: {bid}")

    map_by_id = {m["id"]: m for m in maps}
    for mid, level in sorted(layouts.items()):
        meta = map_by_id.get(mid)
        if meta is None:
            errors.append(f"{mid}: active layout without map catalog entry")
        source = (meta or {}).get("layout_source")
        if source and source.startswith("res://") and not (root / source[6:]).is_file():
            errors.append(f"{mid}: missing layout source {source}")
        matrix.append(record("map", mid, "data/levels/world_levels_v3.json",
                      "layout_present_art_unverified" if meta else "orphan_layout",
                      {"size": level.get("size"), "catalog_status": (meta or {}).get("status"),
                       "art_status": (meta or {}).get("art_status"), "scene_path": (meta or {}).get("scene_path")},
                      ["Scene transition, navigability and mobile render unverified"]))
    if len(maps) != len(layouts):
        warnings.append(f"Map catalog={len(maps)} vs active layouts={len(layouts)}; verify prototype exclusion")

    for job in jobs:
        key = job["id"]
        has_profile = key in profiles
        if not has_profile:
            errors.append(f"{key}: missing vocation profile")
        matrix.append(record("job", key, "story/data/jobs.json + data/gameplay/vocation_profiles.json",
                      "profile_authored_runtime_unverified" if has_profile else "missing_profile",
                      {"catalog_status": job.get("status"), "profile_present": has_profile},
                      ["Unlock/mastery/skill inheritance and old-save regression unverified"]))
    for key in sorted(set(profiles) - {j["id"] for j in jobs}):
        errors.append(f"Orphan vocation profile {key}")

    for source, quests in families:
        for quest in quests:
            key = quest.get("id", "")
            req = quest.get("required_chapter")
            if req and req not in chapter_ids:
                errors.append(f"{key}: orphan required chapter {req}")
            stages = quest.get("stages", [])
            errors.extend(duplicate_errors(stages, f"{key} stages"))
            matrix.append(record("side_quest", key, source,
                        "authored_runtime_unverified" if stages else "missing_stages",
                        {"stages": len(stages), "required_chapter": req,
                         "completion_flag": quest.get("completion_flag")},
                        ["World trigger/choice/reward-once regression not verified"]))

    counts = dict(Counter(x["kind"] for x in matrix))
    for kind, expected in EXPECTED.items():
        if counts.get(kind, 0) != expected:
            errors.append(f"{kind}: expected {expected}; got {counts.get(kind, 0)}")
    save_review = {}
    for name, path in [("v1", "scripts/game_state.gd"),
                       ("v3", "scripts/first_act_state.gd"),
                       ("story_v2", "scripts/story_runtime.gd")]:
        file = root / path
        if not file.is_file():
            errors.append(f"Missing save implementation: {path}")
            continue
        body = file.read_text(encoding="utf-8-sig")
        save_review[name] = {
            "source": path,
            "direct_live_write": bool(re.search(
                r"FileAccess\.open\([^\n]*(?:SAVE_PATH|STORY_SAVE_PATH)\s*,\s*FileAccess\.WRITE", body)),
            "temporary_write_evidence": ".tmp" in body,
            "backup_evidence": "backup_path" in body or ".bak" in body,
            "runtime_compatibility_proven": False}
    if save_review.get("story_v2", {}).get("direct_live_write"):
        warnings.append("P0: story save writes live path directly (crash-truncation risk)")
    resources = {"missing_literal_references": [], "large_assets_over_1mb": []}
    for script in sorted((root / "scripts").glob("*.gd")):
        for relative in re.findall(r'(?:preload|load)\(\s*["\']res://([^"\']+)', script.read_text(encoding="utf-8-sig")):
            if not (root / relative).is_file():
                resources["missing_literal_references"].append(f"{script.relative_to(root)} -> {relative}")
    errors.extend(resources["missing_literal_references"])
    for directory in ("assets",):
        if (root / directory).is_dir():
            for file in (root / directory).rglob("*"):
                if file.is_file() and file.stat().st_size > 1048576:
                    resources["large_assets_over_1mb"].append({
                        "path": str(file.relative_to(root)), "bytes": file.stat().st_size})
    return {"status": "FAIL" if errors else "STATIC_ONLY_NO_RELEASE_CLAIM",
            "expected": EXPECTED, "counts": counts, "errors": errors,
            "warnings": warnings, "save_review": save_review, "resources": resources,
            "matrix": matrix, "godot_test": "NOT_RUN", "mobile_test": "NOT_RUN"}


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--root", type=Path, default=Path(__file__).resolve().parents[2])
    parser.add_argument("--output", type=Path)
    parser.add_argument("--strict", action="store_true")
    args = parser.parse_args()
    report = audit(args.root)
    if args.output:
        args.output.parent.mkdir(parents=True, exist_ok=True)
        args.output.write_text(json.dumps(report, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")
    else:
        print(json.dumps({k: v for k, v in report.items() if k != "matrix"}, ensure_ascii=False, indent=2))
    return 1 if args.strict and report["status"] == "FAIL" else 0


if __name__ == "__main__":
    sys.exit(main())
