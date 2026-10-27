extends RefCounted
## C V8 central terrain atlas registry: source IDs stay 0 ground / 1 water.
## This module deliberately has no dependency on CArtOverrides or TilePool.
const REGISTRY_PATH: String = "res://data/assets/c_shared_terrain_v8.json"
const CORE_GROUND: String = "res://assets/art/tilesets/coast_ground.png"
const CORE_WATER: String = "res://assets/art/tilesets/coast_water.png"
static var _registry: Dictionary = {}
# The historical atlas slot can be removed on the third-party-only branch.
# This independent resolver intentionally has no dependency on CArtOverrides:
# CArtOverrides preloads this registry, so importing it here is a cycle.
const THIRD_PARTY_MIGRATION: String = "res://data/assets/c_third_party_only_migration_v1.json"
static var _slot_sources: Dictionary = {}
static var _slot_index_loaded: bool = false

static func _has_source(path: String) -> bool:
    if ResourceLoader.exists(path):
        return true
    if not path.begins_with("res://assets/art/") or path.contains(".."):
        return false
    if not _slot_index_loaded:
        _slot_index_loaded = true
        if FileAccess.file_exists(THIRD_PARTY_MIGRATION):
            var raw: Variant = JSON.parse_string(FileAccess.get_file_as_string(THIRD_PARTY_MIGRATION))
            if raw is Dictionary:
                for entry in raw.get("mappings", []):
                    if not entry is Dictionary:
                        continue
                    var old_slot: String = str(entry.get("old_path", ""))
                    var new_source: String = str(entry.get("new_source", ""))
                    if old_slot.begins_with("assets/art/") and not old_slot.contains("..") and new_source.begins_with("assets/art/external/cc0_named_v1/") and not new_source.contains(".."):
                        _slot_sources["res://" + old_slot] = "res://" + new_source
    var candidate: String = str(_slot_sources.get(path, ""))
    return not candidate.is_empty() and ResourceLoader.exists(candidate)

static func _data() -> Dictionary:
    if not _registry.is_empty():
        return _registry
    if not FileAccess.file_exists(REGISTRY_PATH):
        return {}
    var raw: Variant = JSON.parse_string(FileAccess.get_file_as_string(REGISTRY_PATH))
    if raw is Dictionary:
        _registry = raw
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
    return [land, water]

static func is_regional(region_id: String) -> bool:
    return ( _data().get("regions", {}) as Dictionary).has(region_id)

static func is_authored(map_id: String) -> bool:
    return ( _data().get("map_overrides", {}) as Dictionary).has(map_id)
