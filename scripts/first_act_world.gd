extends Node2D
## 实际可探索地图：TileMapLayer / 实体交互 / 碰撞 / Y轴排序 / 镜头 / 遭遇。
signal interacted(target: String)
signal encounter_requested()

const Actor = preload("res://scripts/first_act_actor.gd")
const CArtOverrides = preload("res://scripts/c_art_overrides.gd")
const TilePool = preload("res://scripts/world_tileset_pool.gd")
const Geography = preload("res://scripts/world_geography.gd")
const WorldStructure = preload("res://scripts/world_structure.gd")
const TownLife = preload("res://scripts/world_town_life.gd")
const WorldDiscoveries = preload("res://scripts/world_discoveries.gd")
const WorldDungeonPuzzles = preload("res://scripts/world_dungeon_puzzles.gd")
const WorldTownEcology = preload("res://scripts/world_town_ecology.gd")
const WorldFieldEcology = preload("res://scripts/world_field_ecology.gd")
const NPCVisual = preload("res://scripts/world_npc_visual.gd")
const SceneDirector = preload("res://scripts/story_scene_director.gd")
const QuestSubmaps = preload("res://scripts/story_quest_submaps.gd")
const EvidencePuzzles = preload("res://scripts/story_evidence_puzzles.gd")
const Ambience = preload("res://scripts/world_ambience.gd")
const InteriorArt = preload("res://scripts/world_interior_art.gd")
const CoastalScene = preload("res://scripts/world_coastal_scene.gd")
const CoastalAudio = preload("res://scripts/world_coastal_audio.gd")
const PrologueStage = preload("res://scripts/prologue_world_stage.gd")
const INN_ATLAS: String = "res://assets/art/interiors/morning_dew_inn/inn_tileset.svg"
const TILE: int = 32
var WIDTH: int = 72
var HEIGHT: int = 48
const GROUND: String = "res://assets/art/tilesets/coast_ground.png"
const WATER: String = "res://assets/art/tilesets/coast_water.png"
const REGION_TILE_DIR: String = "res://assets/art/tilesets/regions/"
const REGION_NAMES: Array[String] = ["晨露村 · 十年前的星灯祭", "晨露村 · 澄舟旧屋", "白砂港 · 收容所", "断桅海蚀洞", "白砂港 · 黑帆酒馆", "鲸骨浅滩", "潮歌灯塔"]
const SCENE_LABELS: Array[String] = ["", "", "", "", "", "", ""]
const NPC_NAMES: Array[String] = ["澄舟", "村长", "港务员", "朔弦", "酒馆老板", "港务官", "守灯工匠"]
const PROPS: Array[String] = ["palm_tree", "cottage", "barrel", "sign", "beacon", "flowerpot", "crab", "rock", "star_lantern", "sea_crystal", "fish_stall", "dock_boat"]
const SITES: Dictionary = {
    "key_npc": Vector2i(16, 11),
    "clue": Vector2i(32, 10),
    "witness": Vector2i(27, 20),
    "crisis": Vector2i(34, 19),
    "resolve": Vector2i(10, 19),
    "inn": Vector2i(20, 8),
    "shop": Vector2i(9, 10),
    "side_start": Vector2i(7, 19),
    "side_item": Vector2i(39, 12),
    "side_return": Vector2i(19, 24)
}
var chapter: int = 0
var custom_region: String = ""
var map_profile: Dictionary = {}
var act01_layouts: Dictionary = {}
var current_layout: Dictionary = {}
var terrain_layout: Dictionary = {}
var geography = Geography.new()
var town_life = TownLife.new()
var discoveries = WorldDiscoveries.new()
var dungeon_puzzles = WorldDungeonPuzzles.new()
var town_ecology = WorldTownEcology.new()
var field_ecology = WorldFieldEcology.new()
var ambience
var clock_minutes: int = 480
var calendar_day: int = 1
var npc_positions: Dictionary = {}
var story_marker_ids: Array[String] = []
var story_marker_signature: String = ""
var story_marker_positions: Dictionary = {}
var scene_director = SceneDirector.new()
var quest_submaps = QuestSubmaps.new()
var story_palette_flags: Dictionary = {}
var evidence_puzzles = EvidencePuzzles.new()
var interior_building: String = ""
var interior_kind: String = ""
var exterior_position: Vector2 = Vector2.ZERO
var last_party_size: int = 2
var root: Node2D
var scenery: Node2D
var coastal_scene
var coastal_audio
var prologue_stage
var prologue_cast: Dictionary = {}
var layer: TileMapLayer
var blocked: Dictionary = {}
var reachable_tiles: Dictionary = {}
var nodes: Dictionary = {}
var hero
var companion
var third
var fourth
var party_ids: Array = []
var camera: Camera2D
var focus_name: String = ""
var side_focus_name: String = ""
var focus_label: Label
var focus_light: Sprite2D
var side_light: Sprite2D
var movement: Vector2 = Vector2.ZERO
var locked: bool = false
var walk_speed: float = 141.0
var encounter_meter: float = 0.0
var next_encounter: float = 420.0
var rng: RandomNumberGenerator = RandomNumberGenerator.new()

func _ready() -> void:
    rng.randomize()
    var path: String = "res://data/levels/act01_layouts.json"
    if FileAccess.file_exists(path):
        var json: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
        if json is Dictionary:
            for entry in json.get("chapters",[]):
                if entry is Dictionary:
                    act01_layouts[int(entry.get("chapter",-1))] = entry

func build(new_chapter: int, party_size: int) -> void:
    chapter = maxi(0, new_chapter)
    last_party_size = party_size
    current_layout = act01_layouts.get(chapter,{})
    if is_instance_valid(root):
        remove_child(root)
        root.free()
    blocked.clear()
    reachable_tiles.clear()
    nodes.clear()
    prologue_cast.clear()
    story_marker_ids.clear()
    story_marker_positions.clear()
    story_marker_signature = ""
    root = Node2D.new()
    root.name = "FirstActLocation"
    add_child(root)
    _make_tiles()
    scenery = Node2D.new()
    scenery.y_sort_enabled = true
    root.add_child(scenery)
    _decorate()
    _install_coastal_scenery()
    _build_sites()
    _reconcile_interaction_markers()
    _spawn_residents()
    hero = Actor.new()
    hero.setup(_party_sprite(0, "leon"))
    var spawn: Vector2i = terrain_layout.get("spawn",Vector2i(10,23))
    hero.position = Vector2(spawn*TILE)+Vector2(16,16)
    hero.z_index = 3
    scenery.add_child(hero)
    companion = Actor.new()
    companion.setup(_party_sprite(1, "lanyin"))
    companion.position = hero.position + Vector2(-29, 22)
    scenery.add_child(companion)
    third = null
    if party_size >= 3:
        third = Actor.new()
        third.setup(_party_sprite(2, "shuoxian"))
        third.position = hero.position + Vector2(-52, 30)
        scenery.add_child(third)
    fourth = null
    if party_size >= 4:
        fourth = Actor.new()
        fourth.setup(_party_sprite(3,"chengzhou"))
        fourth.position = hero.position + Vector2(-78,38)
        scenery.add_child(fourth)
    camera = Camera2D.new()
    camera.zoom = Vector2(1.33, 1.33)
    camera.position_smoothing_enabled = true
    camera.position_smoothing_speed = 5.5
    camera.limit_left = 0
    camera.limit_top = 0
    camera.limit_right = WIDTH * TILE
    camera.limit_bottom = HEIGHT * TILE
    hero.add_child(camera)
    camera.make_current()
    ambience = Ambience.new()
    ambience.z_index = 12
    ambience.hero = hero
    ambience.configure(str(map_profile.get("id","map_coast_01")),str(terrain_layout.get("zone",{}).get("biome","coastal")),Vector2i(WIDTH,HEIGHT))
    root.add_child(ambience)
    coastal_audio=CoastalAudio.new()
    coastal_audio.name="CoastalAudio"
    root.add_child(coastal_audio)
    coastal_audio.configure(str(map_profile.get("id","")),not interior_building.is_empty())
    prologue_stage = PrologueStage.new()
    prologue_stage.name="PrologueWorldStage"
    prologue_stage.z_index=13
    root.add_child(prologue_stage)
    prologue_stage.bind_world(hero,scenery,ambience)
    # Exterior rain, fog and sky grading are never projected inside houses.
    ambience.visible = interior_building.is_empty()
    ambience.set_clock(calendar_day,clock_minutes)
    _make_focus_marker()
    focus_name = ""
    movement = Vector2.ZERO
    encounter_meter = 0.0
    next_encounter = rng.randf_range(350.0, 500.0)

