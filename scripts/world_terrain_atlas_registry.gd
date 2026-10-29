extends RefCounted
## C V8 central terrain atlas registry: source IDs stay 0 ground / 1 water.
## This module deliberately has no dependency on CArtOverrides or TilePool.
const Coherent = preload("res://scripts/c_coherent_terrain_materials.gd")
const Generated = preload("res://scripts/global_generated_art_v3.gd")
const REGISTRY_PATH: String = "res://data/assets/c_shared_terrain_v8.json"
const COAST_V14_SOURCE: String = "res://data/assets/c_act01_global_distribution_v14.json"
static var _coast_terrain_loaded: bool = false
static var _coast_terrain: Dictionary = {}
const CORE_GROUND: String = "res://assets/art/tilesets/coast_ground.png"
const CORE_WATER: String = "res://assets/art/tilesets/coast_water.png"

## Local Pixel Fantasy DLC is an explicit, reversible presentation layer.
## It never alters the underlying 32px V3 map cells or gameplay collision.
const PIXEL_LOCAL_ROOT: String = "res://assets/art/local_themes/pixel_fantasy_v1/"
const PIXEL_LOCAL_SWITCH: String = PIXEL_LOCAL_ROOT + "active.json"

const PIXEL_LOCAL_REGIONS: Array[String] = [
    "region_coast", "region_oaths", "region_forge", "region_isles",
    "region_mirror", "region_oldland", "region_sanctum", "region_city"
]
const PIXEL_LOCAL_PROPS: Array[String] = [
    "cottage.png", "well.png", "fish_stall.png", "lighthouse.png",
    "harbor_crane.png", "market_stall.png"
]

## All-or-nothing local presentation. A missing region or prop must not
## silently produce a patchwork of Pixel Fantasy and the original HD2D art.
## Do not cache this preflight: local images can be removed while running.
static func pixel_theme_ready() -> bool:
    if not FileAccess.file_exists(PIXEL_LOCAL_SWITCH):
        return false
    var raw: Variant = JSON.parse_string(FileAccess.get_file_as_string(PIXEL_LOCAL_SWITCH))
    if not raw is Dictionary or str(raw.get("schema", "")) != "starlit.pixel_fantasy.local.v1" or not bool(raw.get("enabled", false)):
        return false
    for region_id in PIXEL_LOCAL_REGIONS:
        for kind in ["ground", "water"]:
            var atlas: String = PIXEL_LOCAL_ROOT + "regions/" + region_id + "_" + kind + ".png"
            if not FileAccess.file_exists(atlas) or not ResourceLoader.exists(atlas):
                return false
            var image: Texture2D = ResourceLoader.load(atlas) as Texture2D
            if image == null or Vector2i(image.get_size()) != Vector2i(256, 256):
                return false
    for filename in PIXEL_LOCAL_PROPS:
        var path: String = PIXEL_LOCAL_ROOT + "props/" + filename
        if not FileAccess.file_exists(path) or not ResourceLoader.exists(path):
            return false
        var texture: Texture2D = ResourceLoader.load(path) as Texture2D
        if texture == null or texture.get_width() < 8 or texture.get_height() < 8:
            return false
    return true

static func pixel_theme_paths(region_id: String, outdoors: bool = true) -> Array[String]:
    if not outdoors or not region_id in PIXEL_LOCAL_REGIONS or not pixel_theme_ready():
        return []
    var stem: String = PIXEL_LOCAL_ROOT + "regions/" + region_id
    return [stem + "_ground.png", stem + "_water.png"]

static var _registry: Dictionary = {}
# The historical atlas slot can be removed on the third-party-only branch.
# This independent resolver intentionally has no dependency on CArtOverrides:
# CArtOverrides preloads this registry, so importing it here is a cycle.
## A retired logical atlas is valid only when the semantic atlas builder
## explicitly understands its role. A random migrated PNG is NOT a tile sheet.
static func _has_source(path: String) -> bool:
    if not path.begins_with("res://assets/art/") or path.contains(".."):
        return false
    return ResourceLoader.exists(path) or Coherent.supports(path)

