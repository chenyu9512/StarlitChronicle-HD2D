extends CanvasLayer
## Actor-led cinematic cards & transitions for the main playable JRPG.
## The 9 canonical prologue scenes keep their original playable objective/dialogue.
signal finished(cue_id: String, skipped: bool)
const Audio = preload("res://scripts/cinematic_audio.gd")
const COAST: String = "res://assets/art/backdrops/coast/tide_lighthouse.png"
var sound
var overlay: Control
var backdrop: TextureRect
var tint: ColorRect
var kicker: Label
var headline: Label
var scene_location: Label
var speaker: Label
var narration: Label
var portrait: TextureRect
var next_button: Button
var skip_button: Button
var banner: Control
var banner_title: Label
var banner_kicker: Label
var active_id: String = ""
var beats: Array = []
var beat_index: int = 0
var can_skip: bool = true
var mode: String = ""
var transition_tween: Tween

func _ready() -> void:
    layer=28
    sound=Audio.new()
    add_child(sound)
    _build_fullscreen()
    _build_banner()

func _build_fullscreen() -> void:
    overlay=Control.new()
    overlay.name="CinematicStage"
    overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    overlay.mouse_filter=Control.MOUSE_FILTER_STOP
    add_child(overlay)
    backdrop=TextureRect.new()
    backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    backdrop.expand_mode=TextureRect.EXPAND_IGNORE_SIZE
    backdrop.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_COVERED
    backdrop.mouse_filter=Control.MOUSE_FILTER_IGNORE
    overlay.add_child(backdrop)
    tint=ColorRect.new()
    tint.color=Color(0.025,0.055,0.085,0.49)
    tint.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    tint.mouse_filter=Control.MOUSE_FILTER_IGNORE
    overlay.add_child(tint)
    for upper in [true,false]:
        var band := ColorRect.new()
        band.color=Color("061321")
        band.anchor_left=0.0
        band.anchor_right=1.0
        if upper:
            band.anchor_top=0.0
            band.anchor_bottom=0.095
        else:
            band.anchor_top=0.91
            band.anchor_bottom=1.0
        band.mouse_filter=Control.MOUSE_FILTER_IGNORE
        overlay.add_child(band)
    kicker=Label.new()
    kicker.anchor_left=0.08
    kicker.anchor_right=0.94
    kicker.anchor_top=0.12
    kicker.anchor_bottom=0.22
    kicker.add_theme_color_override("font_color",Color("e9c98c"))
    kicker.add_theme_font_size_override("font_size",21)
    overlay.add_child(kicker)
    headline=Label.new()
    headline.anchor_left=0.08
    headline.anchor_right=0.94
    headline.anchor_top=0.22
    headline.anchor_bottom=0.37
    headline.add_theme_color_override("font_color",Color("fff0d0"))
    headline.add_theme_font_size_override("font_size",43)
    headline.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
    overlay.add_child(headline)
    scene_location=Label.new()
    scene_location.anchor_left=0.08
    scene_location.anchor_right=0.90
    scene_location.anchor_top=0.39
    scene_location.anchor_bottom=0.47
    scene_location.add_theme_color_override("font_color",Color("d6e1e7"))
    scene_location.add_theme_font_size_override("font_size",18)
    overlay.add_child(scene_location)
    var panel := PanelContainer.new()
    panel.anchor_left=0.075
    panel.anchor_right=0.925
    panel.anchor_top=0.59
    panel.anchor_bottom=0.89
    var style := StyleBoxFlat.new()
    style.bg_color=Color(0.03,0.075,0.13,0.94)
    style.border_color=Color("b89a67")
    style.set_border_width_all(2)
    style.set_corner_radius_all(7)
    style.set_content_margin_all(14)
    panel.add_theme_stylebox_override("panel",style)
    overlay.add_child(panel)
    var row:=HBoxContainer.new()
    row.add_theme_constant_override("separation",17)
    panel.add_child(row)
    portrait=TextureRect.new()
    portrait.custom_minimum_size=Vector2(130,170)
    portrait.expand_mode=TextureRect.EXPAND_IGNORE_SIZE
    portrait.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED
    row.add_child(portrait)
    var column:=VBoxContainer.new()
    column.size_flags_horizontal=Control.SIZE_EXPAND_FILL
    column.add_theme_constant_override("separation",8)
    row.add_child(column)
    speaker=Label.new()
    speaker.add_theme_color_override("font_color",Color("e5ca8e"))
    speaker.add_theme_font_size_override("font_size",19)
    column.add_child(speaker)
    narration=Label.new()
    narration.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
    narration.size_flags_vertical=Control.SIZE_EXPAND_FILL
    narration.add_theme_font_size_override("font_size",23)
    column.add_child(narration)
    var actions:=HBoxContainer.new()
    actions.alignment=BoxContainer.ALIGNMENT_END
    column.add_child(actions)
    next_button=Button.new()
    next_button.text="继续  ▸"
    next_button.custom_minimum_size=Vector2(140,45)
    next_button.pressed.connect(advance)
    actions.add_child(next_button)
    skip_button=Button.new()
    skip_button.text="略过演出  ⏭"
    skip_button.custom_minimum_size=Vector2(152,45)
    skip_button.pressed.connect(skip)
    actions.add_child(skip_button)
    overlay.hide()

