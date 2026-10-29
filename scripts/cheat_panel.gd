extends CanvasLayer
## Local developer tools. Hidden trigger: tap the small star five times within four seconds.
## This is a convenience password, NOT cryptographic access control.

signal opened()
signal closed()
signal command_requested(command: String)

const ACCESS_CODE: String = "9169"
const TAP_COUNT: int = 5
const TAP_WINDOW_MS: int = 4000

var root: Control
var shade: Control
var password_field: LineEdit
var message_label: Label
var command_list: VBoxContainer
var tap_count: int = 0
var first_tap_ms: int = 0
var authenticated: bool = false

func _ready() -> void:
    layer = 50
    root = Control.new()
    root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    root.mouse_filter = Control.MOUSE_FILTER_IGNORE
    add_child(root)
    var star := Button.new()
    star.text = "✦"
    star.tooltip_text = "星灯"
    star.focus_mode = Control.FOCUS_NONE
    star.add_theme_font_size_override("font_size", 22)
    star.add_theme_color_override("font_color", Color(1.0, 0.86, 0.50, 0.8))
    star.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
    star.offset_left = -68.0
    star.offset_right = -20.0
    star.offset_top = 18.0
    star.offset_bottom = 66.0
    star.pressed.connect(_star_pressed)
    root.add_child(star)
    shade = Control.new()
    shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    shade.mouse_filter = Control.MOUSE_FILTER_STOP
    root.add_child(shade)
    # Export templates have no editor feature: retain an inert shade for the
    # controller's menu-focus contract, but expose no launcher or PIN panel.
    shade.hide()
    if not OS.has_feature("editor"):
        star.hide()
        star.disabled = true
        set_process_unhandled_input(false)
        return
    var dim := ColorRect.new()
    dim.color = Color(0.015, 0.027, 0.054, 0.94)
    dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    dim.mouse_filter = Control.MOUSE_FILTER_STOP
    shade.add_child(dim)
    var panel := PanelContainer.new()
    panel.anchor_left = 0.20
    panel.anchor_right = 0.80
    panel.anchor_top = 0.05
    panel.anchor_bottom = 0.95
    panel.add_theme_stylebox_override("panel", _style())
    shade.add_child(panel)
    var scroll := ScrollContainer.new()
    scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
    panel.add_child(scroll)
    var flow := VBoxContainer.new()
    flow.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    flow.add_theme_constant_override("separation", 9)
    scroll.add_child(flow)
    var title := Label.new()
    title.text = "✦ 星灯秘典"
    title.add_theme_font_size_override("font_size", 28)
    flow.add_child(title)
    var hint := Label.new()
    hint.text = "仅限当前设备，开发调试使用"
    hint.add_theme_font_size_override("font_size", 15)
    flow.add_child(hint)
    password_field = LineEdit.new()
    password_field.placeholder_text = "输入四位密钥"
    password_field.secret = true
    password_field.max_length = 4
    password_field.add_theme_font_size_override("font_size", 22)
    password_field.text_submitted.connect(func(_text: String) -> void: _unlock())
    flow.add_child(password_field)
    _button(flow, "解锁秘典", Callable(self, "_unlock"))
    command_list = VBoxContainer.new()
    command_list.add_theme_constant_override("separation", 8)
    flow.add_child(command_list)
    for item in [
        ["恢复全队 HP / MP", "heal"],
        ["金币 +10000", "gold"],
        ["药草 +99", "potions"],
        ["全队等级 +10", "level"],
        ["攻击 / 防御强化", "stats"],
        ["无敌模式 开 / 关", "god"],
        ["禁用随机遇敌 开 / 关", "encounters"],
        ["经验倍率 ×5 开 / 关", "xp"],
        ["移动速度 ×1.8 开 / 关", "speed"],
        ["传送到晨露村", "village"],
        ["传送到星落遗迹", "ruins"],
        ["剧情章节前进一步（调试）", "next_chapter"]
    ]:
        var label_text: String = str(item[0])
        var key: String = str(item[1])
        _button(command_list, label_text, func() -> void: command_requested.emit(key))
    message_label = Label.new()
    message_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    message_label.add_theme_font_size_override("font_size", 17)
    flow.add_child(message_label)
    _button(flow, "关闭", Callable(self, "close"))
    shade.hide()
    _set_unlocked(false)

func _style() -> StyleBoxFlat:
    var style := StyleBoxFlat.new()
    style.bg_color = Color(0.065, 0.09, 0.15, 0.98)
    style.border_color = Color(0.77, 0.65, 0.36, 1.0)
    style.set_border_width_all(2)
    style.set_corner_radius_all(14)
    style.set_content_margin_all(20)
    return style

func _button(parent: Node, title: String, callback: Callable) -> void:
    var b := Button.new()
    b.text = title
    b.custom_minimum_size.y = 48
    b.add_theme_font_size_override("font_size", 19)
    b.pressed.connect(callback)
    parent.add_child(b)

func _unhandled_input(event: InputEvent) -> void:
    if not OS.has_feature("editor"):
        return
    if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_F10:
        _show_panel()
        get_viewport().set_input_as_handled()
    elif shade.visible and event.is_action_pressed("ui_cancel"):
        close()
        get_viewport().set_input_as_handled()

func _star_pressed() -> void:
    if not OS.has_feature("editor"):
        return
    if shade.visible:
        return
    var now: int = Time.get_ticks_msec()
    if tap_count == 0 or now - first_tap_ms > TAP_WINDOW_MS:
        first_tap_ms = now
        tap_count = 0
    tap_count += 1
    if tap_count >= TAP_COUNT:
        tap_count = 0
        _show_panel()

func _show_panel() -> void:
    if not OS.has_feature("editor"):
        return
    if shade.visible:
        return
    shade.show()
    password_field.text = ""
    message_label.text = ""
    _set_unlocked(authenticated)
    opened.emit()

func _unlock() -> void:
    if not OS.has_feature("editor"):
        return
    if password_field.text == ACCESS_CODE:
        authenticated = true
        message_label.text = "验证成功。已开放调试指令。"
        _set_unlocked(true)
        password_field.release_focus()
    else:
        message_label.text = "密钥错误。"
        password_field.clear()

func _set_unlocked(is_unlocked: bool) -> void:
    command_list.visible = is_unlocked
    password_field.visible = not is_unlocked

func report(text_value: String) -> void:
    message_label.text = text_value

func close() -> void:
    if not shade.visible:
        return
    shade.hide()
    closed.emit()
