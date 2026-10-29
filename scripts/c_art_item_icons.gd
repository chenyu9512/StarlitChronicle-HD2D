extends RefCounted
## UI-only allocation of 288 item/weapon/armor/skill identities to 32px art.
## This is NOT a gameplay/content/save override; all art routes through CArtOverrides.
const ART = preload("res://scripts/c_art_overrides.gd")
const INDEX: String = "res://data/assets/c_art_content_icons_v6.json"
static var _loaded: bool = false
static var _paths: Dictionary = {}

static func _ensure_loaded() -> void:
    if _loaded:
        return
    _loaded = true
    if not FileAccess.file_exists(INDEX):
        push_warning("C art icon allocation file missing")
        return
    var raw: Variant = JSON.parse_string(FileAccess.get_file_as_string(INDEX))
    if not raw is Dictionary:
        push_warning("C art icon allocation JSON invalid")
        return
    for record in raw.get("records", []):
        if not record is Dictionary:
            continue
        var id: String = str(record.get("id", ""))
        var path: String = str(record.get("icon", ""))
        if not id.is_empty() and path.begins_with("res://assets/art/external/cc0_named_v1/icons/") and not path.contains(".."):
            _paths[id] = path

static func icon_path(content_id: String) -> String:
    _ensure_loaded()
    return str(_paths.get(content_id, ""))

static func texture_for(content_id: String) -> Texture2D:
    var path: String = icon_path(content_id)
    if path.is_empty():
        return null
    return ART.texture(path)

static func allocated_count() -> int:
    _ensure_loaded()
    return _paths.size()
