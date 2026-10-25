extends CanvasLayer
## iPhone横屏优先的游戏界面：主标题 / 任务追踪 / 触屏移动 / 对白与选项 / 队伍菜单。
signal started(continue_game: bool)
signal move_changed(direction: Vector2)
signal action_pressed()
signal menu_pressed()
signal save_pressed()
signal potion_pressed()
signal rest_pressed()
signal dialogue_finished()
signal choice_picked(choice: Dictionary)
signal menu_dismissed()
signal adventure_book_requested()
signal atlas_requested()
const BLUE: Color = Color("0b1c32")
const GOLD: Color = Color("e6c47d")
var root: Control
var title_overlay: Control
var title_continue: Button
var hud: PanelContainer
var name_label: Label
var tracker: RichTextLabel
var party_line: Label
var dpad: Control
var act_button: Button
var menu_button: Button
var shortcut_button: Button
var dialog_layer: Control
var dialog_speaker: Label
var dialog_text: RichTextLabel
var dialog_portrait: TextureRect
var dialog_next: Button
var choice_area: VBoxContainer
var dialog_lines: Array = []
var dialog_index: int = 0
var choosing: bool = false
var menu_layer: Control
var menu_summary: RichTextLabel
var toast: Label
var active_dirs: Dictionary = {}

func _ready() -> void:
    layer = 15
    root = Control.new()
    root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    root.mouse_filter = Control.MOUSE_FILTER_IGNORE
    add_child(root)
    _build_hud()
    _build_controls()
    _build_dialog()
    _build_menu()
    _build_title()

func _panel_style(bg: Color = BLUE, border: Color = GOLD) -> StyleBoxFlat:
    var style := StyleBoxFlat.new()
    style.bg_color = bg
    style.border_color = border
    style.set_border_width_all(2)
    style.set_corner_radius_all(13)
    style.set_content_margin_all(14)
    return style

func _button(label_text: String, size: int = 20) -> Button:
    var button := Button.new()
    button.text = label_text
    button.custom_minimum_size.y = 50
    button.add_theme_font_size_override("font_size", size)
    button.add_theme_color_override("font_color", Color("f9efdd"))
    button.add_theme_stylebox_override("normal", _panel_style(Color("12283e"), Color("6889a0")))
    button.add_theme_stylebox_override("hover", _panel_style(Color("24506a"), GOLD))
    button.add_theme_stylebox_override("pressed", _panel_style(Color("1a4258"), GOLD))
    button.focus_mode = Control.FOCUS_NONE
    return button

func _full_screen(name: String, shade_alpha: float = 0.85) -> Control:
    var overlay := Control.new()
    overlay.name = name
    overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    overlay.mouse_filter = Control.MOUSE_FILTER_STOP
    var shade := ColorRect.new()
    shade.color = Color(0.015, 0.032, 0.06, shade_alpha)
    shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    shade.mouse_filter = Control.MOUSE_FILTER_STOP
    overlay.add_child(shade)
    root.add_child(overlay)
    return overlay

func _build_hud() -> void:
    hud = PanelContainer.new()
    hud.anchor_left = 0.015
    hud.anchor_right = 0.782
    hud.anchor_top = 0.025
    hud.anchor_bottom = 0.192
    hud.add_theme_stylebox_override("panel", _panel_style(Color(0.025, 0.075, 0.12, 0.90), Color("ac935d")))
    hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
    root.add_child(hud)
    var row := HBoxContainer.new()
    row.add_theme_constant_override("separation", 10)
    row.mouse_filter = Control.MOUSE_FILTER_IGNORE
    hud.add_child(row)
    name_label = Label.new()
    name_label.custom_minimum_size.x = 203
    name_label.add_theme_font_size_override("font_size", 19)
    name_label.add_theme_color_override("font_color", GOLD)
    name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
    name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    row.add_child(name_label)
    tracker = RichTextLabel.new()
    tracker.bbcode_enabled = true
    tracker.scroll_active = false
    tracker.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    tracker.mouse_filter = Control.MOUSE_FILTER_IGNORE
    tracker.add_theme_font_size_override("normal_font_size", 16)
    row.add_child(tracker)
    party_line = Label.new()
    party_line.custom_minimum_size.x = 170
    party_line.add_theme_font_size_override("font_size", 15)
    party_line.mouse_filter = Control.MOUSE_FILTER_IGNORE
    row.add_child(party_line)

