extends Node2D
const ArtOverrides = preload("res://scripts/c_art_overrides.gd")
const TownAudio = preload("res://scripts/c_town_soundscape.gd")
## Native drawn roof/building painter. No third-party franchise assets.
## Each town shares the same doorway and collision footprint from WorldGeography.
const TILE: float = 32.0
var purpose: String = "house"
var title: String = ""
var biome: String = "coastal"
var cells: Vector2i = Vector2i(8,6)
var facade: Sprite2D
var ground_shadow: Sprite2D
var exterior_identity: String = ""
var entrance_local: Vector2 = Vector2.ZERO
var door_lamp: PointLight2D
var visual_time_minutes: int = 660
var motion_seconds: float = 0.0
var motion_tick: float = 0.0
var door_progress: float = 0.0
var door_target: float = 0.0
var reduced_motion: bool = false
var door_cue: AudioStreamPlayer2D
var _door_cooldown: float = 0.0
var _proximity_elapsed: float = 0.0

func _ready() -> void:
    if not is_instance_valid(door_cue):
        door_cue = AudioStreamPlayer2D.new()
        door_cue.name = "OriginalDoorFoley"
        door_cue.bus = "SFX" if AudioServer.get_bus_index("SFX") >= 0 else "Master"
        door_cue.volume_db = -26.0
        door_cue.max_distance = 180.0
        door_cue.stream = TownAudio.make_foley("door_open")
        add_child(door_cue)
    set_process(true)

func set_reduced_motion(value: bool) -> void:
    reduced_motion = value
    queue_redraw()

func play_door(opened: bool) -> void:
    var target: float = 1.0 if opened else 0.0
    if is_equal_approx(door_target, target):
        return
    door_target = target
    if _door_cooldown <= 0.0 and is_instance_valid(door_cue):
        door_cue.stream = TownAudio.make_foley("door_open" if opened else "door_close")
        door_cue.play()
        _door_cooldown = 0.25
    queue_redraw()

func _process(delta: float) -> void:
    var dt: float = minf(delta, 0.1)
    motion_seconds += dt
    _door_cooldown = maxf(0.0, _door_cooldown - dt)
    _proximity_elapsed += dt
    if _proximity_elapsed >= 0.14:
        _proximity_elapsed = 0.0
        play_door(_player_near_entrance())
    door_progress = move_toward(door_progress, door_target, dt * (8.0 if reduced_motion else 4.6))
    motion_tick += dt
    if motion_tick >= (0.33 if reduced_motion else 0.10) or not is_equal_approx(door_progress, door_target):
        motion_tick = 0.0
        queue_redraw()

func _player_near_entrance() -> bool:
    var stage: Node = get_parent()
    if stage == null:
        return false
    var entrance: Vector2 = to_global(entrance_local)
    for sibling in stage.get_children():
        if sibling == self or not sibling is Node2D:
            continue
        var script: Script = sibling.get_script() as Script
        if script == null or script.resource_path != "res://scripts/first_act_actor.gd":
            continue
        if (sibling as Node2D).global_position.distance_squared_to(entrance) < 52.0 * 52.0:
            return true
    return false

func _draw_scene_motion() -> void:
    var foot_y: float = entrance_local.y - 8.0
    var width: float = 23.0 * (1.0 - door_progress * 0.75)
    # Door feedback overlays the existing facade; collision/building footprint untouched.
    if door_progress > 0.02:
        draw_rect(Rect2(-13.0, foot_y - 22.0, 25.0, 35.0), Color(0.08, 0.10, 0.12, 0.47 * door_progress))
        draw_rect(Rect2(-12.0, foot_y - 21.0, width, 33.0), Color(0.47, 0.28, 0.17, 0.85))
    var phase: float = 0.0 if reduced_motion else sin(motion_seconds * 2.1)
    var high_y: float = -float(cells.y) * TILE * 0.5 + 4.0
    if purpose in ["inn", "shop", "guild"]:
        var x: float = float(cells.x) * TILE * 0.34
        draw_line(Vector2(x, high_y - 14), Vector2(x, high_y + 23), Color("765a42"), 2.0)
        draw_colored_polygon(PackedVector2Array([
            Vector2(x, high_y - 11), Vector2(x + 20 + phase * 2.0, high_y - 5),
            Vector2(x + 17 + phase * 2.5, high_y + 8), Vector2(x, high_y + 5)
        ]), Color(0.73, 0.61, 0.44, 0.88))
    if purpose == "smith":
        var chimney: Vector2 = Vector2(float(cells.x) * TILE * 0.25, high_y + 18.0)
        for i in range(3):
            var drift: float = fposmod(motion_seconds * 10.0 + float(i) * 7.0, 23.0)
            draw_circle(chimney + Vector2(drift * 0.5, -drift - 8.0), 2.0 + drift * 0.09, Color(0.62, 0.59, 0.56, 0.21 * (1.0 - drift / 23.0)))


