extends Control
## Drawn directly from the playable world's tiles and world-registry graph.
## Map is read-only; selecting a map never grants discovery or bypasses travel rules.
signal location_selected(map_id: String)

const W: int = 72
const H: int = 48
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
const GOLD: Color = Color("f6d27e")
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
    mode = value if value in ["local","region","world"] else "local"
    queue_redraw()

func targets(primary: String, secondary: String = "") -> void:
    main_target = primary
    side_target = secondary
    queue_redraw()

func _draw() -> void:
    draw_rect(Rect2(Vector2.ZERO, size), Color("0c1d30"), true)
    if mode == "world":
        _draw_atlas(false)
    elif mode == "region":
        _draw_atlas(true)
    else:
        _draw_local()

func _draw_local() -> void:
    if world == null or not is_instance_valid(world.layer):
        return
    # The compact map follows the hero through a 21 × 15-cell window.
    # The expanded map always displays the whole authored 44 × 28 terrain.
    var columns: int = 25 if compact else W
    var rows: int = 17 if compact else H
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
                if world.layer.get_cell_source_id(tile) == 1:
                    shade = Color("205c83")
                elif atlas.y == 3:
                    shade = PATH
                elif atlas.y == 5:
                    shade = Color("7a7480")
                elif atlas.y == 1:
                    shade = Color("3a806d")
                elif atlas.y == 4:
                    shade = Color("ad7554")
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
        elif id in ["inn", "home_door"] or id.begins_with("building:"):
            color = Color("84d9a4")
        elif id == "shop":
            color = Color("a9b6ff")
        elif id.begins_with("exit:") or id == "interior_exit":
            color = Color("e9b783")
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

func _map_xy(world_xy: Vector2, origin: Vector2, scale: Vector2) -> Vector2:
    return origin + world_xy*scale

func _region_color(region: String) -> Color:
    if router == null:
        return Color("4a8291")
    var data: Dictionary = router.geography.regions.get(region,{})
    return Color(str(data.get("color","#66899b")))

func _draw_island(center: Vector2, axes: Vector2, color: Color, seed: int) -> void:
    var vertices: PackedVector2Array = PackedVector2Array()
    for k in range(24):
        var angle: float = TAU*float(k)/24.0
        var ripple: float = 0.88 + 0.1*sin(float(k*5+seed)*1.37)
        vertices.append(center+Vector2(cos(angle)*axes.x,sin(angle)*axes.y)*ripple)
    draw_colored_polygon(vertices,color)
    for k in range(24):
        draw_line(vertices[k],vertices[(k+1)%24],color.lightened(0.27),1.4,true)

