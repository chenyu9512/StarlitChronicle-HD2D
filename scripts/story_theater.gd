extends Control
## 剧情演出调试器：实际使用 StoryRuntime 的状态、存档、选项与任务条件。
## 仅用于调试剧情，不会冒充地图、战斗、物品等尚未实现的玩法。

const RuntimeScript = preload("res://scripts/story_runtime.gd")
var runtime
var heading: Label
var status: Label
var speaker: Label
var dialogue: RichTextLabel
var info: Label
var actions: HBoxContainer
var footer: Label

func _ready() -> void:
    _build_ui()
    runtime = RuntimeScript.new()
    runtime.dialogue_opened.connect(_on_line)
    runtime.objective_changed.connect(_on_objective)
    runtime.choice_requested.connect(_on_choice)
    runtime.battle_requested.connect(_on_battle)
    runtime.reward_granted.connect(_on_reward)
    runtime.world_event.connect(_on_world_event)
    runtime.scene_finished.connect(_on_scene_finished)
    runtime.chapter_finished.connect(_on_chapter_finished)
    runtime.story_error.connect(_on_error)
    add_child(runtime)
    if not runtime.loaded:
        _on_error("剧情资源校验失败；请先执行 python tools/validate_story.py。")
        return
    if runtime.load_story():
        _set_status("剧情存档已恢复")
        if runtime.current_scene_index >= runtime.current_chapter.get("scenes", []).size():
            _on_chapter_finished(runtime.current_chapter_id)
    else:
        runtime.begin_prologue()

func _build_ui() -> void:
    var backdrop := ColorRect.new()
    backdrop.color = Color(0.035, 0.062, 0.115, 1.0)
    backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    add_child(backdrop)
    var root := MarginContainer.new()
    root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    root.add_theme_constant_override("margin_left", 32)
    root.add_theme_constant_override("margin_right", 32)
    root.add_theme_constant_override("margin_top", 24)
    root.add_theme_constant_override("margin_bottom", 18)
    add_child(root)
    var column := VBoxContainer.new()
    column.add_theme_constant_override("separation", 12)
    root.add_child(column)
    heading = Label.new()
    heading.text = "星灯纪行 · 交互剧情演出模式"
    heading.add_theme_font_size_override("font_size", 26)
    column.add_child(heading)
    status = Label.new()
    status.add_theme_font_size_override("font_size", 16)
    column.add_child(status)
    var line := HSeparator.new()
    column.add_child(line)
    speaker = Label.new()
    speaker.add_theme_font_size_override("font_size", 25)
    speaker.add_theme_color_override("font_color", Color(0.96, 0.78, 0.49))
    column.add_child(speaker)
    dialogue = RichTextLabel.new()
    dialogue.bbcode_enabled = false
    dialogue.fit_content = false
    dialogue.scroll_active = true
    dialogue.size_flags_vertical = Control.SIZE_EXPAND_FILL
    dialogue.add_theme_font_size_override("normal_font_size", 24)
    column.add_child(dialogue)
    info = Label.new()
    info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    info.add_theme_font_size_override("font_size", 15)
    column.add_child(info)
    actions = HBoxContainer.new()
    actions.add_theme_constant_override("separation", 10)
    column.add_child(actions)
    footer = Label.new()
    footer.text = "开发调试：调查/战斗按钮仅模拟任务事件，不等于新地图与Boss已接入游戏。"
    footer.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    footer.add_theme_font_size_override("font_size", 13)
    column.add_child(footer)

func _clear_actions() -> void:
    for child in actions.get_children():
        actions.remove_child(child)
        child.queue_free()

func _add_action(label: String, callback: Callable, disabled: bool = false) -> void:
    var button := Button.new()
    button.text = label
    button.custom_minimum_size = Vector2(156, 56)
    button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    button.disabled = disabled
    button.pressed.connect(callback)
    actions.add_child(button)

func _refresh_heading() -> void:
    if runtime == null:
        return
    var chapter: Dictionary = runtime.current_chapter
    var scene: Dictionary = runtime.get_current_scene()
    var phase: String = str(scene.get("title", "章节尾声"))
    heading.text = ("序章" if runtime.current_chapter_id == "prologue" else "主线 " + runtime.current_chapter_id) + "｜" + str(chapter.get("title", "")) + "｜" + phase

func _set_status(message: String) -> void:
    if status != null:
        status.text = message

