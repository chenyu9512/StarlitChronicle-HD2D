extends RefCounted
## A-line: authoritative runtime-facing semantic art gateway for B/D lines.
## The inventory/slot/region data lives ONLY in c_art_runtime_registry_v1.json.
## No guessed character or boss identity is selected automatically.
const INDEX: String = "res://data/assets/c_art_runtime_registry_v1.json"
const Art = preload("res://scripts/c_art_overrides.gd")
const RuntimeArtTheme = preload("res://scripts/c_art_theme_v2.gd")
const Terrain = preload("res://scripts/world_terrain_atlas_registry.gd")
static var _index: Dictionary = {}
static var _loaded: bool = false

static func _data() -> Dictionary:
    if not _loaded:
        _loaded = true
        var raw: Variant = JSON.parse_string(FileAccess.get_file_as_string(INDEX))
        if raw is Dictionary and str(raw.get("schema", "")) == "starlit.c.art_runtime_registry.v1":
            _index = raw
    return _index

static func texture_path(path: String) -> Texture2D:
    if not path.begins_with("res://assets/") or path.contains(".."):
        return null
    return Art.texture(path)

static func slot_source(slot_id: String) -> String:
    var entry: Dictionary = (_data().get("canonical_slots", {}) as Dictionary).get(slot_id, {})
    return str(entry.get("source", ""))

static func texture_slot(slot_id: String) -> Texture2D:
    if slot_source(slot_id).is_empty():
        return null
    return RuntimeArtTheme.texture(slot_id)

static func region_profile(region_id: String) -> Dictionary:
    return (_data().get("regions", {}) as Dictionary).get(region_id, {}).duplicate(true)

static func region_source(region_id: String, category: String, id: String) -> String:
    var profile: Dictionary = region_profile(region_id)
    if profile.is_empty():
        return ""
    var group: Dictionary = profile.get(category, {})
    if category not in ["scene_props", "material_preview", "npc_identity_bindings", "boss_identity_bindings", "building_bindings"]:
        return ""
    return str(group.get(id, ""))

static func texture_region(region_id: String, category: String, id: String) -> Texture2D:
    var p: String = region_source(region_id, category, id)
    return texture_path(p) if not p.is_empty() else null

static func ui_texture(icon_id: String) -> Texture2D:
    var p: String = str((_data().get("ui", {}) as Dictionary).get(icon_id, ""))
    return texture_path(p) if not p.is_empty() else null

static func atlas_paths(region_id: String, map_id: String, authored: String = "", outdoors: bool = true) -> Array[String]:
    return Terrain.atlas_sources(region_id, map_id, authored, outdoors)

static func audit_source(path: String) -> Dictionary:
    return (_data().get("sources", {}) as Dictionary).get(path, {}).duplicate(true)

static func needs_visual_signoff(path: String) -> bool:
    var row: Dictionary = audit_source(path)
    return row.is_empty() or str(row.get("visual_correct", "")) != "成功"

## All content-ID artwork must originate in the same canonical runtime index.
static func content_icon_source(content_id: String) -> String:
    return str((_data().get("content_icons", {}) as Dictionary).get(content_id, ""))

static func content_icon_texture(content_id: String) -> Texture2D:
    var p: String = content_icon_source(content_id)
    return texture_path(p) if not p.is_empty() else null

static func content_icon_count() -> int:
    return (_data().get("content_icons", {}) as Dictionary).size()

static func monster_source(monster_id: String) -> String:
    var p: String = str((_data().get("monster_id_sources", {}) as Dictionary).get(monster_id, ""))
    return p if not p.is_empty() and texture_path(p) != null else ""
