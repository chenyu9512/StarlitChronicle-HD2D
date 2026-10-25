extends Control
## Drawn directly from the playable world's tiles and world-registry graph.
## Map is read-only; selecting a map never grants discovery or bypasses travel rules.
signal location_selected(map_id: String)

const W: int = 44
const H: int = 28
const TILE: float = 32.0
const REGIONS: Array[String] = [
    "region_coast", "region_oaths", "region_forge", "region_isles",
    "region_mirror", "region_oldland", "region_sanctum", "region_city"
]
const BASE: Color = Color("142c40")
const PASSABLE: Color = Color("345b62")
const PATH: Color = Color("668079")
const WALL: Color = Color("203546")
const MAIN: Color = Color("f6d27e")
const SIDE: Color = Color("7ad2e2")
const HERO: Color = Color("fff4c4")
var world
var router
var mode: String = "local"
var compact: bool = false
var main_target: String = ""
var side_target: String = ""
var selected_location: String = ""
var map_points: Dictionary = {}

func setup(world_ref, router_ref, is_compact: bool = false) -> void:
    world = world_ref
    router = router_ref
    compact = is_compact
    mouse_filter = Control.MOUSE_FILTER_STOP if not compact else Control.MOUSE_FILTER_IGNORE
    queue_redraw()

func display_mode(value: String) -> void:
    mode = value if value in ["local", "world"] else "local"
    queue_redraw()

func targets(primary: String, secondary: String = "") -> void:
    main_target = primary
    side_target = secondary
    queue_redraw()

func _draw() -> void:
    draw_rect(Rect2(Vector2.ZERO, size), Color("0c1d30"), true)
    if mode == "world":
        _draw_world()
    else:
        _draw_local()

func _draw_local() -> void:
    if world == null or not is_instance_valid(world.layer):
        return
    # The compact map follows the hero through a 21 × 15-cell window.
    # The expanded map always displays the whole authored 44 × 28 terrain.
    var columns: int = 21 if compact else W
    var rows: int = 15 if compact else H
    var first_x: int = 0
    var first_y: int = 0
    if compact and is_instance_valid(world.hero):
        var hero_tile: Vector2i = Vector2i(world.hero.position / TILE)
        first_x = clampi(hero_tile.x - int(columns / 2),0,W - columns)
        first_y = clampi(hero_tile.y - int(rows / 2),0,H - rows)
    var cell: float = minf((size.x - 20.0) / float(columns), (size.y - 20.0) / float(rows))
    if cell <= 0.0:
        return
    var origin: Vector2 = (size - Vector2(float(columns), float(rows)) * cell) * 0.5
    var map_rect: Rect2 = Rect2(origin, Vector2(float(columns),float(rows)) * cell)
    draw_rect(map_rect.grow(2.0), Color("8298a1"), false, 1.0)
    for y in range(first_y,first_y + rows):
        for x in range(first_x,first_x + columns):
            var tile: Vector2i = Vector2i(x, y)
            var shade: Color = PASSABLE
            if world.blocked.has(tile):
                shade = WALL
            else:
                var atlas: Vector2i = world.layer.get_cell_atlas_coords(tile)
                if atlas.y == 3:
                    shade = PATH
                elif atlas.y == 5:
                    shade = Color("38575a")
            draw_rect(Rect2(origin + Vector2(x - first_x,y - first_y) * cell, Vector2(cell + 0.08,cell + 0.08)), shade, true)
    if not compact:
        for i in range(1, 4):
            var xx: float = origin.x + float(W) * cell * float(i) / 4.0
            draw_line(Vector2(xx,origin.y), Vector2(xx,origin.y + float(H)*cell), Color(0.8,0.9,0.95,0.12), 1.0)
    for key in world.nodes.keys():
        var id: String = str(key)
        var node: Node2D = world.nodes[key]
        if not is_instance_valid(node) or not node.visible:
            continue
        var color: Color = Color.TRANSPARENT
        if id == main_target:
            color = MAIN
        elif id == side_target or id.begins_with("story_stage_") or id.begins_with("side_"):
            color = SIDE
        elif id in ["inn", "home_door"]:
            color = Color("84d9a4")
        elif id == "shop":
            color = Color("a9b6ff")
        if color.a <= 0.0:
            continue
        var pos: Vector2 = origin + (node.position / TILE - Vector2(first_x,first_y)) * cell
        if compact and not map_rect.has_point(pos):
            if id == main_target:
                var edge: Vector2 = Vector2(clampf(pos.x,map_rect.position.x + 5.0,map_rect.end.x - 5.0),clampf(pos.y,map_rect.position.y + 5.0,map_rect.end.y - 5.0))
                draw_circle(edge,4.0,MAIN)
            continue
        var radius: float = 3.0 if compact else 5.2
        draw_circle(pos, radius + 1.2, Color("0a1b2b"))
        draw_circle(pos, radius, color)
        if id == main_target:
            draw_arc(pos, radius + 3.0, 0.0, TAU, 20, MAIN, 1.5)
    if is_instance_valid(world.hero):
        var hero_pos: Vector2 = origin + (world.hero.position / TILE - Vector2(first_x,first_y)) * cell
        draw_circle(hero_pos, 5.5 if compact else 8.0, Color("132537"))
        draw_circle(hero_pos, 3.5 if compact else 5.5, HERO)
        draw_line(hero_pos, hero_pos + Vector2(0, -6.5 if compact else -10.0), HERO, 1.5)

