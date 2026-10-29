extends RefCounted
## Canonical runtime images produced by Global Art Factory V3.
## No legacy PNG or ad-hoc third-party atlas is needed for these covered roles.
const ROOT: String = "res://assets/art/runtime/global_factory_v3/"
const SWITCH: String = ROOT + "active.json"
const INDEX: String = "res://data/assets/c_art_runtime_registry_v1.json"
static var _sources_loaded: bool = false
static var _official_sources: Dictionary = {}

static func _sources() -> Dictionary:
    if not _sources_loaded:
        _sources_loaded = true
        var raw: Variant = JSON.parse_string(FileAccess.get_file_as_string(INDEX))
        if raw is Dictionary and str(raw.get("schema", "")) == "starlit.c.art_runtime_registry.v1":
            _official_sources = raw.get("generated_assets", {})
    return _official_sources
const REGION_IDS: Array[String] = [
    "region_coast", "region_oaths", "region_forge", "region_isles",
    "region_mirror", "region_oldland", "region_sanctum", "region_city"
]
const LEGACY_CAST: Dictionary = {
    "leon": "char_wayfarer",
    "lanyin": "char_tidecaller",
    "shuoxian": "char_seeker",
    "chengzhou": "char_vanguard",
}
const PROP_ROLES: Array[String] = [
    "tree", "cottage", "shop", "shrine", "well", "lantern", "crate", "banner"
]
static var _checked: bool = false
static var _enabled: bool = false
static var _cache: Dictionary = {}

static func active() -> bool:
    if not _checked:
        _checked = true
        if FileAccess.file_exists(SWITCH):
            var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(SWITCH))
            if data is Dictionary:
                _enabled = str(data.get("schema", "")) == "starlit.global_factory.live.v3" and bool(data.get("enabled", false))
    return _enabled

static func path(group: String, asset_id: String) -> String:
    if not active() or not group in ["terrain", "maps", "interiors", "props", "characters", "npcs", "monsters", "bosses", "ui"]:
        return ""
    if asset_id.is_empty() or asset_id.contains("/") or asset_id.contains(".") or asset_id.contains("\\"):
        return ""
    var source: Dictionary = _sources().get(group + "." + asset_id, {})
    var p: String = str(source.get("source", ""))
    return p if p == ROOT + group + "/" + asset_id + ".png" and ResourceLoader.exists(p) else ""

static func texture(group: String, asset_id: String) -> Texture2D:
    var p: String = path(group, asset_id)
    if p.is_empty():
        return null
    if not _cache.has(p):
        _cache[p] = ResourceLoader.load(p) as Texture2D
    return _cache[p] as Texture2D

static func terrain_paths(region_id: String) -> Array[String]:
    var result: Array[String] = []
    if not active() or not region_id in REGION_IDS:
        return result
    for kind in ["ground", "water"]:
        var p: String = path("terrain", region_id + "_" + kind)
        if p.is_empty():
            return []
        result.append(p)
    return result

static func interior_path(map_id: String, building_id: String) -> String:
    return path("interiors", map_id + "__" + building_id)

static func boss_path(runtime_id: String) -> String:
    var key: String = runtime_id
    if runtime_id.begins_with("boss.ch"):
        key = "boss_ch" + runtime_id.trim_prefix("boss.ch")
    return path("bosses", key)

static func legacy_texture(original: String) -> Texture2D:
    if not active() or not original.begins_with("res://assets/art/"):
        return null
    var file: String = original.get_file().to_lower()
    # Old party movement atlas paths retain the exact 96x192, 3x4 framing.
    # Exact legacy roles are deliberately redirected to current identity art.
    # Never broadly redirect unrelated archive images by substring.
    match original:
        "res://assets/art/backdrops/coast/tide_lighthouse.png":
            return texture("maps", "map_coast_05")
        "res://assets/art/props/coast/star_lantern.png", "res://assets/props/lamp.png":
            return texture("props", "region_coast_lantern")
    if original.ends_with("/walk_4dir_3frames.png"):
        var cast_id: String = str(LEGACY_CAST.get(original.get_base_dir().get_file(), ""))
        return texture("characters", cast_id) if not cast_id.is_empty() else null
    var rid: String = ""
    if original.begins_with("res://assets/art/runtime/act01_global_v14/props/") or original.begins_with("res://assets/art/props/coast/"):
        rid = "region_coast"
    for candidate in REGION_IDS:
        if original.contains(candidate) or original.contains("/" + candidate.trim_prefix("region_") + "/"):
            rid = candidate
            break
    if rid.is_empty():
        return null
    for role in PROP_ROLES:
        # Match a role only as its actual noun, not by broad substring such
        # as "house" matching "shrine" or "crab" matching "crate".
        if file == role + ".png" or file == role + ".svg" or file == "prop_" + role + ".png" or file.begins_with(role + "_"):
            return texture("props", rid + "_" + role)
    return null
