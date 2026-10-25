extends RefCounted
## Phase19-4: twelve canonical lost-page walkable interiors without replacing towns.
const SOURCE: String = "res://story/data/phase19_lost_page_submaps.json"
const LAYOUT_DIR: String = "res://data/levels/v4/interiors/"
var entries: Dictionary = {}
var errors: Array[String] = []

func _init() -> void:
    if not FileAccess.file_exists(SOURCE):
        errors.append("lost-page submap manifest missing")
        return
    var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(SOURCE))
    if not (parsed is Dictionary):
        errors.append("lost-page submap JSON invalid")
        return
    for row in parsed.get("quests",[]):
        if not (row is Dictionary):
            continue
        var q: Dictionary = row
        var quest_id: String = str(q.get("quest_id",""))
        var map_id: String = str(q.get("map_id",""))
        var interior_id: String = str(q.get("building_id",""))
        if quest_id.is_empty() or entries.has(quest_id) or interior_id != "quest__"+quest_id:
            errors.append("invalid quest room " + quest_id)
            continue
        if not FileAccess.file_exists(LAYOUT_DIR+"%s__%s.json" % [map_id,interior_id]):
            errors.append("missing authored room geometry " + quest_id)
            continue
        entries[quest_id] = q
    if entries.size()!=12:
        errors.append("expected exactly twelve playable quest submaps")

func detail(quest_id: String) -> Dictionary:
    return entries.get(quest_id,{})

func matches(quest_id: String,map_id: String,chapter: int) -> bool:
    var data: Dictionary = detail(quest_id)
    if data.is_empty() or str(data.get("map_id",""))!=map_id:
        return false
    return chapter >= int(str(data.get("open_chapter","ch999")).trim_prefix("ch"))

func local(map_id: String,chapter: int) -> Array:
    var results: Array = []
    for quest_id in entries:
        if matches(str(quest_id),map_id,chapter):
            results.append(entries[quest_id])
    return results

func room_name(quest_id: String) -> String:
    return str(detail(quest_id).get("interior_name","调查室"))
