extends Control
## D-line cinematic title foyer. Replaces immediate button stack; no gameplay/save mutation.
signal launch_requested(continue_game: bool)
signal art_manager_requested

const ArtOverrides = preload("res://scripts/c_art_overrides.gd")
const Soundscape = preload("res://scripts/c_town_soundscape.gd")
const BACKDROP: String = "res://assets/art/backdrops/coast/tide_lighthouse.png"
const PREFS: String = "user://starlit_title_preferences.cfg"
const GOLD: Color = Color("e6c47d")
const INK: Color = Color("081422")
const CREAM: Color = Color("f6efe1")

class Starfield:
    extends Control
    var elapsed: float = 0.0
    var reduced_motion: bool = false
    func _ready() -> void:
        mouse_filter = Control.MOUSE_FILTER_IGNORE
    func _process(delta: float) -> void:
        if not reduced_motion:
            elapsed += minf(delta,0.06)
            queue_redraw()
    func _draw() -> void:
        for index in range(84):
            var a: float = float(posmod(index*73+29,997))/997.0
            var b: float = float(posmod(index*197+61,991))/991.0
            var star: Vector2 = Vector2(a*size.x,b*size.y*0.74)
            var flicker: float = 0.68 if reduced_motion else 0.55+0.40*sin(elapsed*(0.7+float(index%5)*0.21)+float(index))
            var strength: float = maxf(0.05,flicker) * (0.38 if index%5 else 0.78)
            draw_circle(star,1.0 if index%6 else 1.8,Color(0.83,0.89,1.0,strength))
        var drift: float = 0.0 if reduced_motion else sin(elapsed*0.65)*9.0
        draw_line(Vector2(size.x*0.13,size.y*0.68+drift),
            Vector2(size.x*0.61,size.y*0.60+drift),Color(0.89,0.77,0.49,0.19),1.4)

var illustration: TextureRect
var continue_button: Button
var new_game_button: Button
var status_label: Label
var save_label: Label
var prompt: Control
var menu_left: Control
var menu_right: Control
var detail_title: Label
var detail_body: RichTextLabel
var prefs_actions: HBoxContainer
var motion_button: Button
var audio_button: Button
var stars: Starfield
var soundscape: Node
var confirmation: Control
var have_save: bool = false
var menu_open: bool = false
var reduced_motion: bool = false
var audio_enabled: bool = true

func _ready() -> void:
    set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    mouse_filter = Control.MOUSE_FILTER_STOP
    _load_preferences()
    _build_background()
    _build_heading()
    _build_prompt()
    _build_menu()
    _build_confirmation()
    soundscape = Soundscape.new()
    add_child(soundscape)
    if audio_enabled:
        soundscape.call("configure","map_coast_01","street",false,0.85)
    _set_page("story")

func _panel(bg: Color, border: Color = Color("89764f")) -> StyleBoxFlat:
    var style := StyleBoxFlat.new()
    style.bg_color = bg
    style.border_color = border
    style.set_border_width_all(1)
    style.set_corner_radius_all(13)
    style.set_content_margin_all(16)
    return style

func _label(message: String, font_size: int, color: Color = CREAM) -> Label:
    var output := Label.new()
    output.text = message
    output.add_theme_font_size_override("font_size",font_size)
    output.add_theme_color_override("font_color",color)
    output.add_theme_color_override("font_shadow_color",Color(0.02,0.03,0.07,0.85))
    output.add_theme_constant_override("shadow_offset_x",1)
    output.add_theme_constant_override("shadow_offset_y",2)
    return output

func _button(message: String, primary: bool = false) -> Button:
    var b := Button.new()
    b.text = message
    b.custom_minimum_size.y = 46
    b.focus_mode = Control.FOCUS_ALL
    b.add_theme_font_size_override("font_size",19 if primary else 16)
    b.add_theme_color_override("font_color",Color("fff7ea"))
    b.add_theme_stylebox_override("normal",_panel(
        Color(0.37,0.29,0.17,0.96) if primary else Color(0.06,0.15,0.22,0.93),
        GOLD if primary else Color(0.42,0.52,0.55,0.72)))
    b.add_theme_stylebox_override("hover",_panel(Color("2e5060"),GOLD))
    b.add_theme_stylebox_override("pressed",_panel(Color("253e46"),GOLD))
    b.add_theme_stylebox_override("focus",_panel(Color(0,0,0,0),GOLD))
    return b

