extends SceneTree
## Offline chapter 1-3 regional route guard. The guide may never mark
## discovery, unlock unearned maps or skip physical adjacency.
const Registry=preload("res://scripts/world_registry.gd")
const State=preload("res://scripts/first_act_state.gd")
var failures: Array[String]=[]

func _initialize() -> void:
    call_deferred("_run")

func check(ok: bool,reason: String) -> void:
    if not ok:
        failures.append(reason)

func _run() -> void:
    var one=State.new()
    one.new_game()
    one.chapter=1
    var first=Registry.new()
    first.bind(one)
    check(first.errors.is_empty(),"Geography configuration errors")
    check(first.chapter_map(1)=="map_coast_01" and first.chapter_map(2)=="map_coast_02" and
        first.chapter_map(3)=="map_coast_03","Canonical chapter maps changed")
    var before_one: Dictionary=one._pack().duplicate(true)
    check(first.current_map()=="map_coast_01","Chapter 1 does not begin in Morning Dew Village")
    check(first.shortest_route("map_coast_01")==["map_coast_01"],
        "Current map should have one-node route")
    check(first.shortest_route("map_coast_02").is_empty() and
        first.shortest_route("map_coast_03").is_empty(),
        "Chapter 1 prematurely unlocked other coastal maps")
    check(not first.travel("map_coast_02"),"Chapter 1 can enter story-locked harbor")
    check(one._pack()==before_one,"Route browsing changed the player save")

    var two=State.new()
    two.new_game()
    two.chapter=2
    var harbor=Registry.new()
    harbor.bind(two)
    check(harbor.current_map()=="map_coast_02","Chapter 2 has wrong harbor anchor")
    check(harbor.travel("map_coast_01"),"Chapter 2 cannot go back to the village")
    var before_two: Dictionary=two._pack().duplicate(true)
    check(harbor.shortest_route("map_coast_02")==["map_coast_01","map_coast_02"],
        "Chapter 2 guide cannot find actual adjacent village/harbor road")
    check(harbor.shortest_route("map_coast_03").is_empty(),
        "Chapter 3 wilderness opened early")
    check(two._pack()==before_two,"Chapter 2 passive map guidance changed save")

    var three=State.new()
    three.new_game()
    three.chapter=3
    var road=Registry.new()
    road.bind(three)
    check(road.current_map()=="map_coast_03","Chapter 3 anchor changed")
    check(road.travel("map_coast_02") and road.travel("map_coast_01"),
        "Chapter 3 lost the real route back to the first village")
    var before_three: Dictionary=three._pack().duplicate(true)
    check(road.shortest_route("map_coast_03")==
        ["map_coast_01","map_coast_02","map_coast_03"],
        "Route planner did not traverse the harbor before saltwind road")
    check(three._pack()==before_three,"Guidance altered travel count or discovery flags")
    check(not road.can_travel("map_coast_03"),"Map guide grants nonadjacent teleport")
    check(road.travel("map_coast_02") and road.travel("map_coast_03"),
        "Following two actual legs cannot reach chapter 3")
    check(road.visited_count()==3,"All three real coastal areas not recorded")
    check(road.shortest_route("map_coast_03")==["map_coast_03"],
        "Already-at-destination route failed")
    check(road.shortest_route("invalid_map").is_empty(),
        "Unknown map illegally appears in route")
    var recovered=State.new()
    check(recovered.restore_snapshot(three._pack()),"Chapter 3 saved geography cannot restore")
    var restored=Registry.new()
    restored.bind(recovered)
    check(restored.current_map()=="map_coast_03","Restored chapter 3 location differs")
    if failures.is_empty():
        print("PASS B coast: chapter 1-3 route, no story bypass, only adjacent travel, saved position")
        quit(0)
        return
    for issue in failures:
        push_error(issue)
    quit(1)