func _on_line(line: Dictionary) -> void:
    _refresh_heading()
    speaker.text = str(line.get("speaker", ""))
    dialogue.text = str(line.get("text", ""))
    var scene: Dictionary = runtime.get_current_scene()
    var count: int = scene.get("dialogue", []).size()
    _set_status("对白 %d / %d · 已自动保存进度" % [runtime.line_index + 1, count])
    info.text = "继续观看剧情；调查目标与战斗将在对应对白结束后出现。"
    _clear_actions()
    _add_action("继续", Callable(self, "_next_line"))

func _next_line() -> void:
    runtime.advance_dialogue()

func _on_objective(objective: Dictionary) -> void:
    _refresh_heading()
    speaker.text = "当前任务目标"
    dialogue.text = str(objective.get("type", "action")) + "  →  " + str(objective.get("target", ""))
    info.text = "该操作应由正式地图中的对应 NPC / 物件 / 位置触发。此处用于验证剧情旗标和下一步是否衔接。"
    _set_status("等待地图事件（测试模式）")
    _clear_actions()
    _add_action("模拟完成该目标", Callable(self, "_complete_objective").bind(str(objective.get("target", ""))))

func _complete_objective(target: String) -> void:
    runtime.complete_objective(target)

func _on_choice(choice: Dictionary) -> void:
    _refresh_heading()
    speaker.text = "你的选择"
    dialogue.text = str(choice.get("prompt", "你要怎么做？"))
    info.text = "某些选项要求先完成额外的主线、世界事件或失落航页。"
    _set_status("等待玩家选择")
    _clear_actions()
    var options: Array = choice.get("options", [])
    for item in options:
        var option: Dictionary = item
        var id: String = str(option.get("id", ""))
        var required: Array = option.get("requires_flags", [])
        var unlocked: bool = runtime.catalog.requirements_met(required, runtime.flags)
        var label: String = str(option.get("label", id))
        if not unlocked:
            label += "（未解锁）"
        _add_action(label, Callable(self, "_choose").bind(id), not unlocked)

func _choose(option_id: String) -> void:
    runtime.choose_option(option_id)

func _on_battle(encounter: Dictionary) -> void:
    _refresh_heading()
    speaker.text = "战斗测试"
    dialogue.text = "对手：" + str(encounter.get("display_name", encounter.get("enemy_id", "未知敌人")))
    info.text = "战斗资源与AI未接入主游戏；下面的按钮仅模拟返回值，用来验证通关条件，不代表真实战斗可玩。"
    _set_status("等待战斗结果")
    _clear_actions()
    _add_action("模拟胜利", Callable(self, "_win_battle"))
    _add_action("模拟失败", Callable(self, "_lose_battle"))

func _win_battle() -> void:
    runtime.report_battle_result(true)

func _lose_battle() -> void:
    runtime.report_battle_result(false)
    _clear_actions()
    _add_action("重试战斗", Callable(self, "_retry_battle"))

func _retry_battle() -> void:
    runtime.retry_encounter()

func _on_reward(reward: Dictionary) -> void:
    _set_status("剧情奖励事件：" + JSON.stringify(reward) + "（尚未兑换到旧版背包）")

func _on_world_event(event: Dictionary) -> void:
    _set_status("世界事件：" + JSON.stringify(event))

func _on_scene_finished(_scene_id: String) -> void:
    # 后续场景由 StoryRuntime 自行开启；旧按钮会被新事件刷新。
    pass

func _on_chapter_finished(chapter_id: String) -> void:
    _refresh_heading()
    speaker.text = "章节完成"
    dialogue.text = "你已经完成 " + str(runtime.current_chapter.get("title", chapter_id)) + "。剧情旗标与进度已写入独立存档。"
    _set_status("本章全部场景已通过")
    info.text = "正式版本将切换地图、结算奖励、刷新队伍，此场景仅测试故事逻辑。"
    _clear_actions()
    if chapter_id == "ch072":
        dialogue.text += "\n\n星灯纪行 · 故事终幕"
        return
    var next_id: String = "ch001" if chapter_id == "prologue" else runtime.catalog.get_next_chapter_id(chapter_id)
    _add_action("进入下一章", Callable(self, "_next_chapter").bind(next_id))

func _next_chapter(chapter_id: String) -> void:
    runtime.begin_chapter(chapter_id)

func _on_error(message: String) -> void:
    _set_status("提示：" + message)
