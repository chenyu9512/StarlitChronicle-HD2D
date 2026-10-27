extends Node2D
## Narrative art layer for forty V3 production maps.
## Purely visual: NEVER changes the canonical terrain, collision, spawn, portals,
## NPC/story anchors, chapter flags, rewards, or old-save data.
const TilePool = preload("res://scripts/world_tileset_pool.gd")
const Geography = preload("res://scripts/world_geography.gd")
const BLUEPRINT_PATH: String = "res://data/levels/story_map_blueprints_v1.json"
const ATLAS_DIR: String = "res://assets/art/tilesets/story_v1/"
const TILE: int = 32
var map_id: String = ""
var layer: TileMapLayer
var painted: int = 0
var art_error: String = ""

static func blueprints() -> Dictionary:
    if not FileAccess.file_exists(BLUEPRINT_PATH):
        return {}
    var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(BLUEPRINT_PATH))
    return parsed if parsed is Dictionary else {}

func painted_cell_count() -> int:
    return painted

func configure(new_map: String, geometry: Dictionary, quality: int = 1) -> void:
    map_id = new_map
    painted = 0
    art_error = ""
    if is_instance_valid(layer):
        remove_child(layer)
        layer.free()
    layer = null
    if new_map.is_empty() or geometry.is_empty():
        return
    var catalogue: Dictionary = blueprints()
    var plan: Dictionary = (catalogue.get("maps", {}) as Dictionary).get(new_map, {})
    if plan.is_empty():
        return
    var region: String = str(plan.get("region_id", ""))
    if not region.begins_with("region_"):
        art_error = "Unrecognized regional art family"
        return
    var path: String = ATLAS_DIR + region + "_decals.svg"
    if not ResourceLoader.exists(path):
        art_error = "Missing narrative detail atlas: " + path
        return
    var paths: Array[String] = [path]
    var set: TileSet = TilePool.shared(paths)
    if set == null:
        art_error = "Narrative atlas failed to import: " + path
        return
    layer = TileMapLayer.new()
    layer.name = "NarrativeDetail32"
    layer.tile_set = set
    layer.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
    layer.z_index = -4
    layer.modulate = Color(1.0, 1.0, 1.0, 0.72 if quality == 0 else 0.93)
    add_child(layer)
    var extent: Vector2i = geometry.get("size", Vector2i(72, 48))
    var floor_tiles: Dictionary = geometry.get("tiles", {})
    var blocked: Dictionary = geometry.get("blocked", {})
    var water: Dictionary = geometry.get("water_mask", {})
    var spawn: Vector2i = geometry.get("spawn", Vector2i(10, 23))
    var protected: Dictionary = {}
    _protect(protected, spawn, 5)
    for group in ["features", "gates"]:
        for feature in geometry.get(group, []):
            if feature is Dictionary and feature.get("cell", null) is Vector2i:
                _protect(protected, feature["cell"], 2)
    # The original 72-chapter anchors may not be listed as generic features.
    # Keep a clean staging ring so players can clearly find active events.
    var geo := Geography.new()
    for anchor in geo._anchors():
        _protect(protected, anchor, 1)
    var seed: int = absi(new_map.hash())
    var rows: Array = plan.get("visual_rows", [0, 1, 2, 6])
    if rows.is_empty():
        return
    var seen: Dictionary = {}
    var story_sites: Array = plan.get("scenic_sites", [])
    for index in range(story_sites.size()):
        var site: Variant = story_sites[index]
        if not site is Dictionary:
            continue
        var pair: Array = site.get("cell", [])
        if pair.size() != 2:
            continue
        var origin: Vector2i = Vector2i(int(pair[0]), int(pair[1]))
        var accent_row: int = clampi(int(site.get("motif_row", 7)), 0, 7)
        for dy in range(-6, 7):
            for dx in range(-6, 7):
                var p: Vector2i = origin + Vector2i(dx, dy)
                if _hash(p.x, p.y, seed + index * 23) % 100 >= 17:
                    continue
                _place(p, accent_row, extent, floor_tiles, blocked, water, protected, seen, seed)
    # Sparse vegetation, paving wear, ore chips and shoreline flecks. One
    # TileMapLayer renders them batched; there are no 1000 Sprite2D children.
    var threshold: int = clampi(roundi(float(plan.get("density", 0.025)) * 10000.0), 40, 310)
    if quality == 0:
        threshold = maxi(30, threshold / 2)
    for y in range(3, extent.y - 3):
        for x in range(3, extent.x - 3):
            if painted >= 240:
                break
            var h: int = _hash(x, y, seed)
            if h % 10000 >= threshold:
                continue
            var kind: int = int(rows[int(h / 10000) % rows.size()])
            _place(Vector2i(x, y), kind, extent, floor_tiles, blocked, water, protected, seen, seed)
    painted = layer.get_used_cells().size()

func _protect(cache: Dictionary, center: Vector2i, distance: int) -> void:
    for y in range(-distance, distance + 1):
        for x in range(-distance, distance + 1):
            cache[center + Vector2i(x, y)] = true

func _hash(x: int, y: int, seed: int) -> int:
    return absi((x * 73856093) ^ (y * 19349663) ^ seed) % 1000000

func _place(p: Vector2i, motif: int, extent: Vector2i, floor_tiles: Dictionary,
        blocked: Dictionary, water: Dictionary, protected: Dictionary,
        used: Dictionary, seed: int) -> void:
    if p.x < 3 or p.y < 3 or p.x >= extent.x - 3 or p.y >= extent.y - 3:
        return
    if blocked.has(p) or water.has(p) or protected.has(p) or used.has(p):
        return
    if not floor_tiles.has(p):
        return
    var row: int = int((floor_tiles[p] as Vector2i).y)
    if row in [3, 6]:
        # No distracting floor foliage on canonical roads, doors or water.
        return
    var variant: int = _hash(p.y, p.x, seed + motif * 41) % 8
    used[p] = true
    layer.set_cell(p, 0, Vector2i(variant, motif))
    painted += 1
