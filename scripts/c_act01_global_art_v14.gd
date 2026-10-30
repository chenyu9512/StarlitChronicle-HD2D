extends RefCounted
const RuntimeArt = preload("res://scripts/c_art_runtime.gd")
## Main2 first-act curated third-party images. Gameplay geometry/state is untouched.
const REGISTRY: String = "res://data/assets/c_act01_global_distribution_v14.json"
const Overrides = preload("res://scripts/c_art_overrides.gd")
const ThemeV2 = preload("res://scripts/c_art_theme_v2.gd")
static var _registry: Dictionary = {}

static func data() -> Dictionary:
    if not _registry.is_empty():
        return _registry
    if not FileAccess.file_exists(REGISTRY):
        return {}
    var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(REGISTRY))
    if parsed is Dictionary and str(parsed.get("schema", "")) == "starlit.c.act01_global_distribution.v14":
        _registry = parsed
    return _registry

static func source_for(category: String, id: String) -> String:
    var manifest: Dictionary = data().get("runtime", {})
    var table: Dictionary = manifest.get(category, {})
    return str(table.get(id, ""))

static func texture_for_prop(kind: String) -> Texture2D:
    return _texture(source_for("props",kind))

static func texture_for_scenery(kind: String, map_id: String) -> Texture2D:
    var maps: Dictionary = data().get("maps", {})
    if not maps.has(map_id):
        return null
    return _texture(source_for("scenery",kind))

static func battle_path(enemy_id: String) -> String:
    var path: String = source_for("monsters",enemy_id)
    return path if not path.is_empty() and Overrides.exists(path) else ""

static func boss_candidate(boss_id: String) -> String:
    return source_for("boss_candidates",boss_id)

static func surface_candidate(map_id: String, kind: String) -> Texture2D:
    var spec: Dictionary = (data().get("runtime",{}).get("terrain",{}) as Dictionary).get(map_id,{})
    return _texture(str(spec.get(kind,"")))

static func _texture(path: String) -> Texture2D:
    # The V14 distribution registry now points to identity-preserving V10
    # generated PNGs; the old imported V14 directory was intentionally removed.
    # Only exact canonical generated-runtime paths may be displayed.
    if path.is_empty() or not path.begins_with("res://assets/art/runtime/generated_gaps_v10/"):
        return null
    var themed: Texture2D = ThemeV2.texture_for_path(path)
    return themed if themed != null else RuntimeArt.texture_path(path)
