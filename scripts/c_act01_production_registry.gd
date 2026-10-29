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

## The authored V10 inventory is retained for migration/audit. It includes
## retired SVGs and must NEVER be presented as physically installed run art.
static func legacy_production_paths(map_id: String) -> Array[String]:
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

## Canonical runtime files for a live First Act map. The official art
## registry is authoritative; do not invent a replacement for each old SVG.
## Every returned path is checked as a real Texture2D in Godot CI.
const LIVE_INDEX: String = "res://data/assets/c_art_runtime_registry_v1.json"
static var _live_index: Dictionary = {}

static func _live() -> Dictionary:
    if not _live_index.is_empty():
        return _live_index
    if not FileAccess.file_exists(LIVE_INDEX):
        return {}
    var raw: Variant = JSON.parse_string(FileAccess.get_file_as_string(LIVE_INDEX))
    if raw is Dictionary and str(raw.get("schema","")) == "starlit.c.art_runtime_registry.v1":
        _live_index = raw
    return _live_index

static func runtime_source(group: String, id: String) -> String:
    var meta: Dictionary = (_live().get("generated_assets",{}) as Dictionary).get(group+"."+id,{})
    var path: String = str(meta.get("source",""))
    if not path.begins_with("res://assets/art/runtime/") or path.contains(".."):
        return ""
    return path

static func production_paths(map_id: String) -> Array[String]:
    var result: Array[String] = []
    if not has_map(map_id) or not map_id.begins_with("map_coast_"):
        return result
    var official: Dictionary = _live().get("generated_assets",{})
    var needed: Array[String] = [
        "maps."+map_id, "terrain.region_coast_ground",
        "terrain.region_coast_water", "ui.region_coast_frame"
    ]
    for key in official.keys():
        var slot: String = str(key)
        if slot.begins_with("interiors."+map_id+"__") or \
            slot.begins_with("props.region_coast_") or \
            slot.begins_with("characters.char_") or \
            slot.begins_with("npcs.npc_coast_") or \
            slot.begins_with("monsters.mon_coast_") or \
            slot.begins_with("bosses.boss_ch00"):
            needed.append(slot)
    for key in needed:
        var entry: Dictionary = official.get(key,{})
        var path: String = str(entry.get("source",""))
        if path.begins_with("res://assets/art/runtime/") and not path.contains("..") and not result.has(path):
            result.append(path)
    var details: Dictionary = _live().get("scene_detail_sources",{})
    for key in details.keys():
        var detail: String = str(details[key])
        if detail.begins_with("res://assets/art/runtime/") and not result.has(detail):
            result.append(detail)
    return result
