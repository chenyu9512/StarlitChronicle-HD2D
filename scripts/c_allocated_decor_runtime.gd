extends Node2D
## Explicitly promoted, allocated 32px props from the later-uploaded third-party library.
## Decoration ONLY: never creates a route, entrance, collision, reward or save flag.
const Art = preload("res://scripts/c_art_overrides.gd")
const MANIFEST: String = "res://data/assets/c_art_allocated_decor_runtime_v1.json"
const SOURCE_PREFIX: String = "res://assets/art/external/cc0_named_v1/props/"
const TILE: int = 32
var placed: Dictionary = {}
var skipped: Dictionary = {}
var map_id: String = ""

func configure(selected_map: String, layout: Dictionary) -> void:
    map_id = selected_map
    for child in get_children():
        remove_child(child)
        child.queue_free()
    placed.clear()
    skipped.clear()
    if not FileAccess.file_exists(MANIFEST):
        skipped["manifest"] = "missing"
        return
    var document: Variant = JSON.parse_string(FileAccess.get_file_as_string(MANIFEST))
    if not document is Dictionary or str(document.get("schema", "")) != "starlit.c.allocated_decor_runtime.v1":
        skipped["manifest"] = "invalid"
        return
    var occupied: Dictionary = {}
    var reserved: Dictionary = _reserved(layout)
    var area: Vector2i = layout.get("size", Vector2i(72, 48))
    for raw in document.get("placements", []):
        if not raw is Dictionary or str(raw.get("map_id", "")) != selected_map:
            continue
        var id: String = str(raw.get("id", ""))
        var path: String = str(raw.get("source", ""))
        var hint: Array = raw.get("hint", [])
        if id.is_empty() or placed.has(id) or not path.begins_with(SOURCE_PREFIX) or path.contains("..") or hint.size() != 2:
            skipped[id] = "invalid_record"
            continue
        var texture: Texture2D = Art.texture(path)
        if texture == null or Vector2i(texture.get_size()) != Vector2i(TILE, TILE):
            skipped[id] = "not_a_32px_runtime_texture"
            continue
        var near := Vector2i(clampi(roundi(float(hint[0]) * area.x), 2, area.x - 3),
            clampi(roundi(float(hint[1]) * area.y), 2, area.y - 3))
        var actual: Vector2i = _safe_cell(near, layout, occupied, reserved)
        if actual.x < 0:
            skipped[id] = "no_safe_world_cell"
            continue
        occupied[actual] = true
        var sprite := Sprite2D.new()
        sprite.name = id
        sprite.texture = texture
        sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
        sprite.position = Vector2(actual * TILE) + Vector2(16, 16)
        sprite.z_index = -2
        sprite.set_meta("allocated_source", path)
        sprite.set_meta("map_cell", actual)
        sprite.set_meta("visual_only", true)
        add_child(sprite)
        placed[id] = sprite

func _reserved(layout: Dictionary) -> Dictionary:
    var result: Dictionary = {}
    for group in ["features", "gates"]:
        for raw in layout.get(group, []):
            if not raw is Dictionary:
                continue
            var cell: Variant = raw.get("cell", null)
            if not cell is Vector2i:
                continue
            var radius: int = 3 if group == "gates" else 2
            for dy in range(-radius, radius + 1):
                for dx in range(-radius, radius + 1):
                    result[cell + Vector2i(dx, dy)] = true
    return result

func _safe_cell(wanted: Vector2i, layout: Dictionary,
        occupied: Dictionary, reserved: Dictionary) -> Vector2i:
    var size: Vector2i = layout.get("size", Vector2i(72, 48))
    var blocked: Dictionary = layout.get("blocked", {})
    var water: Dictionary = layout.get("water_mask", {})
    var tiles: Dictionary = layout.get("tiles", {})
    var start: Vector2i = layout.get("spawn", Vector2i(-100, -100))
    var zone: Dictionary = layout.get("zone", {})
    for radius in range(24):
        for dy in range(-radius, radius + 1):
            for dx in range(-radius, radius + 1):
                if absi(dx) + absi(dy) != radius:
                    continue
                var cell: Vector2i = wanted + Vector2i(dx, dy)
                if cell.x < 3 or cell.y < 3 or cell.x >= size.x - 3 or cell.y >= size.y - 3:
                    continue
                if blocked.has(cell) or water.has(cell) or reserved.has(cell) or occupied.has(cell):
                    continue
                if cell.distance_squared_to(start) < 25:
                    continue
                var paint: Vector2i = tiles.get(cell, Vector2i.ZERO)
                if not tiles.has(cell) or paint.y == 3:
                    continue
                if _near_building(cell, zone.get("buildings", [])):
                    continue
                return cell
    return Vector2i(-1, -1)

func _near_building(cell: Vector2i, buildings: Array) -> bool:
    for raw in buildings:
        if not raw is Dictionary:
            continue
        var center: Array = raw.get("pos", [])
        var size: Array = raw.get("size", [])
        var door: Array = raw.get("door", [])
        if center.size() != 2 or size.size() != 2:
            continue
        var point := Vector2i(int(center[0]), int(center[1]))
        var half := Vector2i(int(size[0]) / 2 + 2, int(size[1]) / 2 + 2)
        if absi(cell.x - point.x) <= half.x and absi(cell.y - point.y) <= half.y:
            return true
        if door.size() == 2 and cell.distance_squared_to(Vector2i(int(door[0]), int(door[1]))) < 16:
            return true
    return false
