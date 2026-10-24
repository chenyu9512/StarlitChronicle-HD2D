extends Node2D
## 实际可探索地图：TileMapLayer / 实体交互 / 碰撞 / Y轴排序 / 镜头 / 遭遇。
signal interacted(target: String)
signal encounter_requested()

const Actor = preload("res://scripts/first_act_actor.gd")
const TILE: int = 32
const WIDTH: int = 44
const HEIGHT: int = 28
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
var root: Node2D
var scenery: Node2D
var layer: TileMapLayer
var blocked: Dictionary = {}
var nodes: Dictionary = {}
var hero
var companion
var third
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

func build(new_chapter: int, party_size: int) -> void:
    chapter = maxi(0, new_chapter)
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
    hero.setup("res://assets/art/characters/leon/walk_4dir_3frames.png")
    hero.position = Vector2(6 * TILE + 16, 13 * TILE + 16)
    hero.z_index = 3
    scenery.add_child(hero)
    companion = Actor.new()
    companion.setup("res://assets/art/characters/lanyin/walk_4dir_3frames.png")
    companion.position = hero.position + Vector2(-29, 22)
    scenery.add_child(companion)
    third = null
    if party_size >= 3:
        third = Actor.new()
        third.setup("res://assets/art/characters/shuoxian/walk_4dir_3frames.png")
        third.position = hero.position + Vector2(-52, 30)
        scenery.add_child(third)
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
    root.add_child(layer)
    var coast: bool = chapter in [2, 5, 6] or (chapter > 6 and int((chapter - 1) / 6) % 3 == 0)
    var dungeon: bool = chapter == 3 or (chapter > 6 and int((chapter - 1) / 6) % 3 == 2)
    for y in range(HEIGHT):
        for x in range(WIDTH):
            var sea_edge: bool = coast and (x <= 2 or y >= HEIGHT - 3 or (chapter == 5 and y >= 23 and x > 23))
            var blocked_edge: bool = x < 2 or x > WIDTH - 3 or y < 2 or y > HEIGHT - 3
            if blocked_edge or sea_edge:
                blocked[Vector2i(x, y)] = true
                layer.set_cell(Vector2i(x, y), 1 if sea_edge else 0, Vector2i((x + y) % 4, 2 if sea_edge else 6))
            else:
                var path: bool = x >= 5 and x <= 38 and (abs(y - 14) <= 2 or abs(x - 22) <= 2)
                var ax: int = 1 if path else (x + y + chapter * 2) % 4
                var ay: int = 3 if path else (5 if dungeon else (1 if coast else 0))
                layer.set_cell(Vector2i(x, y), 0, Vector2i(ax, ay))
    for y in range(11, 18):
        for x in range(5, 39):
            blocked.erase(Vector2i(x, y))

func _decorate() -> void:
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
    for entry in objects:
        var pos := Vector2i(int(entry[1]), int(entry[2]))
        _add_sprite(str(entry[0]), pos, false)

func _add_sprite(kind: String, tile: Vector2i, solid: bool) -> Sprite2D:
    var path: String = "res://assets/art/props/coast/%s.png" % kind
    if not ResourceLoader.exists(path):
        path = "res://assets/art/props/coast/rock.png"
    var sprite := Sprite2D.new()
    sprite.texture = load(path)
    sprite.position = Vector2(tile.x * TILE + 16, tile.y * TILE + 16)
    sprite.offset = Vector2(0, -20)
    sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
    scenery.add_child(sprite)
    if solid:
        blocked[tile] = true
    return sprite

func _build_sites() -> void:
    var icons := {"key_npc": "beacon", "clue": "crate", "witness": "medicine_basket", "crisis": "sea_crystal", "resolve": "star_lantern", "inn": "well", "shop": "fish_stall", "side_start": "sign", "side_item": "crate", "side_return": "beacon"}
    for k in SITES.keys():
        var where: Vector2i = SITES[k]
        var sprite: Sprite2D = _add_sprite(str(icons[k]), where, false)
        nodes[k] = sprite
    for i in range(9):
        var offset := Vector2i(7 + (i % 3) * 12, 10 + int(i / 3) * 5)
        var point: Sprite2D = _add_sprite("star_lantern" if i % 2 == 0 else "sign", offset, false)
        nodes["prologue_%d" % i] = point
    for i in range(9):
        var key: String = "prologue_%d" % i
        nodes[key].visible = chapter == 0
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
    if chapter >= 2 and moved.length_squared() > 0.001:
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
    return REGION_NAMES[chapter] if chapter < REGION_NAMES.size() else custom_region
