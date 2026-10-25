extends Node2D
## First commercial-art vertical slice: live art is driven by the V4 room,
## never an unplayable fullscreen illustration or a replacement game world.
const ART_DIR: String = "res://assets/art/interiors/morning_dew_inn/"
const PROFILE: String = "coast_inn_v1"
const TILE: int = 32
const ALLOWED: Array[String] = [
    "counter", "bed", "fireplace", "bookshelf", "table",
    "window", "lantern", "rug", "curtain", "barrels",
    "window_sunshafts", "saltgrass_planter", "tideway_chart",
    "travelers_shelf", "bread_basket"
]
var prop_nodes: Dictionary = {}
var detail_layer: TileMapLayer
var active_lights: Array[PointLight2D] = []
var light_energy: Array[float] = []
var color_grade: CanvasModulate
var occluder_count: int = 0
var flicker_elapsed: float = 0.0
var animated_fire: AnimatedSprite2D
var sun_shafts: Sprite2D
var night_mode: bool = false

func _process(delta: float) -> void:
    # Soft asymmetric fire and lamp breathing, without any global time/timer.
    flicker_elapsed+=delta
    for i in range(active_lights.size()):
        var wav: float = sin(flicker_elapsed*(4.9 if i==0 else 1.2)+float(i)*1.7)
        var variation: float = (0.065 if i==0 else 0.025)*wav
        active_lights[i].energy=light_energy[i]*(1.0+variation)
    if is_instance_valid(sun_shafts):
        var daylight_alpha: float = 0.035 if night_mode else 0.46
        sun_shafts.modulate.a = daylight_alpha*(1.0+0.018*sin(flicker_elapsed*0.75))

func set_clock(minutes: int) -> void:
    # Called both on room creation and on the actual running world clock.
    var night: bool = minutes>=1140 or minutes<=330
    night_mode = night
    if is_instance_valid(sun_shafts):
        sun_shafts.modulate.a = 0.035 if night else 0.46
    if color_grade!=null:
        color_grade.color = Color("b4ada7") if night else Color("dbcebd")
    for lamp in active_lights:
        lamp.color = Color("fff0cd") if night else Color("ffe2b0")

func install(stage: Node2D, layout: Dictionary, minutes: int) -> void:
    if str(layout.get("art_profile",""))!=PROFILE:
        return
    name = "InteriorArt"
    _build_wall_edging(layout)
    for value in layout.get("visuals",[]):
        if not value is Dictionary:
            continue
        var record: Dictionary = value
        var art_id: String = str(record.get("asset",""))
        var path: String = ART_DIR+art_id+".svg"
        var place: Array = record.get("cell",[])
        if art_id not in ALLOWED or place.size()!=2 or not ResourceLoader.exists(path):
            continue
        var prop := Sprite2D.new()
        prop.name = str(record.get("id",art_id))
        prop.texture = load(path)
        prop.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
        # Y-sort uses the *floor contact point*, not the image offset. The
        # player and furniture must share z=3 so tables can hide/cover legs.
        prop.position = Vector2(float(place[0])*TILE+16.0,float(place[1])*TILE+16.0)
        var visual_offset: Array = record.get("offset",[0,0])
        if visual_offset.size()==2:
            prop.offset=Vector2(float(visual_offset[0]),float(visual_offset[1]))
        var artwork_layer: String = str(record.get("layer",""))
        if art_id in ["rug","window_sunshafts"] or artwork_layer=="floor":
            prop.z_index=-3
            add_child(prop)
        elif art_id in ["window","curtain","tideway_chart"] or artwork_layer=="wall":
            prop.z_index=-1
            stage.add_child(prop)
        else:
            prop.z_index=3
            stage.add_child(prop)
        if art_id=="window_sunshafts":
            sun_shafts=prop
        prop_nodes[prop.name]=prop
    _install_fire_animation(stage,layout)
    color_grade = CanvasModulate.new()
    color_grade.name = "InteriorColorGrade"
    add_child(color_grade)
    _build_occluders(layout)
    for raw_light in layout.get("light_sources",[]):
        if not raw_light is Dictionary:
            continue
        var cell: Array = raw_light.get("cell",[])
        if cell.size()!=2:
            continue
        var lamp := PointLight2D.new()
        lamp.name = str(raw_light.get("id","IndoorLamp"))
        lamp.texture = load(ART_DIR+"light_pool.svg")
        lamp.position = Vector2(float(cell[0])*TILE+16.0,float(cell[1])*TILE+16.0)
        lamp.texture_scale = clampf(float(raw_light.get("scale",2.0)),0.5,4.0)
        lamp.energy = clampf(float(raw_light.get("energy",0.7)),0.1,1.5)
        lamp.shadow_enabled = true
        add_child(lamp)
        active_lights.append(lamp)
        light_energy.append(lamp.energy)
    set_clock(minutes)

