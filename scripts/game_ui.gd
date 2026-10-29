extends CanvasLayer

const ContentDB = preload("res://scripts/content_db.gd")
const CVisual = preload("res://scripts/c_visual_design.gd")
## Native responsive game HUD / D-pad / dialogue / local-save menu.
## All controls are regular Godot GUI nodes, so multi-touch works on iPhone.

signal action_requested()
signal menu_requested()
signal move_changed(direction: Vector2)
signal dialog_closed()
signal menu_closed()
signal save_requested()
signal potion_requested()
signal story_requested()

var root: Control
var hud: PanelContainer
var hud_label: Label
var dpad: Control
var action_button: Button
var menu_button: Button
var dialog_overlay: Control
var dialog_label: Label
var dialog_lines: Array[String] = []
var dialog_index := 0
var menu_overlay: Control
var menu_label: Label
var menu_feedback: Label
var catalog_overlay: Control
var catalog_text: RichTextLabel
var catalog_picker: OptionButton
const CATALOG_LABELS = ["世界地域", "正式人物", "NPC 居民", "地图", "道具与材料", "武器", "防具", "魔法与技能", "普通怪物", "首领 BOSS", "任务（含72章主线）"]
var held: Dictionary = {}
var _touch_mode: bool = false
var _exploring: bool = true

func _ready() -> void:
    layer = 10
    _touch_mode = OS.has_feature("mobile") or DisplayServer.is_touchscreen_available()
    root = Control.new()
    root.name = "GameUIRoot"
    root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    root.mouse_filter = Control.MOUSE_FILTER_IGNORE
    add_child(root)
    _build_hud()
    _build_touchpad()
    _build_dialog()
    _build_menu()
    _build_catalog()
    refresh_hud()
    get_viewport().size_changed.connect(_reflow_game_ui)
    call_deferred("_reflow_game_ui")

func _panel_style() -> StyleBoxFlat:
    return CVisual.surface(false)

func _make_button(label_text: String, font_size: int = 23) -> Button:
    var button := Button.new()
    button.text = label_text
    button.add_theme_font_size_override("font_size", font_size)
    button.add_theme_color_override("font_color", Color(1, 0.96, 0.87))
    button.add_theme_color_override("font_hover_color", Color(1, 1, 1))
    button.add_theme_stylebox_override("normal", _panel_style())
    button.add_theme_stylebox_override("hover", _panel_style())
    button.add_theme_stylebox_override("pressed", _panel_style())
    CVisual.style_button(button)
    button.focus_mode = Control.FOCUS_NONE
    return button

func _build_hud() -> void:
    hud = PanelContainer.new()
    hud.position = Vector2(18, 14)
    hud.custom_minimum_size = Vector2(345, 72)
    hud.add_theme_stylebox_override("panel", _panel_style())
    hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
    hud_label = Label.new()
    hud_label.add_theme_font_size_override("font_size", 19)
    hud_label.add_theme_color_override("font_color", Color(0.95, 0.95, 1))
    hud_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
    hud.add_child(hud_label)
    root.add_child(hud)

func _build_touchpad() -> void:
    dpad = Control.new()
    dpad.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
    dpad.offset_left = 24
    dpad.offset_top = -225
    dpad.offset_right = 226
    dpad.offset_bottom = -25
    dpad.mouse_filter = Control.MOUSE_FILTER_IGNORE
    root.add_child(dpad)
    _dir_button("↑", Vector2(0, -1), Vector2(70, 0))
    _dir_button("←", Vector2(-1, 0), Vector2(0, 69))
    _dir_button("→", Vector2(1, 0), Vector2(140, 69))
    _dir_button("↓", Vector2(0, 1), Vector2(70, 138))

    action_button = _make_button("调查 / 对话", 19)
    action_button.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
    action_button.offset_left = -182
    action_button.offset_top = -101
    action_button.offset_right = -20
    action_button.offset_bottom = -33
    root.add_child(action_button)
    action_button.pressed.connect(func() -> void: action_requested.emit())

    menu_button = _make_button("☰ 菜单", 18)
    menu_button.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
    menu_button.offset_left = -118
    menu_button.offset_top = -84
    menu_button.offset_right = -18
    menu_button.offset_bottom = -25
    root.add_child(menu_button)
    menu_button.pressed.connect(func() -> void: menu_requested.emit())

