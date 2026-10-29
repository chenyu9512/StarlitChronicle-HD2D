#!/usr/bin/env python3
"""Static QA for the first six chapters on the third-party-only art branch.

Usage:
    python tools/audit_act01_third_party_art.py
    python tools/audit_act01_third_party_art.py --require-commercial

The first mode checks actual files, mappings and PNG header geometry.
The strict mode additionally refuses unsigned semantic, scene and Godot gates.
This tool never mutates game assets. It is NOT a substitute for Godot rendering.
"""
from __future__ import annotations

import argparse
import json
import struct
from collections import Counter
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
INDEX = ROOT / "data/assets/c_act01_semantic_rematch_v11.json"
MIGRATION = ROOT / "data/assets/c_third_party_only_migration_v1.json"
RUNTIME = ROOT / "assets/art/runtime/manifest.json"
PREFIX = "res://assets/art/external/cc0_named_v1/"


def source_file(path: str) -> Path:
    if not isinstance(path, str) or not path.startswith("res://"):
        raise ValueError("expected a res:// path")
    relative = Path(path[6:])
    if relative.is_absolute() or ".." in relative.parts:
        raise ValueError("unsafe art source")
    return ROOT / relative


def png_dimensions(path: Path) -> tuple[int, int] | None:
    try:
        with path.open("rb") as stream:
            head = stream.read(24)
        if len(head) != 24 or head[:8] != b"\x89PNG\r\n\x1a\n" or head[12:16] != b"IHDR":
            return None
        return struct.unpack(">II", head[16:24])
    except OSError:
        return None


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--require-commercial", action="store_true",
                        help="fail until visual, layout and Godot QA is signed off")
    args = parser.parse_args()

    catalog = json.loads(INDEX.read_text(encoding="utf-8"))
    migration = json.loads(MIGRATION.read_text(encoding="utf-8"))
    runtime = json.loads(RUNTIME.read_text(encoding="utf-8"))
    if len(catalog.get("chapters", [])) != 6:
        raise ValueError("Act I must have six chapter rows")
    if catalog.get("schema") != "starlit.c.act01.semantic_rematch.v11":
        raise ValueError("unexpected act 1 manifest version")

    redirects = {}
    for item in migration.get("mappings", []):
        old = "res://" + item["old_path"]
        new = "res://" + item["new_source"]
        if old in redirects:
            raise ValueError("duplicate third-party redirect: " + old)
        redirects[old] = new

    defects = []
    semantics = Counter()
    for item in catalog["slots"]:
        old = item["slot"]
        source = item["source"]
        semantics[item["semantic_status"]] += 1
        if item["source_status"] == "source_exists_migrated" and redirects.get(old) != source:
            defects.append("redirect disagreement: " + old)
        if not source.startswith(PREFIX):
            defects.append("runtime image outside named third-party upload: " + source)
            continue
        target = source_file(source)
        if not target.is_file():
            defects.append("missing source: " + source)
            continue
        dims = png_dimensions(target)
        if dims is None:
            defects.append("not a valid PNG source: " + source)
        elif item["semantic_status"] == "atlas_contract_not_verified":
            width, height = dims
            if width < 256 or height < 256 or width % 32 or height % 32:
                defects.append("cannot be a 32px 8x8 atlas: " + source + " size=" + str(dims))
        if old != source and source_file(old).is_file():
            defects.append("retired original art still on the branch: " + old)

    for item in runtime["entries"]:
        old, source = item["path"], item.get("source_path", "")
        if redirects.get(old) != source:
            defects.append("runtime catalog disagrees: " + old)
        if not source.startswith(PREFIX) or not source_file(source).is_file():
            defects.append("runtime source missing: " + old)

    chapters = catalog["chapters"]
    scenes_blocked = [row["chapter"] for row in chapters
                      if row.get("special_scene_blocker") not in ("none", "")]
    for chapter in chapters:
        print("第%s章: %s | 场景=%s | 美术验收=%s" % (
            chapter["chapter"], chapter["title"], chapter.get("special_scene_blocker"),
            chapter.get("atlas_and_semantic_visual_acceptance")))

    print("首幕资源槽=%d; 运行图源=%d; 静态缺陷=%d; 需独立场景的章节=%s" % (
        len(catalog["slots"]), len(runtime["entries"]), len(defects), scenes_blocked))
    if defects:
        print("静态资源检查：未通过")
        for problem in defects[:40]:
            print(" - " + problem)
    else:
        print("静态资源检查：成功")
    print("Godot实际加载/人物动作/碰撞/商业画面验收：未测试")
    if args.require_commercial:
        unaccepted = [s for s in catalog["slots"]
                      if s.get("semantic_status") != "commercial_visual_accepted"]
        if scenes_blocked or unaccepted or defects:
            print("商业级第一幕放行：未通过（缺少角色/场景/图集/画面验收）")
            return 1
    return 1 if defects else 0


if __name__ == "__main__":
    raise SystemExit(main())
