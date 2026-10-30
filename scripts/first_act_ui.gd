extends CanvasLayer
const ArtAssets = preload("res://scripts/art_assets.gd")
const ArtOverrides = preload("res://scripts/c_art_overrides.gd")
const ArtManagerUI = preload("res://scripts/c_art_manager_ui.gd")
const CVisual = preload("res://scripts/c_visual_design.gd")
const DTitleScreen = preload("res://scripts/d_title_screen.gd")
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
var art_manager: ArtManagerUI
var title_illustration: TextureRect
var title_continue: Button
var title_status: Label
var hud: PanelContainer
var name_label: Label
var tracker: RichTextLabel
var party_line: Label
var status_frame: PanelContainer
var status_rows: RichTextLabel
var dpad: Control
# Dynamic multi-touch joystick, independent of the legacy fixed D-pad.
const STICK_SIZE: float = 144.0
const STICK_KNOB_SIZE: float = 50.0
const STICK_TRAVEL: float = 54.0
const STICK_DEADZONE: float = 10.0
var floating_stick: Control
var floating_knob: Panel
var stick_touch_id: int = -1
var stick_origin: Vector2 = Vector2.ZERO
var stick_vector: Vector2 = Vector2.ZERO
var act_button: Button
var menu_button: Button
var shortcut_button: Button
var dialog_layer: Control
var dialog_speaker: Label
var dialog_text: RichTextLabel
var evidence_art: TextureRect
var dialog_portrait: TextureRect
var dialog_next: Button
var dialog_actions: HBoxContainer
var dialog_auto_button: Button
var dialog_history_button: Button
var dialog_skip_button: Button
var dialog_history_screen: Control
var dialog_history_text: RichTextLabel
var dialogue_auto: bool = false
var dialogue_can_skip: bool = false
var dialogue_count: float = 0.0
var auto_wait: float = 0.0
var dialogue_speed: float = 42.0
var dialogue_history: Array[Dictionary] = []
var choice_area: VBoxContainer
var dialog_lines: Array = []
var dialog_index: int = 0
var choosing: bool = false
var menu_layer: Control
var menu_summary: RichTextLabel
var toast: Label
var active_dirs: Dictionary = {}
var dialogue_panel: PanelContainer
var camp_panel: PanelContainer
var camp_commands: GridContainer
var _hud_accent: Color = GOLD
var _touch_mode: bool = false
var _playing: bool = false
var _interaction_hint: String = ""
var interaction_label: Label
var status_toggle: Button
var status_expanded: bool = false
var _party_detail_lines: PackedStringArray = PackedStringArray()

func _ready() -> void:
    layer = 15
    _touch_mode = OS.has_feature("mobile") or DisplayServer.is_touchscreen_available()
    root = Control.new()
    root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    root.mouse_filter = Control.MOUSE_FILTER_IGNORE
    add_child(root)
    _build_hud()
    _build_controls()
    _build_dialog()
    _build_menu()
    _build_title()
    _build_dialogue_history()
    get_viewport().size_changed.connect(_reflow_layout)
    call_deferred("_reflow_layout")

func _panel_style(bg: Color = BLUE, border: Color = GOLD) -> StyleBoxFlat:
    return CVisual.frame(bg, border, 13, 14)

