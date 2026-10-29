extends RefCounted
## Phase19-2: 120 canonical quests linked to existing sectors and authored building doors.
## Coordinates are intentionally repaired against ACTUAL runtime collision; never carve terrain.
const SOURCE: String = "res://story/data/phase19_quest_world_anchors.json"
var locations: Dictionary = {}
var errors: Array[String] = []

func _init() -> void:
    var file: Variant = JSON.parse_string(FileAccess.get_file_as_string(SOURCE))
    if not (file is Dictionary):
        errors.append("invalid phase19 quest site manifest")
        return
    for row in file.get("quests",[]):
        if not (row is Dictionary):
            continue
        var id: String = str(row.get("quest_id",""))
        if id.is_empty() or locations.has(id):
            errors.append("duplicate quest location " + id)
            continue
        var map_id: String = str(row.get("map_id",""))
        var point: Array = row.get("anchor_hint",[])
        if not map_id.begins_with("map_") or point.size()!=2:
            errors.append("bad map location " + id)
            continue
        locations[id] = row
    if locations.size()!=120:
        errors.append("expected 120 quest map anchors, got %d" % locations.size())

func site(quest_id: String) -> Dictionary:
    return locations.get(quest_id,{})

func map_for(quest_id: String) -> String:
    return str(site(quest_id).get("map_id",""))

func matches(quest_id: String,map_id: String) -> bool:
    return not map_id.is_empty() and map_for(quest_id)==map_id

func find_reachable(world) -> Dictionary:
    # Walkability from the current actual hero cell: prevents placing markers
    # beyond blocked water, behind shop walls or on inaccessible scenery.
    var result: Dictionary = {}
    if not is_instance_valid(world.hero):
        return result
    var initial: Vector2i = Vector2i(world.hero.position / world.TILE)
    if world.blocked.has(initial):
        return result
    var todo: Array[Vector2i] = [initial]
    result[initial] = true
    var cursor: int = 0
    while cursor < todo.size():
        var cell: Vector2i = todo[cursor]
        cursor += 1
        for next in [cell+Vector2i.LEFT,cell+Vector2i.RIGHT,cell+Vector2i.UP,cell+Vector2i.DOWN]:
            if next.x<2 or next.y<2 or next.x>=world.WIDTH-2 or next.y>=world.HEIGHT-2:
                continue
            if world.blocked.has(next) or result.has(next):
                continue
            result[next] = true
            todo.append(next)
    return result

func position_for(site_info: Dictionary,reachable: Dictionary,occupied: Array[Vector2i],
        step: int = 0) -> Vector2i:
    var array: Array = site_info.get("anchor_hint",[36,24])
    var base: Vector2i = Vector2i(int(array[0]),int(array[1]))
    var offset: Vector2i = [Vector2i.ZERO,Vector2i(6,1),Vector2i(-3,6)][clampi(step,0,2)]
    var wanted: Vector2i = base+offset
    var closest: Vector2i = Vector2i(-1,-1)
    var best: float = INF
    for candidate in reachable.keys():
        var p: Vector2i = candidate
        var keep: bool = true
        for other in occupied:
            if p.distance_squared_to(other)<20:
                keep = false
                break
        if not keep:
            continue
        var score: float = float(p.distance_squared_to(wanted))
        if score < best:
            best=score
            closest=p
    return closest

func route_summary(quest_id: String,router) -> String:
    var point: Dictionary = site(quest_id)
    if point.is_empty():
        return "暂无合法地图地点"
    var target: String = str(point.get("map_id",""))
    var label: String = str(point.get("map_name",target))
    var local: String = str(point.get("script_location",label))
    if router.current_map()==target:
        return "已在%s，寻找地图上的蓝色任务标记（%s）。" % [label,local]
    var path: Array[String] = router.shortest_route(target)
    if path.size()<2:
        return "目的地：%s／%s。尚无已探索的合法连续路线。" % [label,local]
    var names: PackedStringArray = []
    for item in path:
        names.append(str(router.map_info(str(item)).get("name",item)))
    return "目的地：%s／%s。路线：%s（每段按现有旅行规则通行）。" % [label,local," → ".join(names)]
