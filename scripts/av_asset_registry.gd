extends RefCounted
const ArtAssets = preload("res://scripts/art_assets.gd")
## C-line ID-based AV lookup; refuses unreviewed external media and never downloads files.
const REGISTRY_PATH: String = "res://data/assets/av_registry.json"
static var _cache: Dictionary = {}
static var _initialized: bool = false

static func _read() -> Dictionary:
    if _initialized:
        return _cache
    _initialized = true
    if not FileAccess.file_exists(REGISTRY_PATH):
        push_warning("AV registry missing; fallback routes stay active")
        return {}
    var value: Variant = JSON.parse_string(FileAccess.get_file_as_string(REGISTRY_PATH))
    if value is Dictionary:
        _cache = value
    return _cache

static func audio_record(asset_id: String) -> Dictionary:
    var data: Dictionary = _read()
    for entry in data.get("audio_events", []):
        if entry is Dictionary and str(entry.get("id", "")) == asset_id:
            return entry.duplicate(true)
    return {}

static func audio_stream(asset_id: String) -> AudioStream:
    var entry: Dictionary = audio_record(asset_id)
    if entry.is_empty():
        return null
    # Never load planned, unlicensed or unverifiable third-party audio.
    if str(entry.get("license_status", "")) != "commercial_verified":
        return null
    if str(entry.get("status", "")) not in ["imported", "runtime_bound", "qa_passed"]:
        return null
    var path: String = str(entry.get("asset_path", ""))
    if not path.begins_with("res://assets/audio/") or path.contains(".."):
        return null
    if not ResourceLoader.exists(path):
        return null
    return load(path) as AudioStream

static func boss_static_art(boss_id: String) -> String:
    for entry in _read().get("bosses", []):
        if entry is Dictionary and boss_id in [str(entry.get("id", "")), str(entry.get("runtime_id", ""))]:
            var path: String = str(entry.get("static_battle_path", ""))
            if not path.is_empty() and ResourceLoader.exists(path):
                return path
    # Art migration removed legacy B03 originals. Read the same physically
    # loadable V14 chapter portrait as the real combat interface. This is a
    # runtime fallback, not an assertion of final illustration quality.
    return ArtAssets.boss_image(boss_id)

static func bridge_audio_id(event_id: String) -> String:
    var bridge: Dictionary = _read().get("event_bridge", {})
    for entry in bridge.get("mappings", []):
        if entry is Dictionary and str(entry.get("event", "")) == event_id:
            var cue_id: String = str(entry.get("audio_id", ""))
            return "" if cue_id.contains(".by_") else cue_id
    return ""
