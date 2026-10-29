extends Node2D
## Act-I geography-led surface art. The actual V3 road positions and collision
## decide where art appears. Uses imported Golden Horizon deck material and
## painterly accents; never makes a blocked cliff appear like a new shortcut.
const V3 = preload("res://scripts/world_level_v3.gd")
const TILE: int = 32
const PLANKS: String = "res://assets/art/runtime/act01_hd2d_v18/materials/planks.png"
const COBBLES: String = "res://assets/art/runtime/act01_hd2d_v18/materials/cobbles.png"
var village_cobbles: Texture2D
var map_id: String=""
var world: Dictionary={}
var level: Dictionary={}
var decks: Texture2D

func configure(key: String,geometry: Dictionary) -> void:
    map_id=key
    world=geometry
    level=V3.new().level(key)
    decks=load(PLANKS) as Texture2D if ResourceLoader.exists(PLANKS) else null
    village_cobbles=load(COBBLES) as Texture2D if ResourceLoader.exists(COBBLES) else null
    z_index=-2
    queue_redraw()

func _valid_floor(cell: Vector2i) -> bool:
    var extent: Vector2i=world.get("size",Vector2i(72,48))
    if cell.x<3 or cell.y<3 or cell.x>=extent.x-3 or cell.y>=extent.y-3:
        return false
    return (world.get("tiles",{}) as Dictionary).has(cell) and not (
        world.get("blocked",{}) as Dictionary).has(cell) and not (
        world.get("water_mask",{}) as Dictionary).has(cell)

func _path_cells(id_fragment: String) -> Array[Vector2i]:
    var occupied: Dictionary={}
    var result: Array[Vector2i]=[]
    for road in level.get("roads",[]):
        if not str(road.get("id","")).contains(id_fragment):
            continue
        var points: Array=road.get("points",[])
        for i in range(points.size()-1):
            var pa: Array=points[i]
            var pb: Array=points[i+1]
            var a:=Vector2i(int(pa[0]),int(pa[1]))
            var b:=Vector2i(int(pb[0]),int(pb[1]))
            var steps: int=maxi(1,maxi(absi(a.x-b.x),absi(a.y-b.y)))
            for t in range(steps+1):
                var point:=Vector2i(roundi(lerpf(float(a.x),float(b.x),float(t)/steps)),
                    roundi(lerpf(float(a.y),float(b.y),float(t)/steps)))
                if not occupied.has(point) and _valid_floor(point):
                    occupied[point]=true
                    result.append(point)
    return result

func _draw() -> void:
    if world.is_empty() or level.is_empty():
        return
    match map_id:
        "map_coast_01":
            _village_courtyard()
        "map_coast_02":
            _harbor_quays()
        "map_coast_03":
            _saltwind_terraces()
        "map_coast_04":
            _cavern_pool_edges()
        "map_coast_05":
            _lighthouse_stairway()

func _village_courtyard() -> void:
    # Paint the ACTUAL authored well-ring surface with the imported cobble
    # texture. No repeated rectangular cross roads or arbitrary full-map
    # stone stamp; every mark is checked against gameplay collision.
    for cell in _path_cells("dew-circular-well-plaza"):
        var spot: Vector2 = Vector2(cell*TILE)
        if village_cobbles != null and village_cobbles.get_width() >= TILE and village_cobbles.get_height() >= TILE:
            var max_x: int = village_cobbles.get_width()-TILE+1
            var max_y: int = village_cobbles.get_height()-TILE+1
            var crop: Rect2 = Rect2(
                Vector2(float(posmod(cell.x*17+cell.y*3,maxi(1,max_x))),
                        float(posmod(cell.y*11+cell.x*7,maxi(1,max_y)))),
                Vector2(TILE,TILE))
            draw_texture_rect_region(village_cobbles,Rect2(spot,Vector2(TILE,TILE)),
                crop,Color(0.98,0.91,0.76,0.58))
        if posmod(cell.x*7+cell.y*5,5) == 0:
            draw_line(spot+Vector2(5,25),spot+Vector2(25,24),
                Color("6d685b",0.29),1.4)
    # A few fine sandy lane-edge accents, anchored to the village's
    # real east market footpath instead of covering grass everywhere.
    for cell in _path_cells("dew-market-and-inn-lanes"):
        if posmod(cell.x+cell.y,3) != 0:
            continue
        var pos: Vector2=Vector2(cell*TILE)
        draw_line(pos+Vector2(4,28),pos+Vector2(21,27),
            Color("e9d7a5",0.37),2.0)
    # Lower herb plots use a consistent warm soil rhythm, outside solids.
    var well: Vector2=Vector2(35.5,21.5)*TILE
    for segment in range(52):
        var a: float=TAU*float(segment)/52.0
        var p:=Vector2(well.x+225.0*cos(a),well.y+134.0*sin(a))
        var cell:=Vector2i(floori(p.x/TILE),floori(p.y/TILE))
        if not _valid_floor(cell):
            continue
        draw_circle(p,3.5,Color("d4c6a2",0.57))
        if segment%4==0:
            draw_line(p-Vector2(5,1),p+Vector2(4,-1),Color("817963",0.42),1.4)
    # Garden furrows beside the southern homes; no random all-map scatter.
    for row in range(4):
        var yy: float=float(39+row*2)*TILE
        for x in range(12,28):
            var cell:=Vector2i(x,39+row*2)
            if _valid_floor(cell):
                draw_line(Vector2(x*TILE+5,yy+7),
                    Vector2(x*TILE+24,yy+7),Color("826b4c",0.36),2.0)
                if x%3==0:
                    draw_circle(Vector2(x*TILE+14,yy+12),3,Color("7a9b65",0.62))