func _draw_world() -> void:
    map_points.clear()
    if router == null or router.state == null:
        return
    var font: Font = get_theme_default_font()
    var left: float = 22.0
    var top: float = 38.0
    var body_width: float = maxf(60.0, size.x - 44.0)
    var body_height: float = maxf(60.0, size.y - 58.0)
    var columns: int = REGIONS.size()
    var locations: Dictionary = {}
    for region in REGIONS:
        locations[region] = []
    for key in router.maps.keys():
        var id: String = str(key)
        var region_id: String = str(router.maps[id].get("region_id",""))
        if locations.has(region_id):
            (locations[region_id] as Array).append(id)
    for column in range(columns):
        var rid: String = REGIONS[column]
        var center_x: float = left + (float(column) + 0.5) * body_width / float(columns)
        var region_name: String = str(router.regions.get(rid,{}).get("name", rid))
        if font != null:
            draw_string(font, Vector2(center_x - 48, 23), region_name.left(7), HORIZONTAL_ALIGNMENT_CENTER, 96.0, 12, MAIN)
        var items: Array = locations[rid]
        items.sort()
        var count: int = items.size()
        for i in range(count):
            var y: float = top + (float(i) + 0.5) * body_height / float(maxi(1,count))
            map_points[str(items[i])] = Vector2(center_x, y)
    for key in map_points.keys():
        var source_id: String = str(key)
        var start: Vector2 = map_points[source_id]
        for n in router.maps[source_id].get("neighbors",[]):
            var neighbor_id: String = str(n)
            if source_id < neighbor_id and map_points.has(neighbor_id):
                var connected: bool = router.is_available(source_id) and router.is_available(neighbor_id)
                draw_line(start, map_points[neighbor_id], Color("628a9d") if connected else Color("334858"), 1.5, true)
    var visited: Array = router.state.rpg.get("world",{}).get("visited",[])
    var discovered: Array = router.state.rpg.get("world",{}).get("discovered",[])
    for key in map_points.keys():
        var id: String = str(key)
        var point: Vector2 = map_points[id]
        var is_current: bool = id == router.current_map()
        var known: bool = id in discovered
        var color: Color = MAIN if is_current else (SIDE if id in visited else (Color("aec1ca") if known else Color("415462")))
        draw_circle(point, 7.6 if is_current else 5.0, Color("091727"))
        draw_circle(point, 5.8 if is_current else 3.4, color)
        if id == selected_location:
            draw_arc(point, 10.0, 0.0, TAU, 28, HERO, 2.0)
        if font != null:
            var name: String = str(router.maps[id].get("name",id)).left(7) if known else "未探索"
            draw_string(font, point + Vector2(-45, 22), name, HORIZONTAL_ALIGNMENT_CENTER, 90.0, 11, color)

func _gui_input(event: InputEvent) -> void:
    if mode != "world" or compact:
        return
    var location: Vector2
    if event is InputEventMouseButton:
        if not event.pressed or event.button_index != MOUSE_BUTTON_LEFT:
            return
        location = event.position
    elif event is InputEventScreenTouch:
        if not event.pressed:
            return
        location = event.position
    else:
        return
    for key in map_points.keys():
        if location.distance_to(map_points[key]) <= 19.0:
            selected_location = str(key)
            location_selected.emit(selected_location)
            queue_redraw()
            accept_event()
            return