func _button(label_text: String, size: int = 20) -> Button:
    var button := Button.new()
    button.text = label_text
    button.custom_minimum_size.y = 50
    button.add_theme_font_size_override("font_size", size)
    button.add_theme_color_override("font_color", Color("f9efdd"))
    button.add_theme_stylebox_override("normal", _panel_style(Color("12283e"), Color("6889a0")))
    button.add_theme_stylebox_override("hover", _panel_style(Color("24506a"), GOLD))
    button.add_theme_stylebox_override("pressed", _panel_style(Color("1a4258"), GOLD))
    CVisual.style_button(button)
    button.focus_mode = Control.FOCUS_ALL
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
    hud.anchor_left = 0.018
    hud.anchor_right = 0.575
    hud.anchor_top = 0.018
    hud.anchor_bottom = 0.125
    hud.add_theme_stylebox_override("panel", CVisual.surface(true))
    hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
    root.add_child(hud)
    var row := HBoxContainer.new()
    row.add_theme_constant_override("separation", 10)
    row.mouse_filter = Control.MOUSE_FILTER_IGNORE
    hud.add_child(row)
    name_label = Label.new()
    name_label.custom_minimum_size.x = 120
    name_label.add_theme_font_size_override("font_size", 16)
    name_label.add_theme_color_override("font_color", CVisual.GOLD)
    name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
    name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    row.add_child(name_label)
    tracker = RichTextLabel.new()
    tracker.bbcode_enabled = true
    tracker.scroll_active = false
    tracker.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    tracker.mouse_filter = Control.MOUSE_FILTER_IGNORE
    tracker.add_theme_font_size_override("normal_font_size", 13)
    tracker.tooltip_text = "当前主线目标"
    row.add_child(tracker)
    party_line = Label.new()
    party_line.custom_minimum_size.x = 0
    party_line.mouse_filter = Control.MOUSE_FILTER_IGNORE
    row.add_child(party_line)
    party_line.hide() # Gold and consumables belong in the adventure menu.
    # Readable HP/MP command window, distinct from the quest tracker and minimap.
    status_frame = PanelContainer.new()
    status_frame.anchor_left = 0.018
    status_frame.anchor_right = 0.235
    status_frame.anchor_top = 0.858
    status_frame.anchor_bottom = 0.961
    status_frame.add_theme_stylebox_override("panel",CVisual.surface(false))
    status_frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
    root.add_child(status_frame)
    status_rows = RichTextLabel.new()
    status_rows.bbcode_enabled = true
    status_rows.scroll_active = false
    status_rows.add_theme_font_size_override("normal_font_size",14)
    status_rows.mouse_filter = Control.MOUSE_FILTER_IGNORE
    var status_column := VBoxContainer.new()
    status_column.add_theme_constant_override("separation",3)
    status_frame.add_child(status_column)
    status_toggle = Button.new()
    status_toggle.text = "队伍状态  ▾"
    status_toggle.custom_minimum_size.y = 28
    status_toggle.add_theme_font_size_override("font_size",12)
    CVisual.style_button(status_toggle)
    status_toggle.pressed.connect(_toggle_status)
    status_column.add_child(status_toggle)
    status_column.add_child(status_rows)

func _toggle_status() -> void:
    status_expanded = not status_expanded
    status_toggle.text = "队伍状态  ▴" if status_expanded else "队伍状态  ▾"
    _refresh_status_rows()
    _reflow_layout()

func _refresh_status_rows() -> void:
    if status_rows == null:
        return
    status_rows.text = "\n".join(_party_detail_lines) if status_expanded else (_party_detail_lines[0] if not _party_detail_lines.is_empty() else "")
    status_rows.tooltip_text = "\n".join(_party_detail_lines)

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
    _build_floating_stick()
    act_button = _button("✦ 调查", 16)
    act_button.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
    act_button.offset_left = -154
    act_button.offset_right = -16
    act_button.offset_top = -91
    act_button.offset_bottom = -38
    act_button.pressed.connect(func() -> void: action_pressed.emit())
    root.add_child(act_button)
    menu_button = _button("☰", 16)
    menu_button.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
    menu_button.offset_left = -75
    menu_button.offset_right = -16
    menu_button.offset_top = -147
    menu_button.offset_bottom = -94
    menu_button.pressed.connect(func() -> void: menu_pressed.emit())
    root.add_child(menu_button)
    shortcut_button = _button("✦ 冒险书", 16)
    shortcut_button.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
    shortcut_button.offset_left = -216
    shortcut_button.offset_right = -86
    shortcut_button.offset_top = -147
    shortcut_button.offset_bottom = -94
    shortcut_button.pressed.connect(func() -> void: adventure_book_requested.emit())
    root.add_child(shortcut_button)
    interaction_label = Label.new()
    interaction_label.anchor_left = 0.36
    interaction_label.anchor_right = 0.66
    interaction_label.anchor_top = 0.909
    interaction_label.anchor_bottom = 0.968
    interaction_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    interaction_label.add_theme_font_size_override("font_size", 16)
    interaction_label.add_theme_color_override("font_color", CVisual.PAPER)
    interaction_label.add_theme_color_override("font_shadow_color", Color(0,0,0,0.9))
    interaction_label.add_theme_constant_override("shadow_offset_y", 2)
    interaction_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
    root.add_child(interaction_label)
    toast = Label.new()
    toast.anchor_left = 0.30
    toast.anchor_right = 0.70
    toast.anchor_top = 0.175
    toast.anchor_bottom = 0.235
    toast.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    toast.add_theme_font_size_override("font_size", 18)
    toast.add_theme_color_override("font_color", GOLD)
    toast.hide()
    root.add_child(toast)

