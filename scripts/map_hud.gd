extends CanvasLayer
## Original nautical RPG map UI: persistent minimap, explorable area map and world-route atlas.
## The diagram uses the actual collision cells and the existing 42-node travel registry.
signal opened()
signal closed()
signal travel_requested(map_id: String)

const View = preload("res://scripts/map_view.gd")
const INK: Color = Color("0b1c32")
const GOLD: Color = Color("e6c47d")
var world
var router
var root: Control
var small_frame: PanelContainer
var small_view
var small_header: Button
var overlay: Control
var full_view
var full_heading: Label
var map_info: Label
var route_info: Label
var route_button: Button
var local_button: Button
var world_button: Button
var selected_map: String = ""
var shown_mode: String = "local"
var update_clock: float = 0.0
var in_world: bool = false
var primary_target: String = ""
var secondary_target: String = ""

func _ready() -> void:
    layer = 14
    root = Control.new()
    root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    root.mouse_filter = Control.MOUSE_FILTER_IGNORE
    add_child(root)
    _build_small()
    _build_full()
    small_frame.hide()
    overlay.hide()
    set_process(true)

func _frame_style() -> StyleBoxFlat:
    var style := StyleBoxFlat.new()
    style.bg_color = Color("0c2237")
    style.border_color = GOLD
    style.set_border_width_all(2)
    style.set_corner_radius_all(9)
    style.set_content_margin_all(9)
    return style

func _button(title: String) -> Button:
    var btn := Button.new()
    btn.text = title
    btn.custom_minimum_size.y = 43
    btn.add_theme_font_size_override("font_size", 17)
    btn.add_theme_color_override("font_color", Color("f8e9c6"))
    btn.add_theme_stylebox_override("normal", _frame_style())
    return btn

func _build_small() -> void:
    small_frame = PanelContainer.new()
    small_frame.name = "ExploreMinimap"
    small_frame.anchor_left = 0.795
    small_frame.anchor_right = 0.985
    small_frame.anchor_top = 0.025
    small_frame.anchor_bottom = 0.327
    small_frame.add_theme_stylebox_override("panel", _frame_style())
    small_frame.mouse_filter = Control.MOUSE_FILTER_STOP
    root.add_child(small_frame)
    var vertical := VBoxContainer.new()
    vertical.add_theme_constant_override("separation", 4)
    small_frame.add_child(vertical)
    small_header = _button("◇ 地图 / TAB")
    small_header.custom_minimum_size.y = 34
    small_header.add_theme_font_size_override("font_size", 15)
    small_header.pressed.connect(open_map)
    vertical.add_child(small_header)
    small_view = View.new()
    small_view.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    small_view.size_flags_vertical = Control.SIZE_EXPAND_FILL
    small_view.mouse_filter = Control.MOUSE_FILTER_IGNORE
    vertical.add_child(small_view)

func _build_full() -> void:
    overlay = Control.new()
    overlay.name = "AtlasOverlay"
    overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    overlay.mouse_filter = Control.MOUSE_FILTER_STOP
    root.add_child(overlay)
    var tint := ColorRect.new()
    tint.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    tint.color = Color(0.015,0.035,0.065,0.96)
    tint.mouse_filter = Control.MOUSE_FILTER_STOP
    overlay.add_child(tint)
    var panel := PanelContainer.new()
    panel.anchor_left = 0.075
    panel.anchor_right = 0.925
    panel.anchor_top = 0.06
    panel.anchor_bottom = 0.945
    panel.add_theme_stylebox_override("panel",_frame_style())
    overlay.add_child(panel)
    var column := VBoxContainer.new()
    column.add_theme_constant_override("separation",10)
    panel.add_child(column)
    var heading := HBoxContainer.new()
    heading.add_theme_constant_override("separation",12)
    column.add_child(heading)
    full_heading = Label.new()
    full_heading.text = "✦ 航路地图 / 区域"
    full_heading.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    full_heading.add_theme_font_size_override("font_size",25)
    full_heading.add_theme_color_override("font_color",GOLD)
    heading.add_child(full_heading)
    local_button = _button("区域地图")
    local_button.pressed.connect(func() -> void: _set_mode("local"))
    heading.add_child(local_button)
    world_button = _button("世界航路")
    world_button.pressed.connect(func() -> void: _set_mode("world"))
    heading.add_child(world_button)
    var exit_button := _button("返回探索  ×")
    exit_button.pressed.connect(close_map)
    heading.add_child(exit_button)
    var columns := HBoxContainer.new()
    columns.size_flags_vertical = Control.SIZE_EXPAND_FILL
    columns.add_theme_constant_override("separation",15)
    column.add_child(columns)
    full_view = View.new()
    full_view.custom_minimum_size = Vector2(450,340)
    full_view.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    full_view.size_flags_vertical = Control.SIZE_EXPAND_FILL
    full_view.location_selected.connect(_on_location_selected)
    columns.add_child(full_view)
    var sidebar := VBoxContainer.new()
    sidebar.custom_minimum_size.x = 204
    sidebar.add_theme_constant_override("separation",13)
    columns.add_child(sidebar)
    var detail_title := Label.new()
    detail_title.text = "探索情报"
    detail_title.add_theme_color_override("font_color",GOLD)
    detail_title.add_theme_font_size_override("font_size",20)
    sidebar.add_child(detail_title)
    map_info = Label.new()
    map_info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    map_info.add_theme_font_size_override("font_size",16)
    sidebar.add_child(map_info)
    route_info = Label.new()
    route_info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    route_info.add_theme_font_size_override("font_size",15)
    sidebar.add_child(route_info)
    var spacer := Control.new()
    spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
    sidebar.add_child(spacer)
    route_button = _button("旅行到选中地点")
    route_button.pressed.connect(_try_travel)
    sidebar.add_child(route_button)
    var footer := Label.new()
    footer.text = "◆ 当前位置     ✦ 主线目标     ◇ 支线任务     ● 已发现地点    · 方向键移动 / 轻触查看"
    footer.add_theme_color_override("font_color",Color("b6c8d5"))
    footer.add_theme_font_size_override("font_size",14)
    column.add_child(footer)

