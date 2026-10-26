extends Node
## 剧情运行器：独立存档，不触及旧版游戏 State / save_v1。
## 所有战斗与地图判定通过信号交给外部控制器，永不自动伪造胜利。

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
const AtomicStorySave = preload("res://tools/d_control/atomic_story_save.gd")

var catalog
var loaded: bool = false
var flags: Dictionary = {}
var current_chapter_id: String = ""
var current_chapter: Dictionary = {}
var current_scene_index: int = 0
var line_index: int = 0
var dialogue_ended: bool = false
var waiting_battle: bool = false
var choice_made: bool = false
var pending_branch_dialogue: Array = []
var objective_progress: Dictionary = {}
var side_quest_progress: Dictionary = {}
# Persisted B-line rewards awaiting consumer acknowledgement. A/D must ledger event_id.
var reward_outbox: Dictionary = {}


func _checkpoint() -> Dictionary:
    return {
        "flags":flags.duplicate(true),"current_chapter_id":current_chapter_id,
        "current_chapter":current_chapter.duplicate(true),"current_scene_index":current_scene_index,
        "line_index":line_index,"dialogue_ended":dialogue_ended,
        "waiting_battle":waiting_battle,"choice_made":choice_made,
        "pending_branch_dialogue":pending_branch_dialogue.duplicate(true),
        "objective_progress":objective_progress.duplicate(true),
        "side_quest_progress":side_quest_progress.duplicate(true),
        "reward_outbox":reward_outbox.duplicate(true)
    }

func _rollback(saved: Dictionary) -> void:
    flags = saved["flags"]
    current_chapter_id = saved["current_chapter_id"]
    current_chapter = saved["current_chapter"]
    current_scene_index = saved["current_scene_index"]
    line_index = saved["line_index"]
    dialogue_ended = saved["dialogue_ended"]
    waiting_battle = saved["waiting_battle"]
    choice_made = saved["choice_made"]
    pending_branch_dialogue = saved["pending_branch_dialogue"]
    objective_progress = saved["objective_progress"]
    side_quest_progress = saved["side_quest_progress"]
    reward_outbox = saved["reward_outbox"]

func _commit_or_rollback(saved: Dictionary, context: String) -> bool:
    if save_story():
        return true
    _rollback(saved)
    story_error.emit("剧情变更未保存，进度已回滚：" + context)
    return false

func _queue_reward(event_id: String, reward: Dictionary) -> void:
    if reward_outbox.has(event_id):
        return
    var tagged: Dictionary = reward.duplicate(true)
    tagged["event_id"] = event_id
    tagged["receipt_required"] = true
    reward_outbox[event_id] = tagged

func _emit_queued(ids: Array[String]) -> void:
    for event_id in ids:
        if reward_outbox.has(event_id):
            reward_granted.emit((reward_outbox[event_id] as Dictionary).duplicate(true))

## Call only after the reward consumer's handler and persistent event-id ledger exist.
## Replaying is at-least-once. A/D must persist the receipt with the actual payout.
func replay_pending_rewards() -> void:
    var ids: Array[String] = []
    for key in reward_outbox.keys():
        ids.append(str(key))
    ids.sort()
    _emit_queued(ids)

func pending_reward_receipts() -> Dictionary:
    return reward_outbox.duplicate(true)

## Consumer calls this after its own payout and event-id receipt are durably saved.
func acknowledge_reward(event_id: String) -> bool:
    if not reward_outbox.has(event_id):
        return false
    var before: Dictionary = _checkpoint()
    reward_outbox.erase(event_id)
    return _commit_or_rollback(before, "奖励回执 " + event_id)

func _ready() -> void:
    catalog = CatalogScript.new()
    loaded = catalog.load_all()
    if not loaded:
        story_error.emit(catalog.get_errors_text())

func begin_prologue() -> bool:
    if not loaded:
        return false
    var before: Dictionary = _checkpoint()
    flags.clear()
    side_quest_progress.clear()
    reward_outbox.clear()
    current_chapter_id = "prologue"
    current_chapter = catalog.prologue
    current_scene_index = 0
    if not _open_scene():
        _rollback(before)
        return false
    return true

func begin_chapter(chapter_id: String) -> bool:
    if not loaded or not catalog.can_enter_chapter(chapter_id, flags):
        story_error.emit("章节尚未解锁：" + chapter_id)
        return false
    if bool(flags.get("story." + chapter_id + ".done", false)):
        story_error.emit("已通关章节不可重复领取奖励：" + chapter_id)
        return false
    var before: Dictionary = _checkpoint()
    current_chapter_id = chapter_id
    current_chapter = catalog.get_chapter(chapter_id)
    current_scene_index = 0
    if not _open_scene():
        _rollback(before)
        return false
    return true