func _party_sprite(position: int, fallback: String) -> String:
    var characters: Dictionary = {"char_wayfarer":"leon","char_tidecaller":"lanyin","char_seeker":"shuoxian","char_chengzhou":"chengzhou"}
    var id: String = str(party_ids[position]) if position < party_ids.size() else ""
    var suffix: String = str(characters.get(id,fallback))
    var name: String = "res://assets/art/characters/%s/walk_4dir_3frames.png" % suffix
    return name if ResourceLoader.exists(name) else "res://assets/art/characters/leon/walk_4dir_3frames.png"

func _make_tiles() -> void:
    var region: String = str(map_profile.get("region_id", "region_coast"))
    var land_path: String = REGION_TILE_DIR + region + "_ground.png"
    var water_path: String = REGION_TILE_DIR + region + "_water.png"
    var regional_art: bool = ResourceLoader.exists(land_path) and ResourceLoader.exists(water_path)
    # Determine the physical room before selecting the render texture; V4 art
    # and the authoritative terrain now share a single cell coordinate grid.
    if not interior_building.is_empty():
        terrain_layout = geography.interior(interior_building,interior_kind,str(map_profile.get("id","")))
    else:
        terrain_layout = geography.layout(str(map_profile.get("id","map_coast_01")),chapter)
    var extent: Vector2i = terrain_layout.get("size",Vector2i(72,48))
    WIDTH = extent.x
    HEIGHT = extent.y
    var chosen_atlas: String=str(terrain_layout.get("art_tileset",""))
    if chosen_atlas.is_empty() and str(terrain_layout.get("art_profile",""))=="coast_inn_v1":
        chosen_atlas=INN_ATLAS
    if interior_building.is_empty():
        var outdoor_key: String=str(map_profile.get("id",""))
        var outdoor_atlas: String=""
        if outdoor_key=="map_coast_03":
            outdoor_atlas="res://assets/art/exteriors/coast_final_pass/saltwind_route_tileset.svg"
        elif outdoor_key=="map_coast_04":
            outdoor_atlas="res://assets/art/exteriors/coast_final_pass/tide_cavern_tileset.svg"
        if not outdoor_atlas.is_empty() and ResourceLoader.exists(outdoor_atlas):
            chosen_atlas=outdoor_atlas
    var authored_art: bool = not chosen_atlas.is_empty() and ResourceLoader.exists(chosen_atlas)
    # A map owns its cell positions; only the immutable tile atlas is reused.
    # Preserve source IDs 0=ground and 1=water and the 8x8/32px source grid.
    var ground_texture: String = chosen_atlas if authored_art else (land_path if regional_art else GROUND)
    var selected_water: String = water_path if regional_art else WATER
    if interior_building.is_empty() and str(map_profile.get("id",""))=="map_coast_04":
        var cavern_water: String="res://assets/art/exteriors/coast_final_pass/cavern_water_atlas.svg"
        if ResourceLoader.exists(cavern_water):
            selected_water=cavern_water
    var atlas_sources: Array[String]=[ground_texture,selected_water]
    var tile_set: TileSet=TilePool.shared(atlas_sources)
    if tile_set == null:
        push_error("Cannot build playable 32px atlas for "+str(map_profile.get("id","")))
        return
    layer = TileMapLayer.new()
    layer.name = "PlayableGround"
    layer.tile_set = tile_set
    layer.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
    layer.z_index = -5
    if not map_profile.is_empty():
        layer.modulate = Color.WHITE if authored_art or regional_art else map_profile.get("color",Color.WHITE)
    root.add_child(layer)
    blocked = terrain_layout.get("blocked",{}).duplicate()
    var all_tiles: Dictionary = terrain_layout.get("tiles",{})
    var water_mask: Dictionary = terrain_layout.get("water_mask",{})
    for tile in all_tiles.keys():
        var atlas: Vector2i = all_tiles[tile]
        var source_id: int = 0
        if water_mask.has(tile):
            source_id = 1
            atlas = Vector2i(atlas.x,2)
        elif interior_building.is_empty() and blocked.has(tile) and str(map_profile.get("region_id","")) in ["region_coast","region_isles"] and atlas.y==6 and tile.y>=HEIGHT-7:
            source_id = 1
            atlas = Vector2i(atlas.x,2)
        layer.set_cell(tile,source_id,atlas)

func _decorate() -> void:
    if not interior_building.is_empty():
        if interior_building.begins_with("quest__"):
            # Authored room props are still interactive floor objects. Wall
            # furnishing and light overlays augment rather than erase them.
            for feature in terrain_layout.get("features",[]):
                _add_sprite(str(feature.get("kind","barrel")),feature.get("cell",Vector2i(35,20)),false,true)
        if not str(terrain_layout.get("art_profile","")).is_empty():
            var room_art := InteriorArt.new()
            root.add_child(room_art)
            room_art.install(scenery,terrain_layout,clock_minutes)
            return
        for feature in terrain_layout.get("features",[]):
            _add_sprite(str(feature.get("kind","barrel")),feature.get("cell",Vector2i(35,20)),false,true)
        return
    for feature in terrain_layout.get("features",[]):
        var cell: Vector2i = feature.get("cell",Vector2i.ZERO)
        var kind: String = str(feature.get("kind","rock"))
        if feature.has("building"):
            var architecture = WorldStructure.new()
            var region: String = str(terrain_layout.get("zone",{}).get("biome","coastal"))
            var width_data: Vector2i = Vector2i(8,6)
            for record in terrain_layout.get("zone",{}).get("buildings",[]):
                if str(record.get("id","")) == str(feature.get("building","")):
                    var size_data: Array = record.get("size",[8,6])
                    width_data = Vector2i(int(size_data[0]),int(size_data[1]))
                    break
            var entry_cell: Vector2i=feature.get("door",cell+Vector2i(0,width_data.y/2))
            architecture.setup(str(feature.get("building","house")),str(feature.get("name","建筑")),width_data,region,str(map_profile.get("id","")),clock_minutes,entry_cell-cell)
            architecture.position = Vector2(cell*TILE)+Vector2(16,16)
            scenery.add_child(architecture)
        else:
            # Generic procedurally-selected props are not the visual identity of
            # the 21 V7 wilderness scenes. Existing town furniture is preserved.
            if field_ecology.config(str(map_profile.get("id",""))).is_empty() or bool(map_profile.get("settlement",false)):
                if not bool(map_profile.get("settlement",false)) or _town_prop_clear(kind,cell):
                    _add_sprite(kind,cell,_reserve_tree_trunk(cell) if bool(map_profile.get("settlement",false)) and kind=="palm_tree" else false,true)
    # Each V7 wilderness scene receives its own 16-site art dressing pass,
    # with biome-correct props, palette variation and authored placements.
    var outdoor_art: Dictionary=field_ecology.config(str(map_profile.get("id","")))
    if not outdoor_art.is_empty():
        var color_grade: Color=Color(str(outdoor_art.get("art_tint","ffffff")))
        for fixture in outdoor_art.get("scenery",[]):
            if not fixture is Dictionary:
                continue
            var coords: Array=fixture.get("cell",[])
            if coords.size()!=2:
                continue
            var point: Vector2i=Vector2i(int(coords[0]),int(coords[1]))
            if point.x<3 or point.y<3 or point.x>=WIDTH-3 or point.y>=HEIGHT-3 or blocked.has(point):
                continue
            var decoration: Sprite2D=_add_sprite(str(fixture.get("kind","rock")),point,false,true)
            decoration.scale=Vector2.ONE*clampf(float(fixture.get("scale",1.0)),0.7,1.3)
            decoration.modulate=color_grade.lerp(Color.WHITE,0.56)
            decoration.set_meta("field_art",true)
        if not bool(map_profile.get("settlement",false)):
            return
    # Towns now rely on separately art-directed districts and scene dressing.
    # Do not stamp the same generic palm trees, crates and stalls over each town.
    if bool(map_profile.get("settlement",false)):
        for entry in current_layout.get("objects",[]):
            if entry is Array and entry.size()>=3:
                var kind: String=str(entry[0])
                # Historic act-I cottages were decorative sprites without
                # building IDs, collision or interiors: do not draw fake houses.
                if kind=="cottage":
                    continue
                var site: Vector2i=geography.old_to_new(Vector2i(int(entry[1]),int(entry[2])))
                if _town_prop_clear(kind,site):
                    _add_sprite(kind,site,_reserve_tree_trunk(site) if kind=="palm_tree" else false,true)
        return
    var objects: Array = [
        ["palm_tree", 7, 5], ["palm_tree", 38, 6], ["cottage", 11, 6], ["cottage", 34, 6],
        ["barrel", 24, 7], ["fish_stall", 19, 20], ["rock", 6, 21], ["rock", 39, 19],
        ["star_lantern", 13, 22], ["sea_crystal", 36, 22], ["palm_tree", 38, 23],
        ["flowerpot", 9, 23], ["dock_boat", 29, 24], ["well", 20, 22]
    ]
    if chapter in [3, 5, 6]:
        objects.append_array([["rock", 14, 6], ["rock", 30, 7], ["sea_crystal", 24, 22], ["beacon", 34, 23]])
    if chapter == 4:
        objects.append_array([["barrel", 28, 6], ["barrel", 17, 23], ["crate", 37, 14]])
    if not map_profile.is_empty():
        var map_seed: int = absi(int(map_profile.get("seed",0)))
        for k in range(5):
            var xx: int = 5 + int((map_seed + k * 23) % 34)
            var yy: int = 4 if k % 2 == 0 else 23
            objects.append([PROPS[(map_seed + k) % PROPS.size()],xx,yy])
    for entry in current_layout.get("objects",[]):
        if entry is Array and entry.size() >= 3:
            objects.append(entry)
    for entry in objects:
        # Unbound cottages have no interiors or collision.
        if str(entry[0])=="cottage":
            continue
        var pos := Vector2i(int(entry[1]), int(entry[2]))
        _add_sprite(str(entry[0]), pos, false)

