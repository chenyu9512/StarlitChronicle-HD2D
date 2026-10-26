extends Node2D
## Persistent world node. Ground is a hand-built texture, while all visible props
## and actors occupy the same Y-sorting layer for correct feet/foreground overlap.

signal interaction_requested(kind: String, payload: Dictionary)
signal encounter_requested()

const TILE := 32
const ActorScript = preload("res://scripts/actor.gd")
const CArtOverrides = preload("res://scripts/c_art_overrides.gd")

var map_id := "village"
var map_width := 44
var map_height := 28
var terrain_rows: Array = []
var blocked: Dictionary = {}
var interactables: Array[Dictionary] = []
var content: Node2D
var player
var companion
var cam: Camera2D
var input_vector := Vector2.ZERO
var locked := false
var travel_meter := 0.0
var next_encounter := 220.0
var rng := RandomNumberGenerator.new()

func _ready() -> void:
    rng.randomize()

func load_map(id: String, entry_tile: Vector2i) -> void:
    if is_instance_valid(content):
        content.queue_free()
    for child in get_children():
        remove_child(child)
        child.queue_free()
    blocked.clear()
    interactables.clear()
    terrain_rows.clear()
    map_id = id
    var path := "res://data/%s.json" % id
    var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
    if not (parsed is Dictionary):
        push_error("地图文件无法读取：" + path)
        return
    var info: Dictionary = parsed
    map_width = int(info["width"])
    map_height = int(info["height"])
    terrain_rows = info["tiles"]

    var ground := Sprite2D.new()
    ground.name = "Ground"
    ground.centered = false
    ground.texture = CArtOverrides.texture("res://assets/maps/%s.png" % id)
    ground.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
    ground.z_index = -10
    add_child(ground)

    content = Node2D.new()
    content.name = "YSortedWorld"
    content.y_sort_enabled = true
    add_child(content)

    for entry in info["props"]:
        var item: Dictionary = entry
        if str(item.get("id", "")) == "ruins_chest" and State.opened_chests.has("ruins_chest"):
            item = item.duplicate()
            item["kind"] = "chest_open"
            item["interact"] = "opened_chest"
        if str(item.get("id", "")) == "boss" and State.boss_defeated:
            continue
        _add_prop(item)

    player = ActorScript.new()
    player.name = "Hero"
    player.setup("hero")
    player.position = tile_to_world(entry_tile)
    content.add_child(player)

    companion = ActorScript.new()
    companion.name = "Companion"
    companion.setup("companion")
    companion.position = player.position + Vector2(-24, 18)
    content.add_child(companion)

    cam = Camera2D.new()
    cam.name = "Camera"
    cam.zoom = Vector2(1.6, 1.6)
    cam.position_smoothing_enabled = true
    cam.position_smoothing_speed = 6.0
    cam.limit_left = 0
    cam.limit_top = 0
    cam.limit_right = map_width * TILE
    cam.limit_bottom = map_height * TILE
    player.add_child(cam)
    cam.make_current()
    travel_meter = 0.0
    next_encounter = rng.randf_range(170.0, 270.0)
    locked = false

func tile_to_world(tile: Vector2i) -> Vector2:
    return Vector2(tile.x * TILE + 16, tile.y * TILE + 16)

func get_player_tile() -> Vector2i:
    if not is_instance_valid(player):
        return Vector2i(12, 17)
    return Vector2i(floori(player.position.x / TILE), floori(player.position.y / TILE))

func _add_prop(item: Dictionary) -> void:
    var kind := str(item["kind"])
    var sprite := Sprite2D.new()
    sprite.name = str(item.get("id", kind))
    sprite.texture = CArtOverrides.texture("res://assets/props/%s.png" % kind)
    sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
    sprite.position = tile_to_world(Vector2i(int(item["x"]), int(item["y"])))
    if sprite.texture != null:
        sprite.offset.y = -float(sprite.texture.get_height()) * 0.5 + 9.0
    content.add_child(sprite)
    var size: Array = item.get("solid", [])
    if size.size() == 2:
        for dx in range(int(size[0])):
            for dy in range(int(size[1])):
                blocked[Vector2i(int(item["x"]) + dx, int(item["y"]) + dy)] = true
    if item.has("interact"):
        var inter := item.duplicate()
        inter["world_position"] = sprite.position
        interactables.append(inter)
    if kind in ["lamp", "crystal", "altar", "portal"]:
        var light_sprite := Sprite2D.new()
        light_sprite.texture = CArtOverrides.texture("res://assets/fx/glow.png")
        light_sprite.position = sprite.position + Vector2(0, -33)
        light_sprite.z_index = 6
        light_sprite.modulate = Color(1.0, 0.69, 0.24, 0.30) if kind in ["lamp", "portal"] else Color(0.33, 0.75, 1.0, 0.29)
        light_sprite.scale = Vector2(1.1, 1.1)
        light_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
        add_child(light_sprite)

func _physics_process(delta: float) -> void:
    if locked or not is_instance_valid(player):
        if is_instance_valid(player):
            player.set_motion(delta, Vector2.ZERO)
        return
    var key_dir := Input.get_vector("move_left", "move_right", "move_up", "move_down")
    var direction := (key_dir + input_vector).limit_length(1.0)
    var step := direction * delta * (244.0 if State.cheat_fast_walk else 136.0)
    var old_pos: Vector2 = player.position
    var proposed := old_pos + Vector2(step.x, 0)
    if not _is_solid(proposed):
        player.position.x = proposed.x
    proposed = player.position + Vector2(0, step.y)
    if not _is_solid(proposed):
        player.position.y = proposed.y
    var actual: Vector2 = player.position - old_pos
    player.set_motion(delta, actual.normalized())
    companion.position = companion.position.lerp(player.position + Vector2(-19, 20), minf(delta * 4.0, 1.0))
    companion.set_motion(delta, actual.normalized() if actual.length() > 0.1 else Vector2.ZERO)
    if map_id == "ruins" and not State.cheat_no_encounters:
        travel_meter += actual.length()
        if travel_meter >= next_encounter:
            travel_meter = 0.0
            next_encounter = rng.randf_range(200.0, 310.0)
            locked = true
            encounter_requested.emit()

func _is_solid(pos: Vector2) -> bool:
    for corner in [Vector2(-9, -6), Vector2(9, -6), Vector2(-9, 6), Vector2(9, 6)]:
        var cell := Vector2i(floori((pos.x + corner.x) / TILE), floori((pos.y + corner.y) / TILE))
        if cell.x < 1 or cell.y < 1 or cell.x >= map_width - 1 or cell.y >= map_height - 1:
            return true
        if blocked.has(cell):
            return true
        var row: String = str(terrain_rows[cell.y])
        if row[cell.x] == "W" or row[cell.x] == "w":
            return true
    return false

func interact() -> bool:
    if locked or not is_instance_valid(player):
        return false
    var closest_dist := 64.0
    var closest: Dictionary = {}
    for item in interactables:
        # Dictionary values are Variant; explicitly type both coordinates and distance.
        var player_position: Vector2 = player.position
        var target_position: Vector2 = item["world_position"]
        var distance: float = player_position.distance_to(target_position)
        if distance < closest_dist:
            closest_dist = distance
            closest = item
    if closest.is_empty():
        return false
    interaction_requested.emit(str(closest["interact"]), closest)
    return true
