extends RefCounted
## Physically rehomes EXISTING main-story markers to the correct City chapters.
## No quest completion, no teleport, no artificial NPC or collision footprints.
const SOURCE: String = "res://data/levels/act10_city_stations_v1.json"
const TILE: int = 32
var chapters: Dictionary = {}

func _init() -> void:
    if not FileAccess.file_exists(SOURCE):
        push_warning("Act X map-specific stations missing")
        return
    var raw: Variant = JSON.parse_string(FileAccess.get_file_as_string(SOURCE))
    if raw is Dictionary:
        chapters = raw.get("chapters",{})

func arrange(chapter: int, map_id: String, geometry: Dictionary,
        reachable: Dictionary, nodes: Dictionary) -> Dictionary:
    var id: String = "ch%03d" % chapter
    var rule: Dictionary = chapters.get(id,{})
    if str(rule.get("map_id","")) != map_id or rule.is_empty():
        return {}
    var positions: Dictionary = rule.get("stations",{})
    var blocked: Dictionary = geometry.get("blocked",{})
    var water: Dictionary = geometry.get("water_mask",{})
    var extent: Vector2i = geometry.get("size",Vector2i(72,48))
    var reserved: Dictionary = {}
    reserved[geometry.get("spawn",Vector2i(10,23))] = true
    # Keep real doors, resident workplaces, travel gates and side-quest
    # interactions unobscured. The five existing story markers may move.
    for marker_key in nodes.keys():
        if positions.has(str(marker_key)):
            continue
        var node: Variant = nodes[marker_key]
        if node is Node2D and is_instance_valid(node):
            var cell: Vector2i = Vector2i(
                floori((node as Node2D).position.x/float(TILE)),
                floori((node as Node2D).position.y/float(TILE)))
            reserved[cell] = true
    for feature in geometry.get("features",[]):
        if not (feature is Dictionary):
            continue
        reserved[(feature as Dictionary).get("cell",Vector2i(-1,-1))] = true
        if (feature as Dictionary).has("door"):
            var doorway: Vector2i = (feature as Dictionary).get("door",Vector2i(-1,-1))
            reserved[doorway] = true
            reserved[doorway+Vector2i.DOWN] = true
    for gate in geometry.get("gates",[]):
        if gate is Dictionary:
            reserved[(gate as Dictionary).get("cell",Vector2i(-1,-1))] = true
    var assigned: Dictionary = {}
    for marker_id in ["key_npc","clue","witness","crisis","resolve"]:
        if not nodes.has(marker_id) or not positions.has(marker_id):
            continue
        var marker: Variant = nodes[marker_id]
        if not (marker is Node2D) or not is_instance_valid(marker):
            continue
        var record: Dictionary = positions[marker_id]
        var coordinates: Array = record.get("cell",[])
        if coordinates.size()!=2:
            continue
        var wanted: Vector2i = Vector2i(int(coordinates[0]),int(coordinates[1]))
        var chosen: Vector2i = _walkable_neighbor(wanted,extent,reachable,blocked,water,reserved)
        if chosen.x<0:
            push_warning("City chapter station unreachable: "+id+"/"+marker_id)
            # Fail closed: a fictional floating marker must never be placed on
            # a roof, lake or disconnected island. Original marker is retained.
            continue
        (marker as Node2D).position = Vector2(chosen*TILE)+Vector2(16,16)
        (marker as Node2D).set_meta("site_name",str(record.get("title",marker_id)))
        (marker as Node2D).set_meta("act10_authored_station",id+"/"+marker_id)
        reserved[chosen] = true
        assigned[marker_id] = chosen
    return assigned

func _walkable_neighbor(wanted: Vector2i,extent: Vector2i,
        reachable: Dictionary, blocked: Dictionary, water: Dictionary,
        reserved: Dictionary) -> Vector2i:
    for radius in range(0,19):
        for dy in range(-radius,radius+1):
            for dx in range(-radius,radius+1):
                if absi(dx)+absi(dy)!=radius:
                    continue
                var at: Vector2i=wanted+Vector2i(dx,dy)
                if at.x<3 or at.y<3 or at.x>=extent.x-3 or at.y>=extent.y-3:
                    continue
                if not reachable.has(at) or blocked.has(at) or water.has(at) or reserved.has(at):
                    continue
                # Another citizen or gate stands here? Do not move the marker
                # into an adjacent doorway just because the tile is walkable.
                var conflict: bool = false
                for direction in [Vector2i.LEFT,Vector2i.RIGHT,Vector2i.UP,Vector2i.DOWN]:
                    if reserved.has(at+direction):
                        conflict=true
                        break
                if not conflict:
                    return at
    return Vector2i(-1,-1)
