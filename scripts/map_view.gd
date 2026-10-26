extends Control
## Local-area and minimap renderer. All terrain and legitimate interaction markers
## remain visible; no exploration fog, region atlas or global world chart.

const W: int = 72
const H: int = 48
const TILE: float = 32.0
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
## The same tile renderer works for all 40 production maps and authored interiors.
## Compact view follows the player; expanded view supports zoom and touch/mouse panning.
var local_zoom: float = 1.0
var local_pan: Vector2 = Vector2.ZERO
var local_context: String = ""
const MIN_LOCAL_ZOOM: float = 1.0
const MAX_LOCAL_ZOOM: float = 4.0


func setup(world_ref, router_ref, is_compact: bool = false) -> void:
    world = world_ref
    router = router_ref
    compact = is_compact
    clip_contents = true
    mouse_filter = Control.MOUSE_FILTER_STOP if not compact else Control.MOUSE_FILTER_IGNORE
    queue_redraw()

func display_mode(_value: String) -> void:
    # Preserve the public API for existing callers, but never expose the
    # deprecated global or regional atlas modes.
    mode = "local"
    queue_redraw()


func reset_local_view() -> void:
    local_zoom = 1.0
    local_pan = Vector2.ZERO
    queue_redraw()

func zoom_local(multiplier: float) -> void:
    if compact or multiplier <= 0.0:
        return
    local_zoom = clampf(local_zoom * multiplier, MIN_LOCAL_ZOOM, MAX_LOCAL_ZOOM)
    if is_equal_approx(local_zoom, MIN_LOCAL_ZOOM):
        local_pan = Vector2.ZERO
    queue_redraw()

func recenter_local() -> void:
    local_pan = Vector2.ZERO
    queue_redraw()

## Exposed to deterministic QA: the viewport is always clamped to authored terrain,
## even when maps expand beyond the legacy 72x48 grid.
func local_frame() -> Dictionary:
    if world == null or not is_instance_valid(world.layer):
        return {}
    var extent: Vector2i = world.terrain_layout.get("size", Vector2i(W,H))
    var actual_w: int = maxi(1,extent.x)
    var actual_h: int = maxi(1,extent.y)
    # Guarantee legible cells on narrow landscape devices instead of shrinking a
    # fixed 25x17 window into unreadable 3-pixel squares.
    var compact_columns: int = clampi(floori(maxf(1.0,size.x-20.0)/7.5),13,25)
    var compact_rows: int = clampi(floori(maxf(1.0,size.y-20.0)/7.5),9,17)
    var columns: int = mini(actual_w,compact_columns) if compact else clampi(ceili(float(actual_w)/local_zoom),1,actual_w)
    var rows: int = mini(actual_h,compact_rows) if compact else clampi(ceili(float(actual_h)/local_zoom),1,actual_h)
    var hero_tile: Vector2i = Vector2i(actual_w/2,actual_h/2)
    if is_instance_valid(world.hero):
        hero_tile = Vector2i(floori(world.hero.position.x/TILE),floori(world.hero.position.y/TILE))
    var pan: Vector2 = Vector2.ZERO if compact else local_pan
    var first_x: int = clampi(hero_tile.x-int(columns/2)+roundi(pan.x),0,maxi(0,actual_w-columns))
    var first_y: int = clampi(hero_tile.y-int(rows/2)+roundi(pan.y),0,maxi(0,actual_h-rows))
    if not compact and local_zoom <= MIN_LOCAL_ZOOM:
        first_x=0
        first_y=0
    var cell: float = minf(maxf(1.0,size.x-20.0)/float(columns),
        maxf(1.0,size.y-20.0)/float(rows))
    if cell <= 0.0:
        return {}
    var origin: Vector2 = (size-Vector2(float(columns),float(rows))*cell)*0.5
    var bounds: Rect2 = Rect2(origin,Vector2(float(columns),float(rows))*cell)
    return {"width":actual_w,"height":actual_h,"columns":columns,"rows":rows,
        "first_x":first_x,"first_y":first_y,"cell":cell,"origin":origin,
        "rect":bounds}

func targets(primary: String, secondary: String = "") -> void:
    main_target = primary
    side_target = secondary
    queue_redraw()

func _draw() -> void:
    draw_rect(Rect2(Vector2.ZERO, size), Color("0c1d30"), true)
    _draw_local()

