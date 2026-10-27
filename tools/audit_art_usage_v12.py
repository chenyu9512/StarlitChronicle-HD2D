#!/usr/bin/env python3
"""Audit C-line V12 asset distribution without deleting or modifying assets.

    python tools/audit_art_usage_v12.py
    python tools/audit_art_usage_v12.py --verify-git-blobs
    python tools/audit_art_usage_v12.py --require-commercial

A passing static inventory means all tracked PNG paths are allocated to explicit
technical groups; it does NOT mean those pictures are used in playable scenes.
"""
from __future__ import annotations

import argparse
import hashlib
import json
from collections import Counter
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
SOURCE_PREFIX = "assets/art/source_packs/"
NAMED_PREFIX = "assets/art/external/cc0_named_v1/"
SOURCES = "data/assets/c_art_usage_source_v12.json"
EXTERNAL = "data/assets/c_art_usage_external_v12.json"
SIDECARS = "data/assets/c_art_nonimage_groups_v12.json"
GROUPS = "data/assets/c_art_group_contracts_v12.json"
MIGRATION = "data/assets/c_third_party_only_migration_v1.json"
ACT1 = "data/assets/c_act01_semantic_rematch_v11.json"
ICONS = "data/assets/c_art_content_icons_v6.json"
DRESSING = "data/assets/c_art_live_coast_v7.json"


def load(filename: str) -> dict:
    return json.loads((ROOT / filename).read_text(encoding="utf-8"))


def path_for_res(source: str) -> Path:
    if not source.startswith("res://"):
        raise ValueError("not a res path: " + source)
    relative = Path(source[6:])
    if relative.is_absolute() or ".." in relative.parts:
        raise ValueError("invalid res path: " + source)
    return ROOT / relative