func _stick_style(background: Color, outline: Color, radius: int) -> StyleBoxFlat:
    var style := StyleBoxFlat.new()
    style.bg_color = background
    style.border_color = outline
    style.set_border_width_all(2)
    style.set_corner_radius_all(radius)
    style.anti_aliasing = true
    return style

func _build_floating_stick() -> void:
    floating_stick = Control.new()
    floating_stick.name = "FloatingTouchStick"
    floating_stick.size = Vector2.ONE * STICK_SIZE
    floating_stick.mouse_filter = Control.MOUSE_FILTER_IGNORE
    root.add_child(floating_stick)
    var ring := Panel.new()
    ring.size = floating_stick.size
    ring.mouse_filter = Control.MOUSE_FILTER_IGNORE
    ring.add_theme_stylebox_override("panel", _stick_style(Color(0.06, 0.13, 0.22, 0.34), Color(0.90, 0.77, 0.49, 0.80), int(STICK_SIZE * 0.5)))
    floating_stick.add_child(ring)
    floating_knob = Panel.new()
    floating_knob.size = Vector2.ONE * STICK_KNOB_SIZE
    floating_knob.position = (floating_stick.size - floating_knob.size) * 0.5
    floating_knob.mouse_filter = Control.MOUSE_FILTER_IGNORE
    floating_knob.add_theme_stylebox_override("panel", _stick_style(Color(0.92, 0.79, 0.52, 0.55), GOLD, int(STICK_KNOB_SIZE * 0.5)))
    floating_stick.add_child(floating_knob)
    floating_stick.hide()

func _stick_can_start() -> bool:
    # Main2's PC-first HUD only exposes touch movement on mobile/touch screens.
    if not _playing or not _touch_mode or dpad == null or not dpad.visible:
        return false
    for overlay in [title_overlay, dialog_layer, dialog_history_screen, menu_layer]:
        if overlay != null and overlay.visible:
            return false
    return true

func _touch_hits_buttons(point: Vector2) -> bool:
    # GUI handles touch after _input, so guard all visible controls explicitly.
    for button in [act_button, menu_button, shortcut_button, status_toggle]:
        if button != null and button.visible and button.get_global_rect().has_point(point):
            return true
    for button in dpad.get_children():
        if button is Control and button.visible and button.get_global_rect().has_point(point):
            return true
    return false

func _update_floating_stick(point: Vector2) -> void:
    var offset: Vector2 = point - stick_origin
    var travel: Vector2 = offset.limit_length(STICK_TRAVEL)
    floating_knob.position = (floating_stick.size - floating_knob.size) * 0.5 + travel
    var length: float = offset.length()
    if length <= STICK_DEADZONE:
        stick_vector = Vector2.ZERO
    else:
        var strength: float = minf(1.0, (length - STICK_DEADZONE) / (STICK_TRAVEL - STICK_DEADZONE))
        stick_vector = offset.normalized() * strength
    _emit_movement()

