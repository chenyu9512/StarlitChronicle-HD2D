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
    var unique_guidance: Dictionary={}
    for chapter in range(1,7):
        var state=State.new()
        state.new_game()
        state.chapter=chapter
        # The canonical quest table now names the DESTINATION, not the
        # previous chapter's starting sector. Build a legitimate saved
        # starting point and let every leg traverse a real adjacent gate.
        var start_by_chapter: Dictionary={
            1:"map_coast_01",2:"map_coast_01",3:"map_coast_03",
            4:"map_coast_04",5:"map_coast_02",6:"map_coast_04"
        }
        state.rpg["world"]=state.rpg.get("world",{})
        state.rpg["world"]["current_map"]=str(start_by_chapter[chapter])
        state.rpg["world"]["bound_chapter"]=chapter
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
        var spoken: String=str(preview.get("guidance",""))
        check(spoken.length()>=20,
            "Chapter %d has no useful in-world objective text" % chapter)
        check(not unique_guidance.has(spoken),
            "Two first-act chapters show the same generic quest hint")
        unique_guidance[spoken]=true
        check(state._pack()==before,
            "Chapter %d guidance silently wrote progress/visited/discovery" % chapter)
        check(not bool(preview.get("requires_save",true)),
            "Chapter %d guidance requests an unauthorized save" % chapter)
        if chapter==3:
            check(str(preview.get("next_map_id",""))=="map_coast_04",
                "Cave target is not reached by the actual coast-03 exit")
            check(bool(preview.get("can_take_next_leg",false)),
                "Chapter 3 must now open the genuine Saltwind-to-cave exit")
        if chapter==4:
            check(preview.get("next_map_id","")=="map_coast_03" and
                bool(preview.get("can_take_next_leg",false)),
                "Chapter 4 should physically backtrack through Saltwind")
        if chapter==5:
            check(path==["map_coast_02","map_coast_03"],
                "Chapter 5 primary route must start in the chapter-4 harbor")
            check(preview.get("next_map_id","")=="map_coast_03" and
                bool(preview.get("can_take_next_leg",false)),
                "Chapter 5 normal continuation must walk from harbor to shoal")
            check(preview.get("route_map_ids",[])==["map_coast_02","map_coast_03"],
                "Chapter 5 new save was incorrectly sent to the lighthouse")
            check(not router.is_available("map_coast_05"),
                "New chapter-5 save has prematurely discovered/unlocked the lighthouse")
            check(not router.can_travel("map_coast_05"),
                "New chapter-5 save can illegally travel to chapter-6 lighthouse")
        # Follow each leg ONLY through Registry.travel; the B preview may
        # not secretly unlock a door or skip a region.
        var playable_path: Array=preview.get("route_map_ids",[])
        var starting_index: int=playable_path.find(router.current_map())
        check(starting_index>=0,
            "Chapter %d legacy spawn missing from intended journey" % chapter)
        for leg in range(starting_index+1,playable_path.size()):
            var next_id: String=str(playable_path[leg])
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

    # Real chapter-4-to-5 continuation is harbor -> shoal, not
    # lighthouse -> cave -> shoal. Chapter transitions do not teleport.
    var sequential=State.new()
    sequential.new_game()
    sequential.chapter=1
    var sequential_router=Registry.new()
    sequential_router.bind(sequential)
    sequential.chapter=2
    sequential_router.sync_chapter(2)
    check(sequential_router.travel("map_coast_02"),
        "Chapter 2 harbor unavailable from village")
    sequential.chapter=3
    sequential_router.sync_chapter(3)
    check(sequential_router.travel("map_coast_03"),
        "Chapter 3 Saltwind transit is blocked")
    check(sequential_router.travel("map_coast_04"),
        "Cannot reach chapter-3 cave before chapter-4 return")
    sequential.chapter=4
    sequential_router.sync_chapter(4)
    check(sequential_router.travel("map_coast_03"),
        "Cannot return from cave via Saltwind")
    check(sequential_router.travel("map_coast_02"),
        "Cannot reach harbor for chapter-4 tavern")
    sequential.chapter=5
    sequential_router.sync_chapter(5)
    check(sequential_router.current_map()=="map_coast_02",
        "Chapter-5 transition silently teleported out of the harbor")
    var before_sequential: Dictionary=sequential._pack().duplicate(true)
    var fifth_hint: Dictionary=journey.preview(5,sequential_router.current_map(),sequential)
    check(fifth_hint.get("route_map_ids",[])==["map_coast_02","map_coast_03"] and
        fifth_hint.get("next_map_id","")=="map_coast_03" and
        bool(fifth_hint.get("can_take_next_leg",false)),
        "Live chapter-5 harbor continuation has no legal shoal route")
    check(before_sequential==sequential._pack(),
        "Chapter-5 sequential preview changed save data")
    check(sequential_router.travel("map_coast_03"),
        "Chapter-5 shoal is not reachable from harbor")
    check(bool(journey.preview(5,sequential_router.current_map(),sequential).get("arrived_at_map",false)),
        "Chapter-5 arrival does not recognize the real shoal")

    # An actual older Chapter-5 save may already be in the lighthouse.
    # Do not teleport it to the harbor: preserve a three-gate retreat
    # through the cave and saltwind road, with no invented short-cut.
    var legacy=State.new()
    legacy.new_game()
    legacy.chapter=5
    legacy.rpg["world"]=legacy.rpg.get("world",{})
    legacy.rpg["world"]["current_map"]="map_coast_05"
    legacy.rpg["world"]["bound_chapter"]=5
    var legacy_router=Registry.new()
    legacy_router.bind(legacy)
    var old_preview: Dictionary=journey.preview(5,"map_coast_05",legacy)
    check(old_preview.get("route_map_ids",[])==
        ["map_coast_05","map_coast_04","map_coast_03"] and
        old_preview.get("next_map_id","")=="map_coast_04" and
        bool(old_preview.get("can_take_next_leg",false)),
        "Legacy Chapter-5 lighthouse save has no real return route")
    check(legacy_router.travel("map_coast_04") and
        legacy_router.travel("map_coast_03"),
        "Legacy Chapter-5 path cannot physically walk lighthouse to shoal")
    check(not legacy_router.can_travel("map_coast_05"),
        "Legacy retreat accidentally reopened the locked lighthouse entrance")

    var missing=State.new()
    missing.new_game()
    var before_missing: Dictionary=missing._pack().duplicate(true)
    check(not bool(journey.preview(7,"map_coast_01",missing).get("valid",true)),
        "Act-II chapter accepted by an Act-I-only route adviser")
    check(journey.preview(4,"map_coast_05",missing).get("reason","")=="chapter_mismatch",
        "Spoofed future chapter offered a route before the save reached it")
    check(missing._pack()==before_missing,
        "Spoofed chapter hint changed the save")
    missing.chapter=4
    var before_stranger: Dictionary=missing._pack().duplicate(true)
    var stranger: Dictionary=journey.preview(4,"map_coast_05",missing)
    check(stranger.get("blocked_reason","")=="outside_authored_route",
        "An off-route location offered an unsafe teleport")
    check(missing._pack()==before_stranger,
        "Invalid off-route hint changed the save")
    if failures.is_empty():
        print("PASS B Act-I: six physical chapter routes, pure guidance, chapter-3 lock, no teleport or skip")
        quit(0)
        return
    for item in failures:
        push_error(item)
    quit(1)
