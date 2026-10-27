extends SceneTree
## B-line roof routing regression. Uses actual V3 geography plus a synthetic
## blocked street: the pathfinding dictionary MUST use Vector2i keys.
## Does not write player saves or grant any story progress.
const Geography = preload("res://scripts/world_geography.gd")
var errors: Array[String] = []

func _initialize() -> void:
    call_deferred("_run")

func _expect(ok: bool, reason: String) -> void:
    if not ok:
        errors.append(reason)

func _run() -> void:
    var geo = Geography.new()
    _expect(geo.faults.is_empty(),"Atlas failed to parse")
    var start: Vector2i = Vector2i(5,8)
    var goal: Vector2i = Vector2i(16,8)
    var roof: Dictionary = {}
    var blocked: Dictionary = {}
    for x in range(8,15):
        roof[Vector2i(x,8)] = true
    for x in range(6,16):
        blocked[Vector2i(x,7)] = true
    var path: Array[Vector2i] = geo._path_around_roofs(start,goal,roof,blocked)
    _expect(not path.is_empty(),"Roof-safe route returned an empty path")
    if not path.is_empty():
        _expect(path[0]==start and path[-1]==goal,"Route endpoints corrupted")
        for i in range(path.size()):
            var p: Vector2i = path[i]
            _expect(not roof.has(p),"Route tunnels through a house roof at "+str(p))
            if i>0:
                _expect((p-path[i-1]).length_squared()==1,
                    "Non-adjacent roof route step at "+str(p))
    _expect(geo._path_around_roofs(start,Vector2i(9,8),roof,blocked).is_empty(),
        "Route should reject a door target inside a solid roof")

    var towns: int = 0
    var entrances: int = 0
    for raw_map in geo.zones.keys():
        var mid: String = str(raw_map)
        var zone: Dictionary = geo.zone(mid)
        if not bool(zone.get("settlement",false)):
            continue
        towns += 1
        var layout: Dictionary = geo.layout(mid,1)
        var size: Vector2i = layout.get("size",Vector2i(72,48))
        var spawn: Vector2i = layout.get("spawn",Vector2i(10,23))
        var walls: Dictionary = layout.get("blocked",{})
        var features: Array = layout.get("features",[])
        for raw in zone.get("buildings",[]):
            var building: Dictionary=raw
            var id: String=str(building.get("id",""))
            var raw_door: Array=building.get("door",[])
            if raw_door.size()!=2:
                _expect(false,mid+" has no door for "+id)
                continue
            var threshold: Vector2i=Vector2i(int(raw_door[0]),int(raw_door[1]))+Vector2i.DOWN
            var entrance: bool=not walls.has(threshold)
            var reachable: bool=geo.reachable({"blocked":walls,"size":size},[spawn],[threshold])
            _expect(entrance and reachable,mid+"/"+id+" has unreachable front step")
            var marker: bool=false
            for feature in features:
                if str(feature.get("building",""))==id and feature.get("door",Vector2i(-1,-1))==threshold-Vector2i.DOWN:
                    marker=true
            _expect(marker,mid+"/"+id+" missing canonical feature/door link")
            entrances+=1
    _expect(towns==11 and entrances==68,"Lost one of 11 settlements or 68 physical doors")
    if errors.is_empty():
        print("PASS B roof-safe routing: valid Vector2i BFS, no roof tunneling, 68 reachable building thresholds")
        quit(0)
        return
    for reason in errors:
        push_error(reason)
    quit(1)
