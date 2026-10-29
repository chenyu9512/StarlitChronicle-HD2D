extends RefCounted
## Read-only battle/map art adapter; never changes quest state or enemy stats.
const PATH: String = "res://data/assets/librarium_assignments_v1.json"
const Overrides = preload("res://scripts/c_art_overrides.gd")
static var _cache: Dictionary = {}
static var _loaded: bool = false

static func _initialize() -> void:
    if _loaded:
        return
    _loaded = true
    if not FileAccess.file_exists(PATH):
        return
    var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(PATH))
    if not data is Dictionary:
        return
    for record in data.get("assignments", []):
        if record is Dictionary:
            _cache[str(record.get("id", ""))] = record
    for name in (data.get("aliases", {}) as Dictionary).keys():
        var alias_id: String = str(data["aliases"][name])
        if _cache.has(alias_id):
            _cache[str(name)] = _cache[alias_id]

static func assignment(content_id: String) -> Dictionary:
    _initialize()
    return _cache.get(content_id, {})

static func motion(content_id: String) -> Dictionary:
    var info: Dictionary = assignment(content_id)
    var path: String = str(info.get("primary_mv", ""))
    if not bool(info.get("live", false)) or path.is_empty() or not ResourceLoader.exists(path):
        return {}
    var picture: Texture2D = Overrides.texture(path)
    if picture == null:
        return {}
    var w: int = picture.get_width()
    var h: int = picture.get_height()
    if w < 90 or h < 60 or w % 9 != 0 or h % 6 != 0:
        return {}
    return {"texture":picture, "cell":Vector2i(w / 9, h / 6)}

static func preview(content_id: String) -> AtlasTexture:
    var spec: Dictionary = motion(content_id)
    if spec.is_empty():
        return null
    var cell: Vector2i = spec["cell"]
    var cropped := AtlasTexture.new()
    cropped.atlas = spec["texture"]
    cropped.region = Rect2(cell.x * 3, 0, cell.x, cell.y)
    return cropped

## Only for map encounter markers; no automatic spawning or collision.
static func map_preview(content_id: String) -> Texture2D:
    var info: Dictionary = assignment(content_id)
    for candidate in info.get("map_candidates", []):
        var path: String = str(candidate)
        if not ResourceLoader.exists(path):
            continue
        var source: Texture2D = Overrides.texture(path)
        if source == null or source.get_width() % 3 != 0 or source.get_height() % 4 != 0:
            continue
        var w: int = source.get_width() / 3
        var h: int = source.get_height() / 4
        var region := AtlasTexture.new()
        region.atlas = source
        region.region = Rect2(w, 0, w, h)
        return region
    return null