func _get_scene() -> Dictionary:
    var scenes: Array = current_chapter.get("scenes", [])
    if current_scene_index < 0 or current_scene_index >= scenes.size():
        return {}
    var scene: Dictionary = scenes[current_scene_index]
    return scene

func _scene_completed_key(scene_id: String) -> String:
    return "scene." + scene_id + ".completed"

func _open_scene() -> bool:
    var scene: Dictionary = _get_scene()
    if scene.is_empty():
        story_error.emit("无法定位场景：" + current_chapter_id)
        return false
    var trigger: Dictionary = scene.get("trigger", {})
    var required: Array = trigger.get("requires_flags", [])
    if not catalog.requirements_met(required, flags):
        story_error.emit("场景解锁条件未满足：" + str(scene.get("id", "")))
        return false
    var before: Dictionary = _checkpoint()
    line_index = 0
    dialogue_ended = false
    waiting_battle = false
    choice_made = false
    pending_branch_dialogue.clear()
    objective_progress.clear()
    if not _commit_or_rollback(before, "开始场景 " + str(scene.get("id", ""))):
        return false
    var lines: Array = scene.get("dialogue", [])
    if lines.is_empty():
        _on_dialogue_end()
    else:
        var first_line: Dictionary = lines[0]
        dialogue_opened.emit(first_line)
    return true

func advance_dialogue() -> void:
    if dialogue_ended or waiting_battle or _get_scene().is_empty():
        return
    var scene: Dictionary = _get_scene()
    var lines: Array = pending_branch_dialogue if not pending_branch_dialogue.is_empty() else scene.get("dialogue", [])
    if line_index + 1 < lines.size():
        var before: Dictionary = _checkpoint()
        line_index += 1
        if not _commit_or_rollback(before, "推进对白"):
            return
        var next_line: Dictionary = lines[line_index]
        dialogue_opened.emit(next_line)
    else:
        _on_dialogue_end()

func _on_dialogue_end() -> void:
    var before: Dictionary = _checkpoint()
    var had_reply: bool = not pending_branch_dialogue.is_empty()
    if had_reply:
        pending_branch_dialogue.clear()
    dialogue_ended = true
    if not _commit_or_rollback(before, "结束对白"):
        return
    var scene: Dictionary = _get_scene()
    if not had_reply and scene.has("choice") and not choice_made:
        choice_requested.emit(scene["choice"])
        return
    if scene.has("encounter"):
        _request_battle()
    else:
        _request_next_objective_or_finish()

func _request_battle() -> void:
    var scene: Dictionary = _get_scene()
    if not scene.has("encounter") or waiting_battle:
        return
    var before: Dictionary = _checkpoint()
    waiting_battle = true
    if not _commit_or_rollback(before, "请求战斗"):
        return
    var encounter: Dictionary = scene["encounter"]
    battle_requested.emit(encounter)

func _next_objective() -> Dictionary:
    var scene: Dictionary = _get_scene()
    var objectives: Array = scene.get("objectives", [])
    for item in objectives:
        var objective: Dictionary = item
        var target: String = str(objective.get("target", ""))
        if not objective_progress.has(target):
            return objective
    return {}

func _request_next_objective_or_finish() -> void:
    var next_objective: Dictionary = _next_objective()
    if next_objective.is_empty():
        _finish_scene()
    else:
        objective_changed.emit(next_objective)

func complete_objective(target: String) -> bool:
    if not dialogue_ended or waiting_battle or _get_scene().is_empty():
        return false
    var scene: Dictionary = _get_scene()
    if scene.has("choice") and not choice_made:
        return false
    var next_objective: Dictionary = _next_objective()
    if next_objective.is_empty() or str(next_objective.get("target", "")) != target:
        story_error.emit("任务目标不匹配或顺序错误：" + target)
        return false
    var before: Dictionary = _checkpoint()
    objective_progress[target] = true
    if not _commit_or_rollback(before, "任务目标 " + target):
        return false
    _request_next_objective_or_finish()
    return true

func choose_option(option_id: String) -> bool:
    var scene: Dictionary = _get_scene()
    if not dialogue_ended or not scene.has("choice") or choice_made:
        return false
    var choice: Dictionary = scene["choice"]
    var options: Array = choice.get("options", [])
    for item in options:
        var option: Dictionary = item
        if str(option.get("id", "")) != option_id:
            continue
        var requires: Array = option.get("requires_flags", [])
        if not catalog.requirements_met(requires, flags):
            story_error.emit("该选项未解锁：" + option_id)
            return false
        var before: Dictionary = _checkpoint()
        var sets: Dictionary = option.get("sets", {})
        for key in sets:
            flags[str(key)] = sets[key]
        choice_made = true
        objective_progress[str(choice.get("id", ""))] = true
        var reply: Array = option.get("branch_dialogue", [])
        if not reply.is_empty():
            pending_branch_dialogue = reply.duplicate(true)
            line_index = 0
            dialogue_ended = false
        if not _commit_or_rollback(before, "剧情选项 " + option_id):
            return false
        if not reply.is_empty():
            dialogue_opened.emit(pending_branch_dialogue[0])
        elif scene.has("encounter"):
            _request_battle()
        else:
            _request_next_objective_or_finish()
        return true
    return false