func _install_coastal_scenery() -> void:
    coastal_scene = null
    if not interior_building.is_empty():
        return
    var map_id: String=str(map_profile.get("id",""))
    if map_id not in ["map_coast_01","map_coast_02","map_coast_03","map_coast_04"]:
        return
    coastal_scene=CoastalScene.new()
    coastal_scene.name="CoastalScene"
    scenery.add_child(coastal_scene)
    coastal_scene.configure(map_id,terrain_layout,scenery)
    coastal_scene.set_clock(clock_minutes)
    # Tall coastal tree roots are solid only when this does not cut a required
    # route. Bushes and canopy art remain walk-through visual layers.
    for tree in coastal_scene.wind_sway_sprites:
        if not is_instance_valid(tree) or not str(tree.get_meta("art_kind","")) in ["saltwind_oak","sea_wind_pine"]:
            continue
        var trunk: Vector2i=Vector2i(floori(tree.position.x/TILE),floori(tree.position.y/TILE))
        _reserve_tree_trunk(trunk)

func _add_sprite(kind: String, tile: Vector2i, solid: bool, authored: bool = false) -> Sprite2D:
    var path: String = "res://assets/art/props/coast/%s.png" % kind
    if not ResourceLoader.exists(path):
        path = "res://assets/art/props/coast/rock.png"
    var sprite := Sprite2D.new()
    sprite.texture = CArtOverrides.texture(path)
    sprite.set_meta("prop_kind",kind)
    var place: Vector2i = tile if authored else geography.old_to_new(tile)
    sprite.position = Vector2(place*TILE)+Vector2(16,16)
    sprite.offset = Vector2(0, -20)
    if kind in ["palm_tree","saltwind_oak","sea_wind_pine"]:
        # A canopy sorts against the actor by trunk/ground contact, not its top.
        sprite.z_index=3
        if sprite.texture!=null:
            sprite.offset=Vector2(0,-sprite.texture.get_height()*0.5+14.0)
    sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
    scenery.add_child(sprite)
    if solid:
        blocked[place] = true
    return sprite

## Town dressing is cosmetic, never an extra fake doorway and never laid
## over a house, a sidewalk threshold, a quest anchor or the main route.
## A tree occupies one foot tile, never its full canopy. Refuse the blocker
## unless the player's accessible network (quests, doors, exits) stays intact.
func _reserve_tree_trunk(cell: Vector2i) -> bool:
    if not interior_building.is_empty() or blocked.has(cell) or cell.x<3 or cell.y<3 or cell.x>=WIDTH-3 or cell.y>=HEIGHT-3:
        return false
    var from: Vector2i=terrain_layout.get("spawn",Vector2i(10,23))
    var connected: Dictionary=_walkable_tiles()
    if not connected.has(cell):
        return false
    var must_reach: Array[Vector2i]=[]
    for landmark in geography._anchors():
        if connected.has(landmark):
            must_reach.append(landmark)
    for feature in terrain_layout.get("features",[]):
        if not feature.has("building"):
            continue
        var entrance: Vector2i=feature.get("door",Vector2i.ZERO)+Vector2i.DOWN
        if cell.distance_squared_to(entrance)<13:
            return false
        if connected.has(entrance):
            must_reach.append(entrance)
    for gate in terrain_layout.get("gates",[]):
        var exit: Vector2i=gate.get("cell",Vector2i.ZERO)
        if connected.has(exit):
            must_reach.append(exit)
    var candidate: Dictionary=blocked.duplicate()
    candidate[cell]=true
    if not geography.reachable({"blocked":candidate,"size":Vector2i(WIDTH,HEIGHT)},[from],must_reach):
        return false
    blocked[cell]=true
    var authoritative: Dictionary=terrain_layout.get("blocked",{})
    authoritative[cell]=true
    terrain_layout["blocked"]=authoritative
    reachable_tiles.clear()
    return true

func _town_prop_clear(kind: String,site: Vector2i) -> bool:
    if kind=="cottage" or site.x<3 or site.y<3 or site.x>=WIDTH-3 or site.y>=HEIGHT-3 or blocked.has(site):
        return false
    var floor: Vector2i=terrain_layout.get("tiles",{}).get(site,Vector2i.ZERO)
    if floor.y==3:
        return false
    var start: Vector2i=terrain_layout.get("spawn",Vector2i(10,23))
    if site.distance_squared_to(start)<16:
        return false
    for building in terrain_layout.get("features",[]):
        if not building.has("building"):
            continue
        var door: Vector2i=building.get("door",Vector2i.ZERO)
        if site.distance_squared_to(door+Vector2i.DOWN)<13:
            return false
    for essential in geography._anchors():
        if site.distance_squared_to(essential)<4:
            return false
    return true

func _walkable_tiles() -> Dictionary:
    if not reachable_tiles.is_empty():
        return reachable_tiles
    var spawn: Vector2i=terrain_layout.get("spawn",Vector2i(10,23))
    if blocked.has(spawn):
        return reachable_tiles
    var visited: Dictionary={spawn:true}
    var frontier: Array[Vector2i]=[spawn]
    var index: int=0
    while index<frontier.size():
        var p: Vector2i=frontier[index]
        index+=1
        for shift in [Vector2i.LEFT,Vector2i.RIGHT,Vector2i.UP,Vector2i.DOWN]:
            var next: Vector2i=p+shift
            if next.x<2 or next.y<2 or next.x>=WIDTH-2 or next.y>=HEIGHT-2 or blocked.has(next) or visited.has(next):
                continue
            visited[next]=true
            frontier.append(next)
    reachable_tiles=visited
    return reachable_tiles

func _safe_site_cell(anchor: Vector2i) -> Vector2i:
    if not interior_building.is_empty():
        return anchor
    var reachable: Dictionary=_walkable_tiles()
    for radius in range(13):
        for y in range(-radius,radius+1):
            for x in range(-radius,radius+1):
                if absi(x)+absi(y)!=radius:
                    continue
                var point: Vector2i=anchor+Vector2i(x,y)
                if point.x<3 or point.y<3 or point.x>=WIDTH-3 or point.y>=HEIGHT-3 or blocked.has(point):
                    continue
                if reachable.has(point):
                    return point
    push_warning("No reachable marker tile near "+str(anchor))
    return anchor

func _reconcile_interaction_markers() -> void:
    if not interior_building.is_empty():
        return
    var reachable: Dictionary=_walkable_tiles()
    for key in nodes.keys():
        if str(key).begins_with("building:") or not is_instance_valid(nodes[key]):
            continue
        var node: Node2D=nodes[key]
        var position_cell:=Vector2i(floori(node.position.x/TILE),floori(node.position.y/TILE))
        if reachable.has(position_cell):
            continue
        var safe: Vector2i=_safe_site_cell(position_cell)
        if safe!=position_cell:
            node.position=Vector2(safe*TILE)+Vector2(16,16)

func _town_event_cell(anchor: Vector2i,reserved: Dictionary) -> Vector2i:
    var origin: Vector2i = terrain_layout.get("spawn",Vector2i(10,23))
    for radius in range(0,10):
        for dx in range(-radius,radius+1):
            for dy in range(-radius,radius+1):
                if absi(dx)+absi(dy)!=radius:
                    continue
                var site: Vector2i = anchor+Vector2i(dx,dy)
                if site.x<4 or site.y<4 or site.x>=WIDTH-4 or site.y>=HEIGHT-4 or blocked.has(site) or reserved.has(site):
                    continue
                if _walkable_tiles().has(site):
                    return site
    return Vector2i(-1,-1)

func _refresh_town_event_lighting() -> void:
    if town_ecology==null or not interior_building.is_empty():
        return
    var clock_hour: int = int(clock_minutes / 60)
    var map_id: String = str(map_profile.get("id",""))
    for event in town_ecology.entries(map_id):
        var key: String = "townlife:"+str(event.get("id",""))
        if not nodes.has(key):
            continue
        var sprite: Node2D = nodes[key]
        if is_instance_valid(sprite):
            sprite.modulate = Color.WHITE if town_ecology.is_open(event,clock_hour) else Color(0.44,0.52,0.61,0.70)

