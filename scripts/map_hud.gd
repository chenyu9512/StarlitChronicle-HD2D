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
var region_button: Button
var world_button: Button
var selected_map: String = ""
var shown_mode: String = "local"
var update_clock: float = 0.0
var in_world: bool = false
var primary_target: String = ""
var secondary_target: String = ""
var quest_destination: String = ""
var quest_summary: String = ""

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
    local_button = _button("当前地图")
    local_button.pressed.connect(func() -> void: _set_mode("local"))
    heading.add_child(local_button)
    region_button = _button("地区分块")
    region_button.pressed.connect(func() -> void: _set_mode("region"))
    heading.add_child(region_button)
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
    footer.text = "◆ 当前角色  ✦ 主线  ◇ 支线  ■ 城镇  ◆ 地牢  · 可触控地图及移动端横屏适配"
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

func set_story_route(map_id: String,description: String = "") -> void:
    quest_destination = map_id
    quest_summary = description
    if small_view != null:
        small_view.quest_destination = map_id
        small_view.queue_redraw()
    if full_view != null:
        full_view.quest_destination = map_id
        full_view.queue_redraw()

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
    var name: String = "世界" if shown_mode=="world" else ("分区" if shown_mode=="region" else "当前区域")
    full_heading.text = "✦ 星灯图志 / " + name
    _refresh_info()

func _on_location_selected(map_id: String) -> void:
    selected_map = map_id
    _refresh_info()

func _try_travel() -> void:
    if router == null:
        return
    var steps: Array[String] = router.shortest_route(selected_map)
    if steps.size() <= 1 or not router.can_travel(steps[1]):
        _refresh_info()
        return
    # Perform exactly one permitted adjacent leg, never bypassing story locks.
    var target: String = steps[1]
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
    var area_class: String = "建筑内部" if not world.interior_building.is_empty() else str(world.map_profile.get("kind","field"))
    var current_clock: Dictionary = router.state.rpg.get("game_clock",{})
    var minutes: int = int(current_clock.get("minutes",480))
    var time_label: String = "%02d:%02d" % [int(minutes/60),minutes%60]
    var weather_id: String = str(world.ambience.weather) if world.ambience!=null and is_instance_valid(world.ambience) else "clear"
    var weather_name: String = {"clear":"晴朗","rain":"阵雨","mist":"薄雾","ash":"浮灰"}.get(weather_id,"晴朗")
    var fog_progress: String = "未知"
    if world.fog != null:
        fog_progress = "%d%%" % world.fog.percent(world.fog_key())
    var discovery_line: String = ""
    if world.interior_building.is_empty() and world.discoveries!=null:
        var entries: Array = world.discoveries.entries(router.current_map())
        if not entries.is_empty():
            var finished: int = 0
            for record in entries:
                if bool(router.state.flags.get(world.discoveries.flag(router.current_map(),str(record.get("id",""))),false)):
                    finished += 1
            discovery_line = "\n地图调查：%d / %d" % [finished,entries.size()]
    map_info.text = "%s\n\n坐标：%d，%d  ·  %d × %d格\n类型：%s\n已探索：%s%s\n第%d天  %s  ·  %s" % [world_name,hero_pos.x,hero_pos.y,world.WIDTH,world.HEIGHT,area_class,fog_progress,discovery_line,int(current_clock.get("day",1)),time_label,weather_name]
    if shown_mode in ["world","region"]:
        var info: Dictionary = router.map_info(selected_map)
        if info.is_empty():
            route_info.text = "轻触城镇、洞窟或野外地点查看。\n浅蓝：到访\n灰白：发现\n暗色：未探索\n\n已到访 %d / 42" % router.visited_count()
        else:
            var name: String = str(info.get("name",selected_map))
            var steps: Array[String] = router.shortest_route(selected_map)
            var available: bool = steps.size() > 1 and router.can_travel(steps[1])
            var selected_spec: Dictionary = router.geography.zone(selected_map)
            var biome: String = str(selected_spec.get("biome",""))
            var setting: String = str(selected_spec.get("layout",""))
            var directions: PackedStringArray = []
            for stop in steps:
                directions.append(str(router.map_info(stop).get("name",stop)).left(8))
            var instructions: String = " → ".join(directions) if available else "尚未探索出可到达该地点的连续航路"
            route_info.text = "目的地：%s\n地貌：%s\n布局：%s\n\n路线：%s" % [name,biome,setting,instructions]
        route_button.visible = true
        var possible_route: Array[String] = router.shortest_route(selected_map)
        route_button.disabled = possible_route.size() <= 1
        route_button.text = "前往下一站（不越级）"
    else:
        route_info.text = "金色：主线目标\n浅蓝：委托NPC、证物、回访\n青绿：地区线索和隐藏补给\n绿色：客栈/建筑/营地\n紫色：符文机关\n白金：自己\n\n" + (quest_summary if not quest_destination.is_empty() else "探索世界并选择下一条支线。")
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
