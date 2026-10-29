#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""非破坏性的全72章正典索引校核与支线目录生成器。

默认只生成 story/runtime/side_content_catalog.json。
可选 --compile-campaign 调用仓库既有 build_and_validate_story.py，
绝不覆写 story/campaign/act_*.json，不创建 Godot 主场景，不自动 git push。
"""
import argparse
import json
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
CAMPAIGN = ROOT / "story" / "campaign"
DATA = ROOT / "story" / "data"
OUT = ROOT / "story" / "runtime" / "side_content_catalog.json"
QUEST_SOURCES = (
    ("original", "side_quests.json", 36),
    ("companion", "companion_quests.json", 48),
    ("regional", "regional_quests_v2.json", 36),
)
REQUIRED_STAGES = ("opening", "investigate", "crisis", "resolve")


def read_json(path: Path) -> dict:
    with path.open("r", encoding="utf-8") as stream:
        value = json.load(stream)
    if not isinstance(value, dict):
        raise ValueError(f"正典源不是 JSON 对象: {path}")
    return value


def verify_campaign() -> None:
    seen = set()
    for act_number in range(1, 13):
        source = read_json(CAMPAIGN / f"act_{act_number:02d}.json")
        chapters = source.get("chapters")
        if not isinstance(chapters, list) or len(chapters) != 6:
            raise ValueError(f"第{act_number}幕不是六章")
        for chapter_number, chapter in enumerate(chapters, 1):
            chnum = (act_number - 1) * 6 + chapter_number
            chapter_id = f"ch{chnum:03d}"
            if not isinstance(chapter, dict) or chapter.get("id") != chapter_id:
                raise ValueError(f"主线编号冲突: {chapter_id}")
            scenes = chapter.get("scenes", [])
            scene_ids = {x.get("id") for x in scenes if isinstance(x, dict)}
            required = {f"{chapter_id}.{stage}" for stage in REQUIRED_STAGES}
            if not required.issubset(scene_ids):
                raise ValueError(f"{chapter_id} 缺少正式四阶段场景")
            seen.add(chapter_id)
            if chnum == 71 and "赫西安" not in str(chapter.get("boss", "")):
                raise ValueError("终局战应对应第71章赫西安，不是第72章")
            if chnum == 72 and "ch072.ending" not in scene_ids:
                raise ValueError("第72章缺少正典结局收束")
    if len(seen) != 72:
        raise ValueError("72章编号存在重复或缺失")


def build_catalog() -> dict:
    verify_campaign()
    quests = []
    pages = []
    ids = set()
    for category, filename, expected in QUEST_SOURCES:
        raw = read_json(DATA / filename)
        entries = raw.get("quests")
        if not isinstance(entries, list) or len(entries) != expected:
            raise ValueError(f"{filename} 正典任务数不匹配")
        source_path = f"story/data/{filename}"
        for entry in entries:
            if not isinstance(entry, dict):
                raise ValueError(f"{filename} 包含非法任务")
            qid = entry.get("id")
            if not isinstance(qid, str) or not qid or qid in ids:
                raise ValueError(f"任务ID缺失或重复: {qid}")
            if not re.fullmatch(r"ch\d{3}", str(entry.get("required_chapter", ""))):
                raise ValueError(f"{qid} 章节门槛缺失")
            if not entry.get("completion_flag") or not entry.get("title"):
                raise ValueError(f"{qid} 缺少名称或正式完成旗标")
            ids.add(qid)
            quests.append({
                "id": qid,
                "title": entry["title"],
                "category": category,
                "required_chapter": entry["required_chapter"],
                "completion_flag": entry["completion_flag"],
                "source": source_path,
            })
            match = re.fullmatch(r"sq_page_(\d{2})", qid)
            if match:
                if category != "original":
                    raise ValueError(f"航页不得复制到其他任务源: {qid}")
                page_id = f"page_{match.group(1)}"
                if entry.get("rewards", {}).get("lost_page") != page_id:
                    raise ValueError(f"航页正式奖励与任务不匹配: {qid}")
                pages.append({
                    "quest_id": qid,
                    "page_id": page_id,
                    "completion_flag": entry["completion_flag"],
                    "world_flag": f"world.page_{match.group(1)}",
                    "source": source_path,
                })
    if len(quests) != 120 or len(pages) != 12:
        raise ValueError("120任务 / 12航页源数据不匹配")
    if {p["page_id"] for p in pages} != {f"page_{i:02d}" for i in range(1, 13)}:
        raise ValueError("失落航页缺页或ID重复")
    lore_data = read_json(DATA / "lore_texts.json").get("entries")
    if not isinstance(lore_data, list) or len(lore_data) != 27:
        raise ValueError("27份正典文献源数据不匹配")
    lore = [{
        "id": item["id"], "title": item["title"],
        "chapter": item.get("chapter", ""),
        "source": "story/data/lore_texts.json",
    } for item in lore_data]
    if len({item["id"] for item in lore}) != 27:
        raise ValueError("文献ID重复")
    return {
        "schema": "starlit.story.side_content_catalog.v1",
        "status": "canonical_index_only_not_runtime_acceptance",
        "source_of_truth": {
            "original_quests": "story/data/side_quests.json",
            "companion_quests": "story/data/companion_quests.json",
            "regional_quests": "story/data/regional_quests_v2.json",
            "lore": "story/data/lore_texts.json",
            "main_story": "story/campaign/act_01.json .. act_12.json",
        },
        "counts": {
            "original": 36, "companion": 48, "regional": 36,
            "total_quests": 120, "lore_documents": 27, "lost_pages": 12,
            "acts": 12, "chapters": 72,
        },
        "isolation": {
            "ch026_main_evidence": "保留 ch026 主线的正式证据ID；不得把航页作为该章主线证据",
            "lost_page_reward_id_format": "page_01..page_12",
            "page_completion_flags": "world.page_01..world.page_12",
            "ending_c": "由正式 endings.json 按 world.all_twelve_pages 等条件裁定，不在目录中授予",
        },
        "quests": quests,
        "lore_documents": lore,
        "lost_navigation_pages": sorted(pages, key=lambda p: p["page_id"]),
    }


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--compile-campaign", action="store_true",
                        help="额外运行既有全72章正典合并器（不会覆写幕源文件）")
    args = parser.parse_args()
    catalog = build_catalog()
    OUT.parent.mkdir(parents=True, exist_ok=True)
    OUT.write_text(json.dumps(catalog, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print("索引源检查通过：12幕72章 / 120任务 / 27文献 / 12航页")
    print("已更新:", OUT)
    if args.compile_campaign:
        from build_and_validate_story import build_compiled_campaign
        build_compiled_campaign()
    print("[UNTESTED] 未进行 Godot 实机、玩家路径、战斗或存档验收")


if __name__ == "__main__":
    main()
