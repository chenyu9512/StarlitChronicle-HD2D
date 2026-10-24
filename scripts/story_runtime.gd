extends Node
## 星灯纪行剧情状态机。可嵌入未来正式Game控制器。
## 不依赖原型State，使用独立JSON存档，避免破坏v0.1.1。

signal dialogue_opened(line: Dictionary)
signal objective_changed(objective: Dictionary)
signal choice_requested(choice: Dictionary)
signal battle_requested(encounter: Dictionary)
signal reward_granted(reward: Dictionary)
signal world_event(event: Dictionary)
signal scene_finished(scene_id: String)
signal chapter_finished(chapter_id: String)
signal story_error(message: String)

const CatalogScript = preload("res://scripts/story_catalog.gd")
const STORY_SAVE_PATH: String = "user://starlit_story_v1.json"
var catalog
var flags: Dictionary = {}
var current_chapter_id: String = ""
var current_chapter: Dictionary = {}
var current_scene_index: int = 0
var line_index: int = 0
var dialogue_ended: bool = false
var waiting_battle: bool = false
var choice_made: bool = false
var objective_progress: Dictionary = {}
var loaded: bool = false

func _ready() -> void:
    catalog = CatalogScript.new()
    loaded = catalog.load_all()
    if not loaded:
        story_error.emit(catalog.get_errors_text())

func begin_prologue() -> bool:
    if not loaded:
        return false
    flags.clear()
    current_chapter_id = "prologue"
    current_chapter = catalog.prologue
    current_scene_index = 0
    _open_scene()
    return true

func begin_chapter(chapter_id: String) -> bool:
    if not loaded or not catalog.can_enter_chapter(chapter_id, flags):
        story_error.emit("章节未解锁或资料缺失：" + chapter_id)
        return false
    current_chapter_id = chapter_id
    current_chapter = catalog.get_chapter(chapter_id)
    current_scene_index = 0
    _open_scene()
    return true

func _get_scene() -> Dictionary:
    var scenes: Array = current_chapter.get("scenes", [])
    if current_scene_index < 0 or current_scene_index >= scenes.size():
        return {}
    var entry: Dictionary = scenes[current_scene_index]
    return entry

func _open_scene() -> void:
    var scene: Dictionary = _get_scene()
    if scene.is_empty():
        story_error.emit("无法定位剧情场景：" + current_chapter_id)
        return
    var trigger: Dictionary = scene.get("trigger", {})
    var requirements: Array = trigger.get("requires_flags", [])
    if not catalog.requirements_met(requirements, flags):
        story_error.emit("场景条件尚未达成：" + str(scene.get("id", "")))
        return
    line_index = 0
    dialogue_ended = false
    waiting_battle = false
    choice_made = false
    objective_progress.clear()
    var dialogue: Array = scene.get("dialogue", [])
    if dialogue.is_empty():
        _on_dialogue_end()
    else:
        dialogue_opened.emit(dialogue[0])

func advance_dialogue() -> void:
    if dialogue_ended or waiting_battle:
        return
    var scene: Dictionary = _get_scene()
    var dialogue: Array = scene.get("dialogue", [])
    if line_index + 1 < dialogue.size():
        line_index += 1
        dialogue_opened.emit(dialogue[line_index])
        return
    _on_dialogue_end()

func _on_dialogue_end() -> void:
    dialogue_ended = true
    var scene: Dictionary = _get_scene()
    if scene.has("choice"):
        choice_requested.emit(scene["choice"])
        return
    if scene.has("encounter") and scene["encounter"] is Dictionary:
        waiting_battle = true
        battle_requested.emit(scene["encounter"])
        return
    _request_next_objective_or_finish()

func _request_next_objective_or_finish() -> void:
    var scene: Dictionary = _get_scene()
    var objectives: Array = scene.get("objectives", [])
    for objective in objectives:
        var entry: Dictionary = objective
        var target: String = str(entry.get("target", ""))
        if not objective_progress.has(target):
            objective_changed.emit(entry)
            return
    _finish_scene()

func complete_objective(target: String) -> bool:
    if not dialogue_ended or waiting_battle:
        return false
    var scene: Dictionary = _get_scene()
    var objectives: Array = scene.get("objectives", [])
    for objective in objectives:
        var entry: Dictionary = objective
        if str(entry.get("target", "")) == target:
            objective_progress[target] = true
            _request_next_objective_or_finish()
            return true
    return false