func _build_banner() -> void:
    banner=Control.new()
    banner.mouse_filter=Control.MOUSE_FILTER_IGNORE
    banner.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    add_child(banner)
    var base := PanelContainer.new()
    base.anchor_left=0.26
    base.anchor_right=0.74
    base.anchor_top=0.20
    base.anchor_bottom=0.40
    base.mouse_filter=Control.MOUSE_FILTER_IGNORE
    var style:=StyleBoxFlat.new()
    style.bg_color=Color(0.01,0.04,0.085,0.85)
    style.border_color=Color("e7bb78")
    style.set_border_width_all(2)
    style.set_corner_radius_all(6)
    style.set_content_margin_all(10)
    base.add_theme_stylebox_override("panel",style)
    banner.add_child(base)
    var column:=VBoxContainer.new()
    column.alignment=BoxContainer.ALIGNMENT_CENTER
    base.add_child(column)
    banner_kicker=Label.new()
    banner_kicker.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
    banner_kicker.add_theme_color_override("font_color",Color("dfc28d"))
    banner_kicker.add_theme_font_size_override("font_size",16)
    column.add_child(banner_kicker)
    banner_title=Label.new()
    banner_title.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
    banner_title.add_theme_color_override("font_color",Color("fff0d0"))
    banner_title.add_theme_font_size_override("font_size",28)
    column.add_child(banner_title)
    banner.hide()

func start(cue_id: String,data: Dictionary) -> bool:
    if not active_id.is_empty() or data.is_empty():
        return false
    active_id=cue_id
    mode=str(data.get("tone","hope"))
    beats=data.get("lines",[]).duplicate(true)
    beat_index=0
    can_skip=bool(data.get("can_skip",true))
    kicker.text=str(data.get("sub",""))
    headline.text=str(data.get("title","星灯纪行"))
    scene_location.text=str(data.get("location","洛维恩 · 星光航路"))
    var art_path: String=str(data.get("image",COAST))
    if not ResourceLoader.exists(art_path):
        art_path=COAST
    backdrop.texture=load(art_path) if ResourceLoader.exists(art_path) else null
    var palettes: Dictionary={
        "danger":Color(0.16,0.015,0.045,0.69),
        "grief":Color(0.065,0.085,0.16,0.64),
        "warm":Color(0.10,0.074,0.04,0.39),
        "festival":Color(0.10,0.05,0.02,0.38),
        "mystery":Color(0.025,0.06,0.14,0.54),
        "hope":Color(0.035,0.07,0.10,0.45)
    }
    tint.color=palettes.get(mode,Color(0.04,0.07,0.12,0.55))
    skip_button.visible=can_skip
    overlay.show()
    _render_beat()
    sound.cue(mode)
    overlay.modulate=Color(1,1,1,0)
    var fade:=create_tween()
    fade.tween_property(overlay,"modulate",Color.WHITE,0.28)
    return true

func is_playing() -> bool:
    return not active_id.is_empty()

func advance() -> void:
    if active_id.is_empty():
        return
    beat_index+=1
    if beat_index>=beats.size():
        _finish(false)
    else:
        _render_beat()

func skip() -> void:
    if active_id.is_empty() or not can_skip:
        return
    _finish(true)

func _render_beat() -> void:
    var record: Dictionary=beats[beat_index] if beat_index<beats.size() else {}
    speaker.text=str(record.get("speaker","旁白"))
    narration.text=str(record.get("text","……"))
    var portrait_path: String=""
    match speaker.text:
        "澄舟":portrait_path="res://assets/art/characters/chengzhou/dialogue.png"
        "岚音":portrait_path="res://assets/art/characters/lanyin/dialogue.png"
        "主角","幼年主角":portrait_path="res://assets/art/characters/leon/dialogue.png"
    portrait.visible=not portrait_path.is_empty() and ResourceLoader.exists(portrait_path)
    if portrait.visible:
        portrait.texture=load(portrait_path)
    next_button.text="进入旅程 ▸" if beat_index>=beats.size()-1 else "继续  ▸"

func _finish(skipped: bool) -> void:
    var completed: String=active_id
    active_id=""
    overlay.hide()
    sound.stop()
    finished.emit(completed,skipped)

func banner_card(heading: String,subheading: String,tone: String="hope") -> void:
    banner_title.text=heading
    banner_kicker.text=subheading
    banner.show()
    banner.modulate=Color(1,1,1,0)
    if transition_tween!=null and transition_tween.is_running():
        transition_tween.kill()
    transition_tween=create_tween()
    transition_tween.tween_property(banner,"modulate",Color.WHITE,0.20)
    transition_tween.tween_interval(1.9 if tone=="danger" else 1.4)
    transition_tween.tween_property(banner,"modulate",Color(1,1,1,0),0.48)
    transition_tween.tween_callback(func() -> void: banner.hide())
    if tone in ["danger","victory","mystery"]:
        sound.cue(tone)

func cancel_all() -> void:
    # Loading a slot cancels visual timelines without applying their effects.
    active_id=""
    overlay.hide()
    banner.hide()
    if transition_tween!=null and transition_tween.is_running():
        transition_tween.kill()
    sound.stop()
