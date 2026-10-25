extends Node2D
## 实际可探索地图：TileMapLayer / 实体交互 / 碰撞 / Y轴排序 / 镜头 / 遭遇。
signal interacted(target: String)
signal encounter_requested()

const Actor = preload("res://scripts/first_act_actor.gd")
const Geography = preload("res://scripts/world_geography.gd")
const WorldStructure = preload("res://scripts/world_structure.gd")
const TILE: int = 32
const WIDTH: int = 72
const HEIGHT: int = 48
const GROUND: String = "res://assets/art/tilesets/coast_ground.png"
const WATER: String = "res://assets/art/tilesets/coast_water.png"
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
var interior_building: String = ""
var interior_kind: String = ""
var exterior_position: Vector2 = Vector2.ZERO
var last_party_size: int = 2
var root: Node2D
var scenery: Node2D
var layer: TileMapLayer
var blocked: Dictionary = {}
var nodes: Dictionary = {}
var hero
var companion
var third
var fourth
var party_ids: Array = []
var camera: Camera2D
var focus_name: String = ""
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
    nodes.clear()
    root = Node2D.new()
    root.name = "FirstActLocation"
    add_child(root)
    _make_tiles()
    scenery = Node2D.new()
    scenery.y_sort_enabled = true
    root.add_child(scenery)
    _decorate()
    _build_sites()
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
    var tile_set := TileSet.new()
    tile_set.tile_size = Vector2i(TILE, TILE)
    var land := TileSetAtlasSource.new()
    land.texture = load(GROUND)
    land.texture_region_size = Vector2i(TILE, TILE)
    for y in range(8):
        for x in range(8):
            land.create_tile(Vector2i(x, y))
    tile_set.add_source(land, 0)
    var sea := TileSetAtlasSource.new()
    sea.texture = load(WATER)
    sea.texture_region_size = Vector2i(TILE, TILE)
    for y in range(8):
        for x in range(8):
            sea.create_tile(Vector2i(x, y))
    tile_set.add_source(sea, 1)
    layer = TileMapLayer.new()
    layer.name = "PlayableGround"
    layer.tile_set = tile_set
    layer.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
    layer.z_index = -5
    if not map_profile.is_empty():
        layer.modulate = map_profile.get("color",Color.WHITE)
    root.add_child(layer)
    if not interior_building.is_empty():
        terrain_layout = geography.interior(interior_building,interior_kind)
    else:
        terrain_layout = geography.layout(str(map_profile.get("id","map_coast_01")),chapter)
    blocked = terrain_layout.get("blocked",{}).duplicate()
    var all_tiles: Dictionary = terrain_layout.get("tiles",{})
    for tile in all_tiles.keys():
        var atlas: Vector2i = all_tiles[tile]
        var source_id: int = 0
        if interior_building.is_empty() and str(map_profile.get("region_id","")) in ["region_coast","region_isles"] and atlas.y==6 and tile.y>=HEIGHT-7:
            source_id = 1
            atlas = Vector2i(atlas.x,2)
        layer.set_cell(tile,source_id,atlas)

func _decorate() -> void:
    if not interior_building.is_empty():
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
            architecture.setup(str(feature.get("building","house")),str(feature.get("name","建筑")),width_data,region)
            architecture.position = Vector2(cell*TILE)+Vector2(16,16)
            scenery.add_child(architecture)
        else:
            _add_sprite(kind,cell,false,true)
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
        var pos := Vector2i(int(entry[1]), int(entry[2]))
        _add_sprite(str(entry[0]), pos, false)

func _add_sprite(kind: String, tile: Vector2i, solid: bool, authored: bool = false) -> Sprite2D:
    var path: String = "res://assets/art/props/coast/%s.png" % kind
    if not ResourceLoader.exists(path):
        path = "res://assets/art/props/coast/rock.png"
    var sprite := Sprite2D.new()
    sprite.texture = load(path)
    var place: Vector2i = tile if authored else geography.old_to_new(tile)
    sprite.position = Vector2(place*TILE)+Vector2(16,16)
    sprite.offset = Vector2(0, -20)
    sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
    scenery.add_child(sprite)
    if solid:
        blocked[place] = true
    return sprite