func _harbor_quays() -> void:
    # Real Golden Horizon plank material is only placed on walked-on harbor
    # jetty corridors, not straight across deep-water collision.
    for label in ["boarding-pier","shipyard-pier"]:
        var tiles: Array[Vector2i]=_path_cells(label)
        for cell in tiles:
            var p: Vector2=Vector2(cell*TILE)
            draw_rect(Rect2(p,Vector2(TILE,TILE)),Color("725743",0.84),true)
            if decks!=null and decks.get_width()>=TILE and decks.get_height()>=TILE:
                var source:=Vector2(float(posmod(cell.x*11, maxi(1,decks.get_width()-TILE))),
                    float(posmod(cell.y*7,maxi(1,decks.get_height()-TILE))))
                draw_texture_rect_region(decks,Rect2(p,Vector2(TILE,TILE)),
                    Rect2(source,Vector2(TILE,TILE)),Color(0.94,0.84,0.72,0.66))
            draw_line(p+Vector2(0,9),p+Vector2(TILE,9),
                Color("503c2e",0.75),1.8)
            draw_line(p+Vector2(0,25),p+Vector2(TILE,25),
                Color("d7b88d",0.48),1.0)
            if posmod(cell.x+2*cell.y,7)==0:
                draw_rect(Rect2(p+Vector2(3,4),Vector2(3,5)),
                    Color("dbc197",0.66),true)
    # Continuous quay edge separates waterfront work zone from merchant street.
    for cell in _path_cells("quay-main-street"):
        if cell.x%3==0 and cell.x>23 and cell.x<76:
            var p:=Vector2(cell*TILE)+Vector2(15,15)
            draw_line(p-Vector2(10,0),p+Vector2(9,0),
                Color("d9c6a2",0.45),3.0)

func _saltwind_terraces() -> void:
    # Stone retaining courses and wind-worn trail edges follow the actual
    # switchback network, creating clear high/low travel bands.
    var switchbacks: Array[Vector2i]=_path_cells("ascending-switchbacks")
    for cell in switchbacks:
        if posmod(cell.x+cell.y,3)!=0:
            continue
        var p:=Vector2(cell*TILE)+Vector2(6,25)
        draw_line(p,p+Vector2(20,-2),Color("e8d0a5",0.39),3.0)
        draw_line(p+Vector2(0,4),p+Vector2(14,3),
            Color("665948",0.48),1.5)
    for cell in _path_cells("high-watch-terrace"):
        if posmod(cell.x,2)==0:
            var p:=Vector2(cell*TILE)+Vector2(4,7)
            draw_line(p,p+Vector2(24,0),Color("9b927c",0.65),3.0)
            draw_line(p+Vector2(3,5),p+Vector2(18,5),Color("dfc69a",0.33),1.0)
    # Preserve visual calm near the whale skeleton: no clutter stamped there.

func _cavern_pool_edges() -> void:
    var wet: Dictionary=world.get("water_mask",{})
    var floors: Dictionary=world.get("tiles",{})
    for cell in wet.keys():
        var at: Vector2i=cell
        var border: bool=false
        for delta in [Vector2i.LEFT,Vector2i.RIGHT,Vector2i.UP,Vector2i.DOWN]:
            var near: Vector2i=at+delta
            if not wet.has(near) and floors.has(near) and _valid_floor(near):
                border=true
                break
        if not border:
            continue
        var p:=Vector2(at*TILE)
        # Small irregular surf lines soften the hard square atlas boundaries.
        var salt: int=posmod(at.x*7+at.y*13,5)
        draw_line(p+Vector2(4,12+salt),p+Vector2(25,11+salt),
            Color("97c6c3",0.36),2.2)
        if salt==0:
            draw_circle(p+Vector2(17,21),3.0,Color("b3d7d0",0.20))
    for cell in _path_cells("crystal-stalactite-bridge"):
        if posmod(cell.x+2*cell.y,3)==0:
            var p:=Vector2(cell*TILE)+Vector2(8,25)
            draw_line(p,p+Vector2(18,-5),Color("aaa68f",0.41),2.2)

func _lighthouse_stairway() -> void:
    # The summit and intermediate overlooks are stone terraces. Draw actual
    # tread rhythm along the winding climb, not a copied harbor boardwalk.
    for cell in _path_cells("main-cliff-spiral"):
        if posmod(cell.x+2*cell.y,3)!=0:
            continue
        var p:=Vector2(cell*TILE)+Vector2(6,19)
        draw_line(p,p+Vector2(21,-1),Color("ded5b7",0.61),3.2)
        draw_line(p+Vector2(1,4),p+Vector2(19,3),Color("736c5f",0.48),1.4)
    for center in [Vector2i(58,24),Vector2i(80,29),Vector2i(86,20)]:
        for x in range(-3,4):
            for y in range(-2,3):
                var cell: Vector2i=center+Vector2i(x,y)
                if not _valid_floor(cell) or posmod(x+y,3)!=0:
                    continue
                var p:=Vector2(cell*TILE)+Vector2(4,6)
                draw_line(p,p+Vector2(14,0),Color("d7cab0",0.35),1.5)