func _build_controls() -> void:
    dpad = Control.new()
    dpad.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
    dpad.offset_left = 20
    dpad.offset_right = 207
    dpad.offset_top = -215
    dpad.offset_bottom = -16
    dpad.mouse_filter = Control.MOUSE_FILTER_IGNORE
    root.add_child(dpad)
    _direction("↑", "up", Vector2(0, -1), Vector2(64, 0))
    _direction("←", "left", Vector2(-1, 0), Vector2(0, 61))
    _direction("→", "right", Vector2(1, 0), Vector2(128, 61))
    _direction("↓", "down", Vector2(0, 1), Vector2(64, 122))
    act_button = _button("✦ 调查 / 对话", 18)
    act_button.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
    act_button.offset_left = -195
    act_button.offset_right = -15
    act_button.offset_top = -99
    act_button.offset_bottom = -28
    act_button.pressed.connect(func() -> void: action_pressed.emit())
    root.add_child(act_button)
    menu_button = _button("☰ 指令", 17)
    menu_button.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
    menu_button.offset_left = -195
    menu_button.offset_right = -15
    menu_button.offset_top = -168
    menu_button.offset_bottom = -111
    menu_button.pressed.connect(func() -> void: menu_pressed.emit())
    root.add_child(menu_button)
    shortcut_button = _button("✦ 冒险书", 17)
    shortcut_button.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
    shortcut_button.offset_left = -342
    shortcut_button.offset_right = -207
    shortcut_button.offset_top = -168
    shortcut_button.offset_bottom = -111
    shortcut_button.pressed.connect(func() -> void: adventure_book_requested.emit())
    root.add_child(shortcut_button)
    toast = Label.new()
    toast.anchor_left = 0.29
    toast.anchor_right = 0.71
    toast.anchor_top = 0.79
    toast.anchor_bottom = 0.88
    toast.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    toast.add_theme_font_size_override("font_size", 18)
    toast.add_theme_color_override("font_color", GOLD)
    toast.hide()
    root.add_child(toast)

func _direction(symbol: String, key: String, vector: Vector2, position: Vector2) -> void:
    var button := _button(symbol, 30)
    button.position = position
    button.size = Vector2(58, 57)
    dpad.add_child(button)
    button.button_down.connect(func() -> void:
        active_dirs[key] = vector
        _emit_movement()
    )
    button.button_up.connect(func() -> void:
        active_dirs.erase(key)
        _emit_movement()
    )

func _emit_movement() -> void:
    var total := Vector2.ZERO
    for vec in active_dirs.values():
        total += vec
    move_changed.emit(total.normalized())

func clear_movement() -> void:
    active_dirs.clear()
    _emit_movement()

func set_hud(chapter: int, location: String, objective: String, actors: Array[Dictionary], gold: int, potions: int) -> void:
    var act_number: int = int((chapter - 1) / 6) + 1 if chapter > 0 else 0
    name_label.text = "✦ %s\n%s" % ["序章 · 记忆之灯" if chapter == 0 else "第%d幕 · 第%d章" % [act_number,chapter], location]
    tracker.text = "[color=#e6c47d]◆ 当前目标[/color]\n" + objective
    var values := PackedStringArray()
    for member in actors:
        values.append("%s %d/%d" % [str(member.get("name","")),int(member.get("hp",0)),int(member.get("max_hp",1))])
    party_line.text = "队伍 · %d人\n%d G  ·  药草 %d" % [values.size(), gold, potions]
    party_line.tooltip_text = "HP / " + "  ".join(values)

func show_message(text_value: String) -> void:
    toast.text = text_value
    toast.show()
    var timer: SceneTreeTimer = get_tree().create_timer(2.5)
    timer.timeout.connect(func() -> void:
        if is_instance_valid(toast) and toast.text == text_value:
            toast.hide()
    )