func _build_background() -> void:
    illustration = TextureRect.new()
    illustration.name = "TitleBackdrop"
    illustration.texture = ArtOverrides.texture(BACKDROP)
    illustration.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
    illustration.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
    illustration.mouse_filter = Control.MOUSE_FILTER_IGNORE
    illustration.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    add_child(illustration)
    var shade := ColorRect.new()
    shade.color = Color(0.018,0.044,0.080,0.57)
    shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
    shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    add_child(shade)
    var side_veil := ColorRect.new()
    side_veil.color = Color(0.015,0.033,0.052,0.39)
    side_veil.anchor_left = 0.0
    side_veil.anchor_right = 0.62
    side_veil.anchor_top = 0.0
    side_veil.anchor_bottom = 1.0
    side_veil.mouse_filter = Control.MOUSE_FILTER_IGNORE
    add_child(side_veil)
    stars = Starfield.new()
    stars.reduced_motion = reduced_motion
    stars.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    add_child(stars)

func _build_heading() -> void:
    var caption := _label("ORIGINAL HD-2D FANTASY   /   A JOURNEY OF STARS",14,GOLD)
    caption.anchor_left = 0.10
    caption.anchor_right = 0.91
    caption.anchor_top = 0.12
    caption.anchor_bottom = 0.18
    add_child(caption)
    var logo := _label("星 灯 纪 行",69,CREAM)
    logo.anchor_left = 0.09
    logo.anchor_right = 0.92
    logo.anchor_top = 0.20
    logo.anchor_bottom = 0.37
    add_child(logo)
    var english := _label("S T A R L I T   C H R O N I C L E",20,GOLD)
    english.anchor_left = 0.10
    english.anchor_right = 0.90
    english.anchor_top = 0.365
    english.anchor_bottom = 0.423
    add_child(english)
    var rule := ColorRect.new()
    rule.color = Color(0.93,0.78,0.47,0.78)
    rule.anchor_left = 0.105
    rule.anchor_right = 0.39
    rule.anchor_top = 0.45
    rule.anchor_bottom = 0.453
    rule.mouse_filter = Control.MOUSE_FILTER_IGNORE
    add_child(rule)

func _build_prompt() -> void:
    prompt = Control.new()
    prompt.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    add_child(prompt)
    var lines := VBoxContainer.new()
    lines.anchor_left = 0.095
    lines.anchor_right = 0.82
    lines.anchor_top = 0.65
    lines.anchor_bottom = 0.94
    lines.add_theme_constant_override("separation",12)
    prompt.add_child(lines)
    var words := _label("当最后一盏星灯熄灭，谁来照亮归途？",23,CREAM)
    lines.add_child(words)
    var intro := _label("十二幕 · 七十二章   |   一场横越大陆与记忆的冒险",16,Color("cdd8df"))
    lines.add_child(intro)
    var enter := _button("✦   触碰星光，开始旅程",true)
    enter.custom_minimum_size = Vector2(330,56)
    enter.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
    enter.pressed.connect(_reveal_menu)
    lines.add_child(enter)
    var key_hint := _label("轻触或按 Enter / Space 进入旅途大厅",13,Color("adbfc4"))
    lines.add_child(key_hint)

