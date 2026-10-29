extends Node2D
## Generated role-correct shoreline sprite sheets. Animated at real water edges
## with 3 frames per strip; NOT a collectible, collider or invisible map gate.
const Art = preload("res://scripts/c_art_overrides.gd")
const DIR: String = "res://assets/art/runtime/shore_waves_v1/"
const TILE: int = 32
var animated: Array[Dictionary] = []
var art_errors: Array[String] = []
var elapsed: float = 0.0

func _source(big: bool, heading: String) -> String:
    var size_name: String = "big" if big else "small"
    return DIR + size_name + "_" + heading + ".png"

func configure(map_id: String, layout: Dictionary) -> void:
    for child in get_children():
        remove_child(child)
        child.queue_free()
    animated.clear()
    art_errors.clear()
    elapsed = 0.0
    if map_id != "map_coast_03":
        return
    var water: Dictionary = layout.get("water_mask", {})
    var blocked: Dictionary = layout.get("blocked", {})
    var tiles: Dictionary = layout.get("tiles", {})
    var area: Vector2i = layout.get("size", Vector2i(72, 48))
    var sources: Dictionary = {}
    for size_name in ["small", "big"]:
        for heading in ["down", "up", "left", "right"]:
            var big: bool = size_name == "big"
            var path: String = _source(big, heading)
            var texture: Texture2D = Art.texture(path)
            var frame_size: int = 64 if big else 32
            if texture == null or Vector2i(texture.get_size()) != Vector2i(frame_size * 3, frame_size):
                art_errors.append("Unusable 3-frame wave: " + path)
                continue
            sources[size_name + ":" + heading] = texture
    if not art_errors.is_empty():
        return
    var count: int = 0
    for y in range(3, area.y - 3):
        if count >= 12:
            break
        for x in range(3, area.x - 3):
            if count >= 12:
                break
            var cell := Vector2i(x, y)
            if not water.has(cell):
                continue
            var shore: bool = false
            var orientation: String = "down"
            for direction in [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]:
                var adjacent: Vector2i = cell + direction
                if tiles.has(adjacent) and not water.has(adjacent) and not blocked.has(adjacent):
                    shore = true
                    orientation = "up" if direction == Vector2i.UP else ("left" if direction == Vector2i.LEFT else ("right" if direction == Vector2i.RIGHT else "down"))
                    break
            if not shore or posmod(x * 17 + y * 31, 11) != 0:
                continue
            var big: bool = count % 4 == 0
            var size_name: String = "big" if big else "small"
            var source: Texture2D = sources.get(size_name + ":" + orientation) as Texture2D
            if source == null:
                continue
            var frame_size: int = 64 if big else 32
            var atlas := AtlasTexture.new()
            atlas.atlas = source
            atlas.region = Rect2(0, 0, frame_size, frame_size)
            var wave := Sprite2D.new()
            wave.name = "ShoreWave_%02d" % count
            wave.texture = atlas
            wave.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
            wave.modulate.a = 0.80
            wave.z_index = -3
            wave.position = Vector2(cell * TILE) + Vector2(16, 16)
            add_child(wave)
            animated.append({"sprite":wave,"atlas":atlas,"size":frame_size,"phase":count % 3,
                "source":_source(big, orientation),"cell":cell})
            count += 1

func _process(delta: float) -> void:
    if animated.is_empty():
        return
    elapsed += clampf(delta, 0.0, 0.12)
    for entry in animated:
        var atlas: AtlasTexture = entry["atlas"]
        var size: int = int(entry["size"])
        var frame: int = posmod(int(elapsed / 0.18) + int(entry["phase"]), 3)
        atlas.region = Rect2(frame * size, 0, size, size)
