extends SceneTree
## Architecture regression: map graph, chapter routing, events/time, three manual saves and menu integration.
const State = preload("res://scripts/first_act_state.gd")
const World = preload("res://scripts/world_registry.gd")
const Events = preload("res://scripts/game_events.gd")
const Slots = preload("res://scripts/save_slots.gd")
const Menu = preload("res://scripts/rpg_menu.gd")
const Core = preload("res://scripts/rpg_core.gd")
const Game = preload("res://scripts/first_act.gd")
var faults: Array[String] = []

func _initialize() -> void:
    call_deferred("_run")

func check(ok: bool, message: String) -> void:
    if not ok:
        faults.append(message)

func _run() -> void:
    var state = State.new()
    state.new_game()
    var core = Core.new()
    core.bind(state)
    var world = World.new()
    world.bind(state)
    check(world.errors.is_empty(), "Map graph invalid: %s" % str(world.errors))
    check(world.maps.size() == 42 and world.regions.size() == 8, "World inventory mismatch")
    check(world.chapter_maps.size() == 72, "72 chapter-to-map links missing")
    check(world.current_map() == "map_coast_01", "Prologue spawn incorrect")
    check(world.profile().get("authored_scene",true) == false, "Planned level incorrectly labeled authored")
    state.chapter = 2
    world.sync_chapter(2)
    check(world.current_map() == "map_coast_02", "Chapter 2 quest map incorrect")
    check(world.can_travel("map_coast_01"), "Adjacent already visited map should be reachable")
    check(not world.can_travel("map_coast_03"), "Cannot travel to chapter 3 map from chapter 2")
    check(world.travel("map_coast_01"), "Unlocked return journey failed")
    check(world.visited_count() >= 2, "Discovery did not persist")
    state.chapter = 3
    world.sync_chapter(3)
    check(world.current_map() == "map_coast_03", "Chapter 3 did not activate its canonical map")
    var events = Events.new()
    events.bind(state)
    events.advance_time(750)
    check(int(state.rpg["game_clock"]["day"]) == 1, "Time advanced unexpected number of days")
    events.record("battle_victory",{"xp":20})
    events.record("chapter_completed",{"chapter":2})
    check(bool(state.rpg["achievements"].get("first_victory",false)), "Event achievement not unlocked")
    check(events.history().size() == 2, "Event history did not grow")
    var slots = Slots.new()
    check(slots.save_slot(state,1), "Manual slot 1 cannot save")
    state.gold = 777
    check(slots.save_slot(state,2), "Manual slot 2 cannot save")
    state.gold = 42
    check(slots.load_slot(state,1), "Manual slot 1 cannot load")
    check(state.gold == 80, "Manual slot 1 gold not restored")
    check(slots.load_slot(state,2), "Manual slot 2 cannot load")
    check(state.gold == 777, "Manual slot 2 gold not restored")
    check(not slots.load_slot(state,0), "Invalid save slot loaded")
    world.bind(state)
    events.bind(state)
    check(world.current_map() == "map_coast_03", "World map lost after slot loading")
    check(events.history().size() == 2, "Event history lost after slot loading")
    var menu = Menu.new()
    root.add_child(menu)
    menu.world_router = world
    menu.game_events = events
    menu.slot_service = slots
    core.bind(state)
    menu.show_menu(core,state)
    check(Menu.SECTIONS.size() >= 16, "New architecture menus missing")
    for section in ["世界地图","冒险履历","存档管理"]:
        menu.render(section)
    menu.close_menu()
    check(not menu.root.visible, "Menu cannot close")
    var game = Game.new()
    root.add_child(game)
    game.ui.title_overlay.hide()
    game._start(false)
    game.progress.chapter = 2
    game.world_router.sync_chapter(2)
    game._enter_location()
    game._travel_to("map_coast_01")
    check(game.world_router.current_map() == "map_coast_01", "Travel signal did not reach main game")
    check(game.world.map_profile.get("id","") == "map_coast_01", "Map profile not linked to world visuals")
    if faults.is_empty():
        print("PASS: 8 regions, 42 maps, 72 quest/map anchors, gated travel, events/achievements, 3-slot save and new UI services")
        quit(0)
    else:
        for fault in faults:
            push_error(fault)
        quit(1)
