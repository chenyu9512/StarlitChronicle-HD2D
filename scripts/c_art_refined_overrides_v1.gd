extends RefCounted
## Stable, path-exact layer for regenerated visual-detail derivatives.
## Every override has the same physical dimensions and alpha grid as its
## retained source. It never changes world collisions, gameplay IDs or saves.
const MANIFEST: String = "res://assets/art/runtime/refined_overrides_v1/manifest.json"
const SCHEMA: String = "starlit.refined_overrides.v1"

static var _loaded: bool = false
static var _routes: Dictionary = {}
static var _textures: Dictionary = {}

static func _ensure() -> void:
    if _loaded:
        return
    _loaded = true
    if not FileAccess.file_exists(MANIFEST):
        return
    var raw: Variant = JSON.parse_string(FileAccess.get_file_as_string(MANIFEST))
    if not raw is Dictionary:
        return
    if str(raw.get("schema", "")) != SCHEMA or not bool(raw.get("enabled", false)):
        return
    var records: Variant = raw.get("routes", {})
    if records is Dictionary:
        _routes = records

static func texture(source: String) -> Texture2D:
    _ensure()
    if not source.begins_with("res://assets/art/") or source.contains(".."):
        return null
    if not _routes.has(source):
        return null
    var record: Variant = _routes[source]
    if not record is Dictionary:
        return null
    var target: String = str(record.get("output", ""))
    if not target.begins_with("res://assets/art/runtime/refined_overrides_v1/"):
        return null
    if target.contains("..") or not ResourceLoader.exists(target):
        return null
    if not _textures.has(target):
        _textures[target] = ResourceLoader.load(target) as Texture2D
    return _textures[target] as Texture2D

static func replacement_count() -> int:
    _ensure()
    return _routes.size()