func setup(kind: String,building_name: String,dimensions: Vector2i,area: String,map_key: String = "",minutes: int = 660,entrance_delta: Vector2i = Vector2i(-999,-999)) -> void:
    purpose = kind
    title = building_name
    biome = area
    cells = dimensions
    # Explicit door-relative position shared with the map's interaction tile.
    # Old callers use the south-facing central threshold as a safe fallback.
    entrance_local = Vector2(0.0,float(cells.y)*TILE*0.5)
    if entrance_delta.x != -999:
        entrance_local = Vector2(entrance_delta*TILE)
    exterior_identity=map_key+"#"+kind
    visual_time_minutes=minutes
    # The façade and actor share the exact y-sorted z layer. Our node position
    # remains its architectural floor contact; large roofs overlap characters
    # correctly as they move behind/forward across the doorway.
    z_index=3
    # The original painter remains the compatibility fallback for other biomes.
    var file: String = "res://assets/art/exteriors/coast_final_pass/%s_%s.svg" % [map_key,kind]
    if ArtOverrides.exists(file):
        facade=Sprite2D.new()
        facade.name="AuthoredFacade"
        facade.texture=ArtOverrides.texture(file)
        facade.texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST
        facade.scale=Vector2(float(cells.x)*TILE/256.0,float(cells.y)*TILE/192.0)
        facade.z_index=0
        add_child(facade)
        var shadow_file: String="res://assets/art/exteriors/coast_final_pass/building_ground_shadow.svg"
        if ArtOverrides.exists(shadow_file):
            ground_shadow=Sprite2D.new()
            ground_shadow.name="FootprintContactShadow"
            ground_shadow.texture=ArtOverrides.texture(shadow_file)
            ground_shadow.texture_filter=CanvasItem.TEXTURE_FILTER_LINEAR
            ground_shadow.scale=Vector2(float(cells.x)*TILE/256.0,float(cells.y)*TILE/192.0)
            ground_shadow.position=Vector2(0,float(cells.y)*TILE*0.5-22.0)
            ground_shadow.z_index=-1
            add_child(ground_shadow)
        var glow: String="res://assets/art/interiors/morning_dew_inn/light_pool.svg"
        if ArtOverrides.exists(glow):
            door_lamp=PointLight2D.new()
            door_lamp.name="DoorLanternLight"
            door_lamp.texture=ArtOverrides.texture(glow)
            door_lamp.texture_scale=0.58
            door_lamp.position=entrance_local+Vector2(0,-37)
            door_lamp.color=Color("ffdea1")
            add_child(door_lamp)
            set_clock(visual_time_minutes)
    queue_redraw()

func set_clock(minutes: int) -> void:
    visual_time_minutes=posmod(minutes,1440)
    if is_instance_valid(door_lamp):
        door_lamp.energy=0.85 if visual_time_minutes>=1140 or visual_time_minutes<360 else 0.16

func _palette() -> Dictionary:
    var wall: Color = Color("c5b093")
    var roof: Color = Color("456f83")
    var trim: Color = Color("e9d39e")
    match biome:
        "volcanic":
            wall=Color("aa826b")
            roof=Color("694955")
            trim=Color("e3aa6c")
        "highland":
            wall=Color("a7a79a")
            roof=Color("5b6770")
        "archipelago":
            wall=Color("d7bba0")
            roof=Color("397c92")
        "mistforest":
            wall=Color("b4bdc4")
            roof=Color("665a83")
        "badlands":
            wall=Color("bba585")
            roof=Color("625d52")
        "celestial":
            wall=Color("d8d1d1")
            roof=Color("8b80b5")
        "metropolis":
            wall=Color("b4a7ac")
            roof=Color("6b6175")
            trim=Color("f0c791")
    match purpose:
        "inn": roof=roof.lightened(0.13)
        "smith": roof=roof.darkened(0.30)
        "guild": roof=roof.darkened(0.08)
        "shrine": roof=Color("7797ae")
        "shop": roof=Color("b7745e")
    return {"wall":wall,"roof":roof,"trim":trim}

