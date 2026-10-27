extends RefCounted
## Shared, bounded atlas TileSet cache for the authored 32px 2D world.
## Cached TileSets are immutable after construction. TileMapLayer keeps its own
## cells and collision state; sharing the atlas does not share map geometry.
## An LRU cap prevents all regions/interiors staying resident indefinitely.
const Art = preload("res://scripts/c_art_overrides.gd")
const TerrainAdapter = preload("res://scripts/third_party_terrain_adapter.gd")
const TILE: int = 32
const MAX_ENTRIES: int = 12

static var _sets: Dictionary = {}
static var _adapted: Dictionary = {}
static var _recent: Array[String] = []
static var _revision: int = -1
static var _builds: int = 0
static var _hits: int = 0
static var _evictions: int = 0


static func reset() -> void:
    _sets.clear()
    _adapted.clear()
    _recent.clear()
    _revision = Art.revision()
    _builds = 0
    _hits = 0
    _evictions = 0


static func stats() -> Dictionary:
    _sync_revision()
    return {"entries": _sets.size(), "max_entries": MAX_ENTRIES,
        "builds": _builds, "hits": _hits, "evictions": _evictions,
        "art_revision": _revision}


static func _sync_revision() -> void:
    var latest: int = Art.revision()
    if _revision == latest:
        return
    # Existing TileMapLayers may keep references to old TileSets until
    # their scene is retired; newly built scenes receive the new art.
    _sets.clear()
    _adapted.clear()
    _recent.clear()
    _revision = latest


static func _mark_used(key: String) -> void:
    _recent.erase(key)
    _recent.append(key)


## paths[0] becomes atlas source 0, paths[1] source 1, etc.
## row_start=7,row_count=1 supports indoor wall-edge tiles at atlas row 7.
static func shared(paths: Array[String], columns: int = 8,
        row_start: int = 0, row_count: int = 8) -> TileSet:
    if paths.is_empty() or columns < 1 or row_start < 0 or row_count < 1:
        return null
    for path in paths:
        if path.is_empty() or not Art.exists(path):
            push_warning("Missing atlas resource: " + path)
            return null
    _sync_revision()
    # Build cache identity from the resolved Texture2D objects, not source
    # path strings. Several region paths may intentionally point to the SAME
    # 256px image through a global terrain DLC; one TileSet then serves them all.
    var textures: Array[Texture2D] = []
    var texture_ids: Array[String] = []
    for path in paths:
        var texture: Texture2D = Art.texture(path)
        if TerrainAdapter.supports(path) and Art.third_party_source(path) != path:
            if not _adapted.has(path):
                _adapted[path] = TerrainAdapter.assemble(path, texture)
            texture = _adapted[path] as Texture2D
        if texture == null or texture.get_width() < columns*TILE or texture.get_height() < (row_start+row_count)*TILE:
            push_warning("Atlas has wrong 32px dimensions: " + path)
            return null
        textures.append(texture)
        texture_ids.append(str(texture.get_instance_id()))
    var key: String = "%d:%d:%d:%d:%s" % [
        _revision, columns, row_start, row_count, JSON.stringify(texture_ids)]
    if _sets.has(key):
        _hits += 1
        _mark_used(key)
        return _sets[key] as TileSet

    var result := TileSet.new()
    result.tile_size = Vector2i(TILE, TILE)
    for source_id in range(textures.size()):
        var atlas := TileSetAtlasSource.new()
        atlas.texture = textures[source_id]
        atlas.texture_region_size = Vector2i(TILE, TILE)
        for y in range(row_start, row_start+row_count):
            for x in range(columns):
                atlas.create_tile(Vector2i(x, y))
        result.add_source(atlas, source_id)

    _sets[key] = result
    _mark_used(key)
    _builds += 1
    while _recent.size() > MAX_ENTRIES:
        var oldest: String = _recent.pop_front()
        _sets.erase(oldest)
        _evictions += 1
    return result