func retry_encounter() -> void:
    var scene: Dictionary = _get_scene()
    if dialogue_ended and not waiting_battle and scene.has("encounter"):
        _request_battle()

func report_battle_result(victory: bool) -> void:
    if not waiting_battle:
        return
    var before: Dictionary = _checkpoint()
    waiting_battle = false
    var scene: Dictionary = _get_scene()
    if victory:
        var encounter: Dictionary = scene.get("encounter", {})
        var flag: String = str(encounter.get("win_flag", ""))
        if not flag.is_empty():
            flags[flag] = true
            if flag == "ch071.battle_won":
                flags["boss.ch071.won"] = true
    if not _commit_or_rollback(before, "战斗结果"):
        return
    if victory:
        _finish_scene()
    else:
        story_error.emit("战斗失败；恢复队伍后可重新挑战。")

func _apply_milestones() -> void:
    if bool(flags.get("story.ch060.done", false)):
        flags["world.distributed_network"] = true
    if bool(flags.get("story.ch066.done", false)):
        flags["world.seven_lanterns"] = true
    if bool(flags.get("ch071.battle_won", false)):
        flags["boss.ch071.won"] = true
    var page_count: int = 0
    for index in range(1, 13):
        if bool(flags.get("world.page_%02d" % index, false)):
            page_count += 1
    if page_count == 12:
        flags["world.all_twelve_pages"] = true

func _finish_scene() -> void:
    var scene: Dictionary = _get_scene()
    if scene.is_empty():
        return
    var scene_id: String = str(scene.get("id", ""))
    if scene_id.is_empty():
        story_error.emit("不能结算缺少ID的剧情场景。")
        return
    var complete_key: String = _scene_completed_key(scene_id)
    if bool(flags.get(complete_key, false)):
        return
    var before: Dictionary = _checkpoint()
    var delayed_events: Array[Dictionary] = []
    var reward_ids: Array[String] = []
    flags[complete_key] = true
    var effect_index: int = 0
    for item in scene.get("effects", []):
        if not (item is Dictionary):
            effect_index += 1
            continue
        var effect: Dictionary = item
        match str(effect.get("type", "")):
            "set_flag":
                flags[str(effect.get("key", ""))] = effect.get("value", true)
            "grant":
                var event_id: String = "b.story.scene." + scene_id + ".reward." + str(effect_index)
                _queue_reward(event_id, effect)
                reward_ids.append(event_id)
            "time_skip":
                flags["world.years_passed"] = int(flags.get("world.years_passed", 0)) + int(effect.get("years", 0))
                delayed_events.append(effect)
            "finish_chapter":
                pass
        effect_index += 1
    _apply_milestones()
    var scenes: Array = current_chapter.get("scenes", [])
    current_scene_index += 1
    if not _commit_or_rollback(before, "完成场景 " + scene_id):
        return
    for effect in delayed_events:
        world_event.emit(effect)
    scene_finished.emit(scene_id)
    _emit_queued(reward_ids)
    if current_scene_index < scenes.size():
        _open_scene()
    else:
        chapter_finished.emit(current_chapter_id)

func start_side_quest(quest_id: String) -> bool:
    if not loaded:
        return false
    var quest: Dictionary = catalog.get_quest(quest_id)
    if quest.is_empty():
        return false
    var complete_flag: String = str(quest.get("completion_flag", ""))
    if bool(flags.get(complete_flag, false)):
        return false
    var required_chapter: String = str(quest.get("required_chapter", ""))
    if not required_chapter.is_empty() and not bool(flags.get("story." + required_chapter + ".done", false)):
        story_error.emit("对应主线尚未完成：" + required_chapter)
        return false
    if not side_quest_progress.has(quest_id):
        var before: Dictionary = _checkpoint()
        side_quest_progress[quest_id] = 0
        return _commit_or_rollback(before, "接取支线 " + quest_id)
    return true