func _build_dialog() -> void:
    dialog_layer = _full_screen("StoryDialogue", 0.44)
    var panel := PanelContainer.new()
    panel.anchor_left = 0.055
    panel.anchor_right = 0.945
    panel.anchor_top = 0.51
    panel.anchor_bottom = 0.975
    panel.add_theme_stylebox_override("panel", _panel_style(Color("101e34"), GOLD))
    dialog_layer.add_child(panel)
    var row := HBoxContainer.new()
    row.add_theme_constant_override("separation", 16)
    panel.add_child(row)
    dialog_portrait = TextureRect.new()
    dialog_portrait.custom_minimum_size = Vector2(170, 235)
    dialog_portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
    dialog_portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
    dialog_portrait.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
    row.add_child(dialog_portrait)
    var content := VBoxContainer.new()
    content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    content.add_theme_constant_override("separation", 7)
    row.add_child(content)
    dialog_speaker = Label.new()
    dialog_speaker.add_theme_font_size_override("font_size", 23)
    dialog_speaker.add_theme_color_override("font_color", GOLD)
    content.add_child(dialog_speaker)
    dialog_text = RichTextLabel.new()
    dialog_text.bbcode_enabled = false
    dialog_text.scroll_active = true
    dialog_text.size_flags_vertical = Control.SIZE_EXPAND_FILL
    dialog_text.add_theme_font_size_override("normal_font_size", 23)
    content.add_child(dialog_text)
    choice_area = VBoxContainer.new()
    choice_area.add_theme_constant_override("separation", 5)
    content.add_child(choice_area)
    dialog_next = _button("继续  ▸", 18)
    dialog_next.custom_minimum_size.x = 168
    dialog_next.size_flags_horizontal = Control.SIZE_SHRINK_END
    dialog_next.pressed.connect(_next)
    content.add_child(dialog_next)
    dialog_layer.hide()

func show_dialogue(lines: Array) -> void:
    dialog_lines = lines.duplicate(true)
    dialog_index = 0
    choosing = false
    choice_area.hide()
    dialog_next.show()
    clear_movement()
    dialog_layer.show()
    _render_line()

func _portrait_for(speaker: String) -> String:
    if speaker.contains("岚音"):
        return "res://assets/art/characters/lanyin/dialogue.png"
    if speaker.contains("朔弦"):
        return "res://assets/art/characters/shuoxian/dialogue.png"
    if speaker.contains("澄舟"):
        return "res://assets/art/characters/chengzhou/dialogue.png"
    if speaker.contains("黎昂") or speaker.contains("主角"):
        return "res://assets/art/characters/leon/dialogue.png"
    return "res://assets/art/characters/chengzhou/dialogue.png"

func _render_line() -> void:
    if dialog_lines.is_empty():
        dialog_speaker.text = "旁白"
        dialog_text.text = "……"
        return
    var item: Dictionary = dialog_lines[dialog_index]
    var speaker: String = str(item.get("speaker", "旁白"))
    dialog_speaker.text = speaker
    dialog_text.text = str(item.get("text", ""))
    var path: String = _portrait_for(speaker)
    dialog_portrait.visible = speaker != "旁白" and ResourceLoader.exists(path)
    if dialog_portrait.visible:
        dialog_portrait.texture = load(path)
    dialog_next.text = "结束  ▸" if dialog_index == dialog_lines.size() - 1 else "继续  ▸"

func _next() -> void:
    if choosing:
        return
    dialog_index += 1
    if dialog_index >= dialog_lines.size():
        dialog_layer.hide()
        dialogue_finished.emit()
    else:
        _render_line()

func show_choices(choice_data: Dictionary) -> void:
    choosing = true
    dialog_layer.show()
    choice_area.show()
    dialog_next.hide()
    dialog_speaker.text = "旅途的抉择"
    dialog_text.text = str(choice_data.get("prompt", "现在你决定怎样做？"))
    for child in choice_area.get_children():
        choice_area.remove_child(child)
        child.queue_free()
    for option in choice_data.get("options", []):
        if not option is Dictionary:
            continue
        var item: Dictionary = option
        var button := _button(str(item.get("label", "继续")), 18)
        button.disabled = bool(item.get("locked", false))
        button.tooltip_text = str(item.get("locked_reason", ""))
        button.pressed.connect(func() -> void:
            choosing = false
            choice_area.hide()
            dialog_layer.hide()
            choice_picked.emit(item)
        )
        choice_area.add_child(button)