func refresh_field_ecology(state) -> void:
    if field_ecology==null or not interior_building.is_empty() or state==null:
        return
    var id: String = str(map_profile.get("id",""))
    var current: Dictionary = field_ecology.snapshot(state,id)
    if field_ecology.config(id).is_empty():
        return
    for site in field_ecology.sites(id):
        var action: String = str(site.get("id",""))
        var key: String = "field:"+action
        if not nodes.has(key):
            continue
        var marker: Sprite2D = nodes[key]
        marker.visible=chapter>0 and (action!="cache" or bool(current.get("passage",false)))
        if action=="trial":
            marker.modulate=Color("83d5b3") if bool(current.get("trial",false)) else Color("f1c087")
        elif action=="gather":
            marker.modulate=Color("b9dd93") if bool(current.get("harvested",false)) else Color.WHITE
        elif action=="passage":
            marker.modulate=Color("9ccdf0") if bool(current.get("passage",false)) else Color("d7cbf5")
        elif action=="cache":
            marker.modulate=Color("9aa8af") if bool(current.get("claimed",false)) else Color("f7d88c")

func teleport_field_secret() -> bool:
    if not interior_building.is_empty() or not nodes.has("field:cache") or not is_instance_valid(hero):
        return false
    var destination: Sprite2D=nodes["field:cache"]
    hero.position=destination.position
    companion.position=hero.position+Vector2(-28,20)
    if is_instance_valid(third):
        third.position=hero.position+Vector2(-53,27)
    if is_instance_valid(fourth):
        fourth.position=hero.position+Vector2(-78,40)
    return true

func _build_sites() -> void:
    if not interior_building.is_empty():
        if interior_building.begins_with("quest__"):
            var details: Dictionary = quest_submaps.detail(interior_building.trim_prefix("quest__"))
            var spots: Array = terrain_layout.get("quest_points",[])
            var quest_exit: Dictionary = terrain_layout.get("interact_cells",{})
            nodes["interior_exit"] = _add_sprite("sign",quest_exit.get("exit",Vector2i(36,40)),false,true)
            if spots.size()==3 and not details.is_empty():
                for step in range(3):
                    var art: String = ["crate","sea_crystal","sign"][step]
                    nodes["questcase:"+str(step)] = _add_sprite(art,spots[step],false,true)
                    var title_tag := Label.new()
                    title_tag.text = str(details.get("displays",[])[step]).left(14)
                    title_tag.position = Vector2(-65,-59)
                    title_tag.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
                    title_tag.custom_minimum_size.x = 130
                    title_tag.add_theme_font_size_override("font_size",12)
                    nodes["questcase:"+str(step)].add_child(title_tag)
                for stage_index in range(5):
                    var stage_spots: Array = terrain_layout.get("story_stage_points",[])
                    var stage_cell: Vector2i = stage_spots[stage_index] if stage_spots.size()==5 else spots[[0,1,2,0,2][stage_index]]
                    var quest_stage: Sprite2D
                    if stage_index in [0,3,4]:
                        # An actual quest giver silhouette, with the existing
                        # overworld idle animation, replaces the generic sign.
                        var giver := NPCVisual.new()
                        giver.setup({"id":"", "role":"quest", "name":str(details.get("original_npc","委托人"))})
                        giver.position = Vector2(stage_cell*TILE)+Vector2(16,16)
                        scenery.add_child(giver)
                        quest_stage = giver
                    else:
                        quest_stage = _add_sprite("star_lantern" if stage_index==4 else "sign",stage_cell,false,true)
                    nodes["story_stage_%d" % stage_index] = quest_stage
                    quest_stage.visible = false
            return
        var markers: Dictionary = terrain_layout.get("interact_cells",{})
        nodes["interior_exit"] = _add_sprite("sign",markers.get("exit",Vector2i(35,34)),false,true)
        nodes["interior_service"] = _add_sprite("beacon",markers.get("service",Vector2i(29,17)),false,true)
        nodes["interior_storage"] = _add_sprite("barrel",markers.get("storage",Vector2i(45,19)),false,true)
        if not str(terrain_layout.get("art_profile","")).is_empty():
            # Keep node visible for input and minimap; custom counter/art
            # replaces its old beacon/barrel pictogram at the same anchor.
            nodes["interior_service"].modulate.a = 0.0
            nodes["interior_storage"].modulate.a = 0.0
        return
    var archetype: String = str(terrain_layout.get("zone",{}).get("archetype",""))
    if archetype == "dungeon":
        nodes["dungeon_switch_a"] = _add_sprite("beacon",Vector2i(19,14),false,true)
        nodes["dungeon_switch_b"] = _add_sprite("sea_crystal",Vector2i(53,16),false,true)
        nodes["dungeon_chest"] = _add_sprite("crate",Vector2i(54,36),false,true)
    elif archetype in ["field","route","landmark"]:
        nodes["wild_cache"] = _add_sprite("crate",Vector2i(60,35),false,true)
        nodes["wild_camp"] = _add_sprite("star_lantern",Vector2i(24,14),false,true)
    # V7 independent physical puzzle devices. The original two-switch treasure
    # stays intact, preserving existing chapter puzzles, flags, and old saves.
    var puzzle_id: String = str(map_profile.get("id",""))
    var puzzle_catalog: Dictionary = dungeon_puzzles.config(puzzle_id)
    if archetype=="dungeon" and not puzzle_catalog.is_empty():
        for mechanism in dungeon_puzzles.devices(puzzle_id):
            var point_data: Array = mechanism.get("cell",[])
            if point_data.size()!=2:
                continue
            var point: Vector2i = Vector2i(int(point_data[0]),int(point_data[1]))
            if blocked.has(point):
                # Do not let new devices occupy hand-authored walls or doors.
                var found: bool = false
                for distance in range(1,7):
                    if found:
                        break
                    for vector in [Vector2i(distance,0),Vector2i(-distance,0),Vector2i(0,distance),Vector2i(0,-distance)]:
                        var candidate: Vector2i = point+vector
                        if not blocked.has(candidate) and candidate.x>2 and candidate.y>2 and candidate.x<WIDTH-3 and candidate.y<HEIGHT-3:
                            point=candidate
                            found=true
                            break
            var device_id: String = "puzzle:"+str(mechanism.get("id",""))
            var object: Sprite2D = _add_sprite(str(mechanism.get("icon","beacon")),point,false,true)
            object.set_meta("site_name",str(mechanism.get("name","机关")))
            nodes[device_id]=object
    # New exploratory sites are authentic outdoor interactions in the expanded sector,
    # not replacements for existing chapter, house or side-quest markers.
    var current_map_id: String = str(map_profile.get("id",""))
    for record in discoveries.entries(current_map_id):
        var coordinates: Array = record.get("cell",[])
        if coordinates.size()!=2:
            continue
        var target_cell: Vector2i = Vector2i(int(coordinates[0]),int(coordinates[1]))
        if blocked.has(target_cell):
            # Find the closest free floor without moving the documented marker.
            # The authored dataset must still pass dedicated accessibility checks.
            var found: bool = false
            for distance in range(1,5):
                if found:
                    break
                for shift in [Vector2i(distance,0),Vector2i(-distance,0),Vector2i(0,distance),Vector2i(0,-distance)]:
                    var candidate: Vector2i = target_cell+shift
                    if not blocked.has(candidate):
                        target_cell = candidate
                        found = true
                        break
        var key: String = "discovery:"+str(record.get("id",""))
        var discovery_marker: Sprite2D = _add_sprite(str(record.get("icon","sign")),target_cell,false,true)
        discovery_marker.visible = chapter>0
        discovery_marker.set_meta("site_name",str(record.get("name","未知地标")))
        nodes[key] = discovery_marker
    for gate in terrain_layout.get("gates",[]):
        var id: String = str(gate.get("id",""))
        if not id.is_empty():
            nodes["exit:"+id] = _add_sprite("beacon",gate.get("cell",Vector2i(4,24)),false,true)
    for feature in terrain_layout.get("features",[]):
        if feature.has("building"):
            var door: Vector2i = feature.get("door",Vector2i.ZERO)
            # Doorway itself is part of the solid house: the actionable
            # threshold stands one tile south, on the visible front step.
            var front: Vector2i = door+Vector2i.DOWN
            var marker: Sprite2D=_add_sprite("sign",front,false,true)
            marker.scale=Vector2(0.72,0.72)
            marker.modulate=Color("f4dda7")
            marker.set_meta("door_cell",door)
            nodes["building:"+str(feature.get("building",""))] = marker
    var icons := {"key_npc": "beacon", "clue": "crate", "witness": "medicine_basket", "crisis": "sea_crystal", "resolve": "star_lantern", "inn": "well", "shop": "fish_stall", "side_start": "sign", "side_item": "crate", "side_return": "beacon"}
    for k in SITES.keys():
        var where: Vector2i = SITES[k]
        var sprite: Sprite2D = _add_sprite(str(icons[k]), where, false)
        nodes[k] = sprite
    # V7 neighborhood identity: three real, named district stations in each of
    # the eleven town plans. Placed only on connected walkable cells.
    if interior_building.is_empty() and bool(map_profile.get("settlement",false)):
        var occupied: Dictionary = {}
        for existing in nodes.values():
            if is_instance_valid(existing):
                occupied[Vector2i(existing.position/TILE)]=true
        for activity in town_ecology.entries(str(map_profile.get("id",""))):
            var coordinates: Array = activity.get("cell",[])
            if coordinates.size()!=2:
                continue
            var candidate: Vector2i = _town_event_cell(Vector2i(int(coordinates[0]),int(coordinates[1])),occupied)
            if candidate.x<0:
                push_warning("Town ecology location unreachable: "+str(map_profile.get("id",""))+" / "+str(activity.get("id","")))
                continue
            occupied[candidate]=true
            var object: Sprite2D = _add_sprite(str(activity.get("icon","sign")),candidate,false,true)
            object.visible = chapter>0
            object.set_meta("site_name",str(activity.get("title","社区活动")))
            nodes["townlife:"+str(activity.get("id",""))]=object
        _refresh_town_event_lighting()
    # The four dedicated wild sites occupy independent walkable cells, without
    # displacing the legacy camp, treasure, V6 discoveries, gates, or town life.
    var field_id: String = str(map_profile.get("id",""))
    if interior_building.is_empty() and not field_ecology.config(field_id).is_empty():
        var field_reserved: Dictionary = {}
        for placed in nodes.values():
            if is_instance_valid(placed):
                field_reserved[Vector2i(placed.position/TILE)]=true
        for field_site in field_ecology.sites(field_id):
            var authored_cell: Array = field_site.get("cell",[])
            if authored_cell.size()!=2:
                continue
            var preferred: Vector2i = Vector2i(int(authored_cell[0]),int(authored_cell[1]))
            var walkable: Vector2i = _town_event_cell(preferred,field_reserved)
            if walkable.x<0:
                push_warning("Unreachable V7 field station: "+field_id+"/"+str(field_site.get("id","")))
                continue
            field_reserved[walkable]=true
            var field_marker: Sprite2D = _add_sprite(str(field_site.get("icon","rock")),walkable,false,true)
            var field_key: String = "field:"+str(field_site.get("id",""))
            field_marker.visible = chapter>0 and field_key!="field:cache"
            field_marker.set_meta("site_name",str(field_site.get("title","地形探查")))
            nodes[field_key]=field_marker
    if str(map_profile.get("kind","")) == "town":
        # Housing services use a notice near the real residence, not a fake house.
        for feature in terrain_layout.get("features",[]):
            if str(feature.get("building",""))!="house":
                continue
            var house_step: Vector2i=feature.get("door",Vector2i.ZERO)+Vector2i.DOWN
            var service_cell: Vector2i=_safe_site_cell(house_step+Vector2i(4,2))
            var notice: Sprite2D=_add_sprite("sign",service_cell,false,true)
            notice.set_meta("site_name","家园服务")
            nodes["home_door"] = notice
            break
    for i in range(9):
        var offset := Vector2i(7 + (i % 3) * 12, 10 + int(i / 3) * 5)
        var point: Sprite2D = _add_sprite("star_lantern" if i % 2 == 0 else "sign", offset, false)
        nodes["prologue_%d" % i] = point
    for i in range(9):
        var key: String = "prologue_%d" % i
        nodes[key].visible = chapter == 0
    # 每章两处命名线索、阶段NPC和可选中段对白，使用相同交互距离规则。
    var optional_markers: Dictionary = {
        "inspect_1": ["crate", Vector2i(8, 8)],
        "inspect_2": ["sea_crystal", Vector2i(36, 12)],
        "ambient_npc": ["sign", Vector2i(23, 8)],
        "midpoint": ["star_lantern", Vector2i(25, 22)]
    }
    for name in optional_markers:
        var record: Array = optional_markers[name]
        var sprite: Sprite2D = _add_sprite(str(record[0]),record[1],false)
        sprite.visible = chapter > 0
        nodes[name] = sprite
    # 可选小戏：仅开放对应章节与场景窗口。禁用不代表不允许主线推进。
    nodes["optional_town"] = _add_sprite("sign",Vector2i(13,17),false)
    nodes["optional_evidence"] = _add_sprite("sea_crystal",Vector2i(36,21),false)
    for name in ["optional_town","optional_evidence"]:
        nodes[name].visible = false
    # 编剧分支的36条支线：五阶段航页与普通三阶段委托均具有地图实体。
    for i in range(5):
        var site: Vector2i = Vector2i(10 + (i % 3) * 11, 5 + int(i / 3) * 18)
        var prop: Sprite2D = _add_sprite("sign" if i == 0 else ("crate" if i % 2 else "sea_crystal"), site, false)
        nodes["story_stage_%d" % i] = prop
        prop.visible = chapter > 0