func _stop_floating_stick() -> void:
    stick_touch_id = -1
    stick_origin = Vector2.ZERO
    stick_vector = Vector2.ZERO
    if floating_stick != null:
        floating_stick.hide()

func _input(event: InputEvent) -> void:
    if stick_touch_id == -1:
        return
    if event is InputEventScreenDrag and event.index == stick_touch_id:
        if not _stick_can_start():
            _stop_floating_stick()
            _emit_movement()
        else:
            _update_floating_stick(event.position)
        get_viewport().set_input_as_handled()
    elif event is InputEventScreenTouch and event.index == stick_touch_id and not event.pressed:
        _stop_floating_stick()
        _emit_movement()
        get_viewport().set_input_as_handled()

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
    var total: Vector2 = stick_vector
    for vec in active_dirs.values():
        total += vec
    move_changed.emit(total.limit_length(1.0))

func clear_movement() -> void:
    active_dirs.clear()
    _stop_floating_stick()
    _emit_movement()

func set_interaction_hint(hint: String) -> void:
    if hint == _interaction_hint:
        return
    _interaction_hint = hint
    interaction_label.text = "E · " + hint if not hint.is_empty() else ""
    act_button.text = "✦ " + hint.left(7)
    _update_explore_controls()

func _update_explore_controls() -> void:
    if dpad == null or interaction_label == null:
        return
    dpad.visible = _playing and _touch_mode
    act_button.visible = _playing and _touch_mode and not _interaction_hint.is_empty()
    shortcut_button.visible = false
    menu_button.visible = _playing
    interaction_label.visible = _playing and not _touch_mode and not _interaction_hint.is_empty()
    if not dpad.visible and (not active_dirs.is_empty() or stick_touch_id != -1):
        clear_movement()

func set_hud(chapter: int, location: String, objective: String, actors: Array[Dictionary], gold: int, potions: int) -> void:
    var act_number: int = int((chapter - 1) / 6) + 1 if chapter > 0 else 0
    _hud_accent = CVisual.act_accent(chapter)
    hud.add_theme_stylebox_override("panel", CVisual.surface(true,chapter))
    name_label.add_theme_color_override("font_color",_hud_accent)
    # Keep the chapter/location two-line label readable in a 120px HUD.
    # The detailed area name remains available from the minimap and tracker.
    var short_location: String = location.get_slice("（", 0).strip_edges().left(7)
    name_label.text = "%s\n%s" % ["序章" if chapter == 0 else "第%d幕 · %d章" % [act_number,chapter], short_location]
    tracker.text = "[color=#%s]◆ 目标[/color]  %s" % [_hud_accent.to_html(false),objective.split("\n")[0].left(46)]
    tracker.tooltip_text = objective
    var values := PackedStringArray()
    for member in actors:
        values.append("%s %d/%d" % [str(member.get("name","")),int(member.get("hp",0)),int(member.get("max_hp",1))])
    party_line.text = "队伍 · %d人\n%d G  ·  药草 %d" % [values.size(), gold, potions]
    var detailed := PackedStringArray()
    for member in actors:
        var hp: int = int(member.get("hp",0))
        var cap: int = maxi(1,int(member.get("max_hp",1)))
        var color: String = "#f6a4a4" if hp * 4 <= cap else "#d7eaf1"
        detailed.append("[color=%s]%s Lv%d[/color]  HP%d/%d  MP%d" % [color,str(member.get("name","")).left(4),int(member.get("level",1)),hp,cap,int(member.get("mp",0))])
    _party_detail_lines = detailed
    _refresh_status_rows()

func show_message(text_value: String) -> void:
    toast.text = text_value
    toast.show()
    var timer: SceneTreeTimer = get_tree().create_timer(2.5)
    timer.timeout.connect(func() -> void:
        if is_instance_valid(toast) and toast.text == text_value:
            toast.hide()
    )

