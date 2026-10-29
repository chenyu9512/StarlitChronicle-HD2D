extends CanvasLayer
## Scene-by-scene playable narrative interpreter: real dialogue, choices,
## prerequisites, progress flags, reward effects, encounter handoff and save.

signal closed()
signal battle_requested(enemy_id: String, display_name: String)

const StoryCatalog = preload("res://scripts/story_catalog.gd")
var catalog
var overlay: Control
var header: Label
var subtitle: Label
var dialogue: RichTextLabel
var status: Label
var next_button: Button
var choice_box: VBoxContainer
var line_index: int = 0
var awaiting_battle: bool = false
var battle_done: bool = false
var blocked: bool = false
var waiting_choice: bool = false

func _ready() -> void:
    layer = 24
    catalog = StoryCatalog.new()
    _build_ui()
    if not catalog.load_all():
        status.text = "叙事数据不完整：\n" + catalog.get_errors_text()
        blocked = true
    overlay.hide()

func _build_ui() -> void:
    overlay = Control.new()
    overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    overlay.mouse_filter = Control.MOUSE_FILTER_STOP
    add_child(overlay)
    var bg := ColorRect.new()
    bg.color = Color(0.025, 0.045, 0.089, 0.98)
    bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    bg.mouse_filter = Control.MOUSE_FILTER_STOP
    overlay.add_child(bg)
    var shell := PanelContainer.new()
    shell.anchor_left = 0.10
    shell.anchor_right = 0.90
    shell.anchor_top = 0.04
    shell.anchor_bottom = 0.96
    var style := StyleBoxFlat.new()
    style.bg_color = Color(0.065, 0.105, 0.16, 1)
    style.border_color = Color(0.74, 0.66, 0.44, 1)
    style.set_border_width_all(2)
    style.set_corner_radius_all(12)
    style.set_content_margin_all(16)
    shell.add_theme_stylebox_override("panel", style)
    overlay.add_child(shell)
    var scroll := ScrollContainer.new()
    scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
    shell.add_child(scroll)
    var v := VBoxContainer.new()
    v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    v.add_theme_constant_override("separation", 10)
    scroll.add_child(v)
    header = Label.new()
    header.add_theme_font_size_override("font_size", 25)
    v.add_child(header)
    subtitle = Label.new()
    subtitle.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    subtitle.add_theme_font_size_override("font_size", 18)
    v.add_child(subtitle)
    dialogue = RichTextLabel.new()
    dialogue.custom_minimum_size.y = 150
    dialogue.size_flags_vertical = Control.SIZE_EXPAND_FILL
    dialogue.bbcode_enabled = false
    dialogue.scroll_active = true
    dialogue.add_theme_font_size_override("normal_font_size", 22)
    v.add_child(dialogue)
    choice_box = VBoxContainer.new()
    choice_box.add_theme_constant_override("separation", 8)
    v.add_child(choice_box)
    status = Label.new()
    status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    status.add_theme_font_size_override("font_size", 17)
    v.add_child(status)
    var row := HBoxContainer.new()
    row.add_theme_constant_override("separation", 10)
    v.add_child(row)
    next_button = _button(row, "继续 · 调查 / 决定", Callable(self, "_advance"))
    _button(row, "关闭 · 返回探索", Callable(self, "_close"))

func _button(parent: Node, caption: String, callback: Callable) -> Button:
    var button := Button.new()
    button.text = caption
    button.custom_minimum_size = Vector2(175, 50)
    button.add_theme_font_size_override("font_size", 19)
    button.pressed.connect(callback)
    parent.add_child(button)
    return button

func open_campaign() -> void:
    overlay.show()
    line_index = 0
    waiting_choice = false
    awaiting_battle = false
    battle_done = false
    _render()

func _chapter_data() -> Dictionary:
    if State.story_chapter == 0:
        return catalog.prologue
    return catalog.get_chapter("ch%03d" % State.story_chapter)

func _scene_data() -> Dictionary:
    var scenes: Array = _chapter_data().get("scenes", [])
    if State.story_scene >= 0 and State.story_scene < scenes.size():
        if scenes[State.story_scene] is Dictionary:
            return scenes[State.story_scene]
    return {}

func _render() -> void:
    choice_box.hide()
    for node in choice_box.get_children():
        choice_box.remove_child(node)
        node.queue_free()
    if blocked:
        next_button.disabled = true
        return
    if State.story_chapter == 72 and bool(State.story_flags.get("story.ch072.done", false)):
        _render_finale()
        return
    var chapter: Dictionary = _chapter_data()
    var scene: Dictionary = _scene_data()
    if scene.is_empty():
        status.text = "没有可加载的剧情场景，请检查 JSON。"
        next_button.disabled = true
        return
    var scenes: Array = chapter.get("scenes", [])
    header.text = ("童年序章" if State.story_chapter == 0 else "第 %02d 章" % State.story_chapter) + " · " + str(chapter.get("title", ""))
    subtitle.text = "%s  ·  第 %d/%d 场" % [str(scene.get("title", "")), State.story_scene + 1, scenes.size()]
    var chapter_requirements: Array = chapter.get("required_flags", [])
    for flag in chapter_requirements:
        if not bool(State.story_flags.get(str(flag), false)):
            status.text = "尚未达成章节条件：" + str(flag)
            next_button.disabled = true
            return
    var requirements: Array = scene.get("trigger", {}).get("requires_flags", [])
    for flag in requirements:
        if not bool(State.story_flags.get(str(flag), false)):
            status.text = "尚未达成剧情条件：" + str(flag)
            next_button.disabled = true
            return
    var lines: Array = scene.get("dialogue", [])
    if not lines.is_empty():
        line_index = clampi(line_index, 0, lines.size() - 1)
        var entry: Dictionary = lines[line_index]
        var speaker: String = str(entry.get("speaker", "旁白"))
        dialogue.text = "%s\n\n%s" % [speaker, str(entry.get("text", ""))]
    else:
        dialogue.text = "（此场景无对白）"
    var objective_text: String = str(scene.get("objective", ""))
    if objective_text.is_empty():
        var objectives: Array = scene.get("objectives", [])
        if not objectives.is_empty():
            var first: Variant = objectives[0]
            objective_text = str(first.get("type", "")) + " · " + str(first.get("target", "")) if first is Dictionary else str(first)
    status.text = "目标：" + objective_text
    if scene.has("encounter") and scene.get("encounter") is Dictionary:
        status.text += "\n此场包含战斗事件，胜利后才能继续。"
    next_button.disabled = false

