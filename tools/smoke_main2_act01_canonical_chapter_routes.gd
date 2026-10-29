extends SceneTree
## Canonical Act-I main quest IDs and the ONLY physical route unlocks:
## the player walks neighboring gates, never warps to story destination.
const State = preload("res://scripts/first_act_state.gd")
const Registry = preload("res://scripts/world_registry.gd")
const QUESTS: String = "res://data/content/quests.json"
const LOCATIONS: String = "res://data/levels/act01_scene_locations_v1.json"
const REQUIRED: Dictionary = {
    1:"map_coast_01",2:"map_coast_02",3:"map_coast_04",
    4:"map_coast_02",5:"map_coast_03",6:"map_coast_05"
}
var errors: Array[String] = []
func check(value: bool, why: String) -> void:
    if not value:
        errors.append(why)

func _initialize() -> void:
    call_deferred("_run")

func _run() -> void:
    var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(QUESTS))
    var contract: Variant = JSON.parse_string(FileAccess.get_file_as_string(LOCATIONS))
    check(data is Dictionary and contract is Dictionary,"Missing canonical content files")
    if not(data is Dictionary and contract is Dictionary):
        quit(1)
        return
    var quests: Dictionary = {}
    for row in data.get("entries",[]):
        if row is Dictionary and str(row.get("kind","")) == "main":
            var chapter: int = int(row.get("chapter",0))
            if chapter in REQUIRED:
                quests[chapter] = row
    var scenes: Dictionary = {}
    for row in contract.get("chapters",[]):
        if row is Dictionary:
            scenes[int(row.get("chapter",0))] = row
    var registry := Registry.new()
    check(registry.errors.is_empty(),"World registry failed normal static catalog validation")
    for chapter in range(1,7):
        var canonical_map: String = REQUIRED[chapter]
        check(quests.has(chapter), "Main quest absent: "+str(chapter))
        check(scenes.has(chapter), "Story scene contract absent: "+str(chapter))
        if quests.has(chapter):
            check(str(quests[chapter].get("map_id","")) == canonical_map,
                "Chapter "+str(chapter)+" quest still points to old wrong map")
        check(registry.chapter_map(chapter) == canonical_map,
            "Registry chapter map and story location disagree: "+str(chapter))
        check(registry.act01_target_map(chapter) == canonical_map,
            "Runtime story destination disagrees: "+str(chapter))
        if scenes.has(chapter):
            check(str(scenes[chapter].get("required_map_id","")) == canonical_map,
                "Scene and quest map differ: "+str(chapter))
    check(int(registry.first_chapter.get("map_coast_03",999)) == 3,
        "Chapter 3 passage through saltwind road is incorrectly locked")
    check(int(registry.first_chapter.get("map_coast_04",999)) == 3,
        "Chapter 3 boss cave does not unlock at the right chapter")
    check(int(registry.first_chapter.get("map_coast_05",999)) == 6,
        "Chapter-6 lighthouse was globally unlocked early by an old-save retreat path")
    var state := State.new()
    state.new_game()
    state.chapter = 1
    registry.bind(state)
    check(registry.current_map()=="map_coast_01","New game did not start in village")
    check(not registry.can_travel("map_coast_02"),"Harbor allowed before chapter 2")
    state.chapter = 2
    registry.sync_chapter(2)
    check(registry.current_map()=="map_coast_01","Chapter 2 teleported the player")
    check(registry.can_travel("map_coast_02"),"Cannot walk from village to harbor in chapter 2")
    check(registry.travel("map_coast_02"),"Actual adjacent harbor gate blocked")
    state.chapter = 3
    registry.sync_chapter(3)
    check(registry.current_map()=="map_coast_02","Chapter 3 teleported to cave")
    check(not registry.can_travel("map_coast_04"),"Non-adjacent direct cave teleport became possible")
    var path_to_cave: Array[String] = registry.route_towards("map_coast_04")
    check(path_to_cave == ["map_coast_02","map_coast_03","map_coast_04"],
        "Chapter 3 physical two-leg cave route is missing: "+str(path_to_cave))
    check(registry.travel("map_coast_03"),"Saltwind road not unlocked in chapter 3")
    check(registry.travel("map_coast_04"),"Cave exit from saltwind road is blocked")
    state.chapter = 4
    registry.sync_chapter(4)
    check(registry.current_map()=="map_coast_04","Chapter 4 return from cave teleported to harbor")
    check(registry.travel("map_coast_03"),"Chapter 4 return road is blocked")
    check(registry.travel("map_coast_02"),"Chapter 4 harbor tavern cannot be reached")
    state.chapter = 5
    registry.sync_chapter(5)
    check(registry.current_map()=="map_coast_02","Chapter 5 teleported away from tavern")
    check(registry.travel("map_coast_03"),"Chapter 5 shoal approach is inaccessible")
    check(not registry.is_available("map_coast_05"),
        "Chapter 5 unexpectedly unlocked the chapter-6 lighthouse")
    check(not registry.can_travel("map_coast_05"),
        "Chapter 5 can skip the cave to reach the lighthouse")
    state.chapter = 6
    registry.sync_chapter(6)
    check(registry.current_map()=="map_coast_03","Chapter 6 teleported from shoal to lighthouse")
    check(not registry.can_travel("map_coast_05"),"Chapter 6 direct nonadjacent lighthouse warp")
    check(registry.travel("map_coast_04"),"Lighthouse approach via cave is blocked")
    check(registry.travel("map_coast_05"),"Chapter 6 lighthouse actual gate is unavailable")
    if errors.is_empty():
        print("PASS Main2: six canonical main quest maps, chapter-3 cave transit unlock and all adjacent physical chapter routes without auto-teleport")
        quit(0)
        return
    for error in errors:
        push_error(error)
    quit(1)
