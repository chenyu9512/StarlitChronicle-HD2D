extends SceneTree
## Commercial Act-I wayfinding smoke. The route adviser must remain pure,
## respect D's live unlocks, and guide only through actual adjacent exits.
const State=preload("res://scripts/first_act_state.gd")
const Registry=preload("res://scripts/world_registry.gd")
const Journey=preload("res://scripts/world_act01_journey.gd")
var failures: Array[String]=[]


func _initialize() -> void:
    call_deferred("_run")


func check(ok: bool,reason: String) -> void:
    if not ok:
        failures.append(reason)


func _run() -> void:
    var journey=Journey.new()
    check(journey.issues.is_empty(),"Act-I route catalog invalid: "+str(journey.issues))
    check(journey.chapters.size()==6,"Missing an Act-I route")
    for chapter in range(1,7):
        var state=State.new()
        state.new_game()
        state.chapter=chapter
        var router=Registry.new()
        router.bind(state)
        var path: Array[String]=journey.route(chapter)
        check(not path.is_empty(),"No authored wayfinding for chapter "+str(chapter))
        check(str(path[path.size()-1])==
            str(journey.chapters[chapter].get("required_map_id","")),
            "Chapter %d route does not finish at actual scene" % chapter)
        var before: Dictionary=state._pack().duplicate(true)
        var preview: Dictionary=journey.preview(chapter,router.current_map(),state)
        check(bool(preview.get("valid",false)),
            "Chapter %d has no read-only player guidance" % chapter)
        check(state._pack()==before,
            "Chapter %d guidance silently wrote progress/visited/discovery" % chapter)
        check(not bool(preview.get("requires_save",true)),
            "Chapter %d guidance requests an unauthorized save" % chapter)
        if chapter==3:
            check(str(preview.get("next_map_id",""))=="map_coast_04",
                "Cave target is not reached by the actual coast-03 exit")
            check(not bool(preview.get("can_take_next_leg",true)) and
                str(preview.get("blocked_reason",""))=="chapter_gate",
                "Chapter 3 cave remains blocked in D routing; never falsely unlock it")
        if chapter==4:
            check(preview.get("next_map_id","")=="map_coast_03" and
                bool(preview.get("can_take_next_leg",false)),
                "Chapter 4 should physically backtrack through Saltwind")
        if chapter==5:
            check(preview.get("next_map_id","")=="map_coast_04",
                "Chapter 5 current legacy spawn must return through the cave")
        # Follow each leg ONLY through Registry.travel; the B preview may
        # not secretly unlock a door or skip a region.
        for next_id in path.slice(1):
            var direction: Dictionary=journey.preview(chapter,router.current_map(),state)
            check(str(direction.get("next_map_id",""))==str(next_id),
                "Chapter %d missing physical next gate %s" % [chapter,next_id])
            if not bool(direction.get("can_take_next_leg",false)):
                check(not router.can_travel(str(next_id)),
                    "B route reports blocked but D travel opens "+str(next_id))
                break
            check(router.can_travel(str(next_id)),
                "B route suggests leg that D's actual adjacent travel rejects "+str(next_id))
            check(router.travel(str(next_id)),
                "Failed to walk real exit to "+str(next_id))
            var arrived: Dictionary=journey.preview(chapter,router.current_map(),state)
            check(bool(arrived.get("valid",false)),
                "Journey cannot re-evaluate after actual gate travel")
        var check_again: Dictionary=journey.preview(chapter,router.current_map(),state)
        check(str(check_again.get("target_map_id",""))==str(path[-1]),
            "Preview target changed after walking legitimate route")
        var final_snapshot: Dictionary=state._pack().duplicate(true)
        journey.preview(chapter,router.current_map(),state)
        check(final_snapshot==state._pack(),
            "Route reread changed a previously persisted world snapshot")

    var missing=State.new()
    missing.new_game()
    var before_missing: Dictionary=missing._pack().duplicate(true)
    check(not bool(journey.preview(7,"map_coast_01",missing).get("valid",true)),
        "Act-II chapter accepted by an Act-I-only route adviser")
    check(journey.preview(4,"map_coast_05",missing).get("reason","")=="chapter_mismatch",
        "Spoofed future chapter offered a route before the save reached it")
    missing.chapter=4
    var stranger: Dictionary=journey.preview(4,"map_coast_05",missing)
    check(stranger.get("blocked_reason","")=="outside_authored_route",
        "An off-route location offered an unsafe teleport")
    check(missing._pack()==before_missing,
        "Invalid route changed the save")
    if failures.is_empty():
        print("PASS B Act-I: six physical chapter routes, pure guidance, chapter-3 lock, no teleport or skip")
        quit(0)
        return
    for item in failures:
        push_error(item)
    quit(1)