## Distinct cartographic palettes for the eight authored regions and room floors.
## Only the UI is tinted; playable tiles, collision and story flags stay unchanged.
func _map_palette() -> Dictionary:
    if world != null and not world.interior_building.is_empty():
        return {"ground":Color("696778"),"road":Color("b3a38b"),
            "wall":Color("30354a"),"floor":Color("a58d77"),"water":Color("416f9b")}
    var biome: String = str(world.map_profile.get("biome","coastal"))
    match biome:
        "highland":
            return {"ground":Color("637f68"),"road":Color("b4a784"),
                "wall":Color("3d5353"),"floor":Color("809081"),"water":Color("40748f")}
        "volcanic":
            return {"ground":Color("826153"),"road":Color("b89172"),
                "wall":Color("4c3337"),"floor":Color("995c4d"),"water":Color("bb674a")}
        "archipelago":
            return {"ground":Color("438a7c"),"road":Color("c1b88d"),
                "wall":Color("31606c"),"floor":Color("8ba28c"),"water":Color("2869a0")}
        "mistforest":
            return {"ground":Color("476f66"),"road":Color("9b9d79"),
                "wall":Color("2b5154"),"floor":Color("668c77"),"water":Color("497d8c")}
        "badlands":
            return {"ground":Color("947561"),"road":Color("c0a17b"),
                "wall":Color("5d514d"),"floor":Color("b58e70"),"water":Color("647c94")}
        "celestial":
            return {"ground":Color("757b9e"),"road":Color("c2b9bd"),
                "wall":Color("4d4e79"),"floor":Color("938cac"),"water":Color("6c83be")}
        "metropolis":
            return {"ground":Color("6e7f88"),"road":Color("aaa798"),
                "wall":Color("404f62"),"floor":Color("948e93"),"water":Color("477a9a")}
        _:
            return {"ground":Color("517f6f"),"road":Color("b7a78a"),
                "wall":Color("334d59"),"floor":Color("a18d78"),"water":Color("377c9c")}

