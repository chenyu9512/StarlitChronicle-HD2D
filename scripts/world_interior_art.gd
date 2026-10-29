extends Node2D
const RuntimeArt = preload("res://scripts/c_art_runtime.gd")
const Generated = preload("res://scripts/global_generated_art_v3.gd")
const GeneratedFurniture = preload("res://scripts/c_generated_room_furniture_v4.gd")
const ArtOverrides = preload("res://scripts/c_art_overrides.gd")
const ThemeV2 = preload("res://scripts/c_art_theme_v2.gd")
const GlobalArt = preload("res://scripts/c_act01_global_art_v14.gd")
const SemanticArt = preload("res://scripts/c_act01_semantic_art_v17.gd")
const TilePool = preload("res://scripts/world_tileset_pool.gd")
const InteractionFX = preload("res://scripts/c_interaction_fx.gd")
const TownSoundscape = preload("res://scripts/c_town_soundscape.gd")
## First commercial-art vertical slice: live art is driven by the V4 room,
## never an unplayable fullscreen illustration or a replacement game world.
const ART_DIR: String = "res://assets/art/interiors/morning_dew_inn/"
const PROFILE: String = "coast_inn_v1"
const DISTRICT_ART: String = "res://assets/art/interiors/coastal_district/"
const SIGNATURE_DIR: String = "res://assets/art/interiors/morning_dew_signature/"
const SIGNATURE_MANIFEST: String = "res://data/assets/c_morning_dew_signature.json"
const BLACK_SAIL_ART: String = "res://assets/art/runtime/act01_tavern_v2/"
const SHELTER_ART: String = "res://assets/art/runtime/act01_shelter_v3/"
## Dedicated clinic furniture is registered in the same all-or-nothing V2
## theme as the rest of Act I. No tavern furniture identity is borrowed.
const SHELTER_PROPS: Dictionary = {
    "shelter_cot": true, "shelter_medicine_cabinet": true,
    "shelter_linen_cart": true, "shelter_treatment_tray": true,
    "medical_registration_counter": true, "treatment_bench": true,
}
const SEMANTIC_ROOM_ICONS: Dictionary = {
    "medicine":"res://assets/art/external/cc0_named_v1/icons/owlish_icons/base/icon_owlish_icons_medicine.png",
    "paper":"res://assets/art/external/cc0_named_v1/icons/owlish_icons/base/icon_owlish_icons_paper.png",
    "book":"res://assets/art/external/cc0_named_v1/icons/owlish_icons/base/icon_owlish_icons_book.png"
}
var theme_atlas: String = ART_DIR+"inn_tileset.svg"
var soundscape
var presentation_fx
var reduced_motion: bool = false
var visual_quality: int = 1
var light_tick: float = 0.0

func set_reduced_motion(value: bool) -> void:
    reduced_motion = value
    if is_instance_valid(animated_fire):
        animated_fire.speed_scale = 0.5 if value else 1.0

func set_visual_quality(level: int) -> void:
    visual_quality = clampi(level,0,2)
    set_reduced_motion(visual_quality == 0)
    # Lighting is purely visual. Keep one shadowless lamp on low; medium
    # offers two lights, high up to four with a limited shadow budget.
    var lamp_cap: int = 1 if visual_quality==0 else (2 if visual_quality==1 else 4)
    for index in range(active_lights.size()):
        var lamp: PointLight2D = active_lights[index]
        lamp.visible = index < lamp_cap
        lamp.shadow_enabled = visual_quality == 2 and index < 2
    set_process(visual_quality > 0)


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
var signature_nodes: Dictionary = {}
var detail_layer: TileMapLayer
var active_lights: Array[PointLight2D] = []
var light_energy: Array[float] = []
var color_grade: CanvasModulate
var occluder_count: int = 0
var flicker_elapsed: float = 0.0
var animated_fire: AnimatedSprite2D
## A light sourced from the real installed fireplace prop when the retired
## illustrated flame strip is unavailable. It is not claimed as frame art.
var hearth_glow: PointLight2D
var sun_shafts: Sprite2D
var night_mode: bool = false
var room_day_tint: Color = Color("dbcebd")
var room_night_tint: Color = Color("b4ada7")