func _clear_story_world_markers() -> void:
    for id in story_marker_ids:
        if nodes.has(id):
            var marker: Node2D = nodes[id]
            nodes.erase(id)
            if is_instance_valid(marker):
                marker.queue_free()
    story_marker_ids.clear()
    story_marker_positions.clear()

func _story_sprite(target_id: String,kind: String,cell: Vector2i,caption: String,branch: String = "", art_override: String = "", phase: String = "") -> void:
    var marker: Node2D
    if kind == "npc":
        var npc = NPCVisual.new()
        npc.setup({"name":caption,"role":"quest"})
        # apply_story_presentation owns both phase/route colors and daylight tint.
        # Overriding modulate here would erase the night palette on room entry.
        npc.apply_story_presentation(phase if not phase.is_empty() else "intro",branch,clock_minutes)
        marker = npc
        marker.z_index = 5
        marker.position = Vector2(_safe_site_cell(cell)*TILE)+Vector2(16,16)
        scenery.add_child(marker)
    else:
        var art: String = art_override if not art_override.is_empty() else ("sea_crystal" if kind == "evidence" else "sign")
        var obj: Sprite2D = _add_sprite(art,_safe_site_cell(cell),false,true)
        obj.modulate = Color("a2e8f1") if kind == "evidence" else Color("f2d79a")
        marker = obj
        var title_tag := Label.new()
        title_tag.text = caption.left(11)
        title_tag.position = Vector2(-62,-58)
        title_tag.custom_minimum_size.x = 124
        title_tag.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
        title_tag.add_theme_font_size_override("font_size",12)
        title_tag.add_theme_color_override("font_color",Color("f0edd8"))
        marker.add_child(title_tag)
    nodes[target_id] = marker
    story_marker_ids.append(target_id)
    story_marker_positions[target_id] = Vector2i(marker.position/TILE)