func _draw() -> void:
    if is_instance_valid(facade):
        _draw_scene_motion()
        return
    var palette: Dictionary = _palette()
    var w: float = float(cells.x)*TILE
    var h: float = float(cells.y)*TILE
    var shadow := Color(0.03,0.07,0.12,0.45)
    var roof: Color = palette["roof"]
    var trim: Color = palette["trim"]
    var wall: Color = palette["wall"]
    var left: float = -w/2.0
    var top: float = -h/2.0
    draw_rect(Rect2(left+12,top+32,w-16,h-12),shadow,true)
    draw_rect(Rect2(left+13,top+27,w-26,h-24),wall.darkened(0.19),true)
    draw_rect(Rect2(left+17,top+24,w-34,h-30),wall,true)
    for row in range(3):
        var yy: float = top+48.0+float(row)*30.0
        draw_line(Vector2(left+18,yy),Vector2(left+w-17,yy),wall.darkened(0.13),1.0)
    # Wide roof silhouette: sloped polygon, contrasting ridgeline and shingle strokes.
    var roof_poly: PackedVector2Array = PackedVector2Array([
        Vector2(left-5,top+28),Vector2(left+w/2.0,top-22),
        Vector2(left+w+5,top+28),Vector2(left+w-10,top+76),
        Vector2(left+10,top+76)
    ])
    draw_colored_polygon(roof_poly,roof)
    draw_polyline(PackedVector2Array([roof_poly[0],roof_poly[1],roof_poly[2]]),trim,3.0,true)
    draw_line(Vector2(left+10,top+74),Vector2(left+w-10,top+74),roof.darkened(0.35),3.0)
    for row in range(3):
        for col in range(maxi(3,int(cells.x))):
            var xx: float = left+20.0+float(col)*float((w-40.0)/float(maxi(3,int(cells.x))))
            var yy: float = top+21.0+float(row)*16.0+absf(xx)*0.08
            draw_line(Vector2(xx,yy),Vector2(xx+12,yy-1),roof.lightened(0.18 if (row+col)%2==0 else 0.05),1.1)
    # Three-dimensional porch with a highlighted physical doorway.
    var doorway: Rect2 = Rect2(-18,top+h-54,36,46)
    draw_rect(Rect2(doorway.position-Vector2(3,4),doorway.size+Vector2(6,4)),trim,true)
    draw_rect(doorway,Color("263f4c"),true)
    draw_rect(Rect2(doorway.position+Vector2(4,3),Vector2(28,37)),Color("704d38"),true)
    draw_circle(doorway.position+Vector2(25,24),2.5,Color("e4c27b"))
    for side in [-1,1]:
        var window_x: float = float(side)*(w/2.0-45.0)-12.0
        var window: Rect2 = Rect2(window_x,top+h-75,26,24)
        draw_rect(window,trim,true)
        draw_rect(window.grow(-3.0),Color("557d88"),true)
        draw_line(window.position+Vector2(13,3),window.position+Vector2(13,21),trim,2.0)
    # Functional visual markers distinguish market, forge, inn and shrine at a glance.
    var sigil_pos: Vector2 = Vector2(0,top+38)
    match purpose:
        "inn":
            draw_circle(sigil_pos,16.0,Color("f5d7a0"))
            draw_circle(sigil_pos+Vector2(4,-3),11.5,roof)
        "shop":
            draw_colored_polygon(PackedVector2Array([sigil_pos+Vector2(-18,8),sigil_pos+Vector2(18,8),sigil_pos+Vector2(10,-12),sigil_pos+Vector2(-10,-12)]),Color("f9dcaa"))
            for i in range(4):
                draw_line(sigil_pos+Vector2(-12+i*8,-9),sigil_pos+Vector2(-12+i*8,7),Color("cb8064"),2.0)
        "guild":
            draw_colored_polygon(PackedVector2Array([sigil_pos+Vector2(0,-16),sigil_pos+Vector2(14,-3),sigil_pos+Vector2(0,17),sigil_pos+Vector2(-14,-3)]),trim)
            draw_line(sigil_pos+Vector2(0,-11),sigil_pos+Vector2(0,10),roof.darkened(0.3),3)
        "smith":
            draw_rect(Rect2(sigil_pos-Vector2(16,5),Vector2(32,10)),Color("e0a768"),true)
            draw_line(sigil_pos+Vector2(-4,-17),sigil_pos+Vector2(10,-4),trim,5)
        "shrine":
            draw_circle(sigil_pos,16,trim)
            for i in range(8):
                var a: float = TAU*float(i)/8.0
                draw_line(sigil_pos+Vector2(cos(a),sin(a))*10.0,sigil_pos+Vector2(cos(a),sin(a))*16.0,Color.WHITE,2.2)
        _:
            draw_colored_polygon(PackedVector2Array([sigil_pos+Vector2(0,-12),sigil_pos+Vector2(12,0),sigil_pos+Vector2(0,12),sigil_pos+Vector2(-12,0)]),trim)
    _draw_scene_motion()