func choose_option(option_id: String) -> bool:
    var scene: Dictionary = _get_scene()
    if not dialogue_ended or not scene.has("choice") or choice_made:
        return false
    var choice: Dictionary = scene["choice"]
    for item in choice.get("options", []):
        var option: Dictionary = item
        if str(option.get("id", "")) != option_id:
            continue
        var needs: Array = option.get("requires_flags", [])
        if not catalog.requirements_met(needs, flags):
            story_error.emit("该选项条件未满足：" + option_id)
            return false
        var sets: Dictionary = option.get("sets", {})
        for key in sets:
            flags[str(key)] = sets[key]
        choice_made = true
        objective_progress[str(choice.get("id", ""))] = true
        if scene.has("encounter") and scene["encounter"] is Dictionary:
            waiting_battle = true
            battle_requested.emit(scene["encounter"])
        else:
            _request_next_objective_or_finish()
        return true
    return false

func retry_encounter() -> void:
    var scene: Dictionary = _get_scene()
    if dialogue_ended and not waiting_battle and scene.has("encounter"):
        waiting_battle = true
        battle_requested.emit(scene["encounter"])

func report_battle_result(victory: bool) -> void:
    if not waiting_battle:
        return
    waiting_battle = false
    var scene: Dictionary = _get_scene()
    if not victory:
        story_error.emit("本场战斗失败；可恢复队伍并重新挑战。")
        return
    var encounter: Dictionary = scene.get("encounter", {})
    var victory_flag: String = str(encounter.get("win_flag", ""))
    if not victory_flag.is_empty():
        flags[victory_flag] = true
    _finish_scene()

func _finish_scene() -> void:
    var scene: Dictionary = _get_scene()
    if scene.is_empty():
        return
    for item in scene.get("effects", []):
        var effect: Dictionary = item
        match str(effect.get("type", "")):
            "set_flag":
                flags[str(effect.get("key", ""))] = effect.get("value", true)
            "grant":
                reward_granted.emit(effect)
            "time_skip":
                flags["world.years_passed"] = int(flags.get("world.years_passed", 0)) + int(effect.get("years", 0))
                world_event.emit(effect)
            "finish_chapter":
                pass
    scene_finished.emit(str(scene.get("id", "")))
    var scenes: Array = current_chapter.get("scenes", [])
    if current_scene_index + 1 < scenes.size():
        current_scene_index += 1
        save_story()
        _open_scene()
    else:
        # 完成哨兵位置必须持久化，防止读档后二次发奖。
        current_scene_index = scenes.size()
        save_story()
        chapter_finished.emit(current_chapter_id)

func complete_side_quest(quest_id: String) -> bool:
    ## 此方法应在正式任务控制器校验3个阶段目标后调用。
    if not loaded:
        return false
    var quest: Dictionary = catalog.get_quest(quest_id)
    if quest.is_empty():
        return false
    var key: String = str(quest.get("completion_flag", ""))
    if bool(flags.get(key, false)):
        return false
    flags[key] = true
    reward_granted.emit(quest.get("rewards", {}))
    if str(quest.get("type", "")) == "lost_page":
        var page: int = int(quest.get("page_number", 0))
        if page >= 1 and page <= 12:
            flags["world.page_%02d" % page] = true
            var all_present: bool = true
            for number in range(1, 13):
                if not bool(flags.get("world.page_%02d" % number, false)):
                    all_present = false
                    break
            if all_present:
                flags["world.all_twelve_pages"] = true
    save_story()
    return true

func export_flags() -> Dictionary:
    return flags.duplicate(true)

func save_story() -> bool:
    var data: Dictionary = {
        "version": 1,
        "current_chapter_id": current_chapter_id,
        "current_scene_index": current_scene_index,
        "line_index": line_index,
        "flags": flags
    }
    var file := FileAccess.open(STORY_SAVE_PATH, FileAccess.WRITE)
    if file == null:
        story_error.emit("剧情存档失败。")
        return false
    file.store_string(JSON.stringify(data))
    file.close()
    return true

func load_story() -> bool:
    if not loaded or not FileAccess.file_exists(STORY_SAVE_PATH):
        return false
    var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(STORY_SAVE_PATH))
    if not (parsed is Dictionary):
        return false
    var data: Dictionary = parsed
    if int(data.get("version", -1)) != 1 or not (data.get("flags") is Dictionary):
        return false
    flags = data["flags"]
    current_chapter_id = str(data.get("current_chapter_id", ""))
    if current_chapter_id == "prologue":
        current_chapter = catalog.prologue
    else:
        current_chapter = catalog.get_chapter(current_chapter_id)
    if current_chapter.is_empty():
        return false
    var scenes: Array = current_chapter.get("scenes", [])
    var saved_index: int = int(data.get("current_scene_index", 0))
    if saved_index >= scenes.size():
        current_scene_index = scenes.size()
        return true # 当前章节已结算，调用begin_chapter(next_id)继续。
    current_scene_index = clampi(saved_index, 0, maxi(scenes.size() - 1, 0))
    _open_scene()
    return true