func advance_side_quest(quest_id: String, stage_id: String) -> bool:
    var quest: Dictionary = catalog.get_quest(quest_id)
    if quest.is_empty() or not side_quest_progress.has(quest_id):
        return false
    var stage_index: int = int(side_quest_progress[quest_id])
    var stages: Array = quest.get("stages", [])
    if stage_index < 0 or stage_index >= stages.size():
        return false
    var stage: Dictionary = stages[stage_index]
    if str(stage.get("id", "")) != stage_id:
        return false
    var before: Dictionary = _checkpoint()
    side_quest_progress[quest_id] = stage_index + 1
    return _commit_or_rollback(before, "支线阶段 " + quest_id + "/" + stage_id)

func complete_side_quest(quest_id: String) -> bool:
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
    var before: Dictionary = _checkpoint()
    flags[flag] = true
    if str(quest.get("type", "")) == "lost_page":
        var page: int = int(quest.get("page_number", 0))
        if page >= 1 and page <= 12:
            flags["world.page_%02d" % page] = true
    _apply_milestones()
    var event_id: String = "b.story.quest." + quest_id + ".reward"
    var payload: Dictionary = quest.get("rewards", {})
    _queue_reward(event_id, payload)
    if not _commit_or_rollback(before, "结算支线 " + quest_id):
        return false
    _emit_queued([event_id])
    return true

func get_current_scene() -> Dictionary:
    return _get_scene()

func export_flags() -> Dictionary:
    return flags.duplicate(true)

func save_story() -> bool:
    var data: Dictionary = {
        "version": 2,
        "current_chapter_id": current_chapter_id,
        "current_scene_index": current_scene_index,
        "line_index": line_index,
        "dialogue_ended": dialogue_ended,
        "waiting_battle": waiting_battle,
        "choice_made": choice_made,
        "pending_branch_dialogue": pending_branch_dialogue,
        "objective_progress": objective_progress,
        "side_quest_progress": side_quest_progress,
        "reward_outbox": reward_outbox,
        "flags": flags
    }
    if not AtomicStorySave.write_verified(STORY_SAVE_PATH, data):
        story_error.emit("剧情存档失败：已保留此前的完整存档。")
        return false
    return true

func load_story() -> bool:
    if not loaded:
        return false
    var value: Variant = AtomicStorySave.read_verified(STORY_SAVE_PATH)
    if not (value is Dictionary):
        return false
    var data: Dictionary = value
    var version: int = int(data.get("version", -1))
    if version != 1 and version != 2:
        return false
    if not (data.get("flags", null) is Dictionary):
        return false
    if not (data.get("side_quest_progress", {}) is Dictionary):
        return false
    if not (data.get("objective_progress", {}) is Dictionary):
        return false
    if not (data.get("reward_outbox", {}) is Dictionary):
        return false
    var chapter_id: String = str(data.get("current_chapter_id", ""))
    var chapter: Dictionary = catalog.prologue if chapter_id == "prologue" else catalog.get_chapter(chapter_id)
    if chapter.is_empty():
        return false
    # 所有字段通过校验后一次应用；坏档不会清空现有运行状态。
    flags = (data["flags"] as Dictionary).duplicate(true)
    _apply_milestones()
    side_quest_progress = (data.get("side_quest_progress", {}) as Dictionary).duplicate(true)
    reward_outbox = (data.get("reward_outbox", {}) as Dictionary).duplicate(true)
    current_chapter_id = chapter_id
    current_chapter = chapter
    var scenes: Array = chapter.get("scenes", [])
    current_scene_index = clampi(int(data.get("current_scene_index", 0)), 0, scenes.size())
    if current_scene_index >= scenes.size():
        return true # 章节完成哨兵，UI可引导进入下一章。
    var scene: Dictionary = _get_scene()
    var lines: Array = scene.get("dialogue", [])
    # 旧版存档缺少进行中字段：保守地从场景开头恢复。
    if version == 1:
        _open_scene()
        return true
    pending_branch_dialogue = data.get("pending_branch_dialogue", []) if data.get("pending_branch_dialogue", []) is Array else []
    if not pending_branch_dialogue.is_empty():
        lines = pending_branch_dialogue
    line_index = clampi(int(data.get("line_index", 0)), 0, maxi(lines.size()-1, 0))
    dialogue_ended = bool(data.get("dialogue_ended", false))
    waiting_battle = bool(data.get("waiting_battle", false))
    choice_made = bool(data.get("choice_made", false))
    objective_progress = (data.get("objective_progress", {}) as Dictionary).duplicate(true)
    if waiting_battle:
        var encounter: Dictionary = scene.get("encounter", {})
        battle_requested.emit(encounter)
    elif not dialogue_ended:
        if lines.is_empty():
            _on_dialogue_end()
        else:
            var current_line: Dictionary = lines[line_index]
            dialogue_opened.emit(current_line)
    elif scene.has("choice") and not choice_made:
        var choice: Dictionary = scene["choice"]
        choice_requested.emit(choice)
    else:
        _request_next_objective_or_finish()
    return true