func _build_dialog() -> void:
    dialog_layer = _full_screen("StoryDialogue", 0.22)
    dialogue_panel = PanelContainer.new()
    var panel: PanelContainer = dialogue_panel
    panel.anchor_left = 0.055
    panel.anchor_right = 0.945
    panel.anchor_top = 0.51
    panel.anchor_bottom = 0.975
    panel.add_theme_stylebox_override("panel", CVisual.surface(true))
    dialog_layer.add_child(panel)
    var row := HBoxContainer.new()
    row.add_theme_constant_override("separation", 16)
    panel.add_child(row)
    dialog_portrait = TextureRect.new()
    dialog_portrait.custom_minimum_size = Vector2(146, 185)
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
    dialog_speaker.add_theme_color_override("font_color", CVisual.GOLD)
    content.add_child(dialog_speaker)
    evidence_art = TextureRect.new()
    evidence_art.name = "CanonicalEvidenceCloseup"
    evidence_art.custom_minimum_size = Vector2(0,108)
    evidence_art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
    evidence_art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
    evidence_art.mouse_filter = Control.MOUSE_FILTER_IGNORE
    evidence_art.hide()
    content.add_child(evidence_art)
    dialog_text = RichTextLabel.new()
    dialog_text.bbcode_enabled = false
    dialog_text.scroll_active = true
    dialog_text.size_flags_vertical = Control.SIZE_EXPAND_FILL
    dialog_text.add_theme_font_size_override("normal_font_size", 21)
    content.add_child(dialog_text)
    choice_area = VBoxContainer.new()
    choice_area.add_theme_constant_override("separation", 5)
    content.add_child(choice_area)
    dialog_next = _button("继续  ▸", 18)
    dialog_next.custom_minimum_size.x = 168
    dialog_next.size_flags_horizontal = Control.SIZE_SHRINK_END
    dialog_next.pressed.connect(_next)
    dialog_actions = HBoxContainer.new()
    var footer_actions: HBoxContainer = dialog_actions
    footer_actions.add_theme_constant_override("separation",7)
    content.add_child(footer_actions)
    footer_actions.add_child(dialog_next)
    dialog_auto_button=_button("自动播放：关",15)
    dialog_auto_button.pressed.connect(func() -> void:
        dialogue_auto=not dialogue_auto
        dialog_auto_button.text="自动播放：开" if dialogue_auto else "自动播放：关"
    )
    footer_actions.add_child(dialog_auto_button)
    dialog_history_button=_button("对话回顾",15)
    dialog_history_button.pressed.connect(_show_dialogue_history)
    footer_actions.add_child(dialog_history_button)
    dialog_skip_button=_button("跳过已读",15)
    dialog_skip_button.pressed.connect(_skip_seen_dialogue)
    footer_actions.add_child(dialog_skip_button)
    dialog_layer.hide()

func show_dialogue(lines: Array, allow_seen_skip: bool = false) -> void:
    dialog_lines = lines.duplicate(true)
    dialog_index = 0
    dialogue_can_skip=allow_seen_skip
    dialog_skip_button.visible=allow_seen_skip
    dialogue_count=0.0
    auto_wait=0.0
    choosing = false
    choice_area.hide()
    evidence_art.hide()
    dialog_actions.show()
    dialog_next.show()
    clear_movement()
    dialog_layer.show()
    _render_line()
    _reflow_layout()

func _portrait_for(speaker: String) -> String:
    return ArtAssets.dialogue_portrait(speaker)

