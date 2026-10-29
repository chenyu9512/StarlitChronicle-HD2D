extends SceneTree
## Main2 regression: actual Act-I coast routes, real V4 player-furniture
## selection and failed V3 persistence. Runs headless without user-save writes.
const State = preload("res://scripts/first_act_state.gd")
const Registry = preload("res://scripts/world_registry.gd")
const PlayableWorld = preload("res://scripts/first_act_world.gd")
const Home = preload("res://scripts/world_home_interactions.gd")
const Settlement = preload("res://scripts/d_world_interaction/world_object_settlement.gd")
const GameScene = preload("res://scripts/first_act.gd")
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
    state.chapter = 1
    var registry = Registry.new()
    registry.bind(state)
    state.chapter = 2
    registry.sync_chapter(2)
    _check(registry.travel("map_coast_02"),"Cannot reach chapter-2 harbor by its actual village exit")
    state.chapter = 3
    registry.sync_chapter(3)
    _check(registry.travel("map_coast_03"),"Cannot reach Saltwind road from the harbor in chapter 3")
    _check(registry.act01_target_map(3)=="map_coast_04","Chapter 3 canonical cave mismatch")
    _check(registry.act01_target_map(4)=="map_coast_02","Chapter 4 canonical tavern mismatch")
    _check(registry.act01_target_map(5)=="map_coast_03","Chapter 5 canonical shoal mismatch")
    _check(registry.act01_target_map(6)=="map_coast_05","Chapter 6 canonical lighthouse mismatch")
    _check(registry.current_map()=="map_coast_03","Sequential chapter-3 road position changed")
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
    # Authored rooms and semantic replacement signs must remain recognizable.
    var sign_image: Image = world._wayfinding_sign_texture().get_image()
    _check(sign_image.get_size()==Vector2i(32,48),"Road-sign fallback is not a real full-size 32x48 texture")
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
        _check(world.nodes.has("interior_exit"),"Indoor "+building+" has no visible return exit")
        if world.nodes.has("interior_exit"):
            selected = ""
            world.hero.position = (world.nodes["interior_exit"] as Node2D).position
            world.interact()
            _check(selected=="interior_exit","Indoor "+building+" exit cannot be selected with interact")
        if building == "shelter":
            # Simulate a stale save that points into the shelter facade.
            # The exit must recover onto physically connected pavement.
            world.exterior_position = Vector2(52.0*32.0+16.0,22.0*32.0+16.0)
        _check(world.leave_building(),"Cannot leave "+building)
        _check(not world._blocked(world.hero.position),"Room exit returned player inside solid facade "+building)
    _check(inspected==8,"Incomplete harbor investigation coverage")
    # In a map with multiple destinations, exits must be distinct and safe
    # to find again after a real World.build (not only in source JSON).
    for coast_id in ["map_coast_01","map_coast_02","map_coast_03","map_coast_04","map_coast_05"]:
        world.map_profile = registry.profile(coast_id)
        world.build(2,2)
        var used_gates: Dictionary = {}
        for gate in world.terrain_layout.get("gates",[]):
            var cell: Vector2i = gate.get("cell",Vector2i(-1,-1))
            _check(not used_gates.has(cell),"Overlapping travel gates in "+coast_id+" at "+str(cell))
            used_gates[cell] = true

    # A collision-free old exterior checkpoint may still be enclosed by new
    # walls. Check a real disconnected floor component, not just wall overlap.
    world.map_profile = registry.profile("map_coast_02")
    world.build(5,2)
    var normal_spawn: Vector2i=world.terrain_layout.get("spawn",Vector2i(10,23))
    var isolated: Vector2i=Vector2i(-1,-1)
    var base_walkable: Dictionary=world._walkable_tiles().duplicate()
    var cardinal: Array[Vector2i]=[Vector2i.UP,Vector2i.DOWN,Vector2i.LEFT,Vector2i.RIGHT]
    for raw in base_walkable.keys():
        var cell: Vector2i=raw
        if cell.distance_squared_to(normal_spawn)<36:
            continue
        var open_neighbors: bool=true
        for delta in cardinal:
            if not base_walkable.has(cell+delta):
                open_neighbors=false
                break
        if open_neighbors:
            isolated=cell
            break
    _check(isolated.x>=0,"Harbor has no suitable connected floor tile for isolation QA")
    if isolated.x>=0:
        for delta in cardinal:
            world.blocked[isolated+delta]=true
        world.reachable_tiles.clear()
        var isolated_point: Vector2=Vector2(isolated*world.TILE)+Vector2(16,16)
        _check(not world._blocked(isolated_point),
            "Isolation QA did not leave the original checkpoint collision-free")
        _check(not world._walkable_tiles().has(isolated),
            "Isolation QA floor remains connected after sealing four neighbors")
        var rescued: Vector2=world._safe_return_outside(isolated_point)
        var rescued_cell: Vector2i=Vector2i(floori(rescued.x/world.TILE),floori(rescued.y/world.TILE))
        _check(world._walkable_tiles().has(rescued_cell) and not world._blocked(rescued),
            "Exterior return accepted isolated unreachable floor")
        # Real save-slot restore must refuse this same stale-but-passable tile.
        var checkpoint_game=GameScene.new()
        checkpoint_game.progress=state
        checkpoint_game.world=world
        checkpoint_game.world_router=registry
        state.rpg["world"]["player_checkpoint"]={
            "map_id":"map_coast_02","chapter":5,"indoor_building":"",
            "xy":[isolated_point.x,isolated_point.y]
        }
        world.hero.position=Vector2(normal_spawn*world.TILE)+Vector2(16,16)
        checkpoint_game._restore_world_position()
        var loaded_cell: Vector2i=Vector2i(floori(world.hero.position.x/world.TILE),
            floori(world.hero.position.y/world.TILE))
        _check(world._walkable_tiles().has(loaded_cell) and
            not world._blocked(world.hero.position),
            "Old checkpoint load placed hero on disconnected floor")
        _check(loaded_cell!=isolated,
            "Old disconnected checkpoint was incorrectly restored unchanged")
        state.rpg["world"].erase("player_checkpoint")
        checkpoint_game.free()
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