static func _data() -> Dictionary:
    if not _registry.is_empty():
        return _registry
    if not FileAccess.file_exists(REGISTRY_PATH):
        return {}
    var raw: Variant = JSON.parse_string(FileAccess.get_file_as_string(REGISTRY_PATH))
    if raw is Dictionary:
        _registry = raw
    # Region ground/water IDs are owned by the unified registry. The V8 file
    # retains map overrides and compatibility group contracts only.
    var runtime: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/assets/c_art_runtime_registry_v1.json"))
    if runtime is Dictionary and str(runtime.get("schema", "")) == "starlit.c.art_runtime_registry.v1":
        var regions: Dictionary = _registry.get("regions", {})
        for id in (runtime.get("regions", {}) as Dictionary).keys():
            var spec: Dictionary = runtime["regions"][id]
            var atlas_spec: Dictionary = spec.get("terrain", {})
            if atlas_spec.has("ground") and atlas_spec.has("water"):
                regions[id] = atlas_spec.duplicate(true)
        _registry["regions"] = regions
    return _registry

static func group_slots(group_id: String) -> Array[String]:
    var result: Array[String] = []
    if group_id not in ["terrain_ground", "terrain_water"]:
        return result
    var groups: Dictionary = _data().get("groups", {})
    var slots: Array = groups.get(group_id, [])
    for entry in slots:
        var path: String = str(entry)
        if path.begins_with("res://assets/art/") and not path.contains("..") and not result.has(path):
            result.append(path)
    return result

## Authored first-act maps use genuinely distinct 256px ground/water sheets.
## Do not preload the GlobalArt class here: it imports RuntimeArt, whose
## TerrainAtlas dependency would otherwise introduce a GDScript cycle.
static func _coast_authored_pair(map_id: String) -> Array[String]:
    if not _coast_terrain_loaded:
        _coast_terrain_loaded = true
        if FileAccess.file_exists(COAST_V14_SOURCE):
            var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(COAST_V14_SOURCE))
            if parsed is Dictionary and str(parsed.get("schema", "")) == "starlit.c.act01_global_distribution.v14":
                _coast_terrain = (parsed.get("runtime", {}) as Dictionary).get("terrain", {})
    var entry: Dictionary = _coast_terrain.get(map_id, {})
    var ground: String = str(entry.get("ground", ""))
    var water: String = str(entry.get("water", ""))
    if not ground.begins_with("res://assets/art/runtime/generated_gaps_v10/terrain__coast__") or
            not water.begins_with("res://assets/art/runtime/generated_gaps_v10/terrain__coast__"):
        return []
    if not ResourceLoader.exists(ground) or not ResourceLoader.exists(water):
        return []
    var floor_texture: Texture2D = ResourceLoader.load(ground) as Texture2D
    var water_texture: Texture2D = ResourceLoader.load(water) as Texture2D
    if floor_texture == null or water_texture == null or
            floor_texture.get_size() != Vector2(256,256) or water_texture.get_size() != Vector2(256,256):
        return []
    return [ground, water]

static func atlas_sources(region_id: String, map_id: String,
        authored_atlas: String = "", outdoors: bool = true) -> Array[String]:
    var data: Dictionary = _data()
    var spec: Dictionary = (data.get("regions", {}) as Dictionary).get(region_id, {})
    var land: String = str(spec.get("ground", CORE_GROUND))
    var water: String = str(spec.get("water", CORE_WATER))
    if not _has_source(land) or not _has_source(water):
        land = CORE_GROUND
        water = CORE_WATER
    if outdoors:
        var overrides: Dictionary = (data.get("map_overrides", {}) as Dictionary).get(map_id, {})
        var outdoor_land: String = str(overrides.get("ground", ""))
        var outdoor_water: String = str(overrides.get("water", ""))
        if not outdoor_land.is_empty() and _has_source(outdoor_land):
            land = outdoor_land
        if not outdoor_water.is_empty() and _has_source(outdoor_water):
            water = outdoor_water
    elif not authored_atlas.is_empty() and _has_source(authored_atlas):
        land = authored_atlas
    # Explicit fully-verified Pixel Fantasy DLC must outrank the automatic
    # V3 generated default, otherwise the user-selected full theme never
    # reaches the actual TileMap. A broken DLC is rejected for every region.
    var pixel_local: Array[String] = pixel_theme_paths(region_id, outdoors)
    if pixel_local.size() == 2:
        return pixel_local
    if outdoors and region_id == "region_coast":
        var first_act_authored: Array[String] = _coast_authored_pair(map_id)
        if first_act_authored.size() == 2:
            return first_act_authored
    if outdoors:
        var generated: Array[String] = Generated.terrain_paths(region_id)
        if generated.size() == 2:
            return generated
    return [land, water]

static func is_regional(region_id: String) -> bool:
    return ( _data().get("regions", {}) as Dictionary).has(region_id)

static func is_authored(map_id: String) -> bool:
    return ( _data().get("map_overrides", {}) as Dictionary).has(map_id)