func _render_line() -> void:
    if dialog_lines.is_empty():
        dialog_speaker.text = "旁白"
        dialog_text.text = "……"
        return
    var item: Dictionary = dialog_lines[dialog_index]
    var speaker: String = str(item.get("speaker", "旁白"))
    dialog_speaker.text = speaker
    dialog_text.text = str(item.get("text", ""))
    dialog_text.visible_characters=0
    dialogue_count=0.0
    auto_wait=0.0
    var path: String = _portrait_for(speaker)
    dialog_portrait.visible = speaker != "旁白" and ArtOverrides.exists(path) and get_viewport().get_visible_rect().size.x >= 880.0
    if dialog_portrait.visible:
        dialog_portrait.texture = ArtOverrides.texture(path)
    dialog_next.text = "结束  ▸" if dialog_index == dialog_lines.size() - 1 else "继续  ▸"

func _next() -> void:
    if choosing:
        return
    if dialog_text.visible_characters >= 0 and dialog_text.visible_characters < dialog_text.get_total_character_count():
        dialog_text.visible_characters=-1
        auto_wait=0.0
        # Headless controller tests advance dialogue instantly without waiting
        # for frame animation; real keyboard/touch play retains reveal-first.
        if DisplayServer.get_name() != "headless":
            return
    if dialog_index >= 0 and dialog_index < dialog_lines.size():
        dialogue_history.append(dialog_lines[dialog_index].duplicate(true))
        if dialogue_history.size()>240:
            dialogue_history.pop_front()
    dialog_index += 1
    if dialog_index >= dialog_lines.size():
        dialog_layer.hide()
        dialogue_finished.emit()
    else:
        _render_line()

func show_choices(choice_data: Dictionary) -> void:
    evidence_art.hide()
    evidence_art.texture = null
    dialog_portrait.hide()
    dialog_actions.hide()
    choosing = true
    dialog_text.visible_characters=-1
    dialog_layer.show()
    choice_area.show()
    _reflow_layout()
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
        var button := _button(str(item.get("label", "继续")), 16)
        button.custom_minimum_size.y = 40 if get_viewport().get_visible_rect().size.y < 610.0 else 48
        button.disabled = bool(item.get("locked", false))
        button.tooltip_text = str(item.get("locked_reason", ""))
        button.pressed.connect(func() -> void:
            choosing = false
            choice_area.hide()
            dialog_layer.hide()
            choice_picked.emit(item)
        )
        choice_area.add_child(button)


func show_evidence_choices(evidence_id: String, choice_data: Dictionary) -> void:
    # Visual-only: actual hotspots and V3 fact/uncertainty receipts remain
    # owned by StarlightJournal / first_act. Never infer a clue from the SVG.
    show_choices(choice_data)
    var supported: Dictionary = {
        "ev_ch001_envelope":"ev_ch001_envelope.svg",
        "ev_ch003_half_badge":"ev_ch003_half_badge.svg",
        "ev_ch007_rejected_letters":"ev_ch007_rejected_letters.svg",
        "ev_ch008_caravan_site":"ev_ch008_caravan_site.svg"
    }
    if not supported.has(evidence_id):
        return
    var path: String = "res://assets/art/ui/evidence/" + str(supported[evidence_id])
    if not ResourceLoader.exists(path):
        return
    var illustration: Resource = load(path)
    if illustration is Texture2D:
        evidence_art.texture = illustration as Texture2D
        evidence_art.show()
        _reflow_layout()

func _process(delta: float) -> void:
    if dialog_history_screen != null and dialog_history_screen.visible:
        return
    if dialog_layer == null or not dialog_layer.visible or choosing:
        return
    var count: int=dialog_text.get_total_character_count()
    if dialog_text.visible_characters>=0 and dialog_text.visible_characters<count:
        dialogue_count+=delta*dialogue_speed
        dialog_text.visible_characters=mini(count,int(dialogue_count))
        auto_wait=0.0
    elif dialogue_auto:
        auto_wait+=delta
        if auto_wait>=1.7:
            auto_wait=0.0
            _next()