func sync_story_world_markers(binder,core,runtime,tracked_id: String = "") -> Dictionary:
    var region_map: String = str(map_profile.get("id",""))
    var active: Dictionary = runtime.resume()
    var available: Array = runtime.eligible_events(1000)
    var chosen: Dictionary = {}
    if not active.is_empty():
        chosen = active
    elif not tracked_id.is_empty() and runtime.eligible(tracked_id):
        chosen = runtime.get_event(tracked_id)
    else:
        for item in available:
            var event: Dictionary = item
            if binder.matches(str(event.get("quest_id","")),region_map):
                chosen = event
                break
    var quest_room: String = interior_building.trim_prefix("quest__") if interior_building.begins_with("quest__") else ""
    if not quest_room.is_empty() and str(chosen.get("quest_id","")) != quest_room:
        chosen = {}
        for item in available:
            if str(item.get("quest_id","")) == quest_room:
                chosen = item
                break
    var original: Dictionary = core.available_story_side(chapter) if chapter > 0 else {}
    var original_id: String = str(original.get("id",""))
    var original_here: bool = binder.matches(original_id,region_map) and not original.is_empty()
    if not quest_room.is_empty():
        original_here = original_here and original_id == quest_room
    var stage: int = core.story_side_stage(original_id) if original_here else -1
    var currently: int = int(runtime.state.rpg.get("branch_story",{}).get("active",{}).get("line",0))
    var current_id: String = str(chosen.get("id",""))
    var local_branch: bool = binder.matches(str(chosen.get("quest_id","")),region_map)
    if not quest_room.is_empty():
        local_branch = local_branch and str(chosen.get("quest_id",""))==quest_room
    elif not quest_submaps.detail(str(chosen.get("quest_id",""))).is_empty():
        local_branch = false
    var possible_keys := PackedStringArray()
    for candidate in available:
        possible_keys.append(str(candidate.get("id","")))
    var signature: String = "%s|%s|%s|%s|%d|%d|%s" % [
        region_map,interior_building,original_id,current_id,stage,currently,
        ",".join(possible_keys)]
    if signature == story_marker_signature:
        return {"chosen":chosen,"local":local_branch,"original_here":original_here}
    story_marker_signature = signature
    _clear_story_world_markers()
    var occupied: Array[Vector2i] = []
    for landmark_id in ["key_npc","clue","witness","crisis","resolve","side_start","side_item","side_return","interior_exit","interior_service"]:
        if nodes.has(landmark_id):
            var landmark: Node2D = nodes[landmark_id]
            occupied.append(Vector2i(landmark.position/TILE))
    var reachable: Dictionary = binder.find_reachable(self)
    if reachable.is_empty():
        return {"chosen":chosen,"local":false,"original_here":false}
    # Existing original story markers now live next to the selected quest's
    # canonical location rather than five reused arbitrary world positions.
    for step in range(5):
        var key: String = "story_stage_%d" % step
        if nodes.has(key):
            nodes[key].visible = false
    # A lost-page story stage belongs inside its authored quest interior,
    # not on the generic sector sign used by other 108 world quests.
    if interior_building.is_empty():
        for room in quest_submaps.local(region_map,chapter):
            var room_id: String = str(room.get("quest_id",""))
            var room_site: Dictionary = binder.site(room_id)
            var door: Vector2i = binder.position_for(room_site,reachable,occupied,0)
            if door.x<0:
                continue
            _story_sprite("questdoor:"+room_id,"notice",door,str(room.get("interior_name","调查室")),"","sign")
            occupied.append(door)
    if original_here and stage>=0:
        var location: Vector2i = Vector2i(-1,-1)
        if not quest_room.is_empty():
            var original_points: Array = terrain_layout.get("quest_points",[])
            var original_stages: Array = terrain_layout.get("story_stage_points",[])
            if original_stages.size()==5:
                location = original_stages[clampi(stage,0,4)]
            elif original_points.size()==3:
                location = original_points[[0,1,2,0,2][clampi(stage,0,4)]]
        elif quest_submaps.detail(original_id).is_empty() and interior_building.is_empty():
            location = binder.position_for(binder.site(original_id),reachable,occupied,0)
        if location.x>=0:
            var stage_key: String = "story_stage_%d" % stage
            if nodes.has(stage_key):
                nodes[stage_key].position = Vector2(location*TILE)+Vector2(16,16)
                nodes[stage_key].visible = true
                if quest_room.is_empty():
                    var task_evidence: Dictionary = scene_director.dossier(original_id)
                    var prop_kind: String = "sign" if stage!=1 else str(task_evidence.get("evidence_prop","sea_crystal"))
                    var prop_path: String = "res://assets/art/props/coast/"+prop_kind+".png"
                    if ResourceLoader.exists(prop_path):
                        (nodes[stage_key] as Sprite2D).texture=load(prop_path)
                        nodes[stage_key].set_meta("quest_evidence_type",prop_kind)
                    var task_label: Label = nodes[stage_key].get_node_or_null("QuestSpecificLocation")
                    if task_label==null:
                        task_label = Label.new()
                        task_label.name = "QuestSpecificLocation"
                        task_label.position=Vector2(-75,-57)
                        task_label.custom_minimum_size.x=150
                        task_label.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
                        task_label.add_theme_font_size_override("font_size",12)
                        nodes[stage_key].add_child(task_label)
                    task_label.text = str(task_evidence.get("evidence_label","调查证物") if stage==1 else task_evidence.get("witness_name","委托人")).left(17)
                occupied.append(location)
    # Show up to six other quest witnesses in this sector; the tracked event
    # receives three ordered interaction roles (person, evidence, notice).
    var shown: int = 0
    for item in available:
        var e: Dictionary = item
        if str(e.get("id",""))==current_id or not binder.matches(str(e.get("quest_id","")),region_map):
            continue
        if not quest_submaps.detail(str(e.get("quest_id",""))).is_empty():
            continue
        if not interior_building.is_empty() and interior_building.begins_with("quest__"):
            continue
        var info: Dictionary = binder.site(str(e.get("quest_id","")))
        if not interior_building.is_empty() and str(info.get("building_id",""))!=interior_building:
            continue
        var spot: Vector2i = binder.position_for(info,reachable,occupied,0)
        if spot.x<0:
            continue
        occupied.append(spot)
        var hint_plan: Dictionary = scene_director.stage(str(e.get("quest_id","")),e,0)
        _story_sprite("questhint:"+str(e["id"]),"npc",spot,
            str(hint_plan.get("label",info.get("story_npc","见证人"))),str(e.get("branch","")),"",str(e.get("kind","")))
        shown+=1
        if shown>=6:
            break
    if local_branch:
        var info: Dictionary = binder.site(str(chosen.get("quest_id","")))
        if (not quest_room.is_empty() and str(chosen.get("quest_id",""))==quest_room) or (quest_room.is_empty() and (interior_building.is_empty() or str(info.get("building_id","")) == interior_building)):
            var point: Vector2i = binder.position_for(info,reachable,occupied,currently)
            if not quest_room.is_empty():
                var field_stages: Array = terrain_layout.get("branch_stage_points",[])
                var current_points: Array = terrain_layout.get("quest_points",[])
                if field_stages.size()==3:
                    point = field_stages[clampi(currently,0,2)]
                elif current_points.size()==3:
                    point = current_points[clampi(currently,0,2)]
            if point.x>=0:
                occupied.append(point)
                var scene_plan: Dictionary = scene_director.stage(str(chosen.get("quest_id","")),chosen,currently)
                var role: String = str(scene_plan.get("role",["npc","evidence","notice"][clampi(currently,0,2)]))
                var name_text: String = str(scene_plan.get("label",info.get("story_npc","见证人")))
                _story_sprite("branchmap:"+str(chosen["id"])+":"+str(currently),role,point,name_text,
                    str(chosen.get("branch","")),str(scene_plan.get("prop","")),str(chosen.get("kind","")))
    return {"chosen":chosen,"local":local_branch,"original_here":original_here}

func refresh_room_evidence(rpg: Dictionary) -> void:
    if not interior_building.begins_with("quest__"):
        return
    var id: String = interior_building.trim_prefix("quest__")
    var observed: Dictionary = rpg.get("quest_gallery",{}).get(id,{})
    var complete: bool = evidence_puzzles.solved(rpg,id)
    for index in range(3):
        var marker_id: String = "questcase:"+str(index)
        if not nodes.has(marker_id):
            continue
        var marker: Sprite2D = nodes[marker_id]
        if complete and index==2:
            marker.modulate = Color("7cecc4")
        elif bool(observed.get(str(index),false)):
            marker.modulate = Color("f2d68c")
        else:
            marker.modulate = Color("d9d9e9")

func _refresh_world_choice_echo(flags: Dictionary) -> void:
    if not interior_building.is_empty() or not nodes.has("ambient_npc"):
        return
    var marker: Sprite2D = nodes["ambient_npc"]
    var echo: Dictionary = scene_director.latest_world_echo(str(map_profile.get("id","")),flags)
    var label: Label = marker.get_node_or_null("ChoiceWorldEcho") as Label
    if echo.is_empty():
        marker.modulate = Color.WHITE
        if marker.has_meta("story_choice_event_id"):
            marker.remove_meta("story_choice_event_id")
        if label != null:
            label.visible = false
        return
    marker.set_meta("story_choice_event_id",str(echo.get("event_id","")))
    marker.set_meta("story_choice_observation",str(echo.get("observation","")))
    marker.modulate=Color("8bd4f5") if str(echo.get("route",""))=="listen" else Color("efcd8a")
    if label == null:
        label=Label.new()
        label.name="ChoiceWorldEcho"
        label.position=Vector2(-83,-60)
        label.custom_minimum_size.x=166
        label.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
        label.add_theme_font_size_override("font_size",11)
        marker.add_child(label)
    label.text="旧事回响 · "+str(echo.get("label","")).left(11)
    label.visible=true

func refresh_room_npcs(flags: Dictionary) -> void:
    story_palette_flags = flags.duplicate()
    if not interior_building.begins_with("quest__"):
        _refresh_world_choice_echo(flags)
        return
    var quest_id: String = interior_building.trim_prefix("quest__")
    var route: String = str(flags.get("side."+quest_id+".approach",""))
    var finished: bool = bool(flags.get("side."+quest_id+".done",false))
    for stage_index in range(5):
        var marker_id: String = "story_stage_%d" % stage_index
        if not nodes.has(marker_id):
            continue
        var marker: Node2D = nodes[marker_id]
        if marker is NPCVisual:
            var phase: String = "intro"
            if stage_index==3:
                phase = "resolved" if finished else "investigate"
            elif stage_index==4:
                phase = "revisit"
            (marker as NPCVisual).apply_story_presentation(phase,route,clock_minutes)
    for event_id in story_marker_ids:
        if not str(event_id).begins_with("branchmap:") or not nodes.has(event_id):
            continue
        var event_npc: Node2D = nodes[event_id]
        if not (event_npc is NPCVisual):
            continue
        var phase: String = "revisit" if str(event_id).contains(".revisit") else (
            "community" if str(event_id).contains(".community") else "investigate"
        )
        (event_npc as NPCVisual).apply_story_presentation(phase,route,clock_minutes)

