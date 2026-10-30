extends RefCounted
## Shared, bounded atlas TileSet cache for the authored 32px 2D world.
## Cached TileSets are immutable after construction. TileMapLayer keeps its own
## cells and collision state; sharing the atlas does not share map geometry.
## An LRU cap prevents all regions/interiors staying resident indefinitely.
const Art = preload("res://scripts/c_art_overrides.gd")
const RuntimeArt = preload("res://scripts/c_art_runtime.gd")
const TerrainAdapter = preload("res://scripts/third_party_terrain_adapter.gd")
const ThemeV2 = preload("res://scripts/c_art_theme_v2.gd")
const Coherent = preload("res://scripts/c_coherent_terrain_materials.gd")
const TILE: int = 32
const MAX_ENTRIES: int = 12
const MATERIAL_ROOT: String = "res://assets/art/runtime/generated_gaps_v10/"

## The pre-migration logical atlas URLs may have no local imported texture.
## Keep authored cell semantics by rebuilding an opaque atlas from V18 materials.
## This is a rendering fallback, never a change to collision, gates or saves.
static func _verified_material_for(path: String) -> Texture2D:
    if not path.begins_with("res://assets/art/") or path.contains(".."):
        return null
    var file: String = path.get_file()
    var is_ground: bool = (path.contains("/tilesets/") and file.ends_with("_ground.png")) or file in ["saltwind_route_tileset.svg", "tide_cavern_tileset.svg"]
    var is_water: bool = (path.contains("/tilesets/") and file.ends_with("_water.png")) or file == "cavern_water_atlas.svg"
    var is_indoor: bool = path.contains("/interiors/") and file.ends_with("_tileset.svg")
    if not (is_ground or is_water or is_indoor):
        return null
    var material_name: String = "town-grass"
    if is_water:
        material_name = "water-sea"
    elif is_indoor:
        material_name = "planks"
    elif path.contains("forge") or path.contains("mirror") or path.contains("oldland") or path.contains("cavern"):
        material_name = "cliff-rock"
    elif path.contains("city") or path.contains("sanctum"):
        material_name = "cobbles"
    elif path.contains("isles"):
        material_name = "beach-sand"
    var candidate: String = MATERIAL_ROOT + "material__coast__" + material_name.replace("-","_") + ".png"
    if not ResourceLoader.exists(candidate):
        return null
    return ResourceLoader.load(candidate) as Texture2D


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
        if path.is_empty():
            return null
    _sync_revision()
    # Build cache identity from the resolved Texture2D objects, not source
    # path strings. Several region paths may intentionally point to the SAME
    # 256px image through a global terrain DLC; one TileSet then serves them all.
    var textures: Array[Texture2D] = []
    var texture_ids: Array[String] = []
    for path in paths:
        var texture: Texture2D = RuntimeArt.texture_path(path)
        var from_verified_material: bool = false
        if texture == null:
            texture = _verified_material_for(path)
            from_verified_material = texture != null
            if from_verified_material:
                push_warning("Rebuilding absent logical terrain atlas from verified V18 materials: " + path)
        if texture == null:
            push_warning("Missing atlas resource and no verified fallback: " + path)
            return null
        # An imported user DLC already supplies the complete canonical 8x8
        # atlas. Never repaint it through the migration compatibility shader:
        # that silently discards the user's requested art replacement.
        var ready_user_atlas: bool = texture != null and Vector2i(texture.get_size()) == Vector2i(TILE*8,TILE*8) and ((Art.active_pack().begins_with("user_") and Art.pack_has_slot(path)) or (ThemeV2.is_active() and ThemeV2.texture_for_path(path) != null))
        # Directly imported V14 ocean imagery is a photographed source, not
        # the canonical 8x8 32px water tile grid. Reconstruct the physical
        # source using imported V18 water materials while retaining actual
        # selected semantic water, and preserve full user DLC atlas priority.
        var high_res_live_water: bool = path.contains("/runtime/act01_global_v14/surfaces/") and path.ends_with("_water.png")
        # Existing coastal SVG sheets are physical files, but their original
        # rows do not encode the gameplay's modern sand/road/rock semantics.
        # Importing them as-is repeats the same rock tile in distinct roles.
        # Rebuild ONLY these two authored route/cave sheets. Approved user
        # theme atlases above continue to take precedence, untouched.
        var legacy_exterior_roles: bool = path.contains("/exteriors/coast_final_pass/") and path.get_file() in ["tide_cavern_tileset.svg", "saltwind_route_tileset.svg"]
        # The new V10 terrain 8x8 sheets must be sorted back into meaningful
        # authored map rows before painting. Every map keeps its own palette.
        var generated_map_rows: bool = path.begins_with("res://assets/art/runtime/generated_gaps_v10/terrain__coast__")
        if not ready_user_atlas and Coherent.supports(path) and (Art.third_party_source(path) != path or high_res_live_water or from_verified_material or legacy_exterior_roles or generated_map_rows) and texture != null:
            # Cache per semantic path. A dune/road/water atlas cannot share the
            # same assembled texture merely because its source PNG is shared.
            # ResourceLoader can return a different wrapper instance for the
            # same migrated image. The art revision, not transient GPU object
            # identity, controls whether the cached atlas is still valid.
            var semantic_path: String = path
            var shared_theme: bool = Art.active_pack() == "shared_terrain" and Art.pack_has_slot(path)
            if shared_theme:
                semantic_path = "res://assets/art/tilesets/coast_water.png" if path.get_file().contains("water") else "res://assets/art/tilesets/coast_ground.png"
            var identity: String = semantic_path + ":r" + str(_revision)
            if not _adapted.has(identity):
                _adapted[identity] = Coherent.assemble(semantic_path, texture)
            texture = _adapted[identity] as Texture2D
        elif not ready_user_atlas and TerrainAdapter.supports(path) and Art.third_party_source(path) != path and texture != null:
            var source_key: String = path + ":r" + str(_revision)
            if not _adapted.has(source_key):
                _adapted[source_key] = TerrainAdapter.assemble(path, texture)
            texture = _adapted[source_key] as Texture2D
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