func _reflow_game_ui() -> void:
    if hud == null:
        return
    var viewport_size: Vector2 = get_viewport().get_visible_rect().size
    var small: bool = viewport_size.x < 1000.0 or viewport_size.y < 580.0
    hud.position = Vector2(12,10) if small else Vector2(18,14)
    hud.custom_minimum_size = Vector2(270,66) if small else Vector2(345,72)
    hud_label.add_theme_font_size_override("font_size",15 if small else 17)
    dpad.visible = _exploring and _touch_mode
    action_button.visible = _exploring and _touch_mode
    menu_button.visible = _exploring
    dialog_label.add_theme_font_size_override("font_size",20 if small else 25)

func _dir_button(title: String, dir: Vector2, where: Vector2) -> void:
    var button := _make_button(title, 28)
    button.position = where
    button.size = Vector2(62, 62)
    dpad.add_child(button)
    button.button_down.connect(func() -> void:
        held[title] = dir
        _emit_held_direction()
    )
    button.button_up.connect(func() -> void:
        held.erase(title)
        _emit_held_direction()
    )

func _emit_held_direction() -> void:
    var direction := Vector2.ZERO
    for d in held.values():
        direction += d
    move_changed.emit(direction.normalized())

func _make_full_overlay(name_text: String) -> Control:
    var overlay := Control.new()
    overlay.name = name_text
    overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    overlay.mouse_filter = Control.MOUSE_FILTER_STOP
    var shade := ColorRect.new()
    shade.color = Color(0.015, 0.028, 0.06, 0.54)
    shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    shade.mouse_filter = Control.MOUSE_FILTER_STOP
    overlay.add_child(shade)
    root.add_child(overlay)
    return overlay

func _build_dialog() -> void:
    dialog_overlay = _make_full_overlay("DialogueOverlay")
    var panel := PanelContainer.new()
    panel.anchor_left = 0.12
    panel.anchor_right = 0.88
    panel.anchor_top = 0.67
    panel.anchor_bottom = 0.96
    panel.add_theme_stylebox_override("panel", _panel_style())
    dialog_overlay.add_child(panel)
    var flow := VBoxContainer.new()
    flow.add_theme_constant_override("separation", 9)
    panel.add_child(flow)
    dialog_label = Label.new()
    dialog_label.add_theme_font_size_override("font_size", 25)
    dialog_label.add_theme_color_override("font_color", Color(0.96, 0.96, 1))
    dialog_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    dialog_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
    flow.add_child(dialog_label)
    var next := _make_button("继续  ▸", 20)
    next.custom_minimum_size = Vector2(160, 48)
    next.size_flags_horizontal = Control.SIZE_SHRINK_END
    next.pressed.connect(advance_dialog)
    flow.add_child(next)
    dialog_overlay.hide()

func _build_menu() -> void:
    menu_overlay = _make_full_overlay("MenuOverlay")
    var panel := PanelContainer.new()
    panel.anchor_left = 0.18
    panel.anchor_right = 0.82
    panel.anchor_top = 0.04
    panel.anchor_bottom = 0.96
    panel.add_theme_stylebox_override("panel", _panel_style())
    menu_overlay.add_child(panel)
    var scroll := ScrollContainer.new()
    scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
    panel.add_child(scroll)
    var flow := VBoxContainer.new()
    flow.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    flow.add_theme_constant_override("separation", 9)
    scroll.add_child(flow)
    menu_label = Label.new()
    menu_label.add_theme_font_size_override("font_size", 25)
    menu_label.add_theme_color_override("font_color", Color(1.0, 0.88, 0.60))
    flow.add_child(menu_label)
    var heal := _make_button("使用药草（恢复 40 HP）", 21)
    heal.pressed.connect(func() -> void: potion_requested.emit())
    flow.add_child(heal)
    var save := _make_button("保存游戏（本机离线）", 21)
    save.pressed.connect(func() -> void: save_requested.emit())
    flow.add_child(save)
    var story_button := _make_button("✦ 主线剧情 · 十二幕七十二章", 19)
    story_button.pressed.connect(func() -> void: story_requested.emit())
    flow.add_child(story_button)
    var catalog := _make_button("星灯图鉴（内容预览）", 19)
    catalog.pressed.connect(_show_catalog)
    flow.add_child(catalog)
    var close := _make_button("返回游戏", 21)
    close.pressed.connect(_close_menu)
    flow.add_child(close)
    menu_feedback = Label.new()
    menu_feedback.add_theme_font_size_override("font_size", 18)
    menu_feedback.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    menu_feedback.add_theme_color_override("font_color", Color(0.76, 0.94, 0.87))
    flow.add_child(menu_feedback)
    menu_overlay.hide()