def git_blob_sha(path: Path) -> str:
    payload = path.read_bytes()
    return hashlib.sha1(b"blob " + str(len(payload)).encode("ascii") + b"\0" + payload).hexdigest()


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--verify-git-blobs", action="store_true",
                    help="hash every actual asset and compare its Git object SHA")
    ap.add_argument("--require-commercial", action="store_true",
                    help="enforce independent Godot and semantic release gates")
    args = ap.parse_args()
    src, ext, side, groups = (load(x) for x in (SOURCES, EXTERNAL, SIDECARS, GROUPS))
    redirect, act1 = (load(x) for x in (MIGRATION, ACT1))
    icons, scene = (load(x) for x in (ICONS, DRESSING))
    defects: list[str] = []
    src_rows, ext_rows, side_rows = src["rows"], ext["rows"], side["records"]
    all_rows = src_rows + ext_rows + side_rows

    def fail(detail: str) -> None:
        defects.append(detail)

    for label, rows, expected in (
        ("original PNG", src_rows, 746),
        ("named runtime PNG", ext_rows, 667),
        ("non-PNG source", side_rows, 104),
    ):
        if len(rows) != expected:
            fail(f"{label}: {len(rows)} rows expected {expected}")
    seen: set[str] = set()
    for row in all_rows:
        path = row["source"]
        if path in seen:
            fail("duplicate assigned source: " + path)
        seen.add(path)
        real = path_for_res(path)
        if not real.is_file():
            fail("missing physical file: " + path)
        elif args.verify_git_blobs and git_blob_sha(real) != row.get("source_sha", row.get("sha")):
            fail("SHA mismatch: " + path)
        if row["group_id"].startswith("source/"):
            if not path[6:].startswith(SOURCE_PREFIX):
                fail("invalid source custody: " + path)
        elif row["group_id"].startswith("external/"):
            if not path[6:].startswith(NAMED_PREFIX):
                fail("invalid named import custody: " + path)
        else:
            fail("invalid group: " + row["group_id"])

    for prefix, filter_suffix in ((SOURCE_PREFIX, ".png"), (NAMED_PREFIX, ".png")):
        for file in (ROOT / prefix).rglob("*"):
            if not file.is_file():
                continue
            if file.name == ".gdignore":
                continue
            if prefix == SOURCE_PREFIX or file.suffix.lower() == filter_suffix:
                asset = "res://" + file.relative_to(ROOT).as_posix()
                if asset not in seen:
                    fail("unassigned file: " + asset)
    groups_seen = Counter(row["group_id"] for row in all_rows)
    contracts = {group["id"]: group for group in groups["groups"]}
    if set(groups_seen) != set(contracts):
        fail("group contracts do not match asset families")
    for group_id, count in groups_seen.items():
        info = contracts.get(group_id, {})
        bound = (info.get("source_images", 0) + info.get("external_images", 0)
                 + info.get("archives", 0) + info.get("other_sources", 0))
        if bound != count:
            fail("group size disagrees: " + group_id)
    if sum(r["format"] == "zip" for r in side_rows) != 85:
        fail("85 source archives were not preserved in source inventory")
    if any(r.get("runtime_bound") for r in src_rows + side_rows):
        fail("source-only originals must not claim scene-level runtime use")
    if len(icons.get("records", [])) != 288:
        fail("UI item icon binding count changed unexpectedly")
    live_icons = {r["icon"] for r in icons["records"]}
    live_decor = {r["source"] for r in scene["placements"]}
    if len(live_icons) != 28 or len(live_decor) != 7:
        fail("old explicit UI/decor wiring changed; review new active usages")
    statuses = Counter(r["status"] for r in ext_rows)
    for key, expected in (
        ("runtime_registry_referenced_pending_godot_qa", 28),
        ("runtime_scene_manifest_referenced_pending_godot_qa", 7),
        ("legacy_redirect_used_semantic_review_required", 50),
        ("allocated_staged_unbound", 582),
    ):
        if statuses[key] != expected:
            fail(f"{key}: expected {expected}, got {statuses[key]}")
    for row in ext_rows:
        if row["status"] == "runtime_registry_referenced_pending_godot_qa" and row["source"] not in live_icons:
            fail("false UI-binding status: " + row["source"])
        if row["status"] == "runtime_scene_manifest_referenced_pending_godot_qa" and row["source"] not in live_decor:
            fail("false scenery-binding status: " + row["source"])
    if len(redirect["mappings"]) != 616:
        fail("legacy migration coverage changed unexpectedly")
    if len(act1["chapters"]) != 6 or len(act1["slots"]) != 125:
        fail("first-act gate incomplete")
    blocked = [str(c["chapter"]) for c in act1["chapters"]
               if c.get("special_scene_blocker") not in ("", "none")]
    print("C线V12静态分配：源图 %d；第三方命名图 %d；原档/辅助文件 %d（ZIP %d）" % (
        len(src_rows), len(ext_rows), len(side_rows), sum(r["format"] == "zip" for r in side_rows)))
    print("素材组 %d；显式UI图 %d；显式场景装饰图 %d；仅旧映射关联图 %d；候选未接入图 %d" % (
        len(groups_seen), len(live_icons), len(live_decor),
        statuses["legacy_redirect_used_semantic_review_required"], statuses["allocated_staged_unbound"]))
    print("第一幕尚缺独立场景的章节：" + (", ".join(blocked) or "无"))
    print("Godot导入、可见性、资源尺寸、动作帧、场景画质：未测试")
    if args.require_commercial:
        if blocked or any(c.get("commercial_art_gate") != "passed" for c in act1["chapters"]):
            fail("commercial sign-off cannot pass while Act I scenes or visual QA are incomplete")
        if any(r.get("commercial_visual_acceptance") != "passed" for r in ext_rows):
            fail("unreviewed external images cannot be commercially signed off as a complete package")
    if defects:
        print("检查失败，共 %d 处；前40条：" % len(defects))
        for detail in defects[:40]:
            print("  - " + detail)
        return 1
    print("文件/分组/显式引用静态核对通过；不代表游戏已完成。")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