func _unhandled_input(event: InputEvent) -> void:
    if event is InputEventScreenTouch:
        if event.pressed and stick_touch_id == -1 and _stick_can_start() and not _touch_hits_buttons(event.position):
            stick_touch_id = event.index
            stick_origin = event.position
            floating_stick.position = stick_origin - floating_stick.size * 0.5
            floating_stick.show()
            _update_floating_stick(event.position)
            get_viewport().set_input_as_handled()
        return
    if not event is InputEventKey or not event.pressed or event.echo:
        return
    if dialog_history_screen != null and dialog_history_screen.visible:
        if event.keycode==KEY_ESCAPE:
            dialog_history_screen.hide()
            get_viewport().set_input_as_handled()
        return
    if dialog_layer!=null and dialog_layer.visible and not choosing and event.keycode in [KEY_SPACE,KEY_ENTER,KEY_Z]:
        _next()
        get_viewport().set_input_as_handled()

func _skip_seen_dialogue() -> void:
    if not dialogue_can_skip or choosing or not dialog_layer.visible:
        return
    # An already completed dialogue may be skipped, but its effects are still
    # executed by the original story controller's completion handler.
    dialog_layer.hide()
    dialogue_finished.emit()

func _build_dialogue_history() -> void:
    dialog_history_screen=_full_screen("DialogueHistory",0.93)
    var panel:=PanelContainer.new()
    panel.anchor_left=0.14
    panel.anchor_right=0.86
    panel.anchor_top=0.08
    panel.anchor_bottom=0.91
    panel.add_theme_stylebox_override("panel",_panel_style())
    dialog_history_screen.add_child(panel)
    var column:=VBoxContainer.new()
    column.add_theme_constant_override("separation",10)
    panel.add_child(column)
    var label:=Label.new()
    label.text="星灯手记 · 对话回顾"
    label.add_theme_font_size_override("font_size",26)
    label.add_theme_color_override("font_color",GOLD)
    column.add_child(label)
    dialog_history_text=RichTextLabel.new()
    dialog_history_text.bbcode_enabled=false
    dialog_history_text.size_flags_vertical=Control.SIZE_EXPAND_FILL
    dialog_history_text.add_theme_font_size_override("normal_font_size",18)
    column.add_child(dialog_history_text)
    var back:=_button("返回剧情",18)
    back.pressed.connect(func() -> void: dialog_history_screen.hide())
    column.add_child(back)
    dialog_history_screen.hide()

func _show_dialogue_history() -> void:
    var readable: PackedStringArray=[]
    for record in dialogue_history.slice(maxi(0,dialogue_history.size()-80)):
        readable.append("%s：%s" % [str(record.get("speaker","旁白")),str(record.get("text",""))])
    dialog_history_text.text="\\n\\n".join(readable) if not readable.is_empty() else "还没有已读的对白。"
    dialog_history_screen.show()

func _build_menu() -> void:
    menu_layer = _full_screen("CampMenu", 0.84)
    camp_panel = PanelContainer.new()
    var panel: PanelContainer = camp_panel
    panel.anchor_left = 0.23
    panel.anchor_right = 0.77
    panel.anchor_top = 0.05
    panel.anchor_bottom = 0.95
    panel.add_theme_stylebox_override("panel", CVisual.surface(true))
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
    title.add_theme_color_override("font_color", CVisual.GOLD)
    flow.add_child(title)
    menu_summary = RichTextLabel.new()
    menu_summary.bbcode_enabled = true
    menu_summary.custom_minimum_size.y = 150
    menu_summary.add_theme_font_size_override("normal_font_size", 19)
    flow.add_child(menu_summary)
    camp_commands = GridContainer.new()
    var command_grid: GridContainer = camp_commands
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


