#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
《星灯纪行》StarlitChronicle-HD2D
数据管线构建与 V2.1 正典时间线防穿帮校验器
用法: python3 tools/build_and_validate_story.py
"""

import json
import glob
import os
import sys
from pathlib import Path
from typing import Dict, List, Any

PROJECT_ROOT = Path(__file__).resolve().parent.parent
CAMPAIGN_DIR = PROJECT_ROOT / "story" / "campaign"
DATA_DIR = PROJECT_ROOT / "story" / "data"
RUNTIME_OUT_DIR = PROJECT_ROOT / "story" / "runtime"

REQUIRED_STAGES = ["opening", "investigate", "crisis", "resolve"]
VALID_OBJECTIVES = {"reach", "interact", "inspect", "speak", "decide", "finish_chapter"}

# ==========================================
# V2.1 正典伙伴登场与入队权限契约表
# 状态定义:
#   FORBIDDEN       : 严禁作为实体登场（仅限档案提及或使用独立匿名NPC）
#   ACQUAINTED      : 仅剧情相识/同行对话，无战斗单位权限
#   GUEST_SUPPORT   : 临时支援/向导，不可自由编队或穿戴核心转职
#   PROTECTED_CHILD : 受照护儿童（非战斗人员，锁死恋爱与成年交互）
#   ACTIVE_PARTY    : 正式入队参战成员
# ==========================================
CANON_ROSTER_RULES = {
    "leiso": {
        "acquainted_from": 7,
        "guest_chapters": [8],          # 第8章灰鹰商道：仅临时护送支援
        "active_from_chapter": 9,       # 第9章审判厅 resolve 后正式入队
        "active_from_stage": "resolve",
    },
    "ize": {
        "forbidden_chapters": [22],     # 第22章王都白夜祭必须使用 npc_anonymous_court_musician
        "acquainted_from": 27,
        "guest_chapters": [27],         # 第27章青蓝海沟：仅作为向导同行
        "active_from_chapter": 28,      # 第28章断歌礁 resolve 后正式入队
        "active_from_stage": "resolve",
    },
    "xuanli": {
        "acquainted_from": 32,          # 第32-34章镜宫回廊至无名剧场：有自主对话但非战斗队员
        "active_from_chapter": 34,      # 第34章无名剧场亲手写下名字后（ch034.resolve）正式入队
        "active_from_stage": "resolve",
    },
    "visha": {
        "record_only_chapters": [23, 24, 43],  # 仅作为地下档案室记录或留言出现姓名
        "active_from_chapter": 58,             # 第58章正式入队
        "active_from_stage": "resolve",
    },
    "noe": {
        "child_chapters": list(range(39, 49)), # 第39-48章固定为受照护儿童（非战斗成员）
        "playable_from_chapter": 49,           # 第49章十二年后成年转为可操作主角
        "romance_allowed": False,              # 硬性锁死：禁止任何浪漫分支
    }
}

FLASHBACK_CHAPTERS = {
    19: {"era": "ten_years_ago", "lead": "leiso_young"},
    20: {"era": "seven_years_ago", "lead": "shuoxian_young"},
    21: {"era": "ten_years_ago", "lead": "lanyin_young", "requires_present_cut_before_choice": True},
}


class CanonValidationError(Exception):
    pass


def parse_chapter_num(ch_id: str) -> int:
    """从 'ch001' 提取整数 1"""
    digits = "".join(c for c in ch_id if c.isdigit())
    return int(digits) if digits else 0


def load_json_safe(path: Path) -> Dict[str, Any]:
    with open(path, "r", encoding="utf-8") as f:
        return json.load(f)


def collect_expansion_packs() -> Dict[str, Dict[str, Any]]:
    """
    读取 story/data/ 下所有扩展包 (optional_scenes 与 choice_reactions)
    按 chapter_id 归档
    """
    chapter_addons: Dict[str, Dict[str, list]] = {}
    if not DATA_DIR.exists():
        print(f"[WARN] 未找到扩展目录 {DATA_DIR}，将仅编译主线数据。")
        return chapter_addons

    for json_path in sorted(DATA_DIR.glob("*.json")):
        data = load_json_safe(json_path)
        # 挂载 optional_scenes
        for scene in data.get("optional_scenes", []):
            ch_id = scene.get("chapter_id") or scene.get("chapter")
            if ch_id:
                chapter_addons.setdefault(ch_id, {"optional_scenes": [], "choice_reactions": []})
                chapter_addons[ch_id]["optional_scenes"].append(scene)

        # 挂载 choice_reactions
        for reaction in data.get("choice_reactions", []):
            ch_id = reaction.get("chapter_id") or reaction.get("chapter")
            if ch_id:
                chapter_addons.setdefault(ch_id, {"optional_scenes": [], "choice_reactions": []})
                chapter_addons[ch_id]["choice_reactions"].append(reaction)

    return chapter_addons


def validate_chapter_canon(ch_data: Dict[str, Any], errors: List[str]) -> None:
    ch_id = ch_data.get("id", "unknown")
    ch_num = parse_chapter_num(ch_id)

    # 1. 正式数据格式为 scenes: [{id: "ch001.opening", objectives: [...]}, ...]。
    # 兼容未来的 stages 字典，但不可将不存在的 stages 当作缺失剧情。
    stages = ch_data.get("stages", {})
    if not isinstance(stages, dict):
        errors.append(f"[{ch_id}] stages 必须是字典")
        stages = {}
    scenes = ch_data.get("scenes", [])
    if not isinstance(scenes, list):
        errors.append(f"[{ch_id}] scenes 必须是列表")
        scenes = []
    for scene in scenes:
        if not isinstance(scene, dict):
            errors.append(f"[{ch_id}] 存在非字典场景")
            continue
        scene_id = scene.get("id", "")
        prefix = f"{ch_id}."
        if isinstance(scene_id, str) and scene_id.startswith(prefix):
            phase = scene_id[len(prefix):]
            if phase in REQUIRED_STAGES:
                if phase in stages:
                    errors.append(f"[{ch_id}] 重复四阶段节点: '{phase}'")
                else:
                    stages[phase] = scene
    for req_stage in REQUIRED_STAGES:
        if req_stage not in stages:
            errors.append(f"[{ch_id}] 缺失标准四阶段节点: '{req_stage}'")
            continue
        stage_obj = stages[req_stage]
        if not isinstance(stage_obj, dict):
            errors.append(f"[{ch_id}.{req_stage}] 场景内容必须是字典")
            continue
        objectives = stage_obj.get("objectives", [])
        if not isinstance(objectives, list):
            errors.append(f"[{ch_id}.{req_stage}] objectives 必须是列表")
            continue
        objective_types = [stage_obj["objective_type"]] if stage_obj.get("objective_type") else []
        objective_types += [o.get("type") for o in objectives if isinstance(o, dict)]
        if not objective_types:
            errors.append(f"[{ch_id}.{req_stage}] 缺少目标类型")
        for objective_type in objective_types:
            if objective_type not in VALID_OBJECTIVES:
                errors.append(f"[{ch_id}.{req_stage}] 非法目标类型: '{objective_type}'")

    # 2. 校验伙伴越界参战（V2.1 契约）
    active_party = ch_data.get("required_party", []) + ch_data.get("combat_party", [])
    spawned_npcs = ch_data.get("spawned_characters", [])

    # 雷索校验
    if "leiso" in active_party and ch_num < 9:
        errors.append(f"[{ch_id}] V2.1违规：雷索在第9章 resolve 前不得作为正式战斗编队成员（第8章仅限 guest_support）。")

    # 伊泽校验
    if ch_num == 22 and ("ize" in active_party or "ize" in spawned_npcs):
        errors.append(f"[{ch_id}] V2.1违规：第22章王都白夜祭严禁调用伊泽实体，必须使用 'npc_anonymous_court_musician'。")
    if "ize" in active_party and ch_num < 28:
        errors.append(f"[{ch_id}] V2.1违规：伊泽在第28章断歌礁 resolve 前不得进入正式战斗编队（第27章仅限向导）。")

    # 玄璃校验
    if "xuanli" in active_party and ch_num < 34:
        errors.append(f"[{ch_id}] V2.1违规：玄璃在第34章无名剧场写下名字（ch034.resolve）前无战斗队员状态。")

    # 维莎校验
    if ("visha" in active_party or "visha" in spawned_npcs) and ch_num < 58:
        errors.append(f"[{ch_id}] V2.1违规：维莎在第58章前仅可作为档案/留言文本出现，禁止生成实体或入队。")

    # 诺依校验
    if "noe" in active_party and ch_num < 49:
        errors.append(f"[{ch_id}] V2.1违规：诺依在第39-48章固定为受照护儿童，严禁编入战斗小队。")

    # 3. 校验第21章回忆篇切镜锁
    if ch_num == 21:
        crisis_stage = stages.get("crisis", {})
        if isinstance(crisis_stage, dict):
            transition = crisis_stage.get("return_to_present_campfire_before_choice")
            direction = crisis_stage.get("direction", {})
            direction = direction if isinstance(direction, dict) else {}
            transition_note = str(direction.get("phase11_player_time_transition", ""))
            if transition is False or (transition is None and not ("现世" in transition_note and "choice" in transition_note)):
                errors.append("[ch021.crisis] V2.1违规：缺少先回现世、再触发 choice 的正典标记。")
            # 说明：文字标记仅证明剧情数据约束，不能证明 Godot 的镜头切换已执行。

    # 4. 校验第26章主线证据与12张失落航页隔离
    if ch_num == 26:
        rewards = str(ch_data.get("evidence_items", []))
        if "lost_page_" in rewards:
            errors.append(f"[ch026] V2.1违规：第26章主线导航证据必须与 12 张失落航页（collectible.lost_page_01..12）严格区分。")


def build_compiled_campaign() -> None:
    errors: List[str] = []
    addons = collect_expansion_packs()
    compiled_acts: List[Dict[str, Any]] = []

    act_files = sorted(CAMPAIGN_DIR.glob("act_*.json"))
    if not act_files:
        raise CanonValidationError(f"找不到任何 act_*.json，拒绝生成空的正式运行时数据: {CAMPAIGN_DIR}")

    for act_path in act_files:
        act_data = load_json_safe(act_path)
        for ch in act_data.get("chapters", []):
            ch_id = ch.get("id")
            validate_chapter_canon(ch, errors)
            # 只在编译产物中补充四阶段索引，保持原有 scenes 与主控格式不变。
            if not isinstance(ch.get("stages"), dict) or not ch.get("stages"):
                stage_index = {}
                for scene in ch.get("scenes", []):
                    if not isinstance(scene, dict):
                        continue
                    scene_id = str(scene.get("id", ""))
                    prefix = f"{ch_id}."
                    if not scene_id.startswith(prefix):
                        continue
                    phase = scene_id[len(prefix):]
                    if phase not in REQUIRED_STAGES:
                        continue
                    objectives = scene.get("objectives", [])
                    first_type = objectives[0].get("type", "reach") if isinstance(objectives, list) and objectives and isinstance(objectives[0], dict) else "reach"
                    stage_index[phase] = {"scene_id": scene_id, "objective_type": first_type}
                ch["stages"] = stage_index
            if ch_id in addons:
                ch["optional_scenes"] = addons[ch_id]["optional_scenes"]
                ch["choice_reactions"] = addons[ch_id]["choice_reactions"]
            else:
                ch.setdefault("optional_scenes", [])
                ch.setdefault("choice_reactions", [])
        compiled_acts.append(act_data)

    if errors:
        print("❌ V2.1 正典契约校验未通过，发现以下问题：")
        for err in errors:
            print("  -", err)
        sys.exit(1)

    RUNTIME_OUT_DIR.mkdir(parents=True, exist_ok=True)
    out_file = RUNTIME_OUT_DIR / "compiled_campaign.json"
    with open(out_file, "w", encoding="utf-8") as f:
        json.dump({
            "version": "2.1.0-canon-locked",
            "roster_rules": CANON_ROSTER_RULES,
            "flashback_rules": FLASHBACK_CHAPTERS,
            "acts": compiled_acts
        }, f, ensure_ascii=False, indent=2)

    chapter_count = sum(len(act.get("chapters", [])) for act in compiled_acts)
    print(f"✅ 正典数据结构校验通过：{len(compiled_acts)} 幕 / {chapter_count} 章；输出: {out_file}")
    print("[UNTESTED] 此步骤只验证离线数据，不代表 Godot 玩家路径、存档或战斗已验收。")


if __name__ == "__main__":
    try:
        build_compiled_campaign()
    except (CanonValidationError, OSError, ValueError, json.JSONDecodeError) as exc:
        print(f"❌ 构建失败: {exc}", file=sys.stderr)
        sys.exit(1)