var _soft_lamp_cache: Texture2D

func _soft_lamp_texture() -> Texture2D:
    if _soft_lamp_cache != null:
        return _soft_lamp_cache
    # The retired light_pool.svg currently redirects to a paper-lantern prop.
    # An actual lamp falloff is lighting data, not an imported furniture image.
    var image := Image.create(64,64,false,Image.FORMAT_RGBA8)
    var centre := Vector2(31.5,31.5)
    for y in range(64):
        for x in range(64):
            var d: float = Vector2(float(x),float(y)).distance_to(centre)/31.5
            var strength: float = pow(clampf(1.0-d,0.0,1.0),1.8)
            image.set_pixel(x,y,Color(1.0,1.0,1.0,strength))
    _soft_lamp_cache = ImageTexture.create_from_image(image)
    return _soft_lamp_cache


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
    if is_instance_valid(hearth_glow):
        hearth_glow.energy = 0.72 * (1.0 + (0.03 if reduced_motion else 0.13) *
            sin(flicker_elapsed * 7.1))
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
    var active_act01_room: bool = profile_id in ["coast_act01_shelter_v1","coast_act01_tavern_v1"]
    var black_sail_room: bool = profile_id == "coast_act01_tavern_v1"
    var shelter_room: bool = profile_id == "coast_act01_shelter_v1"
    if profile_id!=PROFILE and not profile_id.begins_with("coast_district_") and profile_id!="quest_research_v1" and not active_act01_room:
        return
    if active_act01_room:
        # Stage-specific color temperature accompanies *real* imported
        # furniture/tiles, without altering floor occupancy or save IDs.
        room_day_tint=Color(str(layout.get("room_day_tint","dbcebd")))
        room_night_tint=Color(str(layout.get("room_night_tint","b4ada7")))
    if profile_id=="quest_research_v1":
        room_day_tint=Color(str(layout.get("room_day_tint","dbcebd")))
        room_night_tint=Color(str(layout.get("room_night_tint","b4ada7")))
    var chosen_atlas: String=str(layout.get("art_tileset",""))
    if not chosen_atlas.is_empty() and ArtOverrides.exists(chosen_atlas):
        theme_atlas=chosen_atlas
    name = "InteriorArt"
    if not is_instance_valid(soundscape):
        soundscape = TownSoundscape.new()
        soundscape.name = "IndoorSoundscape"
        add_child(soundscape)
    var identity: String = str(layout.get("layout_id", ""))
    var map_key: String = str(layout.get("map_id", ""))
    var room_key: String = str(layout.get("building_id", ""))
    if identity.contains("#"):
        var parts: PackedStringArray = identity.split("#")
        if parts.size() >= 2:
            if map_key.is_empty():
                map_key = parts[0]
            if room_key.is_empty():
                room_key = parts[1]
    if map_key.is_empty():
        map_key = "map_coast_01"
    if room_key.is_empty():
        room_key = "inn"
    soundscape.configure(map_key, room_key, true)
    if not is_instance_valid(presentation_fx):
        presentation_fx = InteractionFX.new()
        presentation_fx.name = "InteriorInteractionFX"
        presentation_fx.z_index = 5
        add_child(presentation_fx)
    _build_wall_edging(layout, map_key, room_key)
    _install_dew_signature(stage, layout, map_key, room_key)
    for value in layout.get("visuals",[]):
        if not value is Dictionary:
            continue
        var record: Dictionary = value
        var art_id: String = str(record.get("asset",""))
        var path: String = ART_DIR+art_id+".svg"
        if not ArtOverrides.exists(path):
            path=DISTRICT_ART+art_id+".svg"
        var place: Array = record.get("cell",[])
        # Main2 harbor rooms use curated 32px, physically imported V14 PNGs.
        # Obsolete SVG furniture slot names now point to unrelated generic
        # third-party tiles; never render a temple pillar as a medical bed.
        # Chapter IV uses dedicated, semantically correct Black Sail furnishings.
        # The shelter retains its approved imported PNGs and DLC behavior.
        var actual_prop: Texture2D = null
        if black_sail_room:
            actual_prop = ThemeV2.texture("interior.tavern."+art_id)
            if actual_prop == null:
                actual_prop = ArtOverrides.original_texture(BLACK_SAIL_ART+art_id+".svg")
        elif shelter_room and SHELTER_PROPS.has(art_id):
            actual_prop = ThemeV2.texture("interior.shelter." + art_id)
            if actual_prop == null:
                actual_prop = ArtOverrides.original_texture(SHELTER_ART + art_id + ".svg")
        elif active_act01_room:
            actual_prop = GlobalArt.texture_for_prop(art_id)
            if actual_prop == null:
                actual_prop = SemanticArt.texture_for_prop(art_id)
        if place.size()!=2:
            continue
        if active_act01_room:
            if actual_prop == null:
                push_warning("Act-I room furniture missing approved matching image: "+art_id)
                continue
        elif art_id not in ALLOWED:
            continue
        var prop := Sprite2D.new()
        prop.name = str(record.get("id",art_id))
        prop.texture = actual_prop if active_act01_room else RuntimeArt.texture_path(path)
        if prop.texture == null and not active_act01_room:
            # V4 rooms previously depended on removed coastal-district SVGs.
            # Use identifiable generated 2D furniture rather than silently
            # omitting the service desk, bed, shelves or decorative objects.
            prop.texture = GeneratedFurniture.texture(art_id)
        if prop.texture == null:
            push_warning("No matching V4 room prop: " + art_id)
            continue
        if active_act01_room:
            prop.set_meta("act01_imported_furniture",true)
            if black_sail_room:
                prop.set_meta("black_sail_v2_asset",BLACK_SAIL_ART+art_id+".svg")
            elif shelter_room and SHELTER_PROPS.has(art_id):
                prop.set_meta("shelter_medical_furniture_source", SHELTER_ART + art_id + ".svg")
            # A medical basket and an unsigned sailor's log must not both
            # appear as identical crates. These are existing third-party PNG
            # labels composited over actually imported, interactive furniture.
            var clue_icon: String = str(record.get("icon",""))
            if SEMANTIC_ROOM_ICONS.has(clue_icon):
                var icon_texture: Texture2D = ArtOverrides.original_texture(str(SEMANTIC_ROOM_ICONS[clue_icon]))
                if icon_texture != null:
                    var badge_art := Sprite2D.new()
                    badge_art.name = "ClueMaterial_"+clue_icon
                    badge_art.texture = icon_texture
                    badge_art.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
                    badge_art.scale = Vector2.ONE * minf(1.0,16.0/maxf(1.0,maxf(float(icon_texture.get_width()),float(icon_texture.get_height()))))
                    badge_art.position = Vector2(12.0,-12.0)
                    badge_art.z_index = 1
                    prop.add_child(badge_art)
                    prop.set_meta("semantic_icon",clue_icon)
                else:
                    push_warning("Missing approved indoor clue icon: "+clue_icon)
        # Runtime V14 room PNGs are high-resolution standalone objects.
        # Without proportional downscaling they span 10-20 floor cells and
        # completely conceal doors, beds and the playable protagonist.
        if active_act01_room:
            var footprint: Vector2=Vector2(60.0,68.0)
            match art_id:
                "fish_stall":
                    footprint=Vector2(92.0,72.0) # counter/service sideboard
                "barrel":
                    footprint=Vector2(56.0,66.0) # wine or medical supply
                "crate":
                    footprint=Vector2(49.0,47.0) # luggage/medicine chest
                "sign":
                    footprint=Vector2(54.0,68.0) # noticeboard
                "flowerpot":
                    footprint=Vector2(46.0,58.0)
                "star_lantern":
                    footprint=Vector2(38.0,57.0)
            if active_act01_room:
                var authored_footprint: Array = record.get("footprint",[])
                if authored_footprint.size()==2:
                    footprint=Vector2(float(authored_footprint[0]),float(authored_footprint[1]))
            var texsize: Vector2=Vector2(prop.texture.get_size())
            var ratio: float=minf(1.0,minf(footprint.x/maxf(1.0,texsize.x),
                footprint.y/maxf(1.0,texsize.y)))
            prop.scale=Vector2.ONE*ratio
            prop.set_meta("room_visual_footprint",footprint)
            prop.set_meta("room_art_scale",ratio)
            # Metadata/item icons need to stay readable after their parent is
            # rescaled, rather than shrinking to sub-pixel badges.
            for child in prop.get_children():
                if child is Sprite2D:
                    child.scale/=maxf(0.001,ratio)
                    child.position/=maxf(0.001,ratio)
        prop.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST if black_sail_room else (CanvasItem.TEXTURE_FILTER_LINEAR if active_act01_room else CanvasItem.TEXTURE_FILTER_NEAREST)
        # Y-sort uses the *floor contact point*, not the image offset. The
        # player and furniture must share z=3 so tables can hide/cover legs.
        prop.position = Vector2(float(place[0])*TILE+16.0,float(place[1])*TILE+16.0)
        var visual_offset: Array = record.get("offset",[0,0])
        if visual_offset.size()==2:
            if active_act01_room:
                # Sprite origin is the documented floor-contact cell, not
                # the giant PNG canvas center.
                var ratio: float=maxf(0.001,prop.scale.x)
                prop.offset=Vector2(float(visual_offset[0])/ratio,
                    -float(prop.texture.get_height())*0.5+10.0/ratio+
                    float(visual_offset[1])/ratio)
            else:
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
        lamp.texture = _soft_lamp_texture()
        lamp.position = Vector2(float(cell[0])*TILE+16.0,float(cell[1])*TILE+16.0)
        lamp.texture_scale = clampf(float(raw_light.get("scale",2.0)),0.5,4.0)
        lamp.energy = clampf(float(raw_light.get("energy",0.7)),0.1,1.5)
        lamp.shadow_enabled = true
        add_child(lamp)
        active_lights.append(lamp)
        light_energy.append(lamp.energy)
    set_clock(minutes)
    set_visual_quality(visual_quality)

