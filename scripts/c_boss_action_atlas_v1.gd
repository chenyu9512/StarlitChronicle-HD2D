extends RefCounted
## Action-sheet decoder shared by all 66 canonical bosses.
## 128px frames, four animation frames per six visual states.
## No battle state, damage, phase trigger or save game is modified here.
const INDEX: String = "res://assets/art/runtime/boss_motion_v1/manifest.json"
const STATES: Array[String] = ["idle", "attack", "hit", "status", "down", "phase_change"]
static var _loaded: bool = false
static var _index: Dictionary = {}

static func _data() -> Dictionary:
    if not _loaded:
        _loaded = true
        if FileAccess.file_exists(INDEX):
            var raw: Variant = JSON.parse_string(FileAccess.get_file_as_string(INDEX))
            if raw is Dictionary and str(raw.get("schema","")) == "starlit.boss_motion.runtime.v1":
                _index = raw.get("assets", {})
    return _index

static func sheet_id(runtime_id: String) -> String:
    var key: String = runtime_id
    if key.begins_with("boss.ch"):
        key = "boss_ch" + key.trim_prefix("boss.ch")
    return key if _data().has(key) else ""

static func texture(runtime_id: String) -> Texture2D:
    var key: String = sheet_id(runtime_id)
    if key.is_empty():
        return null
    var record: Dictionary = _data()[key]
    var path: String = str(record.get("source",""))
    if not path.begins_with("res://assets/art/runtime/boss_motion_v1/") or not ResourceLoader.exists(path):
        return null
    var texture: Texture2D = ResourceLoader.load(path) as Texture2D
    if texture == null or texture.get_size() != Vector2(512,768):
        return null
    return texture

static func region(state: String, frame: int) -> Rect2:
    var row: int = STATES.find(state)
    if row < 0:
        row = 0
    return Rect2(clampi(frame,0,3)*128,row*128,128,128)

static func count() -> int:
    return _data().size()
