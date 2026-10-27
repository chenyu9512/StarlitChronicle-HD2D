extends SceneTree
## One-save gameplay: optional dungeon puzzle, unique rewards, regional route guidance.
const Game = preload("res://scripts/first_act.gd")
const Router = preload("res://scripts/world_registry.gd")
const State = preload("res://scripts/first_act_state.gd")
var errors: Array[String] = []

func _initialize() -> void:
    call_deferred("_check")

func check(ok: bool,message: String) -> void:
    if not ok:
        errors.append(message)

func _check() -> void:
    var game = Game.new()
    root.add_child(game)
    game.ui.title_overlay.hide()
    game._start(false)
    game.progress.chapter = 4
    game.world_router.sync_chapter(4)
    game._enter_location()
    check(game.world.nodes.has("dungeon_switch_a"),"Cave has no first rune switch")
    check(game.world.nodes.has("dungeon_switch_b"),"Cave has no second rune switch")
    check(game.world.nodes.has("dungeon_chest"),"Cave treasure does not exist")
    var old_gold: int = game.progress.gold
    game._interact("dungeon_chest")
    check(game.progress.gold==old_gold,"Locked treasure bypassed two-switch puzzle")
    game._interact("dungeon_switch_a")
    game._interact("dungeon_chest")
    check(game.progress.gold==old_gold,"Single switch bypassed treasure lock")
    game._interact("dungeon_switch_b")
    game._interact("dungeon_chest")
    check(game.progress.gold>old_gold,"Both dungeon runes did not release the chest")
    var payout: int = game.progress.gold
    game._interact("dungeon_chest")
    check(game.progress.gold==payout,"Treasures can be farmed infinitely")
    check(game.progress.save(),"Puzzle flags could not save")
    var restored = State.new()
    check(restored.load_saved(),"Puzzle flags could not restore")
    check(bool(restored.flags.get("map.map_coast_04.chest_claimed",false)),"Dungeon chest was not persisted")
    # Legacy global atlas was removed by product decision. The same journal
    # action must open ONLY the current fully visible local area and must not
    # unlock any additional area or route.
    var before_map_view: Dictionary=game.progress._pack().duplicate(true)
    game._open_local_map_from_book()
    check(game.atlas.is_open() and game.atlas.full_view.mode=="local",
        "Journal should open the fog-free current-area map, never a world atlas")
    check(game.progress._pack()==before_map_view,
        "Viewing the local map modified the saved world or discovery flags")
    game.atlas.close_map()
    var state = State.new()
    state.chapter=3
    var route = Router.new()
    route.bind(state)
    check(route.current_map()=="map_coast_03","Chapter 3 spawn not routed")
    check(route.travel("map_coast_02"),"Chapter-3 backtracking to unlocked port failed")
    check(route.travel("map_coast_01"),"Visited town is inaccessible through port")
    check(route.travel("map_coast_02"),"Could not move back toward starting route")
    check(route.travel("map_coast_03"),"Cannot return to open route")
    var path: Array[String] = route.shortest_route("map_coast_01")
    check(path==["map_coast_03","map_coast_02","map_coast_01"],"Shortest known safe path did not follow physical roads")
    check(not route.can_travel("map_coast_01"),"Map route display bypassed one-leg travel gate")
    check(route.shortest_route("map_coast_04")==["map_coast_03","map_coast_04"],"Chapter-3 cave requires a real adjacent unlocked exit")
    if errors.is_empty():
        print("PASS: authored cave puzzle, one-time reward, persisted switches, fog-free local journal map and multi-leg gated route planning")
        quit(0)
    else:
        for error in errors:
            push_error(error)
        quit(1)
