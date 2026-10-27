extends SceneTree
## Offline JRPG chapter 1-3 route acceptance: map guidance is advisory
## and must never unlock a chapter, mark an unvisited location or grant
## a shortcut. No global/world map UI and no cheat travel.
const Registry = preload("res://scripts/world_registry.gd")
const State = preload("res://scripts/first_act_state.gd")
var failures: Array[String]=[]


func _initialize() -> void:
    call_deferred("_run")


func check(ok: bool, message: String) -> void:
    if not ok:
        failures.append(message)


func _run() -> void:
    var fresh=State.new()
    fresh.new_game()
    fresh.chapter=1
    var locked=Registry.new()
    locked.bind(fresh)
    check(locked.errors.is_empty(),"Main geography catalog invalid")
    check(locked.chapter_map(1)=="map_coast_01" and
        locked.chapter_map(2)=="map_coast_02" and
        locked.chapter_map(3)=="map_coast_03",
        "Chapters 1–3 no longer link the three authentic coast environments")
    check(locked.current_map()=="map_coast_01","New adventure no longer starts in Morning Dew")
    var read_before: Dictionary=fresh._pack().duplicate(true)
    check(locked.shortest_route("map_coast_01")==["map_coast_01"],
        "Already-arrived route should contain only the actual current map")
    check(locked.shortest_route("map_coast_02").is_empty(),
        "Chapter 1 route illegally revealed the locked harbor")
    check(locked.shortest_route("map_coast_03").is_empty(),
        "Chapter 1 route illegally revealed the locked coast road")
    check(not locked.can_travel("map_coast_02") and not locked.travel("map_coast_02"),
        "Chapter 1 could bypass the harbor story gate")
    check(fresh._pack()==read_before,
        "Reading an unavailable route or rejecting travel mutated the real save")

    var second=State.new()
    second.new_game()
    second.chapter=2
    var harbor=Registry.new()
    harbor.bind(second)
    check(harbor.current_map()=="map_coast_02","Chapter 2 anchor not the actual harbor")
    check(harbor.can_travel("map_coast_01"),"Chapter 2 has no natural way home")
    check(harbor.travel("map_coast_01"),"Failed to return to original village")
    var before_guide: Dictionary=second._pack().duplicate(true)
    var harbor_route: Array[String]=harbor.shortest_route("map_coast_02")
    check(harbor_route==["map_coast_01","map_coast_02"],
        "Chapter 2 route planner must find the direct local harbor road")
    check(second._pack()==before_guide,"Viewing route guide modified save state")
    check(not harbor.can_travel("map_coast_03") and harbor.shortest_route("map_coast_03").is_empty(),
        "Chapter 2 unlocked the chapter 3 coast road early")

    var third=State.new()
    third.new_game()
    third.chapter=3
    var road=Registry.new()
    road.bind(third)
    check(road.current_map()=="map_coast_03","Chapter 3 story anchor changed")
    check(road.travel("map_coast_02"),"Chapter 3 coast road cannot return to harbor")
    check(road.travel("map_coast_01"),"Chapter 3 harbor cannot return to village")
    var save_before: Dictionary=third._pack().duplicate(true)
    var route: Array[String]=road.shortest_route("map_coast_03")
    check(route==["map_coast_01","map_coast_02","map_coast_03"],
        "World route must use the actual harbor before reaching the coast road")
    check(third._pack()==save_before,"Passive route planning moved the player")
    check(not road.can_travel("map_coast_03"),
        "Advisory route illicitly enabled long-distance fast travel")
    check(road.can_travel("map_coast_02") and road.travel("map_coast_02"),
        "Leg 1 of physical journey is blocked")
    check(road.can_travel("map_coast_03") and road.travel("map_coast_03"),
        "Leg 2 of physical journey is blocked")
    check(road.visited_count()==3,"Three real coastal maps were not visited")
    check(road.shortest_route("map_coast_03")==["map_coast_03"],
        "Current-location route became cyclic")
    check(road.shortest_route("invalid_map").is_empty(),
        "Unknown map was offered as a destination")
    var restored=State.new()
    check(restored.restore_snapshot(third._pack()),"The chapter 3 travel state cannot restore")
    var restored_router=Registry.new()
    restored_router.bind(restored)
    check(restored_router.current_map()=="map_coast_03","Saved location did not recover")
    if failures.is_empty():
        print("PASS B: chapters 1-3 use real coastal entrances, no unauthorized travel, deterministic route and save")
        quit(0)
        return
    for issue in failures:
        push_error(issue)
    quit(1)