func _build_sites() -> void:
    if not interior_building.is_empty():
        var exit: Sprite2D = _add_sprite("sign",Vector2i(35,34),false,true)
        nodes["interior_exit"] = exit
        nodes["interior_service"] = _add_sprite("beacon",Vector2i(29,17),false,true)
        nodes["interior_storage"] = _add_sprite("barrel",Vector2i(45,19),false,true)
        return
    var archetype: String = str(terrain_layout.get("zone",{}).get("archetype",""))
    if archetype == "dungeon":
        nodes["dungeon_switch_a"] = _add_sprite("beacon",Vector2i(19,14),false,true)
        nodes["dungeon_switch_b"] = _add_sprite("sea_crystal",Vector2i(53,16),false,true)
        nodes["dungeon_chest"] = _add_sprite("crate",Vector2i(54,36),false,true)
    elif archetype in ["field","route","landmark"]:
        nodes["wild_cache"] = _add_sprite("crate",Vector2i(60,35),false,true)
        nodes["wild_camp"] = _add_sprite("star_lantern",Vector2i(24,14),false,true)
    for gate in terrain_layout.get("gates",[]):
        var id: String = str(gate.get("id",""))
        if not id.is_empty():
            nodes["exit:"+id] = _add_sprite("beacon",gate.get("cell",Vector2i(4,24)),false,true)
    for feature in terrain_layout.get("features",[]):
        if feature.has("building"):
            var door: Vector2i = feature.get("door",Vector2i.ZERO)
            nodes["building:"+str(feature.get("building",""))] = _add_sprite("sign",door,false,true)
    var icons := {"key_npc": "beacon", "clue": "crate", "witness": "medicine_basket", "crisis": "sea_crystal", "resolve": "star_lantern", "inn": "well", "shop": "fish_stall", "side_start": "sign", "side_item": "crate", "side_return": "beacon"}
    for k in SITES.keys():
        var where: Vector2i = SITES[k]
        var sprite: Sprite2D = _add_sprite(str(icons[k]), where, false)
        nodes[k] = sprite
    if str(map_profile.get("kind","")) == "town":
        var door: Sprite2D = _add_sprite("cottage",Vector2i(12,9),false)
        nodes["home_door"] = door
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
        focus_label.text = "✦ 前往调查"

func set_side_focus(name: String) -> void:
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
    var step: Vector2 = direction * walk_speed * delta
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
    if interior_building.is_empty() and chapter >= 2 and moved.length_squared() > 0.001:
        encounter_meter += moved.length()
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
    # Authoritative main objective has priority when the player stands at its marker.
    # Without this, a nearby town door could hijack a chapter-critical interaction.
    if not focus_name.is_empty() and nodes.has(focus_name):
        var focus_node: Node2D = nodes[focus_name]
        if is_instance_valid(focus_node) and focus_node.visible and hero.position.distance_to(focus_node.position) <= 45.0:
            interacted.emit(focus_name)
            return
    # Chapter interaction markers must never be shadowed by a newly placed
    # building doorway, gate, camp or side treasure in their immediate radius.
    for quest_id in ["key_npc","clue","witness","crisis","resolve"]:
        if nodes.has(quest_id):
            var quest_node: Node2D = nodes[quest_id]
            if is_instance_valid(quest_node) and quest_node.visible and hero.position.distance_to(quest_node.position) <= 28.0:
                interacted.emit(quest_id)
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
        var point: Sprite2D = nodes[key]
        var distance: float = hero.position.distance_to(point.position)
        if distance < best:
            best = distance
            chosen = str(key)
    if chosen.is_empty():
        interacted.emit("none")
    else:
        interacted.emit(chosen)

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