func _reflow_layout() -> void:
    # UI-only layout; never changes camera, collision or player position.
    if root == null or hud == null or dialogue_panel == null or camp_panel == null:
        return
    var view: Vector2 = get_viewport().get_visible_rect().size
    var compact: bool = view.x < 1040.0 or view.y < 600.0
    var safe: float = 18.0 / maxf(view.x,1.0)
    hud.anchor_left = safe
    # Preserve the centre of the gameplay screen. Tooltips/menu keep full
    # objective and HP/MP detail; only the passive overlays are compact.
    hud.anchor_right = 0.67 if compact else 0.575
    hud.anchor_top = 0.018
    hud.anchor_bottom = 0.170 if compact else 0.125
    name_label.custom_minimum_size.x = 108.0 if compact else 120.0
    name_label.add_theme_font_size_override("font_size",13 if compact else 15)
    tracker.add_theme_font_size_override("normal_font_size",12 if compact else 13)
    status_frame.anchor_left = safe
    status_frame.anchor_right = (0.43 if status_expanded else 0.30) if compact else (0.34 if status_expanded else 0.235)
    status_frame.anchor_top = 0.225 if _touch_mode else (0.70 if status_expanded else 0.858)
    status_frame.anchor_bottom = (0.54 if status_expanded else 0.38) if _touch_mode else 0.961
    status_rows.add_theme_font_size_override("normal_font_size",12 if compact else 14)
    dpad.offset_left = 14
    dpad.offset_right = 201
    dpad.offset_top = -215
    dpad.offset_bottom = -16
    act_button.offset_left = -154
    act_button.offset_right = -14
    act_button.offset_top = -91
    act_button.offset_bottom = -38
    menu_button.offset_left = -72
    menu_button.offset_right = -14
    menu_button.offset_top = -147
    menu_button.offset_bottom = -94
    dialogue_panel.anchor_left = 0.035 if compact else 0.085
    dialogue_panel.anchor_right = 0.965 if compact else 0.915
    dialogue_panel.anchor_top = (0.065 if compact else 0.31) if choosing else (0.60 if compact else 0.615)
    dialogue_panel.anchor_bottom = 0.981
    dialog_portrait.custom_minimum_size = Vector2(94,115) if compact else Vector2(112,140)
    evidence_art.custom_minimum_size.y = 52.0 if compact else 74.0
    dialog_text.add_theme_font_size_override("normal_font_size",17 if compact else 19)
    dialog_speaker.add_theme_font_size_override("font_size",18 if compact else 21)
    for button in [dialog_next,dialog_auto_button,dialog_history_button,dialog_skip_button]:
        button.custom_minimum_size.y = 36 if compact else 42
        button.add_theme_font_size_override("font_size",12 if compact else 14)
    dialog_speaker.add_theme_color_override("font_color",_hud_accent)
    camp_panel.anchor_left = 0.11 if compact else 0.22
    camp_panel.anchor_right = 0.89 if compact else 0.78
    camp_commands.columns = 2
    toast.anchor_top = 0.19 if compact else 0.175
    toast.anchor_bottom = 0.255 if compact else 0.235
    toast.add_theme_font_size_override("font_size",15 if compact else 18)
    _update_explore_controls()

func _build_title() -> void:
    # D-owned cinematic title foyer. The C art manager remains unchanged.
    var foyer = DTitleScreen.new()
    foyer.name = "TitleScreen"
    title_overlay = foyer
    root.add_child(foyer)
    title_illustration = foyer.illustration
    title_continue = foyer.continue_button
    title_status = foyer.status_label
    foyer.launch_requested.connect(func(continue_game: bool) -> void:
        title_overlay.hide()
        started.emit(continue_game)
    )
    foyer.art_manager_requested.connect(func() -> void:
        art_manager.open_manager()
    )
    art_manager = ArtManagerUI.new()
    art_manager.name = "CArtManager"
    root.add_child(art_manager)
    art_manager.asset_changed.connect(func(path: String) -> void:
        foyer.refresh_illustration(path)
    )

func show_title(has_save: bool, status: String = "") -> void:
    # Preserve failed-Continue behavior: the caller retains corrupted files.
    title_overlay.call("configure",has_save,status)
    title_overlay.show()

func set_play_visible(value: bool) -> void:
    _playing = value
    hud.visible = value
    status_frame.visible = value
    _update_explore_controls()
    if not value:
        clear_movement()
