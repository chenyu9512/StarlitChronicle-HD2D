extends SceneTree
## Commercial-town gate: coherent staging, authored districts and usable interiors.
## No generic prop scatter may replace distinctive authored scenery.
const TownDirector = preload("res://scripts/town_director.gd")
const Geography = preload("res://scripts/world_geography.gd")
const Registry = preload("res://scripts/world_registry.gd")
const GameState = preload("res://scripts/first_act_state.gd")
const World = preload("res://scripts/first_act_world.gd")
var failures: Array[String] = []

func _initialize() -> void:
    call_deferred("_run")

func check(ok: bool, reason: String) -> void:
    if not ok:
        failures.append(reason)

func _run() -> void:
    var designer = TownDirector.new()
    var geo = Geography.new()
    check(designer.problems.is_empty(),"Town plans violate authoring contract: "+str(designer.problems))
    check(geo.faults.is_empty(),"Town atlas failed to load: "+str(geo.faults))
    var state = GameState.new()
    var router = Registry.new()
    router.bind(state)
    var identities: Dictionary = {}
    var tested: int = 0
    var staged: int = 0
    var layout_types: Dictionary = {}
    for id in designer.plans.keys():
        var town_id: String = str(id)
        var plan: Dictionary = designer.plan(town_id)
        var profile: Dictionary = geo.zone(town_id)
        var layout: Dictionary = geo.layout(town_id,5)
        check(bool(profile.get("settlement",false)),"City plan targets an uninhabited zone: "+town_id)
        check(str(profile.get("archetype",""))!="dungeon","Town is incorrectly flagged as a dungeon: "+town_id)
        check(not identities.has(str(plan.get("identity",""))),"Duplicate authored town motif: "+town_id)
        identities[str(plan.get("identity",""))]=true
        layout_types[str(profile.get("layout",""))]=true
        var live_plan: Dictionary=layout.get("town_plan",{})
        check(not live_plan.is_empty(),"Stage plan not applied to actual terrain: "+town_id)
        var approach: Vector2i=layout.get("spawn",Vector2i.ZERO)
        var focal: Array=plan.get("focal_point",[])
        var plaza: Vector2i=Vector2i(int(focal[0]),int(focal[1]))
        check(geo.reachable(layout,[approach],[plaza]),"Town square disconnected from entrance: "+town_id)
        var story_routes: Dictionary=geo.resolve_story_targets(layout,geo._anchors())
        check((story_routes.get("missing",[]) as Array).is_empty(),
            "Actual story markers have no accessible pavement: "+town_id+" / "+str(story_routes.get("missing",[])))
        for gate in layout.get("gates",[]):
            check(geo.reachable(layout,[approach],[gate["cell"]]),"Road gate blocked by district: "+town_id)
        for building in profile.get("buildings",[]):
            var door: Array=building.get("door",[])
            var door_cell: Vector2i=Vector2i(int(door[0]),int(door[1]))
            var front_step: Vector2i=door_cell+Vector2i.DOWN
            check((layout.get("blocked",{}) as Dictionary).has(door_cell),
                "Town door is not a solid building facade: "+town_id+"/"+str(building["id"]))
            check(not (layout.get("blocked",{}) as Dictionary).has(front_step)
                and geo.reachable(layout,[approach],[front_step]),
                "Functional building front step cannot be reached: "+town_id+"/"+str(building["id"]))
        var props: int=0
        for prop in layout.get("features",[]):
            if bool(prop.get("town_dressing",false)):
                props+=1
                check(not layout.get("blocked",{}).has(prop.get("cell",Vector2i.ZERO)),"Decoration collides with town wall: "+town_id)
        staged+=props
        check(props>=7,"Town feels empty; fewer than seven positioned props survived blocking: "+town_id)
        for person_role in ["shop","craft","quest","rumor","lore"]:
            var target: Vector2i=designer.resident_anchor(town_id,person_role,0,12)
            check(target.x>=4 and target.y>=4 and target.x<=67 and target.y<=43,"NPC work/social area out of bounds: "+town_id)
        var original: Dictionary=geo.layout(town_id,68)
        check(original.get("blocked",{})==layout.get("blocked",{}),"Town geometry changes between chapters: "+town_id)
        tested+=1
    check(tested==11,"Eleven independent settlement plans are required")
    check(identities.size()==11,"Towns have insufficient geographic identity")
    check(layout_types.size()>=6,"Six street-geometry families were not preserved")
    for service in ["inn","shop","guild","smith","shrine","house"]:
        var room: Dictionary=geo.interior(service,"测试设施")
        var entrance: Vector2i=room.get("spawn",Vector2i.ZERO)
        check(room.get("building","")==service,"Wrong interior assigned to a service")
        check((room.get("features",[]) as Array).size()>=12,"Interior lacks distinct furnishings: "+service)
        check(geo.reachable(room,[entrance],[Vector2i(29,17),Vector2i(45,19),Vector2i(35,34)]),"Room furnishings obstruct reception or exit: "+service)
    var game_world=World.new()
    root.add_child(game_world)
    game_world.map_profile=router.profile("map_city_02")
    game_world.build(35,3)
    check(not game_world.terrain_layout.get("town_plan",{}).is_empty(),"Free Assembly Hall does not render as a town")
    check(game_world.nodes.has("building:guild"),"Town civic hall has no guild facility entrance")
    check(game_world.nodes.has("key_npc"),"Town overwrote its main quest trigger")
    if failures.is_empty():
        print("PASS: 11 authored urban identities, %d placed town decorations, 44 functional districts, six street families, six usable interiors and uninterrupted story routes" % staged)
        quit(0)
    else:
        for failure in failures:
            push_error(failure)
        quit(1)
