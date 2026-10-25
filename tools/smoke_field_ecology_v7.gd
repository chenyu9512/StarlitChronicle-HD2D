extends SceneTree
## Authored 21-map V7 field regression including reachability, weather, repeat rules, HP safety and save state.
const Ecology = preload("res://scripts/world_field_ecology.gd")
const Geography = preload("res://scripts/world_geography.gd")
const Registry = preload("res://scripts/world_registry.gd")
const World = preload("res://scripts/first_act_world.gd")
const State = preload("res://scripts/first_act_state.gd")
var errors: Array[String] = []

func check(ok: bool,why: String) -> void:
    if not ok:
        errors.append(why)

func _initialize() -> void:
    call_deferred("_run")

func _run() -> void:
    var ecology = Ecology.new()
    var geography = Geography.new()
    var registry = Registry.new()
    check(ecology.issues.is_empty(),"Authored field data invalid: "+str(ecology.issues))
    check(ecology.maps.size()==21,"Expected exactly 21 field sectors")
    var total: int=0
    for map_id in ecology.maps.keys():
        var id: String=str(map_id)
        var spec: Dictionary=ecology.config(id)
        var geo: Dictionary=geography.layout(id,5)
        var real_world=World.new()
        root.add_child(real_world)
        real_world.map_profile=registry.profile(id)
        real_world.build(5,3)
        var actual: Array[Vector2i]=[]
        for site in ecology.sites(id):
            total+=1
            var key: String="field:"+str(site.get("id",""))
            check(real_world.nodes.has(key),"Missing in-world field node: "+id+"/"+key)
            if real_world.nodes.has(key):
                var location: Vector2i=Vector2i(real_world.nodes[key].position/32.0)
                actual.append(location)
                check(not (geo.get("blocked",{}) as Dictionary).has(location),"Field node overlaps a physical wall: "+id+"/"+key)
        check(geography.reachable(geo,[geo.get("spawn",Vector2i.ZERO)],actual),"Field sites cannot be reached by traversing real terrain: "+id)
        check(real_world.nodes.has("wild_camp") and real_world.nodes.has("wild_cache"),"New ecology overwrote legacy wilderness: "+id)
        var state=State.new()
        state.new_game()
        var denied: Dictionary=ecology.interact(id,"cache",state,"clear",480,1)
        check(not bool(denied.get("changed",false)),"Secret cache could be exploited before opening: "+id)
        denied=ecology.interact(id,"gather",state,"clear",480,1)
        check(not bool(denied.get("changed",false)),"Harvest works without terrain scouting: "+id)
        var trial: Dictionary=ecology.interact(id,"trial",state,str(spec.get("challenge",{}).get("danger_weather","")),480,1)
        check(bool(trial.get("changed",false)),"Terrain hazard doesn't clear: "+id)
        for actor in state.actors:
            check(int(actor.get("hp",1))>=1,"Terrain hazard caused instant death: "+id)
        var trial_again: Dictionary=ecology.interact(id,"trial",state,"clear",480,1)
        check(not bool(trial_again.get("changed",false)),"Terrain HP cost can be repeated: "+id)
        var gathered: Dictionary=ecology.interact(id,"gather",state,str(spec.get("gather",{}).get("bonus_weather","")),480,1)
        check(int(gathered.get("reward",{}).get("amount",0))==2,"Weather harvesting should yield two supplies: "+id)
        var repeat: Dictionary=ecology.interact(id,"gather",state,"clear",481,1)
        check(not bool(repeat.get("changed",false)),"Harvest cooldown bypassed: "+id)
        var no_route: Dictionary=ecology.interact(id,"passage",state,"rain",720,1)
        if not bool(no_route.get("teleport",false)):
            var next_day: Dictionary=ecology.interact(id,"gather",state,"clear",480,2)
            check(bool(next_day.get("changed",false)),"Daily harvest did not respawn: "+id)
        var route: Dictionary=ecology.interact(id,"passage",state,"clear",480,2)
        check(bool(route.get("teleport",false)),"Field passage permanently blocked, even after two samples: "+id)
        var chest: Dictionary=ecology.interact(id,"cache",state,"clear",480,2)
        check(bool(chest.get("claimed",false)) and not (chest.get("reward",{}) as Dictionary).is_empty(),"Secret reward missing: "+id)
        var second: Dictionary=ecology.interact(id,"cache",state,"clear",480,3)
        check(not bool(second.get("changed",false)),"Duplicate secret treasure: "+id)
        check(ecology.completed(state,id)==4,"Field four-part ledger incomplete: "+id)
        var restored=State.new()
        check(restored.restore_snapshot(state._pack()),"Field save reload failed: "+id)
        check(bool(ecology.snapshot(restored,id).get("claimed",false)),"Field cache claim was not persisted: "+id)
        real_world.queue_free()
        await process_frame
    check(total==84,"Expected 84 new physical wilderness interactions, found "+str(total))
    if errors.is_empty():
        print("PASS: 21 distinct fields, 84 reachable anchors, nonlethal terrain challenges, weather movement factors, daily harvesting, hidden routes, one-time treasure, backward-compatible save")
        quit(0)
        return
    for error in errors:
        push_error(error)
    quit(1)