func _build_catalog() -> void:
    catalog_overlay = _make_full_overlay("ContentCatalogOverlay")
    var panel := PanelContainer.new()
    panel.anchor_left = 0.14
    panel.anchor_right = 0.86
    panel.anchor_top = 0.08
    panel.anchor_bottom = 0.94
    panel.add_theme_stylebox_override("panel", _panel_style())
    catalog_overlay.add_child(panel)
    var flow := VBoxContainer.new()
    flow.add_theme_constant_override("separation", 10)
    panel.add_child(flow)
    var heading := Label.new()
    heading.text = "✦ 星灯图鉴 · 研发内容预览"
    heading.add_theme_font_size_override("font_size", 25)
    flow.add_child(heading)
    catalog_picker = OptionButton.new()
    catalog_picker.custom_minimum_size = Vector2(250, 48)
    for category_label in CATALOG_LABELS:
        catalog_picker.add_item(category_label)
    catalog_picker.item_selected.connect(_render_catalog)
    flow.add_child(catalog_picker)
    catalog_text = RichTextLabel.new()
    catalog_text.size_flags_vertical = Control.SIZE_EXPAND_FILL
    catalog_text.scroll_active = true
    catalog_text.bbcode_enabled = false
    catalog_text.add_theme_font_size_override("normal_font_size", 20)
    flow.add_child(catalog_text)
    var close := _make_button("返回菜单", 19)
    close.pressed.connect(func() -> void: catalog_overlay.hide())
    flow.add_child(close)
    catalog_overlay.hide()

func _show_catalog() -> void:
    catalog_picker.select(0)
    _render_catalog(0)
    catalog_overlay.show()

func _render_catalog(index: int) -> void:
    if index < 0 or index >= ContentDB.CATEGORIES.size():
        return
    var category: String = ContentDB.CATEGORIES[index]
    var records: Array[Dictionary] = ContentDB.load_entries(category)
    var lines := PackedStringArray()
    for entry in records:
        var detail: String = str(entry.get("character_arc", entry.get("lore", entry.get("objective", ""))))
        if detail.is_empty() and entry.has("element"):
            detail = "属性：" + str(entry["element"])
        if detail.is_empty() and entry.has("tier"):
            detail = "品阶：" + str(entry["tier"])
        if detail.is_empty() and entry.has("region_id"):
            detail = "区域：" + str(entry["region_id"])
        lines.append("◆ " + str(entry["name"]) + "   [" + str(entry["id"]) + "]\n" + detail)
    catalog_text.text = "收录 %d 条设计记录（部分尚无可用美术或战斗实现）\n\n" % records.size() + "\n\n".join(lines)
    catalog_text.scroll_to_line(0)

func refresh_hud() -> void:
    if not is_instance_valid(hud_label):
        return
    var stats: String = ""
    if not State.party.is_empty():
        var person: Dictionary = State.party[0]
        stats = "%s  HP %s/%s  MP %s/%s\n" % [person["name"],person["hp"],person["max_hp"],person["mp"],person["max_mp"]]
    hud_label.text = stats + "◆ " + str(State.quest_title()).left(28)
    if is_instance_valid(menu_label):
        menu_label.text = "✦ 队伍 / 背包\n金币：%d     药草：%d" % [State.gold, State.potions]

func set_exploration_visible(visible_now: bool) -> void:
    _exploring = visible_now
    hud.visible = visible_now
    dpad.visible = visible_now and _touch_mode
    action_button.visible = visible_now and _touch_mode
    menu_button.visible = visible_now
    if not visible_now:
        held.clear()
        _emit_held_direction()

func show_dialog(lines: Array[String]) -> void:
    dialog_lines = lines.duplicate()
    dialog_index = 0
    dialog_label.text = dialog_lines[0] if not dialog_lines.is_empty() else ""
    dialog_overlay.show()
    held.clear()
    _emit_held_direction()

func is_dialog_open() -> bool:
    return dialog_overlay.visible

func advance_dialog() -> void:
    if not dialog_overlay.visible:
        return
    dialog_index += 1
    if dialog_index >= dialog_lines.size():
        dialog_overlay.hide()
        dialog_closed.emit()
    else:
        dialog_label.text = dialog_lines[dialog_index]

func show_menu() -> void:
    refresh_hud()
    menu_feedback.text = "在世界地图中随时保存。"
    held.clear()
    _emit_held_direction()
    menu_overlay.show()

func set_menu_message(message: String) -> void:
    menu_feedback.text = message
    refresh_hud()

func _close_menu() -> void:
    menu_overlay.hide()
    menu_closed.emit()