func _build_menu() -> void:
    menu_left = PanelContainer.new()
    menu_left.anchor_left = 0.095
    menu_left.anchor_right = 0.515
    menu_left.anchor_top = 0.475
    menu_left.anchor_bottom = 0.966
    menu_left.add_theme_stylebox_override("panel",_panel(Color(0.025,0.068,0.108,0.89)))
    add_child(menu_left)
    var left := VBoxContainer.new()
    left.add_theme_constant_override("separation",8)
    menu_left.add_child(left)
    left.add_child(_label("✦  你的旅程",19,GOLD))
    continue_button = _button("续写旅程  ·  CONTINUE",true)
    continue_button.pressed.connect(func() -> void: _request_launch(true))
    left.add_child(continue_button)
    new_game_button = _button("开启新篇  ·  NEW GAME")
    new_game_button.pressed.connect(func() -> void: _request_launch(false))
    left.add_child(new_game_button)
    var art := _button("美术工坊  ·  素材浏览与替换")
    art.pressed.connect(func() -> void: art_manager_requested.emit())
    left.add_child(art)
    save_label = _label("本机旅程档案",13,Color("bcced6"))
    save_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    left.add_child(save_label)
    status_label = _label("",12,Color("ffd2a7"))
    status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    status_label.visible = false
    left.add_child(status_label)

    menu_right = PanelContainer.new()
    menu_right.anchor_left = 0.535
    menu_right.anchor_right = 0.916
    menu_right.anchor_top = 0.475
    menu_right.anchor_bottom = 0.966
    menu_right.add_theme_stylebox_override("panel",_panel(Color(0.025,0.068,0.108,0.90)))
    add_child(menu_right)
    var right := VBoxContainer.new()
    right.add_theme_constant_override("separation",7)
    menu_right.add_child(right)
    var nav := GridContainer.new()
    nav.columns = 2
    right.add_child(nav)
    for item in [["story","世界序章"],["archive","旅程档案"],["controls","操作指南"],["settings","视听设置"]]:
        var page_id: String=str(item[0])
        var action := _button(str(item[1]))
        action.add_theme_font_size_override("font_size",15)
        action.custom_minimum_size.y = 36
        action.size_flags_horizontal = Control.SIZE_EXPAND_FILL
        action.pressed.connect(Callable(self,"_set_page").bind(page_id))
        nav.add_child(action)
    detail_title = _label("",19,GOLD)
    right.add_child(detail_title)
    detail_body = RichTextLabel.new()
    detail_body.bbcode_enabled = true
    detail_body.fit_content = false
    detail_body.scroll_active = true
    detail_body.size_flags_vertical = Control.SIZE_EXPAND_FILL
    detail_body.add_theme_font_size_override("normal_font_size",15)
    right.add_child(detail_body)
    prefs_actions = HBoxContainer.new()
    prefs_actions.add_theme_constant_override("separation",8)
    right.add_child(prefs_actions)
    motion_button = _button("")
    motion_button.add_theme_font_size_override("font_size",14)
    motion_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    motion_button.pressed.connect(_toggle_motion)
    prefs_actions.add_child(motion_button)
    audio_button = _button("")
    audio_button.add_theme_font_size_override("font_size",14)
    audio_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    audio_button.pressed.connect(_toggle_audio)
    prefs_actions.add_child(audio_button)
    menu_left.hide()
    menu_right.hide()

func _build_confirmation() -> void:
    confirmation = PanelContainer.new()
    confirmation.anchor_left = 0.30
    confirmation.anchor_right = 0.70
    confirmation.anchor_top = 0.29
    confirmation.anchor_bottom = 0.72
    confirmation.add_theme_stylebox_override("panel",_panel(Color("102337"),GOLD))
    add_child(confirmation)
    var content := VBoxContainer.new()
    content.add_theme_constant_override("separation",13)
    confirmation.add_child(content)
    content.add_child(_label("开始新的旅程？",25,GOLD))
    var warning := _label("新的自动存档会覆盖当前旅程。\n如需保留进度，请先在游戏内使用手动存档槽位。",17,CREAM)
    warning.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    content.add_child(warning)
    var choices := HBoxContainer.new()
    content.add_child(choices)
    var cancel := _button("返回")
    cancel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    cancel.pressed.connect(func() -> void: confirmation.hide())
    choices.add_child(cancel)
    var agree := _button("确认新游戏",true)
    agree.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    agree.pressed.connect(func() -> void:
        confirmation.hide()
        _launch(false)
    )
    choices.add_child(agree)
    confirmation.hide()

func _read_save_preview() -> String:
    for path in ["user://first_act_v3.json","user://first_act_v3.backup.json"]:
        if not FileAccess.file_exists(path):
            continue
        var value: Variant=JSON.parse_string(FileAccess.get_file_as_string(path))
        if not (value is Dictionary):
            continue
        var data: Dictionary=value
        if int(data.get("version",-1)) != 3:
            continue
        var chapter: int=int(data.get("chapter",-1))
        if chapter<0 or chapter>72:
            continue
        var location: String="序章" if chapter==0 else "第%d章" % chapter
        var gold: int=maxi(0,int(data.get("gold",0)))
        return "%s  ·  %d G  ·  %s" % [location,gold,"自动存档" if path.ends_with("first_act_v3.json") else "备份存档"]
    return "没有检测到可预览的V3存档" if not have_save else "存在存档文件，完整性将在继续时验证"

func configure(has_save: bool, status: String = "") -> void:
    have_save = has_save
    continue_button.disabled = not have_save
    continue_button.text = "续写旅程  ·  CONTINUE" if has_save else "续写旅程  ·  暂无存档"
    save_label.text = _read_save_preview()
    status_label.text = status
    status_label.visible = not status.is_empty()
    if not status.is_empty():
        _reveal_menu()
    if menu_open:
        _set_page("archive")