func _resident_spot(target: Vector2i,used: Dictionary) -> Vector2i:
    for radius in range(0,14):
        for yy in range(-radius,radius+1):
            for xx in range(-radius,radius+1):
                if radius>0 and absi(xx)!=radius and absi(yy)!=radius:
                    continue
                var p: Vector2i = target+Vector2i(xx,yy)
                if p.x<4 or p.y<4 or p.x>=WIDTH-4 or p.y>=HEIGHT-4 or blocked.has(p) or used.has(p) or not _walkable_tiles().has(p):
                    continue
                var near_story: bool = false
                for quest_id in ["key_npc","clue","witness","crisis","resolve"]:
                    if nodes.has(quest_id):
                        var node: Node2D = nodes[quest_id]
                        if node.position.distance_to(Vector2(p*TILE)+Vector2(16,16))<62.0:
                            near_story=true
                            break
                if near_story:
                    continue
                used[p]=true
                return p
    return Vector2i(35,24)

func _spawn_residents() -> void:
    npc_positions.clear()
    if not interior_building.is_empty() or not bool(map_profile.get("settlement",false)):
        return
    var hour: int = int(clock_minutes/60)
    var used: Dictionary = {}
    # B residents belong to the exact map, not just a shared region.
    var residents: Array = town_life.residents_for_map(str(map_profile.get("id","")))
    for index in range(residents.size()):
        var record: Dictionary = residents[index]
        var authored_spot: Vector2i = geography.town_design.resident_anchor(str(map_profile.get("id","")),str(record.get("role","lore")),index,hour,geography.zone(str(map_profile.get("id",""))).get("buildings",[]))
        var point: Vector2i = _resident_spot(authored_spot,used)
        var citizen = NPCVisual.new()
        citizen.setup(record)
        citizen.position=Vector2(point*TILE)+Vector2(16,16)
        citizen.z_index=3
        scenery.add_child(citizen)
        var key: String = "citizen:"+str(record.get("id",""))
        nodes[key] = citizen
        npc_positions[key] = point

func sync_world_clock(day_number: int,minutes: int) -> void:
    var old_period: bool = clock_minutes<360 or clock_minutes>=1200
    calendar_day=maxi(1,day_number)
    clock_minutes=posmod(minutes,1440)
    # An empty flag dictionary is a valid quest state, not a signal to skip
    # the day/night appearance update of existing room NPCs.
    if interior_building.begins_with("quest__"):
        refresh_room_npcs(story_palette_flags)
    _refresh_town_event_lighting()
    var next_period: bool = clock_minutes<360 or clock_minutes>=1200
    if ambience!=null and is_instance_valid(ambience):
        ambience.set_clock(calendar_day,clock_minutes)
    if is_instance_valid(coastal_scene):
        coastal_scene.set_clock(clock_minutes)
    if is_instance_valid(root) and not interior_building.is_empty():
        var indoor_art: Node = root.get_node_or_null("InteriorArt")
        if indoor_art!=null:
            indoor_art.set_clock(clock_minutes)
    elif is_instance_valid(scenery):
        for visual in scenery.get_children():
            if visual is WorldStructure:
                visual.set_clock(clock_minutes)
    if old_period==next_period or interior_building.length()>0 or not bool(map_profile.get("settlement",false)):
        return
    var used: Dictionary = {}
    var people: Array = town_life.residents_for_map(str(map_profile.get("id","")))
    for i in range(people.size()):
        var key: String = "citizen:"+str(people[i].get("id",""))
        if not nodes.has(key):
            continue
        var authored_spot: Vector2i = geography.town_design.resident_anchor(str(map_profile.get("id","")),str(people[i].get("role","lore")),i,int(clock_minutes/60),geography.zone(str(map_profile.get("id",""))).get("buildings",[]))
        var point: Vector2i = _resident_spot(authored_spot,used)
        nodes[key].position=Vector2(point*TILE)+Vector2(16,16)
        npc_positions[key]=point

func _make_focus_marker() -> void:
    focus_light = Sprite2D.new()
    focus_light.texture = load("res://assets/fx/glow.png")
    focus_light.scale = Vector2(1.1, 1.1)
    focus_light.modulate = Color(1, 0.76, 0.22, 0.75)
    focus_light.z_index = 15
    root.add_child(focus_light)
    focus_label = Label.new()
    focus_label.add_theme_font_size_override("font_size", 17)
    focus_label.add_theme_color_override("font_color", Color(1, 0.93, 0.66))
    focus_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 1))
    focus_label.add_theme_constant_override("shadow_offset_x", 2)
    focus_label.add_theme_constant_override("shadow_offset_y", 2)
    focus_label.z_index = 20
    root.add_child(focus_label)
    side_light = Sprite2D.new()
    side_light.texture = load("res://assets/fx/glow.png")
    side_light.modulate = Color(0.38, 0.90, 1.0, 0.67)
    side_light.scale = Vector2(0.85, 0.85)
    side_light.z_index = 13
    root.add_child(side_light)
    set_side_focus("")
    set_focus("")

func set_focus(name: String) -> void:
    focus_name = name
    if not is_instance_valid(focus_light):
        return
    focus_light.visible = nodes.has(name)
    focus_label.visible = nodes.has(name)
    if nodes.has(name):
        var anchor: Sprite2D = nodes[name]
        focus_light.position = anchor.position + Vector2(0, -45)
        focus_label.position = anchor.position + Vector2(-36, -86)
        var prologue_prompts: Array[String] = [
            "✦ 与澄舟交谈", "✦ 帮助岚音", "✦ 参加星灯祭",
            "✦ 查看古老石碑", "✦ 前往潮风灯塔", "✦ 天空出现异象",
            "✦ 跟随岚音撤离", "✦ 询问村长", "✦ 回到澄舟旧屋"
        ]
        if chapter==0 and name.begins_with("prologue_"):
            var scene_no: int=int(name.trim_prefix("prologue_"))
            focus_label.text=prologue_prompts[scene_no] if scene_no>=0 and scene_no<prologue_prompts.size() else "✦ 查看故事目标"
        else:
            focus_label.text = "✦ 前往调查"

func set_side_focus(name: String) -> void:
    side_focus_name = name
    if not is_instance_valid(side_light):
        return
    side_light.visible = nodes.has(name)
    if side_light.visible:
        var target: Sprite2D = nodes[name]
        side_light.position = target.position + Vector2(0, -40)

func _physics_process(delta: float) -> void:
    if not is_instance_valid(hero):
        return
    if locked:
        hero.set_motion(delta, Vector2.ZERO)
        return
    var direction: Vector2 = (Input.get_vector("move_left", "move_right", "move_up", "move_down") + movement).limit_length(1.0)
    var modifier: float = 1.0
    if interior_building.is_empty() and ambience!=null and not field_ecology.config(str(map_profile.get("id",""))).is_empty():
        modifier=field_ecology.movement_multiplier(str(map_profile.get("id","")),str(ambience.weather))
    var step: Vector2 = direction * walk_speed * modifier * delta
    var before: Vector2 = hero.position
    var proposal: Vector2 = before + Vector2(step.x, 0)
    if not _blocked(proposal):
        hero.position.x = proposal.x
    proposal = hero.position + Vector2(0, step.y)
    if not _blocked(proposal):
        hero.position.y = proposal.y
    var moved: Vector2 = hero.position - before
    hero.set_motion(delta, moved.normalized() if moved.length_squared() > 0.001 else Vector2.ZERO)
    companion.position = companion.position.lerp(hero.position + Vector2(-28, 20), minf(1.0, delta * 3.8))
    companion.set_motion(delta, moved.normalized() if moved.length_squared() > 0.001 else Vector2.ZERO)
    if is_instance_valid(third):
        third.position = third.position.lerp(hero.position + Vector2(-53, 27), minf(1.0, delta * 3.1))
        third.set_motion(delta, moved.normalized() if moved.length_squared() > 0.001 else Vector2.ZERO)
    if is_instance_valid(fourth):
        fourth.position = fourth.position.lerp(hero.position + Vector2(-78,40),minf(1.0,delta*2.8))
        fourth.set_motion(delta,moved.normalized() if moved.length_squared() > 0.001 else Vector2.ZERO)
    # Towns/inns are safe areas; random encounters only occur on wilderness
    # and dungeon paths, and camps grant a short exploration reprieve.
    if interior_building.is_empty() and not bool(map_profile.get("settlement",false)) and chapter >= 2 and moved.length_squared() > 0.001:
        var encounter_factor: float = 1.0
        if ambience!=null:
            encounter_factor=field_ecology.encounter_multiplier(str(map_profile.get("id","")),str(ambience.weather))
        encounter_meter += moved.length()*encounter_factor
        if encounter_meter > next_encounter:
            encounter_meter = 0.0
            next_encounter = rng.randf_range(490.0, 760.0)
            locked = true
            encounter_requested.emit()
    if focus_light.visible:
        focus_light.modulate.a = 0.58 + 0.18 * sin(Time.get_ticks_msec() * 0.005)