## C2.1: real room-specific original images, not a UI colour overlay.
## Decorative floor cloths do not alter collision or navigation. Hanging images
## share the existing wall display plane and are not granted interaction IDs.
func _install_dew_signature(stage: Node2D, layout: Dictionary, map_key: String, room_key: String) -> void:
    if map_key != "map_coast_01" or not FileAccess.file_exists(SIGNATURE_MANIFEST):
        return
    var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(SIGNATURE_MANIFEST))
    if not parsed is Dictionary or str(parsed.get("schema", "")) != "starlit.c_morning_dew_signature.v1":
        return
    var rooms: Dictionary = parsed.get("room_dressing", {})
    if not rooms.has(room_key):
        return
    var ground: Dictionary = layout.get("tiles", {})
    var blocked: Dictionary = layout.get("blocked", {})
    for record in rooms.get(room_key, []):
        if not record is Dictionary:
            continue
        var id: String = str(record.get("id", ""))
        var asset: String = str(record.get("asset", ""))
        var layer: String = str(record.get("layer", ""))
        var xy: Array = record.get("cell", [])
        if id.is_empty() or signature_nodes.has(id) or asset.contains("/") or not asset.ends_with(".svg") or xy.size() != 2:
            continue
        if layer not in ["floor", "wall"]:
            continue
        var point := Vector2i(int(xy[0]), int(xy[1]))
        if layer == "floor":
            if blocked.has(point) or not ground.has(point):
                continue
            var safe_footprint: bool = true
            for delta in [Vector2i.ZERO, Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
                if blocked.has(point + delta):
                    safe_footprint = false
                    break
            if not safe_footprint:
                continue
        var path: String = SIGNATURE_DIR + asset
        # The historical 12 SVG motifs were deleted, and almost all their
        # migration targets are the SAME shrine wall tile. Never stamp that
        # object onto a house, shop, guild or inn floor/wall as false identity.
        # A future physically imported or explicitly user-approved DLC motif
        # can fill this exact logical slot without changing room geometry,
        # NPCs or save IDs. A migration to a random shrine-wall PNG cannot.
        var original_or_approved: bool=ResourceLoader.exists(path) or ArtOverrides.has_override(path)
        if not original_or_approved:
            continue
        var texture: Texture2D = RuntimeArt.texture_path(path)
        if texture == null:
            continue
        var art := Sprite2D.new()
        art.name = id
        art.texture = texture
        art.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
        art.position = Vector2(float(point.x) * TILE + 16.0, float(point.y) * TILE + 16.0)
        var art_offset: Array = record.get("offset", [0, 0])
        if art_offset.size() == 2:
            art.offset = Vector2(float(art_offset[0]), float(art_offset[1]))
        art.z_index = -3 if layer == "floor" else -1
        art.set_meta("signature_cell", point)
        art.set_meta("signature_layer", layer)
        if layer == "floor":
            add_child(art)
        else:
            stage.add_child(art)
        signature_nodes[id] = art

func _install_fire_animation(stage: Node2D,layout: Dictionary) -> void:
    var foot: Array=[]
    for entry in layout.get("visuals",[]):
        if entry is Dictionary and str(entry.get("id","")) in ["north_fireplace","forge_hearth"]:
            foot=entry.get("cell",[])
            break
    if foot.size()!=2:
        return
    var center:=Vector2(float(foot[0])*TILE+16.0,float(foot[1])*TILE+16.0)
    var sheet_path: String=ART_DIR+"hearth_flames_6f.svg"
    var sheet: Texture2D=RuntimeArt.texture_path(sheet_path)
    if sheet==null or sheet.get_size()!=Vector2(384,64):
        # Main2 intentionally deleted the original drawn six-frame SVG.
        # Give the already imported furniture a warm *lighting* response,
        # without repurposing a tiny lantern PNG as a six-frame animation.
        hearth_glow=PointLight2D.new()
        hearth_glow.name="RealHearthWarmLight"
        hearth_glow.texture=_soft_lamp_texture()
        hearth_glow.position=center+Vector2(0,-35)
        hearth_glow.color=Color("ffc17a")
        hearth_glow.texture_scale=0.73
        hearth_glow.energy=0.72
        hearth_glow.shadow_enabled=false
        stage.add_child(hearth_glow)
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
    animated_fire=AnimatedSprite2D.new()
    animated_fire.name="HearthFireAnimation"
    animated_fire.sprite_frames=frames
    animated_fire.animation="hearth"
    animated_fire.position=center
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

func _build_wall_edging(layout: Dictionary, map_id: String, building_id: String) -> void:
    var edge_path: String = theme_atlas
    var edge_row: int = 7
    if not ArtOverrides.exists(edge_path):
        # Generated V3 room atlases have their authored WALL tiles in row 6.
        # Old V4 SVG tile atlases were retired; previously this returned
        # early, leaving all 12 coastal rooms without wall edging.
        edge_path = Generated.interior_path(map_id, building_id)
        edge_row = 6
    if edge_path.is_empty() or not ArtOverrides.exists(edge_path):
        push_warning("No drawable wall edging for " + map_id + "#" + building_id)
        return
    var atlas_paths: Array[String] = [edge_path]
    var tiles: TileSet = TilePool.shared(atlas_paths, 8, edge_row, 1)
    if tiles == null:
        return
    detail_layer = TileMapLayer.new()
    detail_layer.name = "WallEdgeTiles"
    detail_layer.tile_set = tiles
    detail_layer.z_index = -4
    detail_layer.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
    add_child(detail_layer)
    var walls: Dictionary = layout.get("blocked", {})
    var cells: Dictionary = layout.get("tiles", {})
    for item in cells.keys():
        var cell: Vector2i = item
        if not walls.has(cell) and walls.has(cell + Vector2i.UP):
            detail_layer.set_cell(cell + Vector2i.UP, 0, Vector2i(posmod(cell.x, 8), edge_row))
