extends SceneTree
## B-only NPC pathfinding on real 32px grid. No story flags, saves, D
## controller or cheated teleport. Measures repeated route work.
const Daily = preload("res://scripts/world_npc_daily.gd")
var errors: Array[String]=[]


func _initialize() -> void:
    call_deferred("_run")


func check(ok: bool, reason: String) -> void:
    if not ok:
        errors.append(reason)


func _run() -> void:
    var daily=Daily.new()
    check(daily.issues.is_empty(),"NPC routine config invalid: "+str(daily.issues))
    var extent: Vector2i=Vector2i(104,72)
    var start: Vector2i=Vector2i(4,4)
    var far: Vector2i=Vector2i(99,67)
    var walls: Dictionary={}
    var path: Array[Vector2i]=daily._route(start,far,walls,extent)
    check(not path.is_empty(),"Large 104x72 town route unexpectedly empty")
    if not path.is_empty():
        check(path[0]==start and path[-1]==far,
            "Large settlement path capped before reaching distant destination")
        for i in range(1,path.size()):
            check((path[i]-path[i-1]).length_squared()==1,
                "Large settlement route contains a teleport/diagonal")
    var blocked_goal: Vector2i=Vector2i(20,20)
    walls[blocked_goal]=true
    var safe: Vector2i=Daily.safe_destination(blocked_goal,walls,extent)
    check(safe!=blocked_goal and not walls.has(safe) and
        safe.distance_squared_to(blocked_goal)<=4,
        "Author-painted building blocked an NPC district standing tile")
    var clear_path: Array[Vector2i]=daily._route(start,safe,walls,extent)
    check(not clear_path.is_empty() and clear_path[-1]==safe,
        "Nearby safe district destination cannot be reached")
    check(daily._route(start,blocked_goal,walls,extent).is_empty(),
        "Pathfinding walked into an explicitly blocked goal")

    # An NPC surrounded by temporary occupants should wait. A cached
    # dead-end is retried after a bounded cooldown, not every frame forever.
    var resident_id: String="npc_coast_01"
    var from_cell: Vector2i=Vector2i(12,12)
    var current: Vector2=Vector2(from_cell)*32.0+Vector2(16,16)
    var restricted: Dictionary={
        from_cell+Vector2i.UP:true,
        from_cell+Vector2i.DOWN:true,
        from_cell+Vector2i.LEFT:true,
        from_cell+Vector2i.RIGHT:true,
    }
    var first: Dictionary=daily.step(resident_id,"map_coast_01",600,current,0.1,restricted,extent)
    check(not bool(first.get("moving",true)) and first.get("position",Vector2.ZERO)==current,
        "Surrounded citizen moved through occupied cells")
    var searches: int=daily.path_queries
    for i in range(8):
        var still: Dictionary=daily.step(resident_id,"map_coast_01",600,current,0.1,restricted,extent)
        check(not bool(still.get("moving",true)),"NPC slipped through a temporary occupant")
    check(daily.path_queries==searches,
        "Dead-end route recalculated every frame instead of throttling")
    # Same wall count but different occupied cells: route must eventually
    # retry and move when space becomes available.
    restricted.erase(from_cell+Vector2i.RIGHT)
    restricted[Vector2i(5,5)]=true
    for i in range(18):
        daily.step(resident_id,"map_coast_01",600,current,0.1,restricted,extent)
    check(daily.path_queries>searches,
        "NPC never retried its cached dead-end after nearby resident moved")
    var resumed: Dictionary=daily.step(resident_id,"map_coast_01",600,current,0.1,restricted,extent)
    check((resumed.get("position",current) as Vector2).distance_to(current)<=8.0,
        "NPC teleported while resuming its route")
    var wrong: Dictionary=daily.step(resident_id,"map_city_01",600,current,0.1,restricted,extent)
    check(not bool(wrong.get("moving",true)),"NPC crossed to another map")
    if errors.is_empty():
        print("PASS B: >4096-cell town routes, stable 4-neighbor motion, safe blocked anchor, throttled occupancy retry")
        quit(0)
        return
    for error in errors:
        push_error(error)
    quit(1)