func _draw_atlas(regional: bool) -> void:
    map_points.clear()
    if router == null or router.state == null:
        return
    var font: Font = get_theme_default_font()
    var pad: Vector2 = Vector2(24,26)
    var available_size: Vector2 = Vector2(maxf(40.0,size.x-pad.x*2.0),maxf(40.0,size.y-pad.y*2.0))
    var world_offset: Vector2 = Vector2.ZERO
    var world_size: Vector2 = Vector2(1200,720)
    var current_region: String = str(router.current_info().get("region_id","region_coast"))
    if regional:
        var region_spec: Dictionary = router.geography.regions.get(current_region,{})
        var c: Array = region_spec.get("center",[600,360])
        world_offset = Vector2(float(c[0])-165.0,float(c[1])-135.0)
        world_size = Vector2(330,270)
    var scale: Vector2 = available_size/world_size
    for column in range(1,12):
        var xx: float = float(column)*100.0
        if xx < world_offset.x or xx > world_offset.x+world_size.x:
            continue
        var xpos: float = pad.x+(xx-world_offset.x)*scale.x
        draw_line(Vector2(xpos,pad.y),Vector2(xpos,size.y-pad.y),Color(0.5,0.75,0.84,0.10),1.0)
    for line in range(1,8):
        var yy: float = float(line)*90.0
        if yy < world_offset.y or yy > world_offset.y+world_size.y:
            continue
        var ypos: float = pad.y+(yy-world_offset.y)*scale.y
        draw_line(Vector2(pad.x,ypos),Vector2(size.x-pad.x,ypos),Color(0.5,0.75,0.84,0.10),1.0)
    for key in REGIONS:
        if regional and key != current_region:
            continue
        var region_data: Dictionary = router.geography.regions.get(key,{})
        var center_data: Array = region_data.get("center",[600,360])
        var radius_data: Array = region_data.get("radius",[110,110])
        var center: Vector2 = pad+(Vector2(float(center_data[0]),float(center_data[1]))-world_offset)*scale
        var radii: Vector2 = Vector2(float(radius_data[0])*scale.x,float(radius_data[1])*scale.y)
        var terrain_color: Color = _region_color(key)
        _draw_island(center,radii,terrain_color.darkened(0.5),abs(key.hash())%61)
        # Nested coast contours convey landmass instead of an abstract spreadsheet grid.
        _draw_island(center,radii*0.78,terrain_color.darkened(0.37),abs(key.hash())%83)
        if font != null:
            draw_string(font,center+Vector2(-70,-radii.y*0.68),str(router.regions.get(key,{}).get("name",key)),HORIZONTAL_ALIGNMENT_CENTER,140.0,16 if regional else 12,GOLD)
    for id in router.maps.keys():
        var map_id: String = str(id)
        var entry: Dictionary = router.geography.zone(map_id)
        if entry.is_empty() or not bool(entry.get("playable",false)):
            continue
        if regional and str(entry.get("region_id","")) != current_region:
            continue
        var p: Array = entry.get("atlas",[])
        if p.size()<2:
            continue
        var point: Vector2 = pad+(Vector2(float(p[0]),float(p[1]))-world_offset)*scale
        map_points[map_id] = point
    for id in map_points.keys():
        var origin: Vector2 = map_points[id]
        for edge in router.maps[id].get("neighbors",[]):
            var dest: String = str(edge)
            if id < dest and map_points.has(dest):
                var known: bool = router.is_available(str(id)) and router.is_available(dest)
                draw_line(origin,map_points[dest],Color("b4c4c5") if known else Color("496574"),3.0 if regional else 1.7,true)
    var discovered: Array = router.state.rpg.get("world",{}).get("discovered",[])
    var visited: Array = router.state.rpg.get("world",{}).get("visited",[])
    for id in map_points.keys():
        var entry: Dictionary = router.geography.zone(str(id))
        var point: Vector2 = map_points[id]
        var known: bool = id in discovered
        var current: bool = id == router.current_map()
        var typ: String = str(entry.get("type","field"))
        var color: Color = MAIN if current else (SIDE if id in visited else (Color("cfced0") if known else Color("405868")))
        var radius: float = 7.0 if regional else 4.2
        if current:
            draw_arc(point,radius+5.0,0,TAU,24,HERO,2.0)
        if typ in ["town","residential","hall"]:
            draw_rect(Rect2(point-Vector2(radius,radius),Vector2(radius*2,radius*2)),color,true)
        elif typ=="dungeon":
            draw_colored_polygon(PackedVector2Array([point+Vector2(0,-radius),point+Vector2(radius,0),point+Vector2(0,radius),point+Vector2(-radius,0)]),color)
        else:
            draw_circle(point,radius,color)
        if id == selected_location:
            draw_arc(point,radius+8.0,0.0,TAU,28,Color("fff3c0"),2.0)
        if font != null and known:
            var name: String = str(entry.get("name",id)).left(6 if not regional else 11)
            var shift: Vector2 = Vector2(-51,22 if regional else 14)
            draw_string(font,point+shift,name,HORIZONTAL_ALIGNMENT_CENTER,102.0,13 if regional else 10,Color("e6e0d0"))

func _gui_input(event: InputEvent) -> void:
    if mode == "local" or compact:
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
