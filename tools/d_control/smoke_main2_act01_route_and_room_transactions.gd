extends SceneTree
## Main2 regression: actual Act-I coast routes, real V4 player-furniture
## selection and failed V3 persistence. Runs headless without user-save writes.
const State = preload("res://scripts/first_act_state.gd")
const Registry = preload("res://scripts/world_registry.gd")
const PlayableWorld = preload("res://scripts/first_act_world.gd")
const Home = preload("res://scripts/world_home_interactions.gd")
const Settlement = preload("res://scripts/d_world_interaction/world_object_settlement.gd")
var failures: Array[String] = []
var selected: String = ""

func _initialize() -> void:
    call_deferred("_run")

func _check(value: bool, message: String) -> void:
    if not value:
        failures.append(message)

func _on_interaction(name: String) -> void:
    selected = name

func _run() -> void:
    var state = State.new()
    state.new_game()
    state.chapter = 3
    var registry = Registry.new()
    registry.bind(state)
    _check(registry.act01_target_map(3)=="map_coast_04","Chapter 3 canonical cave mismatch")
    _check(registry.act01_target_map(4)=="map_coast_02","Chapter 4 canonical tavern mismatch")
    _check(registry.act01_target_map(5)=="map_coast_03","Chapter 5 canonical shoal mismatch")
    _check(registry.act01_target_map(6)=="map_coast_05","Chapter 6 canonical lighthouse mismatch")
    _check(registry.current_map()=="map_coast_03","Legacy chapter-3 starting sector changed")
    _check(registry.is_available("map_coast_04"),"Chapter-3 cave incorrectly chapter-locked")
    _check(registry.can_travel("map_coast_04"),"Physical chapter-3 cave exit not open")
    _check(registry.travel("map_coast_04"),"Cannot walk to chapter-3 cave")
    state.chapter = 4
    registry.sync_chapter(4)
    _check(registry.current_map()=="map_coast_04","Chapter advance teleported away from cave")
    _check(registry.can_travel("map_coast_03"),"Cave-to-Saltwind return closed")
    _check(registry.travel("map_coast_03"),"Cannot walk back through Saltwind")
    _check(registry.travel("map_coast_02"),"Cannot return to harbor for chapter 4")
    state.chapter = 5
    registry.sync_chapter(5)
    _check(registry.current_map()=="map_coast_02","Chapter 5 teleported instead of preserving harbor")

    var world = PlayableWorld.new()
    root.add_child(world)
    world.interacted.connect(_on_interaction)
    world.map_profile = registry.profile("map_coast_02")
    world.build(2,2)
    var home = Home.new()
    var inspected: int = 0
    for building in ["shelter","tavern"]:
        _check(world.enter_building(building),"Cannot enter harbor "+building)
        if world.interior_building != building:
            continue
        var objects: Array = home.objects("map_coast_02",building)
        _check(objects.size()==4,"Not four canonical clues in "+building)
        for clue in objects:
            var key: String = "homeinspect:"+str(clue.get("id",""))
            _check(world.nodes.has(key),"No live V4 inspection node "+key)
            if not world.nodes.has(key):
                continue
            world.hero.position = (world.nodes[key] as Node2D).position
            selected = ""
            world.interact()
            _check(selected==key,"Live player input did not select "+key+"; got "+selected)
            inspected += 1
        _check(world.leave_building(),"Cannot leave "+building)
    _check(inspected==8,"Incomplete harbor investigation coverage")

    # Mutation must not remain marked seen in RAM after a failed V3 save.
    state.save_path = "user://__main2_regression_no_parent__/save.json"
    state.backup_path = "user://__main2_regression_no_parent__/backup.json"
    var original: Dictionary = state._pack().duplicate(true)
    var failed: Dictionary = Settlement.transact(state,func() -> Dictionary:
        var inspected_result: Dictionary = home.inspect(
            "map_coast_02","shelter","inspect_act01_shelter_1",state,false)
        return {"ok":true,"changed":bool(inspected_result.get("changed",false)),
            "result":inspected_result}
    )
    _check(not bool(failed.get("ok",true)),"Unwritable V3 incorrectly accepted inspection")
    _check(state._pack()==original,"Failed V3 write left furniture seen or mutated state")
    _check(not bool(home.preview("map_coast_02","shelter",
        "inspect_act01_shelter_1",state).get("seen",false)),
        "Inspection receipt survived failed save")
    world.queue_free()
    if failures.is_empty():
        print("PASS Main2: Act-I physical cave gate, chapter map continuity, 8 indoor hotspots and failed V3 rollback")
        quit(0)
        return
    for reason in failures:
        push_error(reason)
    quit(1)