func _build_menu() -> void:
    menu_layer = _full_screen("CampMenu", 0.84)
    var panel := PanelContainer.new()
    panel.anchor_left = 0.23
    panel.anchor_right = 0.77
    panel.anchor_top = 0.05
    panel.anchor_bottom = 0.95
    panel.add_theme_stylebox_override("panel", _panel_style())
    menu_layer.add_child(panel)
    var scroller := ScrollContainer.new()
    panel.add_child(scroller)
    var flow := VBoxContainer.new()
    flow.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    flow.add_theme_constant_override("separation", 10)
    scroller.add_child(flow)
    var title := Label.new()
    title.text = "✦ 灯行者 · 旅途指令"
    title.add_theme_font_size_override("font_size", 27)
    title.add_theme_color_override("font_color", GOLD)
    flow.add_child(title)
    menu_summary = RichTextLabel.new()
    menu_summary.bbcode_enabled = true
    menu_summary.custom_minimum_size.y = 150
    menu_summary.add_theme_font_size_override("normal_font_size", 19)
    flow.add_child(menu_summary)
    var command_grid := GridContainer.new()
    command_grid.columns = 2
    command_grid.add_theme_constant_override("h_separation", 10)
    command_grid.add_theme_constant_override("v_separation", 10)
    flow.add_child(command_grid)
    for label_text in ["✦ 冒险手册", "◇ 航路地图", "✚ 使用药草", "✧ 营地休息（30G）", "▣ 保存旅程", "↩ 返回探索"]:
        var b := _button(label_text,17)
        b.custom_minimum_size.y = 56
        b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
        command_grid.add_child(b)
        match label_text:
            "✦ 冒险手册": b.pressed.connect(func() -> void: adventure_book_requested.emit())
            "◇ 航路地图": b.pressed.connect(func() -> void: atlas_requested.emit())
            "✚ 使用药草": b.pressed.connect(func() -> void: potion_pressed.emit())
            "✧ 营地休息（30G）": b.pressed.connect(func() -> void: rest_pressed.emit())
            "▣ 保存旅程": b.pressed.connect(func() -> void: save_pressed.emit())
            _: b.pressed.connect(close_menu)
    menu_layer.hide()

func show_menu(actors: Array[Dictionary], gold: int, potions: int) -> void:
    var lines: PackedStringArray = []
    for person in actors:
        lines.append("[color=#e6c47d]%s  Lv.%d[/color]  HP %d/%d  MP %d/%d  物攻 %d  防御 %d" % [str(person["name"]), int(person["level"]), int(person["hp"]), int(person["max_hp"]), int(person["mp"]), int(person["max_mp"]), int(person["attack"]), int(person["defense"])])
    lines.append("\n持有金币：%d    药草：%d" % [gold, potions])
    menu_summary.text = "\n".join(lines)
    clear_movement()
    menu_layer.show()

func close_menu() -> void:
    menu_layer.hide()
    menu_dismissed.emit()

func _build_title() -> void:
    title_overlay = _full_screen("TitleScreen", 0.34)
    var illustration := TextureRect.new()
    illustration.texture = load("res://assets/art/backdrops/coast/tide_lighthouse.png")
    illustration.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    illustration.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
    illustration.stretch_mode = TextureRect.STRETCH_SCALE
    title_overlay.add_child(illustration)
    var veil := ColorRect.new()
    veil.color = Color(0.02, 0.06, 0.10, 0.58)
    veil.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    title_overlay.add_child(veil)
    var center := VBoxContainer.new()
    center.anchor_left = 0.29
    center.anchor_right = 0.71
    center.anchor_top = 0.23
    center.anchor_bottom = 0.83
    center.alignment = BoxContainer.ALIGNMENT_CENTER
    center.add_theme_constant_override("separation", 15)
    title_overlay.add_child(center)
    var title := Label.new()
    title.text = "星 灯 纪 行"
    title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    title.add_theme_font_size_override("font_size", 51)
    title.add_theme_color_override("font_color", GOLD)
    center.add_child(title)
    var sub := Label.new()
    sub.text = "ST★RLIT CHRONICLE   ·   十二幕七十二章  /  星空航路"
    sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    sub.add_theme_font_size_override("font_size", 17)
    center.add_child(sub)
    title_continue = _button("继续旅程", 21)
    title_continue.pressed.connect(func() -> void:
        title_overlay.hide()
        started.emit(true)
    )
    center.add_child(title_continue)
    var new_game := _button("新的旅程", 21)
    new_game.pressed.connect(func() -> void:
        title_overlay.hide()
        started.emit(false)
    )
    center.add_child(new_game)
    var foot := Label.new()
    foot.text = "原创剧情 · 离线存档 · iPhone横屏"
    foot.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    center.add_child(foot)

func show_title(has_save: bool) -> void:
    title_continue.disabled = not has_save
    title_overlay.show()

func set_play_visible(value: bool) -> void:
    hud.visible = value
    dpad.visible = value
    act_button.visible = value
    menu_button.visible = value
    shortcut_button.visible = value
    if not value:
        clear_movement()