func _draw_local() -> void:
    var frame: Dictionary = local_frame()
    if frame.is_empty():
        return
    var actual_w: int = int(frame["width"])
    var actual_h: int = int(frame["height"])
    var columns: int = int(frame["columns"])
    var rows: int = int(frame["rows"])
    var first_x: int = int(frame["first_x"])
    var first_y: int = int(frame["first_y"])
    var cell: float = float(frame["cell"])
    var origin: Vector2 = frame["origin"]
    var map_rect: Rect2 = frame["rect"]
    draw_rect(map_rect.grow(2.0),Color("8298a1"),false,1.0)
    var palette: Dictionary = _map_palette()
    for y in range(first_y,first_y+rows):
        for x in range(first_x,first_x+columns):
            var tile: Vector2i = Vector2i(x,y)
            var shade: Color = palette["ground"]
            if world.layer.get_cell_source_id(tile)==1:
                shade=palette["water"]
            elif world.blocked.has(tile):
                shade=palette["wall"]
            else:
                var terrain: Vector2i = world.layer.get_cell_atlas_coords(tile)
                match terrain.y:
                    3: shade=palette["road"]
                    5: shade=palette["floor"]
                    1: shade=(palette["ground"] as Color).lightened(0.15)
                    4: shade=(palette["floor"] as Color).darkened(0.12)
                    6: shade=palette["wall"]
                    7: shade=(palette["ground"] as Color).lightened(0.10)
            var pos: Vector2 = origin+Vector2(x-first_x,y-first_y)*cell
            draw_rect(Rect2(pos,Vector2(cell+0.08,cell+0.08)),shade,true)
    if not compact:
        for i in range(1,4):
            var xx: float = origin.x+float(columns)*cell*float(i)/4.0
            draw_line(Vector2(xx,origin.y),Vector2(xx,origin.y+float(rows)*cell),
                Color(0.8,0.9,0.95,0.12),1.0)
        var town_plan: Dictionary = world.terrain_layout.get("town_plan",{})
        if not town_plan.is_empty():
            var town_font: Font = get_theme_default_font()
            for district in town_plan.get("districts",[]):
                var center_data: Array = district.get("center",[])
                if center_data.size()<2:
                    continue
                var loc: Vector2i = Vector2i(int(center_data[0]),int(center_data[1]))
                if loc.x<first_x or loc.x>=first_x+columns or loc.y<first_y or loc.y>=first_y+rows:
                    continue
                var label_pos: Vector2 = origin+Vector2(float(loc.x-first_x),float(loc.y-first_y))*cell
                if cell>=4.0 and town_font != null:
                    draw_string(town_font,label_pos+Vector2(-42,-6),
                        str(district.get("name","街区")),HORIZONTAL_ALIGNMENT_CENTER,
                        84.0,11,Color("f2e4c8"))
    for key in world.nodes.keys():
        var id: String = str(key)
        var node: Node2D = world.nodes[key]
        if not is_instance_valid(node) or not node.visible:
            continue
        var color: Color = Color.TRANSPARENT
        if id == main_target:
            color=MAIN
        elif id == side_target or id.begins_with("branchmap:") or id.begins_with("questhint:") or id.begins_with("story_stage_") or id.begins_with("side_") or id.begins_with("questcase:"):
            color=SIDE
        elif id in ["inn","home_door"] or id.begins_with("building:") or id.begins_with("questdoor:"):
            color=Color("84d9a4")
        elif id in ["shop","interior_service","interior_storage"]:
            color=Color("a9b6ff")
        elif id.begins_with("citizen:"):
            color=Color("aedce4")
        elif id.begins_with("field:"):
            var action: String=id.trim_prefix("field:")
            color={"trial":Color("dc9579"),"gather":Color("8bd89a"),"passage":Color("8acbea"),"cache":Color("f1d082")}.get(action,Color("b2c7de"))
        elif id.begins_with("townlife:"):
            color=Color("f2c980") if id=="townlife:handoff" else Color("8cddb5")
        elif id.begins_with("discovery:"):
            color=Color("a7d9bd")
        elif id.begins_with("puzzle:") or id.begins_with("dungeon_switch_"):
            color=Color("e69ae5")
        elif id in ["dungeon_chest","wild_cache"]:
            color=Color("f2bd73")
        elif id=="wild_camp":
            color=Color("a8de9a")
        elif id.begins_with("exit:") or id=="interior_exit":
            color=Color("e9b783")
        if color.a <= 0.0:
            continue
        var mark: Vector2i = Vector2i(floori(node.position.x/TILE),floori(node.position.y/TILE))
        if mark.x<0 or mark.y<0 or mark.x>=actual_w or mark.y>=actual_h:
            continue
        var objective: bool = id==main_target or id==side_target
        var pos: Vector2 = origin+(node.position/TILE-Vector2(first_x,first_y))*cell
        if not map_rect.has_point(pos):
            if compact and objective:
                var edge: Vector2 = Vector2(clampf(pos.x,map_rect.position.x+5.0,map_rect.end.x-5.0),
                    clampf(pos.y,map_rect.position.y+5.0,map_rect.end.y-5.0))
                draw_circle(edge,4.0,MAIN if id==main_target else SIDE)
            continue
        var radius: float = 3.0 if compact else 5.2
        draw_circle(pos,radius+1.2,Color("0a1b2b"))
        draw_circle(pos,radius,color)
        if id==main_target:
            draw_arc(pos,radius+3.0,0.0,TAU,20,MAIN,1.5)
    if is_instance_valid(world.hero):
        var hero_pos: Vector2 = origin+(world.hero.position/TILE-Vector2(first_x,first_y))*cell
        if map_rect.has_point(hero_pos):
            var hero_radius: float = 5.5 if compact else 8.0
            draw_circle(hero_pos,hero_radius,Color("132537"))
            draw_circle(hero_pos,hero_radius-2.1,HERO)
            var directions: Array[Vector2] = [Vector2.DOWN,Vector2.LEFT,Vector2.UP,Vector2.RIGHT]
            var heading: int = clampi(int(world.hero.facing),0,3)
            draw_line(hero_pos,hero_pos+directions[heading]*(hero_radius+3.0),HERO,2.0)

func _gui_input(event: InputEvent) -> void:
    if compact:
        return
    if mode=="local":
        if event is InputEventMouseButton:
            var mouse: InputEventMouseButton = event as InputEventMouseButton
            if mouse.pressed and mouse.button_index==MOUSE_BUTTON_WHEEL_UP:
                zoom_local(1.25)
                accept_event()
            elif mouse.pressed and mouse.button_index==MOUSE_BUTTON_WHEEL_DOWN:
                zoom_local(0.8)
                accept_event()
        elif event is InputEventMagnifyGesture:
            var gesture: InputEventMagnifyGesture = event as InputEventMagnifyGesture
            zoom_local(gesture.factor)
            accept_event()
        elif event is InputEventMouseMotion:
            var motion: InputEventMouseMotion = event as InputEventMouseMotion
            if (motion.button_mask & MOUSE_BUTTON_MASK_LEFT)!=0 and local_zoom>MIN_LOCAL_ZOOM:
                var frame: Dictionary = local_frame()
                if not frame.is_empty():
                    local_pan -= motion.relative / float(frame["cell"])
                    queue_redraw()
                    accept_event()
        elif event is InputEventScreenDrag and local_zoom>MIN_LOCAL_ZOOM:
            var touch: InputEventScreenDrag = event as InputEventScreenDrag
            var frame: Dictionary = local_frame()
            if not frame.is_empty():
                local_pan -= touch.relative / float(frame["cell"])
                queue_redraw()
                accept_event()
        return
