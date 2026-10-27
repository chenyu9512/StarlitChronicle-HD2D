extends RefCounted
## Central source-of-truth for Act I art. Returns canonical res:// paths only.
## This script owns no gameplay state, map geometry, collision or saved progress.
const PATH: String = "res://data/assets/c_act01_art_production_v10.json"
static var _cached: Dictionary = {}

static func data() -> Dictionary:
    if not _cached.is_empty():
        return _cached
    if not FileAccess.file_exists(PATH):
        return {}
    var raw: Variant = JSON.parse_string(FileAccess.get_file_as_string(PATH))
    if raw is Dictionary and str(raw.get("schema",""))=="starlit.c.act01_production_art.v10":
        _cached = raw
    return _cached

static func has_map(map_id: String) -> bool:
    return (data().get("maps",{}) as Dictionary).has(map_id)

static func map_bundle(map_id: String) -> Dictionary:
    return (data().get("maps",{}) as Dictionary).get(map_id,{}).duplicate(true)

static func chapter_bundle(chapter: int) -> Dictionary:
    if chapter<1 or chapter>6:
        return {}
    for record in data().get("chapters",[]):
        if record is Dictionary and int(record.get("chapter",0))==chapter:
            return record.duplicate(true)
    return {}

static func sprite_path(map_id: String,kind: String) -> String:
    if not has_map(map_id):
        return ""
    var path: String = str((data().get("sprites",{}) as Dictionary).get(kind,""))
    if not path.begins_with("res://assets/art/") or path.contains(".."):
        return ""
    return path

static func production_paths(map_id: String) -> Array[String]:
    var bundle: Dictionary=map_bundle(map_id)
    var paths: Array[String]=[]
    if bundle.is_empty():
        return paths
    var ground: Dictionary=bundle.get("terrain",{})
    for kind in ["ground","water","detail"]:
        var path: String=str(ground.get(kind,""))
        if not path.is_empty() and not paths.has(path):
            paths.append(path)
    for group in ["scenery_sources","facades","interior_tilesets","props","character_slots","coastal_monster_assets"]:
        for raw in bundle.get(group,[]):
            var path: String=str(raw)
            if not path.is_empty() and not paths.has(path):
                paths.append(path)
    return paths