func refresh_illustration(path: String) -> void:
    if path==BACKDROP:
        illustration.texture=ArtOverrides.texture(path)

func _reveal_menu() -> void:
    if menu_open:
        return
    menu_open = true
    prompt.hide()
    menu_left.show()
    menu_right.show()
    if not reduced_motion:
        menu_left.modulate.a = 0.0
        menu_right.modulate.a = 0.0
        var fade: Tween=create_tween()
        fade.set_parallel(true)
        fade.tween_property(menu_left,"modulate:a",1.0,0.45)
        fade.tween_property(menu_right,"modulate:a",1.0,0.57)
    if have_save:
        continue_button.grab_focus()
    else:
        new_game_button.grab_focus()

func _request_launch(continuing: bool) -> void:
    if continuing and not have_save:
        return
    if not continuing and have_save:
        confirmation.show()
        return
    _launch(continuing)

func _launch(continuing: bool) -> void:
    if soundscape != null and is_instance_valid(soundscape):
        soundscape.call("stop_scene",0.25)
    launch_requested.emit(continuing)

func _set_page(key: String) -> void:
    prefs_actions.visible = key == "settings"
    match key:
        "story":
            detail_title.text = "在星灯熄灭之前"
            detail_body.text = "海风带走了旧日的名字，群星却仍记得归途。\n\n穿行十二幕的城镇、群岛与遗迹；结识沿途居民，让选择留下回响。\n\n[color=#e6c47d]故事、探索、回合制战斗与生活事件[/color]在同一个世界中交织。"
        "archive":
            detail_title.text = "旅行者档案"
            detail_body.text = _read_save_preview()+"\n\n[color=#bdcbd4]继续旅程会优先读取有效自动存档；如存档损坏，游戏将保留原文件，不会悄悄重开。[/color]\n\n新的旅程会在确认后创建新自动存档。"
        "controls":
            detail_title.text = "探索与指令"
            detail_body.text = "[color=#e6c47d]键盘[/color]   WASD / 方向键：移动\nE / Z / 空格：交互     M / Esc：指令菜单\n\n[color=#e6c47d]触屏[/color]   左下移动方向键，右下操作与菜单\n\n[color=#bdcbd4]调查NPC、进入住宅、探索地下城并记录旅途。[/color]"
        "settings":
            detail_title.text = "开场视听设置"
            detail_body.text = "调整标题画面的星光动态及城镇氛围音。\n\n这些偏好保存在本机，不修改存档、角色属性或美术素材；游戏内完整设置仍由旅途指令管理。"
            _refresh_preference_labels()

func _load_preferences() -> void:
    var file:=ConfigFile.new()
    if file.load(PREFS)==OK:
        reduced_motion=bool(file.get_value("title","reduced_motion",false))
        audio_enabled=bool(file.get_value("title","audio_enabled",true))

func _save_preferences() -> void:
    var file:=ConfigFile.new()
    file.set_value("title","reduced_motion",reduced_motion)
    file.set_value("title","audio_enabled",audio_enabled)
    if file.save(PREFS)!=OK:
        push_warning("Unable to save title visual/audio preferences")

func _refresh_preference_labels() -> void:
    motion_button.text="星光动效：简化" if reduced_motion else "星光动效：开启"
    audio_button.text="开场氛围音：开" if audio_enabled else "开场氛围音：关"

func _toggle_motion() -> void:
    reduced_motion=not reduced_motion
    stars.reduced_motion=reduced_motion
    stars.queue_redraw()
    _refresh_preference_labels()
    _save_preferences()

func _toggle_audio() -> void:
    audio_enabled=not audio_enabled
    if soundscape!=null and is_instance_valid(soundscape):
        if audio_enabled:
            soundscape.call("configure","map_coast_01","street",false,0.40)
        else:
            soundscape.call("stop_scene",0.25)
    _refresh_preference_labels()
    _save_preferences()

func _unhandled_input(event: InputEvent) -> void:
    if not visible:
        return
    if not menu_open:
        if event is InputEventKey:
            var key: InputEventKey = event
            if key.pressed and not key.echo:
                _reveal_menu()
                get_viewport().set_input_as_handled()
        elif event is InputEventJoypadButton:
            var joy: InputEventJoypadButton = event
            if joy.pressed:
                _reveal_menu()
                get_viewport().set_input_as_handled()
        return
    if event is InputEventKey:
        var key: InputEventKey = event
        if key.pressed and key.keycode == KEY_ESCAPE and confirmation.visible:
            confirmation.hide()
            get_viewport().set_input_as_handled()
