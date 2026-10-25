extends SceneTree
## Gameplay acceptance: authored world atlas -> physical sector -> buildings -> return.
const Geography = preload("res://scripts/world_geography.gd")
const Registry = preload("res://scripts/world_registry.gd")
const World = preload("res://scripts/first_act_world.gd")
const State = preload("res://scripts/first_act_state.gd")
const MapView = preload("res://scripts/map_view.gd")
var failures: Array[String] = []

func _initialize() -> void:
    call_deferred("_run")

func verify(test: bool,why: String) -> void:
    if not test:
        failures.append(why)

func _run() -> void:
    var geo = Geography.new()
    verify(geo.faults.is_empty(),"World atlas schema failure: "+str(geo.faults))
    verify(geo.zones.size()==42 and geo.regions.size()==8,"42 zones / 8 regions must be authored")
    var seen_positions: Dictionary = {}
    var settlement_count: int = 0
    var dungeon_count: int = 0
    var dungeon_shapes: Dictionary = {}
    var town_layouts: Dictionary = {}
    var playable_count: int = 0
    var all_checks: int = 0
    for key in geo.zones.keys():
        var spec: Dictionary = geo.zone(str(key))
        if not bool(spec.get("playable",false)):
            continue
        playable_count += 1
        var position: Array = spec.get("atlas",[])
        verify(position.size()==2,"Atlas position missing: "+str(key))
        var pos_string: String = str(position)
        verify(not seen_positions.has(pos_string),"Two areas overlap on the world chart: "+str(key))
        seen_positions[pos_string] = true
        var layout: Dictionary = geo.layout(str(key),1)
        var spawn: Vector2i = layout.get("spawn",Vector2i.ZERO)
        var targets: Array[Vector2i] = geo._anchors()
        verify(geo.reachable(layout,[spawn],targets),"Inaccessible story/quest/side marker in "+str(key))
        for gate in layout.get("gates",[]):
            targets.append(gate.get("cell",Vector2i.ZERO))
        verify(geo.reachable(layout,[spawn],targets),"Unreachable world border gate in "+str(key))
        var cells: Dictionary = layout.get("tiles",{})
        verify(cells.size() == 72*48,"Missing collision/ground cells: "+str(key))
        verify((layout.get("blocked",{}) as Dictionary).size() > 100,"No authored impassable terrain: "+str(key))
        verify(geo.layout(str(key),56).get("blocked",{})==layout.get("blocked",{}),"The same place regenerated different collisions on chapter change: "+str(key))
        if bool(spec.get("settlement",false)):
            settlement_count += 1
            town_layouts[str(spec.get("layout",""))] = true
            var plots: Array = spec.get("buildings",[])
            verify(plots.size()>=5,"Town has insufficient distinguishable buildings: "+str(key))
            for plot in plots:
                var door: Array = plot.get("door",[])
                var actual: Vector2i = Vector2i(int(door[0]),int(door[1]))
                verify(not (layout.get("blocked",{}) as Dictionary).has(actual),"Town doorway was blocked in "+str(key))
                verify(geo.reachable(layout,[spawn],[actual]),"Town building is inaccessible in "+str(key))
        if str(spec.get("archetype",""))=="dungeon":
            dungeon_count+=1
            dungeon_shapes[str((layout.get("blocked",{}) as Dictionary).hash())] = true
            verify((layout.get("blocked",{}) as Dictionary).size()>1300,"Dungeon lacks meaningful walls: "+str(key))
            verify((spec.get("dungeon_chambers",[]) as Array).size()>=7,"Missing authored chamber network: "+str(key))
            var important: Array[Vector2i] = [Vector2i(19,14),Vector2i(53,16),Vector2i(54,36)]
            verify(geo.reachable(layout,[spawn],important),"Rune switches or treasure are inaccessible in "+str(key))
        all_checks+=targets.size()
    verify(playable_count==40,"Exactly forty production zones excluding two prototypes")
    verify(settlement_count>=9,"World should have nine or more town/district sectors")
    verify(dungeon_count==8,"World should contain eight distinct large dungeons")
    verify(dungeon_shapes.size()==8,"Two dungeons accidentally share the same collision topology")
    verify(town_layouts.size()==6,"Settlement geography must employ all six street archetypes")
    # Twelve physically distinct, fully connected authored first-act interiors.
    var indoor_shapes: Dictionary = {}
    for town in ["map_coast_01","map_coast_02"]:
        for building in ["inn","shop","guild","smith","house","shrine"]:
            var indoor: Dictionary = geo.interior(building,building,town)
            verify(str(indoor.get("authored_source",""))=="v4","Missing physical V4 interior: "+town+" / "+building)
            var marks: Dictionary = indoor.get("interact_cells",{})
            var access: Array[Vector2i] = []
            for site in ["exit","service","storage"]:
                access.append(marks.get(site,Vector2i.ZERO))
            verify(geo.reachable(indoor,[indoor.get("spawn",Vector2i.ZERO)],access),"Inaccessible V4 interior service: "+town+" / "+building)
            var signature: String = str((indoor.get("blocked",{}) as Dictionary).hash())
            verify(not indoor_shapes.has(signature),"Duplicated V4 interior geography: "+town+" / "+building)
            indoor_shapes[signature]=true
    verify(indoor_shapes.size()==12,"Expected 12 unique first-act rooms")
    var state = State.new()
    var registry = Registry.new()
    registry.bind(state)
    verify(registry.validate_catalog().is_empty(),"World atlas lost linkage to quest routing")
    var world = World.new()
    root.add_child(world)
    world.map_profile = registry.profile()
    world.build(1,2)
    verify(world.layer.get_used_rect().size == Vector2i(72,48),"Runtime scene did not use the new playable 72x48 geography")
    verify(world.nodes.has("key_npc") and world.nodes.has("side_start"),"New world lost canonical quest interaction nodes")
    verify(world.nodes.has("exit:map_coast_02"),"Walkable inter-zone exit has not been created")
    verify(world.nodes.has("building:inn"),"Town is missing an enterable inn door")
    var outside: Vector2 = world.hero.position
    verify(world.enter_building("inn"),"Could not enter real walking interior")
    verify(str(world.terrain_layout.get("authored_source",""))=="v4","Morning Dew inn is not using authored room terrain")
    verify(world.nodes.has("interior_exit") and world.nodes.has("interior_storage"),"Interior is missing physical interactable objects")
    verify(not world.nodes.has("key_npc"),"Outside story NPC leaked into building interior")
    verify(not world._blocked(world.hero.position),"Indoor spawn is not passable")
    var inn_collision: Dictionary = world.terrain_layout.get("blocked",{}).duplicate()
    verify(world.leave_building(),"Could not leave building interior")
    verify(world.hero.position == outside,"Exterior return position not restored")
    verify(world.enter_building("shop"),"Could not enter the shop interior")
    verify(str(world.terrain_layout.get("authored_source",""))=="v4","Shop failed to load its distinct room layout")
    verify(world.terrain_layout.get("blocked",{})!=inn_collision,"Shop still uses inn's physical floorplan")
    verify(world.leave_building(),"Shop exit did not return to the overworld")
    var observed: Array[String] = []
    world.interacted.connect(func(id: String) -> void: observed.append(id))
    for id in geo.zones.keys():
        var spec: Dictionary = geo.zone(str(id))
        if not bool(spec.get("settlement",false)):
            continue
        world.map_profile = registry.profile(str(id))
        world.build(1,2)
        world.locked = false
        world.set_focus("")
        for story_id in ["key_npc","clue","witness","crisis","resolve"]:
            observed.clear()
            world.hero.position = world.nodes[story_id].position + Vector2(0,18)
            world.interact()
            verify(not observed.is_empty() and observed[-1] == story_id,"Town doorway overrode story interaction: "+str(id)+" / "+story_id)
    world.map_profile = registry.profile()
    world.build(1,2)
    var map = MapView.new()
    map.custom_minimum_size = Vector2(900,550)
    root.add_child(map)
    map.setup(world,registry,false)
    map.display_mode("world")
    map.size = Vector2(900,550)
    map.queue_redraw()
    await process_frame
    verify(map.map_points.size()==40,"World drawing must show forty explorable geographic pins (not prototypes)")
    map.display_mode("region")
    map.queue_redraw()
    await process_frame
    verify(map.map_points.size()==5,"Coast regional inset should show its five relevant map sectors")
    if failures.is_empty():
        print("PASS: 8 geographic biomes; %d playable 72x48 zones, %d town districts, %d dungeons, %d navigable quest+gate anchors, physical town interiors and 3-tier map navigation" % [playable_count,settlement_count,dungeon_count,all_checks])
        quit(0)
    else:
        for failure in failures:
            push_error(failure)
        quit(1)
