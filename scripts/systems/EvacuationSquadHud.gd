extends CanvasLayer
## Three-lane tactical status overlay for Chapter 47.
## This is not three independent map cameras; real stage progress is recorded
## only by physical in-world rescue interactions and battle settlement.
signal squad_requested(squad_id: String)

const SQUADS := [
    {"id":"EAST_GATE_LEISO", "label":"东门·雷索／岚音"},
    {"id":"SOUTH_GATE_SHUOXIAN", "label":"南门·朔弦／诺依"},
    {"id":"WEST_GATE_TIFA", "label":"西门·缇珐"}
]
var surface: PanelContainer
var timer_label: Label
var toggle: Button
var expanded: bool = false
var world_director
var rows: Dictionary = {}

func _ready() -> void:
    layer = 19
    # Bottom of the screen belongs to the mobile D-pad and action buttons.
    # Keep the mission overlay collapsible near the upper-right edge.
    toggle = Button.new()
    toggle.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
    toggle.offset_left = -230
    toggle.offset_right = -14
    toggle.offset_top = 142
    toggle.offset_bottom = 180
    toggle.add_theme_font_size_override("font_size",12)
    toggle.pressed.connect(func() -> void:
        expanded = not expanded
        surface.visible = expanded
    )
    add_child(toggle)
    surface = PanelContainer.new()
    surface.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
    surface.offset_left = 16
    surface.offset_right = -16
    surface.offset_top = 182
    surface.offset_bottom = 331
    surface.mouse_filter = Control.MOUSE_FILTER_STOP
    var panel_style := StyleBoxFlat.new()
    panel_style.bg_color = Color(0.045, 0.070, 0.12, 0.90)
    panel_style.border_color = Color(0.58, 0.52, 0.37, 0.95)
    panel_style.set_border_width_all(1)
    panel_style.set_corner_radius_all(8)
    panel_style.set_content_margin_all(8)
    surface.add_theme_stylebox_override("panel", panel_style)
    add_child(surface)
    var stack := VBoxContainer.new()
    surface.add_child(stack)
    var heading := HBoxContainer.new()
    stack.add_child(heading)
    var label := Label.new()
    label.text = "三誓王都 · 三门撤离协作"
    label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    label.add_theme_color_override("font_color",Color("f2d9a4"))
    heading.add_child(label)
    timer_label = Label.new()
    timer_label.text = "机械臂倒计时"
    timer_label.add_theme_color_override("font_color",Color("ffba89"))
    heading.add_child(timer_label)
    var columns := HBoxContainer.new()
    columns.add_theme_constant_override("separation",6)
    stack.add_child(columns)
    for descriptor in SQUADS:
        var squad_id: String = str(descriptor["id"])
        var panel := VBoxContainer.new()
        panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
        columns.add_child(panel)
        var name := Label.new()
        name.text = str(descriptor["label"])
        name.add_theme_font_size_override("font_size",14)
        panel.add_child(name)
        var stage := Label.new()
        stage.text = "等待任务"
        stage.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
        stage.add_theme_font_size_override("font_size",12)
        panel.add_child(stage)
        var choose := Button.new()
        choose.text = "切换小队"
        choose.custom_minimum_size.y = 30
        choose.add_theme_font_size_override("font_size",12)
        panel.add_child(choose)
        choose.pressed.connect(func() -> void: squad_requested.emit(squad_id))
        rows[squad_id] = {"title":name,"stage":stage,"button":choose}
    surface.hide()
    toggle.hide()

func update_from_bridge(bridge, chapter: int) -> void:
    if bridge == null or not bridge.registry_loaded or chapter != 47:
        surface.hide()
        toggle.hide()
        return
    toggle.show()
    surface.visible = expanded
    var controller = bridge.evacuation
    var remaining: int = maxi(0,ceili(controller.seconds_remaining))
    var failure: bool = controller.failed
    timer_label.text = ("撤离失败 · 重新部署" if failure else
        ("三队已撤离" if controller.finished else "西门 %02d:%02d" % [int(remaining / 60),remaining % 60]))
    toggle.text = ("收起三门战术" if expanded else
        ("三门战术 · 已失败" if failure else
        ("三门撤离 · 完成" if controller.finished else "三门战术 · %02d:%02d" % [int(remaining / 60),remaining % 60])))
    for descriptor in SQUADS:
        var squad_id: String = str(descriptor["id"])
        var row: Dictionary = rows[squad_id]
        var status: Dictionary = controller.squad_statuses[squad_id]
        var done: int = (status["completed_objectives"] as Array).size()
        var active: bool = controller.active_controlled_squad == squad_id
        row["title"].modulate = Color("ffe6a5") if active else Color("aebfce")
        var stage_text: String = ("✓ 已安全撤离" if bool(status["secured"]) else
            "%d/3 · %s" % [done,controller.current_objective_text(squad_id)])
        if active and not bool(status["secured"]) and world_director != null:
            var current_marker: String = controller.current_objective_marker(squad_id)
            if current_marker in ["evac:east:escort","evac:south:route"]:
                var escort_hint: String = world_director.escort_status(current_marker)
                if not escort_hint.is_empty():
                    stage_text += "\n" + escort_hint
        row["stage"].text = stage_text
        row["button"].text = "当前指挥" if active else "切换小队"
        row["button"].disabled = active or not controller.running