func _install_fire_animation(stage: Node2D,layout: Dictionary) -> void:
    # Six separately hand-authored RGBA frames; this is an actual sprite-sheet
    # animation, not a static fireplace plus brightness oscillator.
    var sheet_path: String=ART_DIR+"hearth_flames_6f.svg"
    if not ResourceLoader.exists(sheet_path):
        return
    var sheet: Texture2D=load(sheet_path)
    if sheet==null:
        return
    var frames:=SpriteFrames.new()
    frames.add_animation("hearth")
    frames.set_animation_speed("hearth",7.0)
    frames.set_animation_loop("hearth",true)
    for index in range(6):
        var tile:=AtlasTexture.new()
        tile.atlas=sheet
        tile.region=Rect2(index*64,0,64,64)
        frames.add_frame("hearth",tile)
    var foot: Array=[38,16]
    for entry in layout.get("visuals",[]):
        if entry is Dictionary and str(entry.get("id",""))=="north_fireplace":
            foot=entry.get("cell",foot)
            break
    animated_fire=AnimatedSprite2D.new()
    animated_fire.name="HearthFireAnimation"
    animated_fire.sprite_frames=frames
    animated_fire.animation="hearth"
    animated_fire.position=Vector2(float(foot[0])*TILE+16.0,float(foot[1])*TILE+16.0)
    animated_fire.offset=Vector2(0,-38)
    animated_fire.texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST
    animated_fire.z_index=3
    stage.add_child(animated_fire)
    animated_fire.play("hearth")

func _build_occluders(layout: Dictionary) -> void:
    # These shadows follow the same authored partition rectangles as collision.
    # Artist refinements can replace these simple silhouettes later.
    for raw_partition in layout.get("solid_regions",[]):
        if not raw_partition is Dictionary:
            continue
        var coords: Array = raw_partition.get("rect",[])
        if coords.size()!=4:
            continue
        var width: float = (float(coords[2])-float(coords[0])+1.0)*TILE
        var height: float = (float(coords[3])-float(coords[1])+1.0)*TILE
        if width<=0.0 or height<=0.0:
            continue
        var shape := OccluderPolygon2D.new()
        shape.polygon = PackedVector2Array([
            Vector2(0,0), Vector2(width,0),
            Vector2(width,height), Vector2(0,height)
        ])
        var occluder := LightOccluder2D.new()
        occluder.name = "WallShadow%d" % occluder_count
        occluder.occluder = shape
        occluder.position = Vector2(float(coords[0])*TILE,float(coords[1])*TILE)
        add_child(occluder)
        occluder_count+=1

func _build_wall_edging(layout: Dictionary) -> void:
    if not ResourceLoader.exists(ART_DIR+"inn_tileset.svg"):
        return
    var tiles := TileSet.new()
    tiles.tile_size=Vector2i(TILE,TILE)
    var source := TileSetAtlasSource.new()
    source.texture=load(ART_DIR+"inn_tileset.svg")
    source.texture_region_size=Vector2i(TILE,TILE)
    for x in range(8):
        source.create_tile(Vector2i(x,7))
    tiles.add_source(source,0)
    detail_layer=TileMapLayer.new()
    detail_layer.name="WallEdgeTiles"
    detail_layer.tile_set=tiles
    detail_layer.z_index=-4
    detail_layer.texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST
    add_child(detail_layer)
    var walls: Dictionary=layout.get("blocked",{})
    var cells: Dictionary=layout.get("tiles",{})
    for item in cells.keys():
        var cell: Vector2i=item
        if not walls.has(cell) and walls.has(cell+Vector2i.UP):
            detail_layer.set_cell(cell+Vector2i.UP,0,Vector2i(posmod(cell.x,8),7))