func _blocked(point: Vector2) -> bool:
    for offset in [Vector2(-9, -6), Vector2(9, -6), Vector2(-9, 6), Vector2(9, 6)]:
        var tile: Vector2i = Vector2i(floori((point.x + offset.x) / TILE), floori((point.y + offset.y) / TILE))
        if blocked.has(tile):
            return true
    return false

func interact() -> void:
    if locked or not is_instance_valid(hero):
        return
    hero.react()
    # Authoritative main objective has priority when the player stands at its marker.
    # Without this, a nearby town door could hijack a chapter-critical interaction.
    if not focus_name.is_empty() and nodes.has(focus_name):
        var focus_node: Node2D = nodes[focus_name]
        if is_instance_valid(focus_node) and focus_node.visible and hero.position.distance_to(focus_node.position) <= 45.0:
            interacted.emit(focus_name)
            return
    # Tracked story-side / postscript objectives take priority over ambient
    # doorways and passing NPCs, but never override a nearby critical main NPC.
    if not side_focus_name.is_empty() and nodes.has(side_focus_name):
        var tracked_node: Node2D = nodes[side_focus_name]
        if is_instance_valid(tracked_node) and tracked_node.visible and hero.position.distance_to(tracked_node.position)<=38.0:
            interacted.emit(side_focus_name)
            return
    # All five original narrative quest stage props are explicit walkable
    # interactions. A neighbouring doorway, generic field prop or chapter
    # errand must not consume the action intended for the selected quest.
    for index in range(5):
        var stage_id: String = "story_stage_%d" % index
        if nodes.has(stage_id):
            var stage_node: Node2D = nodes[stage_id]
            if is_instance_valid(stage_node) and stage_node.visible and hero.position.distance_to(stage_node.position) <= 34.0:
                interacted.emit(stage_id)
                return
    # Chapter interaction markers must never be shadowed by a newly placed
    # building doorway, gate, camp or side treasure in their immediate radius.
    for quest_id in ["key_npc","clue","witness","crisis","resolve"]:
        if nodes.has(quest_id):
            var quest_node: Node2D = nodes[quest_id]
            if is_instance_valid(quest_node) and quest_node.visible and hero.position.distance_to(quest_node.position) <= 28.0:
                interacted.emit(quest_id)
                return
    # A dedicated quest-room entrance must outrank the generic shop/guild
    # doorway when the two share a canonical building door or nearby paving.
    var nearest_quest_door: String = ""
    var nearest_door_distance: float = 38.0
    for marker_id in story_marker_ids:
        if not marker_id.begins_with("questdoor:") or not nodes.has(marker_id):
            continue
        var quest_door: Node2D = nodes[marker_id]
        if not is_instance_valid(quest_door) or not quest_door.visible:
            continue
        var distance_to_door: float = hero.position.distance_to(quest_door.position)
        if distance_to_door < nearest_door_distance:
            nearest_door_distance = distance_to_door
            nearest_quest_door = marker_id
    if not nearest_quest_door.is_empty():
        interacted.emit(nearest_quest_door)
        return
    # Explicit threshold interaction wins over unrelated decor/NPC markers.
    # Only the front side is usable; roofs and side walls remain impassable.
    var nearest_building: String = ""
    var nearest_building_distance: float = 53.0
    for key in nodes.keys():
        if not str(key).begins_with("building:") or not is_instance_valid(nodes[key]):
            continue
        var door_marker: Node2D=nodes[key]
        var offset: Vector2=hero.position-door_marker.position
        if absf(offset.x)>42.0 or offset.y< -26.0:
            continue
        var d: float=offset.length()
        if d<nearest_building_distance:
            nearest_building_distance=d
            nearest_building=str(key)
    if not nearest_building.is_empty():
        interacted.emit(nearest_building)
        return
    var chosen := ""
    var best: float = 65.0
    for key in nodes.keys():
        if str(key).begins_with("prologue_") and chapter != 0:
            continue
        if chapter == 0 and not str(key).begins_with("prologue_") and key not in ["inn", "shop"]:
            continue
        if not nodes[key].visible:
            continue
        var point: Node2D = nodes[key]
        var distance: float = hero.position.distance_to(point.position)
        if distance < best:
            best = distance
            chosen = str(key)
    if chosen.is_empty():
        interacted.emit("none")
    else:
        interacted.emit(chosen)

func sync_prologue_markers(active_index: int, story_chapter: int) -> void:
    # Treat a playable opening as an actual unfolding event, not nine
    # simultaneously glowing developer markers scattered around the village.
    var portraits: Dictionary={
        0:"chengzhou",1:"lanyin",4:"chengzhou",6:"lanyin",8:"lanyin"
    }
    for index in range(9):
        var marker_id: String="prologue_%d" % index
        if not nodes.has(marker_id):
            continue
        var marker: Sprite2D=nodes[marker_id]
        var active: bool=story_chapter==0 and index==active_index and interior_building.is_empty()
        marker.visible=active
        marker.modulate.a=0.30 if portraits.has(index) else 1.0
        if portraits.has(index) and not prologue_cast.has(index):
            var sprite_path: String="res://assets/art/characters/%s/walk_4dir_3frames.png" % str(portraits[index])
            if ResourceLoader.exists(sprite_path):
                var performer=Actor.new()
                performer.name="PrologueCast_%d" % index
                performer.setup(sprite_path)
                performer.position=marker.position+Vector2(0,12)
                performer.z_index=4
                scenery.add_child(performer)
                prologue_cast[index]=performer
        if prologue_cast.has(index):
            var performer_node: Node2D=prologue_cast[index]
            performer_node.visible=active
    # No narrative indices, task records, or collision cells are modified.

func set_prologue_phase(scene_no: int, story_chapter: int) -> void:
    if prologue_stage==null:
        return
    var map_id: String=str(map_profile.get("id",""))
    if story_chapter!=0 or map_id!="map_coast_01" or not interior_building.is_empty():
        prologue_stage.apply("normal",scene_no)
        return
    var phase: String="normal"
    if scene_no in [2,3,4]:
        phase="festival"
    elif scene_no==5:
        phase="falling"
    elif scene_no==6:
        phase="fallen"
    elif scene_no==7:
        phase="forgotten"
    elif scene_no>=8:
        phase="ten_years"
    prologue_stage.apply(phase,scene_no)

func region_name() -> String:
    var area: String = str(map_profile.get("name",custom_region)) if not map_profile.is_empty() else (REGION_NAMES[chapter] if chapter < REGION_NAMES.size() else custom_region)
    if not interior_building.is_empty():
        return area + " · " + interior_kind
    return area

func enter_building(building_id: String) -> bool:
    if not interior_building.is_empty():
        return false
    var entry: Dictionary = {}
    for feature in terrain_layout.get("features",[]):
        if str(feature.get("building","")) == building_id:
            entry = feature
            break
    if entry.is_empty():
        return false
    exterior_position = hero.position
    interior_building = building_id
    interior_kind = str(entry.get("name",building_id))
    build(chapter,last_party_size)
    return true

func enter_story_submap(quest_id: String, restore: bool = false) -> bool:
    if not interior_building.is_empty() or not quest_submaps.matches(quest_id,str(map_profile.get("id","")),chapter):
        return false
    if not restore and not nodes.has("questdoor:"+quest_id):
        return false
    var detail: Dictionary = quest_submaps.detail(quest_id)
    var layout_path: String = "res://data/levels/v4/interiors/%s__quest__%s.json" % [str(map_profile.get("id","")),quest_id]
    if not FileAccess.file_exists(layout_path):
        return false
    exterior_position = hero.position
    interior_building = "quest__"+quest_id
    interior_kind = str(detail.get("interior_name","调查室"))
    build(chapter,last_party_size)
    if terrain_layout.get("quest_points",[]).size()!=3:
        interior_building = ""
        interior_kind = ""
        build(chapter,last_party_size)
        hero.position = exterior_position
        return false
    return true

func leave_building() -> bool:
    if interior_building.is_empty():
        return false
    interior_building = ""
    interior_kind = ""
    build(chapter,last_party_size)
    hero.position = exterior_position
    return true

func spawn_from_exit(previous_map: String) -> void:
    var gate_id: String = "exit:"+previous_map
    if nodes.has(gate_id):
        var landmark: Node2D = nodes[gate_id]
        hero.position = landmark.position + Vector2(0,46)
        if _blocked(hero.position):
            hero.position = landmark.position + Vector2(46,0)

