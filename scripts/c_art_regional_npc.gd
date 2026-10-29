extends RefCounted
const RuntimeArt = preload("res://scripts/c_art_runtime.gd")
## Game NPCs only: use original directional strips from the allocated 48px Foozle
## characters. Never remap arbitrary story characters by index or class.
const Art = preload("res://scripts/c_art_overrides.gd")
const V12: String = "res://data/assets/c_art_usage_external_v12.json"
const FRAME: int = 48
const CAST: Dictionary = {
    "npc_oaths_01": "foozle_warrior", # 白垒队长, armored guard
    "npc_oaths_04": "foozle_warrior", # 银鹫骑手, armored knight
    "npc_mirror_03": "foozle_sorceress", # 梦疫医师, caster
    "npc_mirror_05": "foozle_necromancer", # 王库看守, occult archive keeper
}
static var _indexed: bool = false
static var _paths: Dictionary = {}
static var _texture_cache: Dictionary = {}

static func _index() -> void:
    if _indexed:
        return
    _indexed = true
    var source: Variant = JSON.parse_string(FileAccess.get_file_as_string(V12))
    if not source is Dictionary:
        return
    for raw in source.get("rows", []):
        if not raw is Dictionary or str(raw.get("category", "")) != "characters":
            continue
        var family: String = str(raw.get("family", ""))
        var direction: String = str(raw.get("orientation", ""))
        var action: String = str(raw.get("clip", ""))
        var path: String = str(raw.get("source", ""))
        if family not in ["foozle_warrior","foozle_sorceress","foozle_necromancer"]:
            continue
        if direction not in ["down","left","up","right"] or action not in ["idle","walk","run"]:
            continue
        if not path.begins_with("res://assets/art/external/cc0_named_v1/characters/") or path.contains(".."):
            continue
        _paths[family + ":" + direction + ":" + action] = path

static func has_costume(npc_id: String) -> bool:
    return CAST.has(npc_id)

static func costume(npc_id: String) -> Dictionary:
    if not CAST.has(npc_id):
        return {}
    _index()
    var family: String = str(CAST[npc_id])
    var prepared: Dictionary = {}
    for direction in ["down","left","up","right"]:
        var idle: Dictionary = _clip(family, direction, "idle")
        var walk: Dictionary = _clip(family, direction, "walk")
        if walk.is_empty():
            walk = _clip(family, direction, "run")
        if idle.is_empty() or walk.is_empty():
            return {}
        prepared[direction] = {"idle": idle, "walk": walk}
    return prepared

static func _clip(family: String, direction: String, action: String) -> Dictionary:
    var path: String = str(_paths.get(family + ":" + direction + ":" + action, ""))
    if path.is_empty():
        return {}
    if not _texture_cache.has(path):
        var t: Texture2D = RuntimeArt.texture_path(path)
        if t == null or int(t.get_height()) != FRAME or int(t.get_width()) % FRAME != 0:
            return {}
        _texture_cache[path] = t
    var texture: Texture2D = _texture_cache[path]
    var count: int = int(texture.get_width() / FRAME)
    return {"texture":texture,"count":count,"source":path}
