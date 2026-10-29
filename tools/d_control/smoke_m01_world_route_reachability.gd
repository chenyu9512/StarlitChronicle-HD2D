extends SceneTree
## M0.1 non-destructive production-map route diagnostics.
## Checks the actual 40 generated collision maps after the final roof seal;
## never edits walls, skips blocked gates or teleports story waypoints.
const Geography = preload("res://scripts/world_geography.gd")
var failures: Array[String] = []

func _initialize() -> void:
    call_deferred("_run")

func _walkable(layout: Dictionary) -> Dictionary:
    var blocked: Dictionary = layout.get("blocked",{})
    var size: Vector2i = layout.get("size",Vector2i(72,48))
    var spawn: Vector2i = layout.get("spawn",Vector2i(-1,-1))
    var reached: Dictionary = {}
    if blocked.has(spawn) or spawn.x<2 or spawn.y<2 or spawn.x>=size.x-2 or spawn.y>=size.y-2:
        return reached
    reached[spawn] = true
    var queue: Array[Vector2i] = [spawn]
    var index: int = 0
    while index<queue.size():
        var cell: Vector2i = queue[index]
        index+=1
        for delta in [Vector2i.UP,Vector2i.DOWN,Vector2i.LEFT,Vector2i.RIGHT]:
            var next: Vector2i = cell+delta
            if next.x<2 or next.y<2 or next.x>=size.x-2 or next.y>=size.y-2:
                continue
            if reached.has(next) or blocked.has(next):
                continue
            reached[next] = true
            queue.append(next)
    return reached

func _nearby_walkable(point: Vector2i,reached: Dictionary) -> bool:
    # The live world relocates blocked old-era interaction markers to an
    # accessible pavement tile within a 12-tile Manhattan distance.
    for radius in range(13):
        for y in range(-radius,radius+1):
            for x in range(-radius,radius+1):
                if absi(x)+absi(y)!=radius:
                    continue
                if reached.has(point+Vector2i(x,y)):
                    return true
    return false

func _run() -> void:
    var geo = Geography.new()
    var maps: int = 0
    var buildings: int = 0
    var blocked_legacy: int = 0
    var diagnostics: Array[Dictionary] = []
    if not geo.faults.is_empty():
        failures.append("Geography catalogue invalid: "+str(geo.faults))
    for raw_id in geo.zones.keys():
        var id: String = str(raw_id)
        var zone: Dictionary = geo.zone(id)
        if not bool(zone.get("playable",false)):
            continue
        maps+=1
        var layout: Dictionary = geo.layout(id,3)
        var walked: Dictionary = _walkable(layout)
        var trouble: Array[String] = []
        var relocated: int = 0
        if walked.is_empty():
            trouble.append("blocked or invalid player spawn")
        for gate in layout.get("gates",[]):
            var exit_cell: Vector2i = gate.get("cell",Vector2i(-1,-1))
            if not walked.has(exit_cell):
                trouble.append("unreachable exit to "+str(gate.get("id","unknown")))
        for building in zone.get("buildings",[]):
            buildings+=1
            var d: Array = building.get("door",[])
            if d.size()!=2:
                trouble.append("missing canonical building door "+str(building.get("id","")))
                continue
            var stand: Vector2i = Vector2i(int(d[0]),int(d[1])+1)
            if not walked.has(stand):
                trouble.append("unreachable front step "+str(building.get("id","")))
        for anchor in geo._anchors():
            if walked.has(anchor):
                continue
            blocked_legacy+=1
            if not _nearby_walkable(anchor,walked):
                trouble.append("quest marker has no real reachable alternative within 12 tiles "+str(anchor))
            else:
                relocated+=1
        if not trouble.is_empty() or relocated>0:
            diagnostics.append({"map":id,"relocated_legacy_markers":relocated,"issues":trouble})
        for item in trouble:
            failures.append(id+": "+item)
    print("M0.1 MAP ROUTE DIAGNOSTICS ",JSON.stringify(diagnostics))
    print("MAPS ",maps," BUILDINGS ",buildings," LEGACY_ANCHORS_REQUIRING_RELOCATION ",blocked_legacy)
    if maps!=40 or buildings!=68:
        failures.append("Canonical 40-map/68-door coverage changed")
    if failures.is_empty():
        print("PASS: final production collision reaches all authored exits, building steps and recoverable story markers")
        quit(0)
        return
    for item in failures:
        push_error(item)
    quit(1)