func _advance() -> void:
    if blocked or awaiting_battle or waiting_choice:
        return
    var scene: Dictionary = _scene_data()
    var lines: Array = scene.get("dialogue", [])
    if line_index + 1 < lines.size():
        line_index += 1
        _render()
        return
    var choice: Dictionary = scene.get("choice", {})
    if not choice.is_empty() and not bool(State.story_flags.get(str(choice.get("id", "")) + ".chosen", false)):
        _show_choice(choice)
        return
    var encounter: Variant = scene.get("encounter", null)
    if encounter is Dictionary and not battle_done:
        var spec: Dictionary = encounter
        awaiting_battle = true
        status.text = "迎战：" + str(spec.get("display_name", "未知敌人"))
        next_button.disabled = true
        overlay.hide()
        battle_requested.emit(str(spec.get("enemy_id", "")), str(spec.get("display_name", "敌人")))
        return
    _finish_scene()

func _show_choice(choice: Dictionary) -> void:
    waiting_choice = true
    next_button.disabled = true
    status.text = str(choice.get("prompt", "请选择"))
    choice_box.show()
    for option in choice.get("options", []):
        if option is Dictionary:
            var choice_data: Dictionary = option
            var choice_id: String = str(choice.get("id", ""))
            _button(choice_box, str(choice_data.get("label", "决定")), Callable(self, "_select_choice").bind(choice_data.duplicate(true), choice_id))

func _select_choice(choice_data: Dictionary, choice_id: String) -> void:
    var values: Dictionary = choice_data.get("sets", {})
    for key in values.keys():
        State.story_flags[str(key)] = values[key]
    State.story_flags[choice_id + ".chosen"] = true
    waiting_choice = false
    State.save_game()
    _finish_scene()

func battle_result(victory: bool) -> void:
    awaiting_battle = false
    overlay.show()
    if victory:
        battle_done = true
        var encounter: Dictionary = _scene_data().get("encounter", {})
        var flag_name: String = str(encounter.get("win_flag", ""))
        if not flag_name.is_empty():
            State.story_flags[flag_name] = true
        _finish_scene()
    else:
        battle_done = false
        status.text = "战斗失败。可以整备后再次挑战。"
        next_button.disabled = false

func _finish_scene() -> void:
    var scene: Dictionary = _scene_data()
    for effect in scene.get("effects", []):
        if not (effect is Dictionary):
            continue
        var e: Dictionary = effect
        match str(e.get("type", "")):
            "set_flag":
                State.story_flags[str(e.get("key", ""))] = e.get("value", true)
            "grant":
                State.grant_rewards(maxi(0, int(e.get("xp", 0))), maxi(0, int(e.get("gold", 0))))
    State.story_scene += 1
    line_index = 0
    waiting_choice = false
    battle_done = false
    var count: int = _chapter_data().get("scenes", []).size()
    if State.story_scene >= count:
        if State.story_chapter == 0:
            State.story_flags["story.prologue_done"] = true
            State.story_chapter = 1
        elif State.story_chapter < 72:
            State.story_flags["story.ch%03d.done" % State.story_chapter] = true
            State.story_chapter += 1
        else:
            State.story_flags["story.ch072.done"] = true
            State.story_scene = maxi(0, count - 1)
            State.save_game()
            _render()
            return
        State.story_scene = 0
    State.save_game()
    _render()

func _render_finale() -> void:
    header.text = "终幕 · 星灯的未来"
    subtitle.text = "你所经历的十二幕旅途，终于迎来抉择。"
    next_button.disabled = true
    if not State.story_ending.is_empty():
        var selected: Dictionary = {}
        for ending in catalog.endings.get("endings", []):
            if ending is Dictionary and str(ending.get("id", "")) == State.story_ending:
                selected = ending
        dialogue.text = "【" + str(selected.get("title", "终章")) + "】\n\n" + str(selected.get("description", ""))
        for record in selected.get("epilogue", []):
            if record is Array and record.size() >= 2:
                dialogue.text += "\n\n" + str(record[0]) + "：" + str(record[1])
        status.text = "本地结局已保存。结局CG与演出仍在开发中。"
        return
    dialogue.text = "最终的选择将决定洛维恩的明天。"
    status.text = "请选择符合已达成条件的结局。"
    choice_box.show()
    for item in catalog.endings.get("endings", []):
        if not (item is Dictionary):
            continue
        var ending: Dictionary = item
        var ending_id: String = str(ending.get("id", ""))
        var eligible: bool = catalog.can_unlock_ending(ending_id, State.story_flags)
        var button := _button(choice_box, str(ending.get("title", "结局")) + ("" if eligible else "（尚未满足条件）"), Callable(self, "_select_ending").bind(ending_id))
        button.disabled = not eligible

func _select_ending(ending_id: String) -> void:
    if not catalog.can_unlock_ending(ending_id, State.story_flags):
        return
    State.story_ending = ending_id
    State.save_game()
    _render()

func _close() -> void:
    overlay.hide()
    closed.emit()
