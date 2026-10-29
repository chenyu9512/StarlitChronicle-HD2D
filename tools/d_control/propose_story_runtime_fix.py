#!/usr/bin/env python3
"""D-line fail-closed preview for a B-owned shared-story fix. NEVER edits game scripts."""
from __future__ import annotations
import argparse
import difflib
from pathlib import Path
import re

FILE = "scripts/story_runtime.gd"
HELPER = 'const AtomicStorySave = preload("res://tools/d_control/atomic_story_save.gd")\n'


def replace_once(data: str, old: str, new: str, label: str) -> str:
    if data.count(old) != 1:
        raise ValueError(f"{label} changed, D will not produce an unsafe patch")
    return data.replace(old, new, 1)


def replace_func(data: str, name: str, replacement: str) -> str:
    pattern = rf"(?m)^func {re.escape(name)}\([^\n]*\) -> (?:void|bool):\n"
    all_matches = list(re.finditer(pattern, data))
    if len(all_matches) != 1:
        raise ValueError(f"Function {name} changed; manual B-owner review required")
    hit = all_matches[0]
    later = re.search(r"(?m)^func ", data[hit.end():])
    end = hit.end() + later.start() if later else len(data)
    return data[:hit.start()] + replacement.strip("\n") + "\n\n" + data[end:]


SCENE = """func _finish_scene() -> void:
    var scene: Dictionary = _get_scene()
    if scene.is_empty():
        return
    var scene_id: String = str(scene.get("id", ""))
    var complete_key: String = _scene_completed_key(scene_id)
    if bool(flags.get(complete_key, false)):
        return
    var old_flags: Dictionary = flags.duplicate(true)
    var old_index: int = current_scene_index
    var rewards: Array[Dictionary] = []
    var delayed_events: Array[Dictionary] = []
    flags[complete_key] = true
    for item in scene.get("effects", []):
        var effect: Dictionary = item
        match str(effect.get("type", "")):
            "set_flag":
                flags[str(effect.get("key", ""))] = effect.get("value", true)
            "grant":
                rewards.append(effect)
            "time_skip":
                flags["world.years_passed"] = int(flags.get("world.years_passed", 0)) + int(effect.get("years", 0))
                delayed_events.append(effect)
            "finish_chapter":
                pass
    _apply_milestones()
    var scenes: Array = current_chapter.get("scenes", [])
    current_scene_index += 1
    if not save_story():
        flags = old_flags
        current_scene_index = old_index
        story_error.emit("剧情未持久化，未发放奖励；请检查存储空间。")
        return
    for item in delayed_events:
        world_event.emit(item)
    scene_finished.emit(scene_id)
    for reward in rewards:
        reward_granted.emit(reward)
    if current_scene_index < scenes.size():
        _open_scene()
    else:
        chapter_finished.emit(current_chapter_id)
"""

SIDE = """func complete_side_quest(quest_id: String) -> bool:
    var quest: Dictionary = catalog.get_quest(quest_id)
    if quest.is_empty() or not side_quest_progress.has(quest_id):
        return false
    var stages: Array = quest.get("stages", [])
    if int(side_quest_progress[quest_id]) != stages.size():
        story_error.emit("支线目标尚未全部完成：" + quest_id)
        return false
    var flag: String = str(quest.get("completion_flag", ""))
    if flag.is_empty() or bool(flags.get(flag, false)):
        return false
    var old_flags: Dictionary = flags.duplicate(true)
    flags[flag] = true
    if str(quest.get("type", "")) == "lost_page":
        var page: int = int(quest.get("page_number", 0))
        if page >= 1 and page <= 12:
            flags["world.page_%02d" % page] = true
    _apply_milestones()
    if not save_story():
        flags = old_flags
        story_error.emit("支线奖励结算未持久化：" + quest_id)
        return false
    reward_granted.emit(quest.get("rewards", {}))
    return true
"""


def patch(data: str) -> str:
    if HELPER in data:
        raise ValueError("Already patched; refuse to apply twice")
    data = replace_once(data, 'const STORY_SAVE_PATH: String = "user://starlit_story_v1.json"\n',
                        'const STORY_SAVE_PATH: String = "user://starlit_story_v1.json"\n' + HELPER, "save path")
    data = replace_func(data, "_finish_scene", SCENE)
    data = replace_func(data, "complete_side_quest", SIDE)
    before = '''    var file: FileAccess = FileAccess.open(STORY_SAVE_PATH, FileAccess.WRITE)
    if file == null:
        story_error.emit("剧情存档失败：" + str(FileAccess.get_open_error()))
        return false
    file.store_string(JSON.stringify(data, "  "))
    file.close()
    return true'''
    after = '''    if not AtomicStorySave.write_verified(STORY_SAVE_PATH, data):
        story_error.emit("剧情存档失败：已保留上次完整存档。")
        return false
    return true'''
    data = replace_once(data, before, after, "save_story")
    data = replace_once(data, '''    if not loaded or not FileAccess.file_exists(STORY_SAVE_PATH):
        return false
    var value: Variant = JSON.parse_string(FileAccess.get_file_as_string(STORY_SAVE_PATH))''',
        '''    if not loaded:
        return false
    var value: Variant = AtomicStorySave.read_verified(STORY_SAVE_PATH)''', "load_story")
    data = replace_once(data, '''    if not side_quest_progress.has(quest_id):
        side_quest_progress[quest_id] = 0
        save_story()
    return true''',
        '''    if not side_quest_progress.has(quest_id):
        side_quest_progress[quest_id] = 0
        if not save_story():
            side_quest_progress.erase(quest_id)
            return false
    return true''', "start_side_quest")
    data = replace_once(data, '''    side_quest_progress[quest_id] = stage_index + 1
    save_story()
    return true''',
        '''    side_quest_progress[quest_id] = stage_index + 1
    if not save_story():
        side_quest_progress[quest_id] = stage_index
        return false
    return true''', "advance_side_quest")
    return data


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--root", type=Path, default=Path(__file__).resolve().parents[2])
    parser.add_argument("--output", type=Path)
    args = parser.parse_args()
    filename = args.root / FILE
    source = filename.read_text(encoding="utf-8-sig")
    result = patch(source)
    diff = "".join(difflib.unified_diff(source.splitlines(keepends=True),
              result.splitlines(keepends=True), fromfile="a/" + FILE, tofile="b/" + FILE))
    if args.output:
        args.output.parent.mkdir(parents=True, exist_ok=True)
        args.output.write_text(diff, encoding="utf-8")
        print(f"Patch proposal written to {args.output}. Original code unchanged.")
    else:
        print(diff)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
