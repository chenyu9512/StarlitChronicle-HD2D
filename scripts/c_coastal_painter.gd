extends Node2D
## Authored C-line coastal dressing. Read-only view of world collision and map IDs.
const ArtOverrides = preload("res://scripts/c_art_overrides.gd")
const TilePool = preload("res://scripts/world_tileset_pool.gd")
const ART: String = "res://assets/art/exteriors/coast_final_pass/"
const TILE: int = 32
const ATLASES: Dictionary = {"map_coast_01":"dew_ground_glaze.svg","map_coast_02":"harbor_ground_glaze.svg"}
const SET_PIECES: Dictionary = {
    "map_coast_01":[
        ["dew_north_lantern","dew_street_lantern.svg",Vector2i(27,18)],
        ["dew_south_lantern","dew_street_lantern.svg",Vector2i(24,35)],
        ["dew_saltcloth","dew_saltcloth_rack.svg",Vector2i(46,33)]],
    "map_coast_02":[
        ["harbor_mooring_east","harbor_mooring_post.svg",Vector2i(74,34)],
        ["harbor_mooring_west","harbor_mooring_post.svg",Vector2i(65,39)],
        ["harbor_watch_lantern","dew_street_lantern.svg",Vector2i(36,20)]]
}
var accent_layer: TileMapLayer
var road_layer: TileMapLayer
var road_count: int = 0
var placements: Dictionary = {}
var active_lights: Array[PointLight2D] = []
var accent_count: int = 0
var quality: int = 2
var clock_minutes: int = 720
var elapsed: float = 0.0

func set_visual_quality(value: int) -> void:
    quality = clampi(value,0,2)
    for light in active_lights:
        light.visible = quality > 0
    set_process(quality > 1)

func set_clock(minutes: int) -> void:
    clock_minutes=posmod(minutes,1440)
    var strength: float = 0.0
    if clock_minutes >= 1140 or clock_minutes < 330:
        strength=1.0
    elif clock_minutes >= 1020:
        strength=float(clock_minutes-1020)/120.0
    elif clock_minutes < 420:
        strength=float(420-clock_minutes)/90.0
    for light in active_lights:
        light.energy=0.62*strength
        light.visible=quality>0 and strength>0.01

func configure(map_id: String,layout: Dictionary,sorted_stage: Node2D) -> void:
    if not ATLASES.has(map_id):
        return
    var path: String=ART+str(ATLASES[map_id])
    if not ResourceLoader.exists(path):
        return
    var texture: Texture2D=ArtOverrides.texture(path)
    if texture==null or texture.get_width()<256 or texture.get_height()<256:
        return
    var tile_paths: Array[String]=[path]
    var tile_set: TileSet=TilePool.shared(tile_paths)
    if tile_set==null:
        return
    accent_layer=TileMapLayer.new()
    accent_layer.name="OriginalCoastalInk"
    accent_layer.tile_set=tile_set
    accent_layer.z_index=-4
    accent_layer.texture_filter=CanvasItem.TEXTURE_FILTER_LINEAR
    add_child(accent_layer)
    var ground: Dictionary=layout.get("tiles",{})
    var blocked: Dictionary=layout.get("blocked",{})
    var water: Dictionary=layout.get("water_mask",{})
    var seed: int=1701 if map_id=="map_coast_01" else 2707
    for raw in ground.keys():
        var cell: Vector2i=raw
        if blocked.has(cell) or water.has(cell):
            continue
        var floor: Vector2i=ground[cell]
        var chance: int=9 if floor.y==3 else (15 if floor.y==5 else 23)
        var variation: int=posmod(cell.x*97+cell.y*151+cell.x*cell.y*13+seed,100)
        if variation>=chance:
            continue
        var art_row: int=3 if floor.y==3 else (5 if floor.y==5 else (1 if floor.y in [1,7] else 0))
        if map_id=="map_coast_02" and floor.y not in [3,5]:
            art_row=2 if variation%2==0 else 4
        accent_layer.set_cell(cell,0,Vector2i(posmod(cell.x*7+cell.y*11+seed,8),art_row))
        accent_count+=1
    if map_id == "map_coast_01":
        _install_dew_road_material(ground, blocked, water)
    if sorted_stage!=null:
        var used: Dictionary={}
        for entry in SET_PIECES.get(map_id,[]):
            var asset: String=ART+str(entry[1])
            if not ResourceLoader.exists(asset):
                continue
            var spot: Vector2i=_find_verge(entry[2],layout,used)
            if spot.x<0:
                continue
            var tex: Texture2D=ArtOverrides.texture(asset)
            if tex==null:
                continue
            var sprite:=Sprite2D.new()
            sprite.name=str(entry[0])
            sprite.texture=tex
            sprite.position=Vector2(spot*TILE)+Vector2(16,16)
            sprite.offset=Vector2(0,-float(tex.get_height())*0.5+9.0)
            sprite.z_index=3
            sprite.texture_filter=CanvasItem.TEXTURE_FILTER_LINEAR
            sprite.set_meta("art_source",asset)
            sprite.set_meta("art_foot",spot)
            sorted_stage.add_child(sprite)
            placements[sprite.name]=sprite
            used[spot]=true
            if str(entry[1])=="dew_street_lantern.svg":
                _add_lamp(sprite.position)
    set_visual_quality(quality)
    set_clock(clock_minutes)