func bind_world(world_ref, router_ref) -> void:
    world = world_ref
    router = router_ref
    small_view.setup(world,router,true)
    full_view.setup(world,router,false)
    _refresh_info()

func set_targets(main_id: String, side_id: String = "") -> void:
    primary_target = main_id
    secondary_target = side_id
    small_view.targets(primary_target,secondary_target)
    full_view.targets(primary_target,secondary_target)

func show_exploration(value: bool) -> void:
    in_world = value
    small_frame.visible = in_world and not overlay.visible

func is_open() -> bool:
    return overlay.visible

func open_map() -> void:
    if not in_world or world == null or not is_instance_valid(world.hero):
        return
    shown_mode = "local"
    selected_map = ""
    full_view.selected_location = ""
    _set_mode("local")
    overlay.show()
    small_frame.hide()
    opened.emit()

func show_world_map() -> void:
    open_map()
    if overlay.visible:
        _set_mode("world")

func close_map() -> void:
    if not overlay.visible:
        return
    overlay.hide()
    small_frame.visible = in_world
    closed.emit()

func _set_mode(next_mode: String) -> void:
    shown_mode = next_mode
    full_view.display_mode(shown_mode)
    full_heading.text = "✦ 航路地图 / " + ("世界" if shown_mode == "world" else "区域")
    _refresh_info()

func _on_location_selected(map_id: String) -> void:
    selected_map = map_id
    _refresh_info()

func _try_travel() -> void:
    if router == null or not router.can_travel(selected_map):
        _refresh_info()
        return
    var target: String = selected_map
    close_map()
    travel_requested.emit(target)

func _refresh_info() -> void:
    if map_info == null:
        return
    if world == null or router == null or router.state == null:
        map_info.text = "尚未进入游戏。"
        route_button.disabled = true
        return
    var world_name: String = str(world.region_name())
    var hero_pos: Vector2i = Vector2i(-1,-1)
    if is_instance_valid(world.hero):
        hero_pos = Vector2i(world.hero.position / 32.0)
    map_info.text = "%s\n\n地理坐标：%d，%d\n\n地图范围：44 × 28格" % [world_name,hero_pos.x,hero_pos.y]
    if shown_mode == "world":
        var info: Dictionary = router.map_info(selected_map)
        if info.is_empty():
            route_info.text = "轻触地图节点查看。\n浅蓝：到访\n灰白：发现\n暗色：未探索\n\n已到访 %d / 42" % router.visited_count()
        else:
            var name: String = str(info.get("name",selected_map))
            var available: bool = router.can_travel(selected_map)
            route_info.text = "选中：%s\n%s" % [name,"可经相邻道路前往" if available else "尚不能直接前往；需相邻且解锁"]
        route_button.visible = true
        route_button.disabled = not router.can_travel(selected_map)
    else:
        route_info.text = "金色：主线目标\n浅蓝：支线委托\n绿色：休息或家园\n紫色：商店\n白金：自己\n\n区域地图与实际碰撞地形同步。"
        route_button.visible = false
        route_button.disabled = true

func _process(delta: float) -> void:
    if not small_frame.visible and not overlay.visible:
        return
    update_clock += delta
    if update_clock < 0.16:
        return
    update_clock = 0.0
    if small_frame.visible:
        small_view.queue_redraw()
    if overlay.visible:
        full_view.queue_redraw()
        _refresh_info()
