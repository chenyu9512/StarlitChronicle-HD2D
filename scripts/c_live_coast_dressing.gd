extends Node2D
## C7 selected existing 32x32 decorations on the authored coast. Visual-only.
## Never marks blocked tiles or changes entrances, events, map state or save data.
const ArtOverrides = preload("res://scripts/c_art_overrides.gd")
const MANIFEST: String = "res://data/assets/c_art_live_coast_v7.json"
const ART_PREFIX: String = "res://assets/art/external/cc0_named_v1/props/"
const TILE: int = 32
var map_id: String = ""
var placed: Dictionary = {}
var skipped: Array[String] = []

func configure(map_key: String, layout: Dictionary) -> void:
    map_id = map_key
    placed.clear()
    skipped.clear()
    if not FileAccess.file_exists(MANIFEST):
        return
    var raw: Variant = JSON.parse_string(FileAccess.get_file_as_string(MANIFEST))
    if not raw is Dictionary:
        return
    var occupied: Dictionary = {}
    for item in raw.get("placements", []):
        if not item is Dictionary or str(item.get("map_id", "")) != map_key:
            continue
        var id: String = str(item.get("id", ""))
        var path: String = str(item.get("source", ""))
        var coords: Variant = item.get("cell", [])
        if id.is_empty() or placed.has(id) or not coords is Array or coords.size() != 2:
            skipped.append(id)
            continue
        if not path.begins_with(ART_PREFIX) or path.contains(".."):
            skipped.append(id)
            continue
        var texture: Texture2D = ArtOverrides.texture(path)
        if texture == null or Vector2i(texture.get_size()) != Vector2i(TILE, TILE):
            skipped.append(id)
            continue
        var expected: Vector2i = Vector2i(int(coords[0]), int(coords[1]))
        var safe: Vector2i = _find_safe_verge(expected, layout, occupied)
        if safe.x < 0:
            skipped.append(id)
            continue
        occupied[safe] = true
        var sprite := Sprite2D.new()
        sprite.name = "CArtV7_" + id
        sprite.texture = texture
        sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
        sprite.position = Vector2(safe * TILE) + Vector2(16, 16)
        sprite.z_index = -2
        sprite.set_meta("art_kind", str(item.get("kind", "")))
        sprite.set_meta("source_path", path)
        sprite.set_meta("map_cell", safe)
        add_child(sprite)
        placed[id] = sprite

func _find_safe_verge(wanted: Vector2i, layout: Dictionary, occupied: Dictionary) -> Vector2i:
    var extent: Vector2i = layout.get("size", Vector2i(96, 56))
    var blocked: Dictionary = layout.get("blocked", {})
    var water: Dictionary = layout.get("water_mask", {})
    var ground: Dictionary = layout.get("tiles", {})
    var zone: Dictionary = layout.get("zone", {})
    var buildings: Array = zone.get("buildings", [])
    var spawn: Vector2i = layout.get("spawn", Vector2i(-100, -100))
    for radius in range(7):
        for dy in range(-radius, radius + 1):
            for dx in range(-radius, radius + 1):
                if absi(dx) + absi(dy) != radius:
                    continue
                var tile: Vector2i = wanted + Vector2i(dx, dy)
                if tile.x < 3 or tile.y < 3 or tile.x >= extent.x - 3 or tile.y >= extent.y - 3:
                    continue
                if occupied.has(tile) or blocked.has(tile) or water.has(tile):
                    continue
                if tile.distance_squared_to(spawn) < 16:
                    continue
                var paint: Vector2i = ground.get(tile, Vector2i.ZERO)
                if paint.y == 3:
                    continue
                var near_structure: bool = false
                for record in buildings:
                    if not record is Dictionary:
                        continue
                    var pos: Array = record.get("pos", [])
                    var size: Array = record.get("size", [])
                    var door: Array = record.get("door", [])
                    if pos.size() != 2 or size.size() != 2:
                        continue
                    var center := Vector2i(int(pos[0]), int(pos[1]))
                    var half := Vector2i(int(size[0]) / 2, int(size[1]) / 2)
                    if absi(tile.x - center.x) <= half.x + 1 and absi(tile.y - center.y) <= half.y + 1:
                        near_structure = true
                        break
                    if door.size() == 2 and tile.distance_squared_to(Vector2i(int(door[0]), int(door[1])) + Vector2i.DOWN) < 16:
                        near_structure = true
                        break
                if not near_structure:
                    return tile
    return Vector2i(-1, -1)
