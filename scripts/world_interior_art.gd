extends Node2D
const InteractionFX = preload("res://scripts/c_interaction_fx.gd")
const TownSoundscape = preload("res://scripts/c_town_soundscape.gd")
## First commercial-art vertical slice: live art is driven by the V4 room,
## never an unplayable fullscreen illustration or a replacement game world.
const ART_DIR: String = "res://assets/art/interiors/morning_dew_inn/"
const PROFILE: String = "coast_inn_v1"
const DISTRICT_ART: String = "res://assets/art/interiors/coastal_district/"
var theme_atlas: String = ART_DIR+"inn_tileset.svg"
var soundscape: Node
var presentation_fx: Node2D
var reduced_motion: bool = false
var light_tick: float = 0.0

func set_reduced_motion(value: bool) -> void:
    reduced_motion = value
    if is_instance_valid(animated_fire):
        animated_fire.speed_scale = 0.5 if value else 1.0

## Called by D/B integration after authoritative interactions; does not open chests or doors in game state.
func play_prop_action(prop_id: String, action: String) -> bool:
    if action not in ["inspect", "open", "close", "light", "chest"]:
        return false
    if not prop_nodes.has(prop_id):
        return false
    var prop: Sprite2D = prop_nodes[prop_id] as Sprite2D
    if not is_instance_valid(prop):
        return false
    var pulse := create_tween()
    pulse.tween_property(prop, "modulate", Color(1.0, 0.88, 0.58), 0.11)
    pulse.tween_property(prop, "modulate", Color.WHITE, 0.18)
    if is_instance_valid(presentation_fx):
        var fx_kind: String = {"inspect":"inspect", "open":"door_open", "close":"door_close", "light":"lantern_on", "chest":"chest_open"}[action]
        presentation_fx.trigger(fx_kind, prop.position, reduced_motion)
    if is_instance_valid(soundscape):
        soundscape.play_foley({"open":"door_open", "close":"door_close", "chest":"chest_open", "light":"lantern_on", "inspect":"inspect"}[action])
    return true

func show_interaction(event_name: String, position_in_room: Vector2) -> bool:
    if not is_instance_valid(presentation_fx):
        return false
    return presentation_fx.trigger(event_name, position_in_room, reduced_motion)

const TILE: int = 32
const ALLOWED: Array[String] = [
    "counter", "bed", "fireplace", "bookshelf", "table",
    "window", "lantern", "rug", "curtain", "barrels",
    "window_sunshafts", "saltgrass_planter", "tideway_chart",
    "travelers_shelf", "bread_basket",
    "provisions_shelves", "merchant_counter", "guild_noticeboard",
    "guild_emblem", "smith_anvil", "smith_forge", "smith_toolwall",
    "home_hutch", "shrine_starseal", "shrine_altar",
    "shrine_incense", "harbor_guest_bed"
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
var room_day_tint: Color = Color("dbcebd")
var room_night_tint: Color = Color("b4ada7")

func _process(delta: float) -> void:
    # Soft asymmetric fire and lamp breathing, without any global time/timer.
    flicker_elapsed += delta
    light_tick += delta
    if light_tick < (0.28 if reduced_motion else 0.085):
        return
    light_tick = 0.0
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
        color_grade.color = room_night_tint if night else room_day_tint
    for lamp in active_lights:
        lamp.color = Color("fff0cd") if night else Color("ffe2b0")

func install(stage: Node2D, layout: Dictionary, minutes: int) -> void:
    var profile_id: String=str(layout.get("art_profile",""))
    if profile_id!=PROFILE and not profile_id.begins_with("coast_district_") and profile_id!="quest_research_v1":
        return
    if profile_id=="quest_research_v1":
        room_day_tint=Color(str(layout.get("room_day_tint","dbcebd")))
        room_night_tint=Color(str(layout.get("room_night_tint","b4ada7")))
    var chosen_atlas: String=str(layout.get("art_tileset",""))
    if not chosen_atlas.is_empty() and ResourceLoader.exists(chosen_atlas):
        theme_atlas=chosen_atlas
    name = "InteriorArt"
    if not is_instance_valid(soundscape):
        soundscape = TownSoundscape.new()
        soundscape.name = "IndoorSoundscape"
        add_child(soundscape)
    soundscape.configure(str(layout.get("map_id", "map_coast_01")), str(layout.get("building_id", "inn")), true)
    if not is_instance_valid(presentation_fx):
        presentation_fx = InteractionFX.new()
        presentation_fx.name = "InteriorInteractionFX"
        presentation_fx.z_index = 5
        add_child(presentation_fx)
    _build_wall_edging(layout)
    for value in layout.get("visuals",[]):
        if not value is Dictionary:
            continue
        var record: Dictionary = value
        var art_id: String = str(record.get("asset",""))
        var path: String = ART_DIR+art_id+".svg"
        if not ResourceLoader.exists(path):
            path=DISTRICT_ART+art_id+".svg"
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
    var foot: Array=[]
    for entry in layout.get("visuals",[]):
        if entry is Dictionary and str(entry.get("id","")) in ["north_fireplace","forge_hearth"]:
            foot=entry.get("cell",[])
            break
    if foot.size()!=2:
        return
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
    if not ResourceLoader.exists(theme_atlas):
        return
    var tiles := TileSet.new()
    tiles.tile_size=Vector2i(TILE,TILE)
    var source := TileSetAtlasSource.new()
    source.texture=load(theme_atlas)
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
