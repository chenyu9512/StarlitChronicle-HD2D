extends RefCounted
## Authored exploration events separate from the 120 canonical quests.
const SOURCE: String = "res://data/levels/v5/world_discoveries.json"
const LEVELS: String = "res://data/levels/world_levels_v3.json"
var maps: Dictionary = {}
var issues: Array[String] = []

func _init() -> void:
    var input: Variant = JSON.parse_string(FileAccess.get_file_as_string(SOURCE))
    if not input is Dictionary or str(input.get("schema",""))!="starlit.world_discoveries.v1":
        issues.append("Missing or invalid world discovery database")
        return
    maps = input.get("maps",{})
    if maps.size()!=40:
        issues.append("Expected 40 authored outdoor discovery maps")
    var all_maps: Variant = JSON.parse_string(FileAccess.get_file_as_string(LEVELS))
    if not all_maps is Dictionary:
        issues.append("Cannot validate discovery against geometry")
        return
    var levels: Dictionary = all_maps.get("levels",{})
    for map_id in maps.keys():
        if not levels.has(map_id):
            issues.append("Unknown discovery map "+str(map_id))
            continue
        var area: Dictionary = maps[map_id]
        var dimensions: Array = levels[map_id].get("size",[])
        var events: Array = area.get("events",[])
        if events.size()!=3 or area.get("size",[])!=dimensions:
            issues.append("Invalid discovery extent or event count: "+str(map_id))
        var preceding: Dictionary = {}
        for event in events:
            if not event is Dictionary:
                issues.append("Malformed discovery "+str(map_id))
                continue
            var event_id: String = str(event.get("id",""))
            var requirement: String = str(event.get("require",""))
            var cell: Array = event.get("cell",[])
            if preceding.has(event_id) or (not requirement.is_empty() and not preceding.has(requirement)):
                issues.append("Duplicate or invalid discovery order: "+str(map_id)+":"+event_id)
            preceding[event_id]=true
            if cell.size()!=2 or dimensions.size()!=2:
                issues.append("Missing discovery location: "+str(map_id)+":"+event_id)
                continue
            var x: int = int(cell[0])
            var y: int = int(cell[1])
            if x<3 or y<3 or x>=int(dimensions[0])-3 or y>=int(dimensions[1])-3:
                issues.append("Discovery beyond playable bounds: "+str(map_id)+":"+event_id)
            if str(event.get("text","")).length()<12:
                issues.append("Discovery lacks specific writing: "+str(map_id)+":"+event_id)

func entries(map_id: String) -> Array:
    var area: Dictionary = maps.get(map_id,{})
    return area.get("events",[])

func event(map_id: String,event_id: String) -> Dictionary:
    for record in entries(map_id):
        if str(record.get("id",""))==event_id:
            return record
    return {}

static func flag(map_id: String,event_id: String) -> String:
    return "discover.%s.%s" % [map_id,event_id]