## Batch C2.1: independent, authored 32px coastal cobble/grit artwork.
## Only paints existing passable road cells (terrain atlas row 3).
## Does not edit navigation, doors, building placement or collision dictionaries.
func _install_dew_road_material(ground: Dictionary, blocked: Dictionary, water: Dictionary) -> void:
    var path: String = ART + "dew_road_material_8x8.svg"
    if not ResourceLoader.exists(path):
        return
    var texture: Texture2D = ArtOverrides.texture(path)
    if texture == null or texture.get_width() != 256 or texture.get_height() != 256:
        return
    var road_paths: Array[String]=[path]
    var road_set: TileSet=TilePool.shared(road_paths)
    if road_set==null:
        return
    road_layer = TileMapLayer.new()
    road_layer.name = "OriginalDewRoadStone"
    road_layer.tile_set = road_set
    road_layer.z_index = -4
    road_layer.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
    add_child(road_layer)
    for raw in ground.keys():
        var cell: Vector2i = raw
        if blocked.has(cell) or water.has(cell):
            continue
        var tile: Vector2i = ground[cell]
        if tile.y != 3:
            continue
        # Semi-transparent pigment and weathering; leave natural exposed gaps.
        var variation: int = posmod(cell.x * 59 + cell.y * 83 + cell.x * cell.y * 7 + 2021, 100)
        if variation < 13:
            continue
        var column: int = posmod(cell.x * 11 + cell.y * 17 + 5, 8)
        var row: int = posmod(cell.x * 3 + cell.y * 7 + 2, 8)
        road_layer.set_cell(cell, 0, Vector2i(column, row))
        road_count += 1

func _find_verge(desired: Vector2i,layout: Dictionary,used: Dictionary) -> Vector2i:
    var size: Vector2i=layout.get("size",Vector2i(72,48))
    var ground: Dictionary=layout.get("tiles",{})
    var blocked: Dictionary=layout.get("blocked",{})
    var water: Dictionary=layout.get("water_mask",{})
    var spawn: Vector2i=layout.get("spawn",Vector2i(10,23))
    for radius in range(6):
        for y in range(-radius,radius+1):
            for x in range(-radius,radius+1):
                if absi(x)+absi(y)!=radius:
                    continue
                var cell: Vector2i=desired+Vector2i(x,y)
                if cell.x<4 or cell.y<4 or cell.x>=size.x-4 or cell.y>=size.y-4:
                    continue
                if blocked.has(cell) or water.has(cell) or used.has(cell) or cell.distance_squared_to(spawn)<20:
                    continue
                var ground_tile: Vector2i=ground.get(cell,Vector2i.ZERO)
                if ground_tile.y==3:
                    continue
                var near_building: bool=false
                for raw in layout.get("zone",{}).get("buildings",[]):
                    if not raw is Dictionary:
                        continue
                    var pos: Array=raw.get("pos",[])
                    var dims: Array=raw.get("size",[])
                    var door: Array=raw.get("door",[])
                    if pos.size()!=2 or dims.size()!=2:
                        continue
                    var center:=Vector2i(int(pos[0]),int(pos[1]))
                    var half:=Vector2i(int(dims[0])/2,int(dims[1])/2)
                    if abs(cell.x-center.x)<=half.x+1 and abs(cell.y-center.y)<=half.y+1:
                        near_building=true
                        break
                    if door.size()==2 and cell.distance_squared_to(Vector2i(int(door[0]),int(door[1]))+Vector2i.DOWN)<20:
                        near_building=true
                        break
                if not near_building:
                    return cell
    return Vector2i(-1,-1)

func _add_lamp(position_in_world: Vector2) -> void:
    if active_lights.size()>=4:
        return
    var file: String="res://assets/art/interiors/morning_dew_inn/light_pool.svg"
    if not ResourceLoader.exists(file):
        return
    var light:=PointLight2D.new()
    light.name="OriginalCoastalLantern%d" % active_lights.size()
    light.texture=ArtOverrides.texture(file)
    light.texture_scale=0.78
    light.color=Color("ffe0a8")
    light.position=position_in_world+Vector2(0,-52)
    add_child(light)
    active_lights.append(light)

func _process(delta: float) -> void:
    if quality<2 or active_lights.is_empty():
        return
    elapsed+=delta
    if elapsed<0.14:
        return
    var base: float=0.0
    if clock_minutes>=1140 or clock_minutes<330:
        base=0.62
    elif clock_minutes>=1020:
        base=0.62*float(clock_minutes-1020)/120.0
    elif clock_minutes<420:
        base=0.62*float(420-clock_minutes)/90.0
    for index in range(active_lights.size()):
        var l: PointLight2D=active_lights[index]
        if l.visible:
            l.energy=base*(0.985+0.015*sin(elapsed*2.3+float(index)*1.7))
